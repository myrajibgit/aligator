import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";

// Regex deny-list: extend as needed
const PROFANITY_PATTERN =
  /\b(spam|hate|kill|abuse|bully|harass|nude|porn|scam|fraud)\b/gi;

interface MessageData {
  text?: string;
  senderUid?: string;
  reported?: boolean;
}

/**
 * onMessageCreated – Cloud Function v2 Firestore trigger.
 *
 * Fires whenever a new message is written to:
 *   /chats/{chatId}/messages/{messageId}
 *
 * Responsibilities:
 *  1. Screen the message text against a profanity/deny-list regex.
 *  2. If flagged, auto-report and soft-delete the message text.
 *  3. Log the incident in /moderationReports for admin review.
 */
export const onMessageCreated = functions.firestore.onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data() as MessageData;
    const text = data.text ?? "";
    const chatId = event.params.chatId;
    const messageId = event.params.messageId;

    if (!PROFANITY_PATTERN.test(text)) return; // Clean message — nothing to do

    const db = admin.firestore();
    const batch = db.batch();

    // 1. Soft-delete: replace text with a moderation notice
    batch.update(snap.ref, {
      text: "[Message removed by moderation]",
      reported: true,
    });

    // 2. Write auto-report document
    const reportRef = db.collection("moderationReports").doc();
    batch.set(reportRef, {
      reporterUid: "system_automod",
      chatId,
      messageId,
      messageText: text,
      senderUid: data.senderUid ?? "unknown",
      category: "Auto-flagged",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await batch.commit();
    functions.logger.info(
      `[AutoMod] Flagged message ${messageId} in chat ${chatId}`,
    );
  },
);
