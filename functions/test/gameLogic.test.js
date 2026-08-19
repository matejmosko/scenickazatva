"use strict";

const test = require("node:test");
const assert = require("node:assert");
const {
  isPastDeadline,
  computeParticipantUpdate,
} = require("../gameLogic");

test("isPastDeadline", async (t) => {
  const now = Date.UTC(2026, 7, 1);

  await t.test("false when endsAtMs is missing or zero", () => {
    assert.strictEqual(isPastDeadline(undefined, now), false);
    assert.strictEqual(isPastDeadline(null, now), false);
    assert.strictEqual(isPastDeadline(0, now), false);
  });

  await t.test("false before the deadline", () => {
    assert.strictEqual(isPastDeadline(now + 1000, now), false);
  });

  await t.test("true after the deadline", () => {
    assert.strictEqual(isPastDeadline(now - 1000, now), true);
  });
});

test("computeParticipantUpdate", async (t) => {
  const questions = {
    q1: {points: 10},
    q2: {points: 20},
  };

  await t.test("returns null when there are no submissions", () => {
    assert.strictEqual(
        computeParticipantUpdate(null, questions, null, "John"),
        null);
    assert.strictEqual(
        computeParticipantUpdate({}, questions, {winner: true}, "John"),
        null);
  });

  await t.test("scores correct answers from the question points", () => {
    const submissions = {
      q1: {correct: true, answeredAt: "2026-08-01T10:00:00Z"},
      q2: {correct: false, answeredAt: "2026-08-01T11:00:00Z"},
    };
    const update =
        computeParticipantUpdate(submissions, questions, {uid: "u1"}, "John");
    assert.strictEqual(update.score, 10);
    assert.strictEqual(update.correctCount, 1);
    assert.strictEqual(update.answeredCount, 2);
    assert.strictEqual(update.lastAnsweredAt, "2026-08-01T11:00:00Z");
    assert.strictEqual(update.uid, "u1");
  });

  await t.test("ignores non-object submissions", () => {
    const update =
        computeParticipantUpdate({q1: "junk"}, questions, null, "John");
    assert.strictEqual(update.score, 0);
    assert.strictEqual(update.answeredCount, 1);
  });

  await t.test("preserves an existing winner flag", () => {
    const submissions = {
      q1: {correct: true, answeredAt: "2026-08-01T10:00:00Z"},
    };
    const update = computeParticipantUpdate(
        submissions, questions, {winner: true}, "John");
    assert.strictEqual(update.winner, true);
  });

  await t.test("does not invent a winner flag", () => {
    const submissions = {
      q1: {correct: true, answeredAt: "2026-08-01T10:00:00Z"},
    };
    const update = computeParticipantUpdate(submissions, questions, null, "John");
    assert.strictEqual(update.winner, undefined);
  });

  await t.test("sets fullName from user profile on first write", () => {
    const submissions = {
      q1: {correct: true, answeredAt: "2026-08-01T10:00:00Z"},
    };
    const update = computeParticipantUpdate(
        submissions, questions, null, "Ján Novák");
    assert.strictEqual(update.fullName, "Ján Novák");
  });

  await t.test("preserves existing fullName over user profile", () => {
    const submissions = {
      q1: {correct: true, answeredAt: "2026-08-01T10:00:00Z"},
    };
    const existing = {fullName: "Existing Name"};
    const update = computeParticipantUpdate(
        submissions, questions, existing, "New Name");
    assert.strictEqual(update.fullName, "Existing Name");
  });

  await t.test("falls back to user profile when existing fullName is empty", () => {
    const submissions = {
      q1: {correct: true, answeredAt: "2026-08-01T10:00:00Z"},
    };
    const existing = {fullName: ""};
    const update = computeParticipantUpdate(
        submissions, questions, existing, "Profile Name");
    assert.strictEqual(update.fullName, "Profile Name");
  });
});
