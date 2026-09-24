import * as https from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { GoogleGenerativeAI, Part } from "@google/generative-ai";
import { defineSecret } from "firebase-functions/params";

// ─── Secret: Gemini API key stored in Firebase Secret Manager ────────────────
// To set: firebase functions:secrets:set GEMINI_API_KEY
const geminiApiKey = defineSecret("GEMINI_API_KEY");

// ─── Request / Response types ─────────────────────────────────────────────────

interface VerifyStudyRequest {
  imageBase64: string;
  mimeType: string; // "image/jpeg" | "image/png" | "image/webp"
  subjectId: string;
}

interface TopicCoverage {
  completedPercent: number;
  topicsCovered: string[];
  topicsRemaining: string[];
}

interface VerifyStudyResponse {
  success: boolean;
  extractedText?: string;
  coverage?: TopicCoverage;
  matchedChapterId?: string;
  matchedChapterName?: string;
  syllabusAvailable: boolean;
  error?: string;
}

// ─── Constants ────────────────────────────────────────────────────────────────

const GEMINI_MODEL = "gemini-1.5-flash";
const DAILY_QUOTA_FIELD = "studyMission";
const getTodayKey = () => new Date().toISOString().slice(0, 10); // "2026-09-13"
const MAX_IMAGE_BASE64_LENGTH = 9 * 1024 * 1024;
const MAX_DAILY_VERIFICATION_ATTEMPTS = 12;
const ALLOWED_IMAGE_MIME_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);

// ─── Cloud Function ───────────────────────────────────────────────────────────

