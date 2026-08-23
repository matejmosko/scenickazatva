/**
 * Pure helpers for the WordPress article polling function, kept free of
 * Firebase so they can be unit-tested without an emulator.
 */

/**
 * True when a notification should be sent: the polled feed has a post that
 * differs from the last one we already notified about.
 * @param {number|string|null} lastId Stored id of the last notified post.
 * @param {number|string|undefined} latestPostId Id of the newest post.
 * @return {boolean}
 */
function shouldNotify(lastId, latestPostId) {
  return latestPostId != null && String(latestPostId) !== String(lastId);
}

/**
 * Builds the FCM message for a newly detected article.
 * @param {Object} latestPost A WordPress post object.
 * @param {string} topic The FCM topic to notify.
 * @param {string} title The notification title.
 * @return {Object} The FCM message payload.
 */
function buildArticlePayload(latestPost, topic = "magazine_updates",
    title = "Nov\u00fd \u010dl\u00e1nok na javisko.sk") {
  const bodyText = String(
      (latestPost.title && latestPost.title.rendered) || "")
      .replace(/&#8211;/g, "\u2013")
      .replace(/&amp;/g, "&");

  return {
    notification: {
      title: title,
      body: bodyText,
    },
    topic: topic,
    data: {
      id: String(latestPost.id),
      type: "magazine",
    },
  };
}

module.exports = {shouldNotify, buildArticlePayload};
