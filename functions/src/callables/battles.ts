import * as admin from "firebase-admin";
import * as functions from "firebase-functions";

type UserData = FirebaseFirestore.DocumentData;

const battles = () => admin.firestore().collection("battles");
const users = () => admin.firestore().collection("users");

/**
 * Returns the authenticated caller or rejects anonymous requests.
 * @param {functions.https.CallableContext} context Callable context.
 * @return {string} Authenticated user id.
 */
function requiredAuth(context: functions.https.CallableContext): string {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in to use battles.");
  }
  return context.auth.uid;
}

/**
 * Safely reads an optional string supplied by Firestore data.
 * @param {unknown} value Candidate value.
 * @param {string} fallback Value used when candidate is not a string.
 * @return {string} Normalized string.
 */
function stringValue(value: unknown, fallback = ""): string {
  return typeof value === "string" ? value : fallback;
}

/**
 * Safely reads an integer-like numeric stat.
 * @param {unknown} value Candidate value.
 * @return {number} Rounded numeric value, or zero.
 */
function numberValue(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) ? Math.round(value) : 0;
}

/**
 * Converts an unknown value into a string-only list.
 * @param {unknown} value Candidate value.
 * @return {string[]} String values only.
 */
function stringList(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((item): item is string => typeof item === "string") : [];
}

/**
 * Checks that a profile is ready to participate in a battle.
 * @param {UserData} user Student profile document.
 * @return {boolean} Whether the profile can battle.
 */
function isEligibleProfile(user: UserData): boolean {
  return user.onboardingComplete === true &&
    typeof user.schoolId === "string" && user.schoolId.length > 0 &&
    typeof user.classId === "string" && user.classId.length > 0;
}

/**
 * Determines whether a student currently qualifies for cross-school battles.
 * @param {string} uid Student id.
 * @param {string} classId Student class id.
 * @return {Promise<boolean>} Whether the student is a Scout.
 */
async function isScout(uid: string, classId: string): Promise<boolean> {
  const ranking = await users().where("classId", "==", classId).orderBy("xp", "desc").get();
  const rank = ranking.docs.findIndex((doc) => doc.id === uid) + 1;
  if (rank < 1) return false;
  const topTenPercent = Math.max(1, Math.ceil(ranking.size * 0.1));
  return rank <= topTenPercent || (ranking.size < 20 && rank <= 3);
}

/** Creates a challenge from server-side profiles, never from client-provided stats. */
export const createBattle = functions.https.onCall(async (data, context) => {
  const challengerUid = requiredAuth(context);
  const challengedUid = stringValue(data?.challengedUid);
  if (!challengedUid || challengedUid === challengerUid) {
    throw new functions.https.HttpsError("invalid-argument", "Choose another student to challenge.");
  }

  const [challengerDoc, challengedDoc] = await Promise.all([
    users().doc(challengerUid).get(),
    users().doc(challengedUid).get(),
  ]);
  if (!challengerDoc.exists || !challengedDoc.exists) {
    throw new functions.https.HttpsError("not-found", "Student profile not found.");
  }

  const challenger = challengerDoc.data()!;
  const challenged = challengedDoc.data()!;
  if (!isEligibleProfile(challenger) || !isEligibleProfile(challenged)) {
    throw new functions.https.HttpsError("failed-precondition", "Both students must finish onboarding first.");
  }

  const sameClass = challenger.schoolId === challenged.schoolId && challenger.classId === challenged.classId;
  if (!sameClass) {
    const canScout = challenger.area === challenged.area && await isScout(challengerUid, challenger.classId);
    if (!canScout) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Cross-school challenges require Scout status in your area.",
      );
    }
  }

  const weekAgo = admin.firestore.Timestamp.fromDate(new Date(Date.now() - 7 * 24 * 60 * 60 * 1000));
  const [forward, reverse] = await Promise.all([
    battles().where("challengerUid", "==", challengerUid)
      .where("challengedUid", "==", challengedUid)
      .where("createdAt", ">=", weekAgo).get(),
    battles().where("challengerUid", "==", challengedUid)
      .where("challengedUid", "==", challengerUid)
      .where("createdAt", ">=", weekAgo).get(),
  ]);
  if (forward.size + reverse.size >= 2) {
    throw new functions.https.HttpsError("resource-exhausted", "You can battle the same student only twice per week.");
  }

  const battleRef = battles().doc();
  await battleRef.set({
    challengerUid,
    challengerName: stringValue(challenger.displayName, "Student"),
    challengerPhotoUrl: challenger.photoUrl ?? null,
    challengedUid,
    challengedName: stringValue(challenged.displayName, "Student"),
    challengedPhotoUrl: challenged.photoUrl ?? null,
    schoolId: stringValue(challenger.schoolId),
    classId: stringValue(challenger.classId),
    status: "pending",
    rounds: [],
    winnerUid: null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    completedAt: null,
  });
  return { battleId: battleRef.id };
});

