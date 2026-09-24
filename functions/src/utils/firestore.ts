import * as admin from "firebase-admin";

export const db = admin.firestore();

export const COLLECTIONS = {
  USERS: "users",
  MISSIONS: "missions",
  LEADERBOARDS: "leaderboards",
  SCHOOLS: "schools",
  CLASSES: "classes",
};