export const verifyStudyNotes = https.onCall(
  {
    secrets: [geminiApiKey],
    timeoutSeconds: 120,
    memory: "512MiB",
    region: "us-central1",
  },
  async (request): Promise<VerifyStudyResponse> => {
    // ── Auth guard ────────────────────────────────────────────────────────────
    if (!request.auth) {
      throw new https.HttpsError(
        "unauthenticated",
        "You must be signed in to verify your study session."
      );
    }

    const uid = request.auth.uid;
    const data = request.data as VerifyStudyRequest;

    if (typeof data.imageBase64 !== "string" || typeof data.subjectId !== "string" ||
      !data.imageBase64 || !data.subjectId) {
      throw new https.HttpsError(
        "invalid-argument",
        "imageBase64 and subjectId are required."
      );
    }
    if (data.imageBase64.length > MAX_IMAGE_BASE64_LENGTH) {
      throw new https.HttpsError("invalid-argument", "Image is too large. Please use a smaller photo.");
    }
    if (!ALLOWED_IMAGE_MIME_TYPES.has(data.mimeType || "image/jpeg")) {
      throw new https.HttpsError("invalid-argument", "Unsupported image format.");
    }

    const db = admin.firestore();
    const storage = admin.storage().bucket();
    const todayKey = getTodayKey();

    // Ensure callers can only spend AI verification capacity on subjects in
    // their own course plan, then rate-limit expensive model requests.
    const userDoc = await db.collection("users").doc(uid).get();
    const enrolledSubjects: string[] = userDoc.data()?.subjectIds || [];
    if (!userDoc.exists || !enrolledSubjects.includes(data.subjectId)) {
      throw new https.HttpsError("permission-denied", "This subject is not in your study plan.");
    }
    const usageRef = db.collection("studyVerificationUsage").doc(uid).collection("daily").doc(todayKey);
    await db.runTransaction(async (transaction) => {
      const usageDoc = await transaction.get(usageRef);
      const attempts = (usageDoc.data()?.attempts as number | undefined) || 0;
      if (attempts >= MAX_DAILY_VERIFICATION_ATTEMPTS) {
        throw new https.HttpsError(
          "resource-exhausted",
          "You have reached today's note-verification limit. Please try again tomorrow.",
        );
      }
      transaction.set(usageRef, {
        attempts: attempts + 1,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    });

    // ── Anti-cheat: daily quota check ─────────────────────────────────────────
    try {
      const missionDoc = await db
        .collection("missions")
        .doc(uid)
        .collection("daily")
        .doc(todayKey)
        .get();

      if (missionDoc.exists) {
        const missionData = missionDoc.data() || {};
        const studyMission = missionData[DAILY_QUOTA_FIELD];
        if (
          studyMission?.status === "completed" &&
          studyMission?.subjectId === data.subjectId
        ) {
          return {
            success: false,
            syllabusAvailable: false,
            error:
              "Daily quota reached: You have already verified a study session for this subject today.",
          };
        }
      }
    } catch (e) {
      // Non-fatal: proceed if quota check fails
      logger.warn("Quota check failed, proceeding:", e);
    }

    // ── Initialize Gemini ─────────────────────────────────────────────────────
    // eslint-disable-next-line new-cap
    const genAI = new GoogleGenerativeAI(geminiApiKey.value());
    const model = genAI.getGenerativeModel({ model: GEMINI_MODEL });

    // ── Step 1: Extract text from student's photo ─────────────────────────────
    let extractedText = "";
    try {
      const imagePart: Part = {
        inlineData: {
          mimeType: data.mimeType || "image/jpeg",
          data: data.imageBase64,
        },
      };

      const ocrResult = await model.generateContent([
        imagePart,
        {
          text: "Read everything written in this image (handwritten or printed notes). " +
            "Return ONLY the raw text you see, preserving structure and formatting. " +
            "No commentary, no explanation.",
        },
      ]);

      extractedText = ocrResult.response.text().trim();
    } catch (e) {
      logger.error("Gemini OCR failed:", e);
      return {
        success: false,
        syllabusAvailable: false,
        error: "Could not read the photo. Please try a clearer image.",
      };
    }

    if (!extractedText || extractedText.length < 20) {
      return {
        success: false,
        syllabusAvailable: false,
        error:
          "No text detected in the image. Please capture a clear photo of your notes.",
      };
    }

    // ── Step 2: Fetch admin-uploaded syllabus PDF from Firebase Storage ────────
    let syllabusAvailable = false;
    let syllabusBase64 = "";

    try {
      const syllabusPath = `syllabi/${data.subjectId}/textbook.pdf`;
      const file = storage.file(syllabusPath);
      const [exists] = await file.exists();

      if (exists) {
        const [syllabusBuffer] = await file.download();
        syllabusBase64 = syllabusBuffer.toString("base64");
        syllabusAvailable = true;
      }
    } catch (e) {
      logger.warn(
        `Syllabus PDF not found for subject ${data.subjectId}:`,
        e
      );
      syllabusAvailable = false;
    }

    // ── Step 3: Compare notes vs syllabus (or match chapter via keywords) ──────
    let coverage: TopicCoverage = {
      completedPercent: 0,
      topicsCovered: [],
      topicsRemaining: [],
    };

    let matchedChapterId: string | undefined;
    let matchedChapterName: string | undefined;

    if (syllabusAvailable && syllabusBase64) {
      // Full Gemini PDF + notes comparison
      try {
        const pdfPart: Part = {
          inlineData: {
            mimeType: "application/pdf",
            data: syllabusBase64,
          },
        };

        const comparisonPrompt = `You are an educational assessment AI.

STUDENT'S NOTES (extracted from their photo):
---
${extractedText.slice(0, 6000)}
---

The attached PDF is the course syllabus or textbook for subject: ${data.subjectId}.

Your task:
1. Break the PDF into a list of top-level topics/chapters/sections.
2. Determine which topics are clearly reflected in the student's notes ("covered").
3. List topics the student has NOT covered ("remaining").
4. Estimate overall completion percentage (0-100).
5. Also identify the MOST SPECIFIC chapter/topic from the PDF that best matches the student's notes.

Respond with ONLY valid JSON, no markdown fences, no commentary:
{
  "completed_percent": <integer 0-100>,
  "topics_covered": ["topic1", "topic2"],
  "topics_remaining": ["topic3", "topic4"],
  "best_chapter_id": "<slug or number>",
  "best_chapter_name": "<full chapter name>"
}`;

        const comparisonResult = await model.generateContent([
          pdfPart,
          { text: comparisonPrompt },
        ]);

        const raw = comparisonResult.response.text().trim();
        const cleaned = raw
          .replace(/^```json\s*/i, "")
          .replace(/^```\s*/i, "")
          .replace(/```\s*$/i, "")
          .trim();

        const parsed = JSON.parse(cleaned);
        coverage = {
          completedPercent: Math.min(100, Math.max(0, parsed.completed_percent || 0)),
          topicsCovered: parsed.topics_covered || [],
          topicsRemaining: parsed.topics_remaining || [],
        };
        matchedChapterId = parsed.best_chapter_id;
        matchedChapterName = parsed.best_chapter_name;
      } catch (e) {
        logger.error("Gemini syllabus comparison failed:", e);
        // Fall through — use keyword chapter matching below
      }
    }

    // ── Fallback: match chapter via Firestore keywords if PDF unavailable ──────
    if (!syllabusAvailable || !matchedChapterId) {
      try {
        const chaptersSnap = await db
          .collection("questionBank")
          .doc(data.subjectId)
          .collection("chapters")
          .get();

        const lowerText = extractedText.toLowerCase();
        let bestChapterId = "";
        let bestChapterName = "";
        let bestScore = 0;

        for (const doc of chaptersSnap.docs) {
          const chData = doc.data();
          const keywords: string[] = chData.keywords || [];
          let hits = 0;
          for (const kw of keywords) {
            if (lowerText.includes(kw.toLowerCase())) hits++;
          }
          const score = keywords.length > 0 ? hits / keywords.length : 0;
          if (score > bestScore) {
            bestScore = score;
            bestChapterId = doc.id;
            bestChapterName = chData.name || doc.id;
          }
        }

        if (bestScore >= 0.25 && bestChapterId) {
          matchedChapterId = bestChapterId;
          matchedChapterName = bestChapterName;
          coverage = {
            completedPercent: Math.round(bestScore * 100),
            topicsCovered: [bestChapterName],
            topicsRemaining: [],
          };
        } else {
          return {
            success: false,
            syllabusAvailable: false,
            extractedText,
            error:
              "Could not identify a chapter from your notes with sufficient confidence. " +
              "Try capturing more of the page text.",
          };
        }
      } catch (e) {
        logger.error("Chapter keyword matching failed:", e);
        return {
          success: false,
          syllabusAvailable: false,
          error: "Chapter matching failed. Please try again.",
        };
      }
    }

    // ── Step 4: Record anti-cheat image hash in Firestore ─────────────────────
    try {
      // Lightweight hash: use first 32 bytes + length as fingerprint
      const hashSeed = data.imageBase64.slice(0, 64) + data.imageBase64.length;
      let h = 0x811c9dc5;
      for (let i = 0; i < hashSeed.length; i++) {
        h = ((h ^ hashSeed.charCodeAt(i)) * 0x01000193) >>> 0;
      }
      const imageHash = `${data.imageBase64.length.toString(16)}_${h.toString(16)}`;

      const hashDocRef = db
        .collection("users")
        .doc(uid)
        .collection("studyHashes")
        .doc(imageHash);

      const hashDoc = await hashDocRef.get();
      if (hashDoc.exists) {
        return {
          success: false,
          syllabusAvailable,
          error:
            "Duplicate photo detected: This image was already used for a previous study verification.",
        };
      }

      // Record hash (will be finalized after quiz pass)
      await hashDocRef.set({
        subjectId: data.subjectId,
        chapterId: matchedChapterId,
        date: todayKey,
        pending: true, // finalized only after quiz pass
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (e) {
      logger.warn("Hash recording failed:", e);
    }

    // ── Return successful verification result ──────────────────────────────────
    return {
      success: true,
      extractedText,
      coverage,
      matchedChapterId,
      matchedChapterName,
      syllabusAvailable,
    };
  }
);
