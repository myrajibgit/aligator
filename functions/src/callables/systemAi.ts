import * as https from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { defineSecret } from "firebase-functions/params";

const geminiApiKey = defineSecret("GEMINI_API_KEY");

interface SystemAiRequest {
  query: string;
  hunterContext?: {
    rank?: string;
    level?: number;
    intelligence?: number;
    fatigue?: number;
    streak?: number;
    displayName?: string;
  };
}

interface SystemAiResponse {
  success: boolean;
  reply: string;
  source: "gemini" | "heuristic";
}

export const askSystemAi = https.onCall(
  {
    secrets: [geminiApiKey],
    timeoutSeconds: 60,
    memory: "256MiB",
    region: "us-central1",
  },
  async (request): Promise<SystemAiResponse> => {
    if (!request.auth) {
      throw new https.HttpsError("unauthenticated", "You must be signed in to query The System.");
    }

    const data = request.data as SystemAiRequest;
    const query = (data?.query || "").trim();
    if (!query) {
      throw new https.HttpsError("invalid-argument", "Query text cannot be empty.");
    }

    const hunter = data.hunterContext || {};
    const hunterDesc = `Hunter: ${hunter.displayName || "Unknown"}, Rank: ${hunter.rank || "E-Rank"}, ` +
      `Level: ${hunter.level || 1}, INT: ${hunter.intelligence || 20}, Fatigue: ${hunter.fatigue || 0}%, Streak: ${hunter.streak || 0} days.`;

    // Attempt Gemini Generation
    try {
      const apiKey = geminiApiKey.value();
      if (apiKey && apiKey.length > 5) {
        // eslint-disable-next-line new-cap
        const genAI = new GoogleGenerativeAI(apiKey);
        const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });

        const systemPrompt =
          "You are 'The System', the holographic A.I. interface from Solo-Leveling that guides and cultivates the player into the Apex Monarch. " +
          "Your current user is a high school / university student Hunter studying academic subjects (Mathematics, Physics, Chemistry, Biology, Computer Science, Literature) and physical training.\n\n" +
          "Rules:\n" +
          "1. Speak in a cool, robotic yet encouraging Solo-Leveling System HUD persona.\n" +
          "2. Use bracketed System tags like [SYSTEM NOTICE], [COGNITIVE ANALYSIS], [STRATEGIC DIRECTIVE], or [TACTICAL BRIEFING].\n" +
          "3. When answering academic questions, be mathematically and scientifically precise, clear, and easy to understand.\n" +
          "4. Keep explanations concise (150-250 words max) so they fit nicely on mobile screens.\n" +
          "5. Incorporate their hunter stats if relevant: " + hunterDesc + "\n";

        const result = await model.generateContent([
          { text: systemPrompt },
          { text: `Hunter query: "${query}"` },
        ]);

        const text = result.response.text().trim();
        if (text) {
          return {
            success: true,
            reply: text,
            source: "gemini",
          };
        }
      }
    } catch (err) {
      logger.warn("Gemini API call failed or key not set, falling back to heuristic engine:", err);
    }

    // Heuristic Engine Fallback
    const heuristicReply = generateHeuristicReply(query, hunter);
    return {
      success: true,
      reply: heuristicReply,
      source: "heuristic",
    };
  }
);

