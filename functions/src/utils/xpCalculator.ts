export interface SubjectStats {
  [subjectId: string]: number;
}

export interface UserStats {
  knowledgePower: number;
  iq: number;
  battleIQ: number;
  subjectStats: SubjectStats;
}

export interface SubjectMission {
  subjectId: string;
  status: string;
  xpAwarded: number;
}

/**
 * Derives immutable academic stats while retaining the separately earned battle rating.
 * @param {SubjectMission[]} allCompletedMissions Completed academic missions.
 * @param {number} battleIQ Existing battle rating to retain.
 * @return {UserStats} Recomputed academic stats.
 */
export function calculateStats(
  allCompletedMissions: SubjectMission[],
  battleIQ = 0,
): UserStats {
  let knowledgePower = 0;
  const subjectStats: SubjectStats = {};

  for (const mission of allCompletedMissions) {
    knowledgePower += mission.xpAwarded;
    if (!subjectStats[mission.subjectId]) {
      subjectStats[mission.subjectId] = 0;
    }
    subjectStats[mission.subjectId] += mission.xpAwarded;
  }

  let iq = Math.round((knowledgePower / Math.max(1, allCompletedMissions.length)) * 1.5);
  if (iq > 10000) {
    iq = 10000;
  }

  return {
    knowledgePower,
    iq,
    battleIQ,
    subjectStats,
  };
}
