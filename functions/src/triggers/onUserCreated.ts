import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { COLLECTIONS } from "../utils/firestore";

export const onUserCreated = functions.auth.user().onCreate(async (user) => {
  const uid = user.uid;
  const now = admin.firestore.FieldValue.serverTimestamp();

  const userDoc = {
    uid: uid,
    displayName: user.displayName || null,
    photoUrl: user.photoURL || null,
    email: user.email || null,
    xp: 0,
    stats: {
      knowledgePower: 0,
      iq: 0,
      battleIQ: 0,
      subjectStats: {},
    },
    onboardingComplete: false,
    blockedUids: [],
    createdAt: now,
    lastActive: now,
  };

  try {
    // Preserve profile details entered during the short interval before this
    // asynchronous Auth trigger reaches Firestore.
    await admin.firestore().collection(COLLECTIONS.USERS).doc(uid).set(userDoc, { merge: true });
    functions.logger.info(`User document created for uid: ${uid}`);
  } catch (error) {
    functions.logger.error(`Error creating user document for uid: ${uid}`, error);
  }
});
