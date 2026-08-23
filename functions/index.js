const functions = require("firebase-functions/v1");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onValueWritten} = require("firebase-functions/v2/database");
const admin = require("firebase-admin");
const axios = require("axios");
const {shouldNotify, buildArticlePayload} = require("./articles");
const {isPastDeadline, computeParticipantUpdate} = require("./gameLogic");

admin.initializeApp({
  databaseURL: "https://scenickazatva-343517-default-rtdb.europe-west1.firebasedatabase.app",
});

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
 * Recomputes a participant's score from their submissions.
 */
exports.recomputeParticipant = onValueWritten(
    {ref: "users/{uid}/game/{festivalId}/{gameId}/{questionId}",
      region: "europe-west1"},
    async (event) => {
      const {uid, festivalId, gameId} = event.params;
      const db = admin.database();

      const [gameSnap, subSnap, partSnap, userSnap] =
          await Promise.all([
            db.ref(`festivals/${festivalId}/games/${gameId}`).get(),
            db.ref(`users/${uid}/game/${festivalId}/${gameId}`).get(),
            db.ref(`festivals/${festivalId}/games/${gameId}` +
                `/participants/${uid}`).get(),
            db.ref(`users/${uid}`).get(),
          ]);

      const game = gameSnap.val();
      const endsAtMs = game && game.endsAtMs;
      const userProfile = userSnap.val();
      const userFullName =
          userProfile && typeof userProfile.fullName === "string" ?
              userProfile.fullName : "";

      if (isPastDeadline(endsAtMs, Date.now())) {
        await event.data.after.ref.remove();
        return;
      }

      const update = computeParticipantUpdate(
          subSnap.val(),
          (game && game.questions) || null,
          partSnap.val(),
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

/**
 * Synchronizes the lastNewsPostId for a festival.
 * Callable by any authenticated user.
 */
exports.syncLatestNewsId = functions.region("europe-west1")
    .https.onCall(async (data, context) => {
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Only authenticated users can update metadata.",
        );
      }

      const {festivalId, postId} = data;
      if (!festivalId || typeof postId !== "number") {
        console.error("updateLatestNewsId: Invalid arguments", data);
        throw new functions.https.HttpsError(
            "invalid-argument",
            "Missing festivalId or postId.",
        );
      }

      console.log(`Healing metadata for ${festivalId} to ${postId}`);
      const ref = admin.database()
          .ref(`appsettings/festivals/${festivalId}/lastNewsPostId`);

      try {
        const result = await ref.transaction((current) => {
          if (current === null || postId > current) {
            return postId;
          }
          return undefined; // Abort
        });

        return {
          committed: result.committed,
          newId: result.snapshot.val(),
        };
      } catch (error) {
        console.error("updateLatestNewsId transaction failed:", error);
        throw new functions.https.HttpsError(
            "internal",
            "Transaction failed.",
        );
      }
    });

exports.checkNewArticles = onSchedule("every 30 minutes", async (event) => {
  const settingsRef = admin.database().ref("appsettings");

  try {
    const settingsSnap = await settingsRef.get();
    const settings = settingsSnap.val() || {};
    const magazineSrc = settings.magazine_src ||
        "https://javisko.sk/wp-json/wp/v2/posts?per_page=1";
    const url = magazineSrc.includes("per_page") ?
        magazineSrc :
        `${magazineSrc}${magazineSrc.includes("?") ? "&" : "?"}per_page=1`;

    const response = await axios.get(url);
    const latestPost = response.data[0];

    if (!latestPost) return;

    const lastMagazineId = settings.lastMagazinePostId;

    if (shouldNotify(lastMagazineId, latestPost.id)) {
      const message = buildArticlePayload(latestPost);
      await admin.messaging().send(message);
      console.log("Notification sent for magazine article:",
          latestPost.id);
      await settingsRef.update({
        lastMagazinePostId: latestPost.id,
      });
    }

    const activeId = settings.defaultfestival;
    const festivals = settings.festivals || {};
    const currentFest = festivals[activeId];

    if (currentFest && typeof currentFest === "object" &&
        currentFest.news_src) {
      const newsSrc = currentFest.news_src;
      try {
        const fUrl = newsSrc.includes("per_page") ?
            newsSrc :
            `${newsSrc}${newsSrc.includes("?") ? "&" : "?"}per_page=1`;
        const fRes = await axios.get(fUrl, {timeout: 10000});
        const fLatest = fRes.data[0];

        if (fLatest && shouldNotify(currentFest.lastNewsPostId, fLatest.id)) {
          await admin.database()
              .ref(`appsettings/festivals/${activeId}`)
              .update({lastNewsPostId: fLatest.id});
          console.log(`Synced lastNewsPostId for festival ${activeId}:`,
              fLatest.id);
        }
      } catch (e) {
        console.error(`Error polling news for festival ${activeId}:`,
            e.message);
      }
    }
  } catch (error) {
    console.error("Error checking WordPress articles:", error);
  }
});
