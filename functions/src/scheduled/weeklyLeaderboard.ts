import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { COLLECTIONS } from "../utils/firestore";

interface LeaderboardUser {
  uid: string;
  displayName: string | null;
  username: string | null;
  photoUrl: string | null;
  xp: number;
  stats: admin.firestore.DocumentData;
}

export const weeklyLeaderboard = functions.pubsub
  .schedule("0 0 * * 1") // Every Monday at 00:00 UTC
  .timeZone("UTC")
  .onRun(async () => {
    const db = admin.firestore();

    try {
      const usersSnapshot = await db.collection(COLLECTIONS.USERS)
        .orderBy("xp", "desc")
        .limit(100)
        .get();

      if (usersSnapshot.empty) {
        functions.logger.info("No users found for leaderboard.");
        return null;
      }

      const weekKey = getWeekKey(new Date());

      const classGroups: Record<string, LeaderboardUser[]> = {};

      usersSnapshot.forEach((doc) => {
        const data = doc.data();
        const schoolId = data.schoolId;
        const classId = data.classId;

        if (schoolId && classId) {
          const key = classId;
          if (!classGroups[key]) {
            classGroups[key] = [];
          }
          classGroups[key].push({
            uid: doc.id,
            displayName: data.displayName || null,
            username: data.username || null,
            photoUrl: data.photoUrl || null,
            xp: data.xp || 0,
            stats: data.stats || {},
          });
        }
      });

      const batch = db.batch();

      for (const [classId, users] of Object.entries(classGroups)) {
        users.sort((a, b) => b.xp - a.xp);

        const entries = users.map((u, index) => ({
          ...u,
          rank: index + 1,
        }));

        const leaderboardRef = db
          .collection(COLLECTIONS.LEADERBOARDS)
          .doc(classId)
          .collection("weekly")
          .doc(weekKey);

        batch.set(leaderboardRef, { entries });

        // Award Top 3 podium bonuses and notifications
        for (let i = 0; i < Math.min(users.length, 3); i++) {
          const topUser = users[i];
          const rankPos = i + 1;
          const bonusXp = rankPos === 1 ? 200 : rankPos === 2 ? 100 : 50;
          const medal = rankPos === 1 ? "🥇" : rankPos === 2 ? "🥈" : "🥉";

          const userRef = db.collection(COLLECTIONS.USERS).doc(topUser.uid);
          batch.update(userRef, {
            xp: admin.firestore.FieldValue.increment(bonusXp),
          });

          const notifRef = userRef.collection("notifications").doc();
          batch.set(notifRef, {
            type: "levelUp",
            title: `${medal} WEEKLY PODIUM FINISH (#${rankPos})!`,
            body: `Outstanding performance, Hunter! You secured #${rankPos} in your class this week and earned +${bonusXp} XP!`,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            isRead: false,
          });
        }
      }

      await batch.commit();
      functions.logger.info(`Weekly leaderboard completed for week: ${weekKey}`);
    } catch (error) {
      functions.logger.error("Error generating weekly leaderboard", error);
    }

    return null;
  });

/**
 * Returns the ISO week identifier used as a stable leaderboard document ID.
 * @param {Date} date Date to convert.
 * @return {string} ISO week identifier.
 */
function getWeekKey(date: Date): string {
  const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
  const dayNum = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const weekNo = Math.ceil((((d.getTime() - yearStart.getTime()) / 86400000) + 1) / 7);
  return `${d.getUTCFullYear()}-W${weekNo.toString().padStart(2, "0")}`;
}
