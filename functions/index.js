const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();

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

    if (latestPost.id !== lastId) {
      const bodyText = latestPost.title.rendered
          .replace(/&#8211;/g, "–")
          .replace(/&amp;/g, "&");

      const message = {
        notification: {
          title: "Nový článok na javisko.sk",
          body: bodyText,
        },
        topic: "magazine_updates",
        data: {
          id: latestPost.id.toString(),
          type: "magazine",
        },
      };

      await admin.messaging().send(message);
      console.log("Notification sent for article:", latestPost.id);

      await dbRef.set(latestPost.id);
    }
  } catch (error) {
    console.error("Error checking WordPress articles:", error);
  }
});
