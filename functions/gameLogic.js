/**
 * Pure game helpers, kept free of Firebase so they can be unit-tested
 * without an emulator.
 */

/**
 * True when the game deadline has passed. A missing or zero endsAtMs means
 * "no deadline" (the game never closes).
 * @param {number|undefined|null} endsAtMs Epoch milliseconds.
 * @param {number} nowMs Epoch milliseconds.
 * @return {boolean}
 */
function isPastDeadline(endsAtMs, nowMs) {
  return typeof endsAtMs === "number" && endsAtMs > 0 && nowMs > endsAtMs;
}

/**
 * Computes the participant record to persist for a user's festival game.
 * The client can no longer write its own participant record (it could inflate
 * its score), so scores are derived server-side from the stored submissions
 * and the question definitions.
 *
 * @param {Object|null} submissions Map of questionId -> submission
 *     (`{correct, answeredAt}`).
 * @param {Object|null} questions Map of `{questionId: {points}}`.
 * @param {Object|null} existing The current participant record (winner flag is
 *     preserved; it is only writable by admins).
 * @return {Object|null} The participant update, or null when there are no
 *     submissions (caller should delete the record).
 */
function computeParticipantUpdate(submissions, questions, existing) {
  const entries = Object.entries(submissions || {});
  let score = 0;
  let correctCount = 0;
  let lastAnsweredAt = "";

  for (const [questionId, submission] of entries) {
    if (!submission || typeof submission !== "object") continue;
    if (submission.correct === true) {
      const points = questions && questions[questionId] &&
          typeof questions[questionId].points === "number" ?
        questions[questionId].points : 0;
      score += points;
      correctCount++;
    }
    const answeredAt = typeof submission.answeredAt === "string" ?
      submission.answeredAt : "";
    if (answeredAt > lastAnsweredAt) lastAnsweredAt = answeredAt;
  }

  if (entries.length === 0) return null;

  const update = {
    score: score,
    correctCount: correctCount,
    answeredCount: entries.length,
    lastAnsweredAt: lastAnsweredAt,
  };
  if (existing && typeof existing === "object") {
    if (typeof existing.uid === "string") update.uid = existing.uid;
    if (typeof existing.fullName === "string") {
      update.fullName = existing.fullName;
    }
    if (typeof existing.email === "string") update.email = existing.email;
    // winner is admin-managed only; keep whatever is already set.
    if (existing.winner === true) update.winner = true;
  }
  return update;
}

module.exports = {isPastDeadline, computeParticipantUpdate};
