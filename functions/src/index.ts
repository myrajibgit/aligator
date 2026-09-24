import * as admin from "firebase-admin";

admin.initializeApp();

export { onUserCreated } from "./triggers/onUserCreated";
export { onMissionComplete } from "./triggers/onMissionComplete";
export { onMessageCreated } from "./triggers/onMessageCreated";
export { onBattleCreated } from "./triggers/onBattleCreated";
export { weeklyLeaderboard } from "./scheduled/weeklyLeaderboard";
export { verifyStudyNotes } from "./triggers/verifyStudyNotes";
export { createBattle, declineBattle, resolveBattle } from "./callables/battles";
export { askSystemAi } from "./callables/systemAi";
