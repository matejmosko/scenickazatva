const functions = require("firebase-functions/v1");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onValueWritten} = require("firebase-functions/v2/database");
const admin = require("firebase-admin");
const axios = require("axios");
const {shouldNotify, buildArticlePayload} = require("./articles");
const {isPastDeadline, computeParticipantUpdate} = require("./gameLogic");

admin.initializeApp();

/**
 * Normalizes an email for role lookups (lowercase, trimmed).
 * @param {*} email The email to normalize.
 * @return {string} The normalized email.
 */
function normalizeEmail(email) {
  return String(email).toLowerCase().trim();
}

/**
 * Finds the role assigned to an email inside the predefinedRoles map.
 * @param {*} roles The predefinedRoles value from the database.
 * @param {string} email The email to look up.
 * @return {string|null} The matching role, or null.
 */
function findRoleInMap(roles, email) {
  const normalized = normalizeEmail(email);
  for (const [role, value] of Object.entries(roles)) {
    if (Array.isArray(value)) {
      if (value.some(
          (entry) => entry != null && normalizeEmail(entry) === normalized)) {
        return role;
      }
    } else if (value != null && normalizeEmail(value) === normalized) {
      return role;
    }
  }
  return null;
}

/**
 * Reads the role for an email from appsettings/predefinedRoles.
 * @param {string} email The email to look up.
 * @return {Promise<string|null>} The matching role, or null.
 */
async function findRoleForEmail(email) {
  const snapshot = await admin.database()
      .ref("appsettings/predefinedRoles").get();
  const roles = snapshot.val();
  if (!roles || typeof roles !== "object") return null;
  return findRoleInMap(roles, email);
}

/**
 * Assigns a role from predefinedRoles to a newly created user.
 * userRole is never client-writable, so this must happen server-side.
 */
exports.assignRoleOnUserCreated =
    functions.auth.user().onCreate(async (user) => {
      if (!user.email) return;
      const role = await findRoleForEmail(user.email);
      if (role) {
        await admin.database().ref(`users/${user.uid}/userRole`).set(role);
        console.log(`Assigned role "${role}" to ${user.email}`);
      }
    });

/**
 * Re-syncs existing user roles whenever predefinedRoles changes.
 */
exports.syncRolesFromPredefinedRoles = onValueWritten(
    {ref: "appsettings/predefinedRoles", region: "europe-west1"},
    async (event) => {
      const roles = event.data.after.val();
      if (!roles || typeof roles !== "object") return;

      const usersSnapshot = await admin.database().ref("users").get();
      const users = usersSnapshot.val();
      if (!users || typeof users !== "object") return;

      const updates = {};
      Object.entries(users).forEach(([uid, user]) => {
        const email = user && typeof user === "object" ? user.email : null;
        if (typeof email !== "string" || email.length === 0) return;
        const role = findRoleInMap(roles, email);
        if (role) updates[`users/${uid}/userRole`] = role;
      });

      if (Object.keys(updates).length > 0) {
        await admin.database().ref().update(updates);
        console.log(`Synced roles for ${Object.keys(updates).length} users`);
      }
    });

/**
 * Recomputes a participant's score from their submissions whenever one
 * changes, and freezes submissions that arrive after the game deadline.
 *
 * Participant records are server-derived: the client cannot write them (the
 * rules allow only admin/editor), which prevents players from inflating their
 * own score or marking themselves as winners. The `winner` flag is preserved.
 */
exports.recomputeParticipant = onValueWritten(
    {ref: "users/{uid}/game/{festivalId}/{gameId}/{questionId}",
      region: "europe-west1"},
    async (event) => {
      const {uid, festivalId, gameId} = event.params;
      const db = admin.database();

      const [gameSnapshot, submissionsSnapshot, participantSnapshot, userSnapshot] =
          await Promise.all([
            db.ref(`festivals/${festivalId}/games/${gameId}`).get(),
            db.ref(`users/${uid}/game/${festivalId}/${gameId}`).get(),
            db.ref(
                `festivals/${festivalId}/games/${gameId}/participants/${uid}`,
            ).get(),
            db.ref(`users/${uid}`).get(),
          ]);

      const game = gameSnapshot.val();
      const endsAtMs = game && game.endsAtMs;
      const userProfile = userSnapshot.val();
      const userFullName = userProfile && typeof userProfile.fullName === "string"
          ? userProfile.fullName : "";

      // Defense in depth: the security rules already reject late writes, but
      // roll back any that slipped through (e.g. offline writes from an old
      // app version).
      if (isPastDeadline(endsAtMs, Date.now())) {
        await event.data.after.ref.remove();
        return;
      }

      const update = computeParticipantUpdate(
          submissionsSnapshot.val(),
          (game && game.questions) || null,
          participantSnapshot.val(),
          userFullName,
      );

      const participantRef =
          db.ref(`festivals/${festivalId}/games/${gameId}/participants/${uid}`);
      if (update === null) {
        await participantRef.remove();
      } else {
        await participantRef.update(update);
      }
    });

exports.checkNewArticles = onSchedule("every 30 minutes", async (event) => {
  const magazineUrl = "https://javisko.sk/wp-json/wp/v2/posts?per_page=1";
  const dbRef = admin.database().ref("appsettings/lastMagazinePostId");

  try {
    const response = await axios.get(magazineUrl);
    const latestPost = response.data[0];

    if (!latestPost) {
      return;
    }

    const snapshot = await dbRef.get();
    const lastId = snapshot.val();

    if (shouldNotify(lastId, latestPost.id)) {
      const message = buildArticlePayload(latestPost);

      await admin.messaging().send(message);
      console.log("Notification sent for article:", latestPost.id);

      await dbRef.set(latestPost.id);
    }
  } catch (error) {
    console.error("Error checking WordPress articles:", error);
  }
});