/** Lets only the challenged student decline an outstanding challenge. */
export const declineBattle = functions.https.onCall(async (data, context) => {
  const uid = requiredAuth(context);
  const battleId = stringValue(data?.battleId);
  if (!battleId) throw new functions.https.HttpsError("invalid-argument", "battleId is required.");

  const battleRef = battles().doc(battleId);
  await admin.firestore().runTransaction(async (tx) => {
    const battleDoc = await tx.get(battleRef);
    if (!battleDoc.exists) throw new functions.https.HttpsError("not-found", "Battle not found.");
    const battle = battleDoc.data()!;
    if (battle.challengedUid !== uid || battle.status !== "pending") {
      throw new functions.https.HttpsError("permission-denied", "This challenge can no longer be declined.");
    }
    tx.update(battleRef, { status: "declined", completedAt: admin.firestore.FieldValue.serverTimestamp() });
  });
  return { battleId };
});

/** Resolves the three rounds and applies rewards atomically on the server. */
export const resolveBattle = functions.https.onCall(async (data, context) => {
  const uid = requiredAuth(context);
  const battleId = stringValue(data?.battleId);
  if (!battleId) throw new functions.https.HttpsError("invalid-argument", "battleId is required.");

  const battleRef = battles().doc(battleId);
  await admin.firestore().runTransaction(async (tx) => {
    const battleDoc = await tx.get(battleRef);
    if (!battleDoc.exists) throw new functions.https.HttpsError("not-found", "Battle not found.");
    const battle = battleDoc.data()!;
    if (battle.challengedUid !== uid) {
      throw new functions.https.HttpsError("permission-denied", "Only the challenged student can accept this battle.");
    }
    if (battle.status !== "pending") return;

    const challengerRef = users().doc(stringValue(battle.challengerUid));
    const challengedRef = users().doc(uid);
    const [challengerDoc, challengedDoc] = await Promise.all([
      tx.get(challengerRef),
      tx.get(challengedRef),
    ]);
    if (!challengerDoc.exists || !challengedDoc.exists) {
      throw new functions.https.HttpsError("not-found", "A student profile is missing.");
    }
    const challenger = challengerDoc.data()!;
    const challenged = challengedDoc.data()!;
    const challengerStats = challenger.stats ?? {};
    const challengedStats = challenged.stats ?? {};
    const challengerSubjects = stringList(challenger.subjectIds);
    const challengedSubjects = stringList(challenged.subjectIds);
    const commonSubjects = challengerSubjects.filter((subject) => challengedSubjects.includes(subject));
    let subject = challengerSubjects[0] ?? "general";
    if (commonSubjects.length > 0) {
      subject = commonSubjects[Math.floor(Math.random() * commonSubjects.length)];
    }
    const challengerSubjectStats = challengerStats.subjectStats ?? {};
    const challengedSubjectStats = challengedStats.subjectStats ?? {};
    const scoreA = numberValue(challengerSubjectStats[subject]);
    const scoreB = numberValue(challengedSubjectStats[subject]);
    const subjectChance = scoreA + scoreB > 0 ? (scoreA + 5) / (scoreA + scoreB + 10) : 0.5;
    const winner1 = Math.random() < subjectChance ? battle.challengerUid : uid;
    const iqA = numberValue(challengerStats.iq);
    const iqB = numberValue(challengedStats.iq);
    const variedIqA = Math.round(iqA * (0.95 + Math.random() * 0.1));
    const variedIqB = Math.round(iqB * (0.95 + Math.random() * 0.1));
    const winner2 = variedIqA >= variedIqB ? battle.challengerUid : uid;
    const powerA = numberValue(challengerStats.knowledgePower);
    const powerB = numberValue(challengedStats.knowledgePower);
    const variedPowerA = Math.round(powerA * (0.95 + Math.random() * 0.1));
    const variedPowerB = Math.round(powerB * (0.95 + Math.random() * 0.1));
    const winner3 = variedPowerA >= variedPowerB ? battle.challengerUid : uid;
    const rounds = [
      {
        roundNumber: 1, statCategory: subject,
        label: `Subject Duel: ${subject.replace(/_/g, " ")}`,
        scoreA, scoreB, winnerUid: winner1,
      },
      {
        roundNumber: 2, statCategory: "iq", label: "IQ & Precision Duel",
        scoreA: variedIqA, scoreB: variedIqB, winnerUid: winner2,
      },
      {
        roundNumber: 3, statCategory: "knowledgePower", label: "Knowledge Power Clash",
        scoreA: variedPowerA, scoreB: variedPowerB, winnerUid: winner3,
      },
    ];
    const challengerWins = rounds.filter(
      (round) => round.winnerUid === battle.challengerUid,
    ).length;
    const overallWinner = challengerWins >= 2 ? battle.challengerUid : uid;
    const winnerRef = overallWinner === battle.challengerUid ? challengerRef : challengedRef;
    const loserRef = overallWinner === battle.challengerUid ? challengedRef : challengerRef;
    tx.update(battleRef, {
      status: "completed",
      rounds,
      winnerUid: overallWinner,
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.update(winnerRef, {
      "xp": admin.firestore.FieldValue.increment(100),
      "stats.battleIQ": admin.firestore.FieldValue.increment(1),
    });
    tx.update(loserRef, { xp: admin.firestore.FieldValue.increment(20) });
  });
  return { battleId };
});
