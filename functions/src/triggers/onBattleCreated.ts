import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";

/**
 * onBattleCreated – Cloud Function v2 Firestore trigger.
 *
 * Fires whenever a new battle is created:
 *   /battles/{battleId}
 *
 * Responsibilities:
 *  1. Sends FCM push notification to the challenged student.
 *  2. Logs notification event for tracking.
 */
export const onBattleCreated = functions.firestore.onDocumentCreated(
  "battles/{battleId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data();
    const challengerName = data.challengerName ?? "A classmate";
    const challengedUid = data.challengedUid;
    const battleId = event.params.battleId;

    if (!challengedUid) return;

    const db = admin.firestore();

    try {
      // Look up user's FCM push token if available
      const userDoc = await db.collection("users").doc(challengedUid).get();
      if (!userDoc.exists) return;

      const userData = userDoc.data() ?? {};
      // Current clients store a token array so a student can receive alerts on
      // more than one device. Keep the legacy singular field for older users.
      const fcmTokens = Array.isArray(userData.fcmTokens) ?
        userData.fcmTokens.filter((token): token is string => typeof token === "string") :
        typeof userData.fcmToken === "string" ?
          [userData.fcmToken] :
          [];

      if (fcmTokens.length > 0) {
        await admin.messaging().sendEachForMulticast({
          tokens: fcmTokens,
          notification: {
            title: "⚔️ New Battle Challenge!",
            body: `${challengerName} has challenged you to an RPG Stat Duel!`,
          },
          data: {
            type: "duel",
            id: battleId,
          },
        });
        functions.logger.info(
          `[onBattleCreated] Push notification dispatched for battle ${battleId} to ${challengedUid}`,
        );
      }

      // Record in-app notification for the Hunter Notification Bell
      await db
        .collection("users")
        .doc(challengedUid)
        .collection("notifications")
        .add({
          type: "incomingDuel",
          title: "⚔️ New Duel Challenge!",
          body: `${challengerName} has challenged you to an RPG Stat Duel!`,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          isRead: false,
        });
    } catch (err) {
      functions.logger.error(
        `[onBattleCreated] Error sending push notification for battle ${battleId}:`,
        err,
      );
    }
  },
);
