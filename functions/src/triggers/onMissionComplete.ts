import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { COLLECTIONS } from "../utils/firestore";
import { calculateStats, SubjectMission } from "../utils/xpCalculator";

export const onMissionComplete = functions.firestore
  .document(`${COLLECTIONS.MISSIONS}/{uid}/daily/{date}`)
  .onUpdate(async (change, context) => {
    const uid = context.params.uid;
    const beforeData = change.before.data() || {};
    const afterData = change.after.data() || {};

    const db = admin.firestore();
    const userRef = db.collection(COLLECTIONS.USERS).doc(uid);

    const beforeSubjectMissions: SubjectMission[] = beforeData.subjectMissions || [];
    const afterSubjectMissions: SubjectMission[] = afterData.subjectMissions || [];

    const newlyCompletedSubjectMissions = afterSubjectMissions.filter((afterMission) => {
      const beforeMission = beforeSubjectMissions.find(
        (m) => m.subjectId === afterMission.subjectId,
      );
      return afterMission.status === "completed" &&
        (!beforeMission || beforeMission.status !== "completed");
    });

    const beforeFitnessMission = beforeData.fitnessMission;
    const afterFitnessMission = afterData.fitnessMission;
    const fitnessCompleted = afterFitnessMission?.status === "completed" &&
      beforeFitnessMission?.status !== "completed";

    const beforeStudyMission = beforeData.studyMission;
    const afterStudyMission = afterData.studyMission;
    const studyCompleted = afterStudyMission?.status === "completed" && beforeStudyMission?.status !== "completed";

    if (newlyCompletedSubjectMissions.length === 0 && !fitnessCompleted && !studyCompleted) {
      return null;
    }

    try {
      await db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) return;

        let totalXpToAdd = 0;

        for (const mission of newlyCompletedSubjectMissions) {
          if (mission.xpAwarded >= 0 && mission.xpAwarded <= 200) {
            totalXpToAdd += mission.xpAwarded;
          }
        }

        if (fitnessCompleted) {
          totalXpToAdd += 30;
        }

        if (studyCompleted) {
          const studyXp = afterStudyMission.xpAwarded || 0;
          if (studyXp >= 0 && studyXp <= 200) {
            totalXpToAdd += studyXp;
          }
        }

        const dailyMissionsSnapshot = await transaction.get(
          db.collection(COLLECTIONS.MISSIONS).doc(uid).collection("daily")
        );

        let allCompletedMissions: SubjectMission[] = [];
        dailyMissionsSnapshot.forEach((doc) => {
          const data = doc.data();
          const subMissions: SubjectMission[] = data.subjectMissions || [];
          allCompletedMissions = allCompletedMissions.concat(
            subMissions.filter((m) => m.status === "completed")
          );

          const studyMission = data.studyMission;
          if (
            studyMission?.status === "completed" &&
            typeof studyMission.subjectId === "string" &&
            typeof studyMission.xpAwarded === "number"
          ) {
            allCompletedMissions.push({
              subjectId: studyMission.subjectId,
              status: studyMission.status,
              xpAwarded: studyMission.xpAwarded,
            });
          }
        });

        const currentBattleIQ =
          (userDoc.data()?.stats?.battleIQ as number | undefined) ?? 0;
        const newStats = calculateStats(allCompletedMissions, currentBattleIQ);

        const updates = {
          xp: admin.firestore.FieldValue.increment(totalXpToAdd),
          stats: newStats,
          lastActive: admin.firestore.FieldValue.serverTimestamp(),
        };

        transaction.update(userRef, updates);
      });

      functions.logger.info(`Mission completion processed successfully for user ${uid}`);
    } catch (error) {
      functions.logger.error(`Error processing mission completion for user ${uid}`, error);
    }
    return null;
  });