function generateHeuristicReply(
  query: string,
  hunter: { rank?: string; level?: number; displayName?: string },
): string {
  const q = query.toLowerCase();

  if (q.includes("derivative") || q.includes("calculus") || q.includes("integral") || q.includes("math")) {
    return (
      "[SYSTEM COGNITIVE ANALYSIS // MATHEMATICS PROTOCOL]\n\n" +
      "• Calculus Core Principle: The derivative d/dx[f(x)] represents the instantaneous rate of change (tangent slope).\n" +
      "• Key Rules:\n" +
      "  - Power Rule: d/dx(xⁿ) = n·xⁿ⁻¹\n" +
      "  - Product Rule: (u·v)' = u'v + uv'\n" +
      "  - Chain Rule: d/dx[f(g(x))] = f'(g(x))·g'(x)\n\n" +
      "[TACTICAL DIRECTIVE]: Practice 5 differentiation problems in your daily subject mission to solidify INT power."
    );
  }

  if (q.includes("newton") || q.includes("physics") || q.includes("force") || q.includes("energy") || q.includes("velocity")) {
    return (
      "[SYSTEM COGNITIVE ANALYSIS // PHYSICS DYNAMICS]\n\n" +
      "• Newton's 3 Laws of Motion:\n" +
      "  1. Inertia: An object remains in uniform motion unless acted upon by a net external force (ΣF = 0).\n" +
      "  2. Momentum: Force equals rate of change of momentum (F = m·a).\n" +
      "  3. Reciprocity: For every action, there is an equal and opposite reaction (F_AB = -F_BA).\n\n" +
      "[TACTICAL DIRECTIVE]: Kinematics mastery directly enhances your Agility (AGI) and Sense (SEN) stat scaling."
    );
  }

  if (q.includes("cell") || q.includes("dna") || q.includes("biology") || q.includes("mitochondria") || q.includes("mitosis")) {
    return (
      "[SYSTEM COGNITIVE ANALYSIS // CELLULAR BIOLOGY]\n\n" +
      "• Cellular Energetics: Mitochondria generate cellular ATP via oxidative phosphorylation and the Krebs cycle.\n" +
      "• Genetics: DNA replicates semi-conservatively using Helicase (unwinding) and DNA Polymerase (synthesis 5'→3').\n" +
      "• Mitosis Stages: Prophase → Metaphase (equatorial align) → Anaphase (sister chromatid split) → Telophase.\n\n" +
      "[TACTICAL DIRECTIVE]: Log this data in your AI Study Notes Verification to expand your Hunter Grimoire."
    );
  }

  if (q.includes("pomodoro") || q.includes("study") || q.includes("focus") || q.includes("technique") || q.includes("exam")) {
    return (
      "[SYSTEM PROTOCOL // DEEP FOCUS STRATEGY]\n\n" +
      "1. Enter 25-minute Pomodoro protocol with zero distractions (app switching triggers penalty flags).\n" +
      "2. Apply Active Recall: Close the textbook and write down the key concepts from memory.\n" +
      "3. Take a 5-minute cognitive reset before initiating the next focus block.\n\n" +
      "[SYSTEM BONUS]: Equipping the 'Orb of Avarice' from your Monarch's Vault yields +30% Focus Session XP."
    );
  }

  if (q.includes("rank") || q.includes("level") || q.includes("ascension") || q.includes("monarch") || q.includes("xp")) {
    return (
      `[SYSTEM STATUS REPORT // ASCENSION PROTOCOL]\n\n` +
      `Hunter ${hunter.displayName || "Player"}, your current rank is ${hunter.rank || "E-Rank"} (Level ${hunter.level || 1}).\n` +
      "• XP Scaling: Each level requires 200 XP.\n" +
      "• Daily Quests Yield: Subject Quizzes (80 XP) + Fitness Reps (30 XP) + Study Verification (50 XP) + Daily Crate (30-60 XP).\n" +
      "• Active Streaks unlock multipliers from 1.1x up to 2.0x.\n\n" +
      "[DIRECTIVE]: Execute all daily quests today to protect your awakening streak from resetting at midnight."
    );
  }

  return (
    `[SYSTEM QUERY RESOLUTION // STATUS: NOMINAL]\n\n` +
    `Query: "${query}"\n\n` +
    "The System has processed your inquiry. To maximize retention and stat gains, maintain balance between daily STEM quiz practice and physical conditioning. Every challenge overcome brings you one step closer to S-Rank sovereignty."
  );
}
