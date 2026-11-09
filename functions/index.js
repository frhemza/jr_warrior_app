const functions = require("firebase-functions");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * 1. TRIGGER: Automatically sends a push notification when a Coach posts a new announcement.
 * Target: Broadcasts to the 'announcements' topic.
 */
exports.onAnnouncementCreated = functions.firestore
  .document("announcements/{announcementId}")
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    const title = data.title || "New Announcement 📢";
    const body = data.body || data.content || "A new announcement has been posted by your Coach!";

    const message = {
      topic: "announcements",
      notification: {
        title: title,
        body: body,
      },
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        type: "announcement",
        announcementId: context.params.announcementId,
      },
      webpush: {
        notification: {
          title: title,
          body: body,
          icon: "/icons/Icon-192.png",
        },
        fcmOptions: {
          link: "/",
        },
      },
    };

    try {
      await admin.messaging().send(message);
      console.log("Successfully broadcast announcement notification.");
      return null;
    } catch (error) {
      console.error("Error sending announcement notification:", error);
      return null;
    }
  });

/**
 * 2. TRIGGER: Sends a push notification to a parent when a Fee Challan is issued.
 * Listens for a child's feeStatus changing to 'due'.
 */
exports.onFeeChallanIssued = functions.firestore
  .document("children/{childId}")
  .onUpdate(async (change, context) => {
    const dataBefore = change.before.data();
    const dataAfter = change.after.data();

    // Trigger only when feeStatus transitions to 'due'
    if (dataBefore.feeStatus !== "due" && dataAfter.feeStatus === "due") {
      const parentId = dataAfter.parentId;
      const childName = dataAfter.name || "Warrior";

      if (!parentId) return null;

      // Fetch parent's user document to retrieve their FCM token
      const parentDoc = await admin.firestore().collection("users").doc(parentId).get();
      if (!parentDoc.exists) return null;

      const fcmToken = parentDoc.data().fcmToken;
      if (!fcmToken) return null;

      const message = {
        token: fcmToken,
        notification: {
          title: "Fee Challan Issued 💳",
          body: `Monthly tuition fee challan for ${childName} is now due. Please review in the app.`,
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          type: "fee_challan",
          childId: context.params.childId,
        },
        webpush: {
          notification: {
            title: "Fee Challan Issued 💳",
            body: `Monthly tuition fee challan for ${childName} is now due.`,
            icon: "/icons/Icon-192.png",
          },
          fcmOptions: {
            link: "/",
          },
        },
      };

      try {
        await admin.messaging().send(message);
        console.log(`Successfully sent fee challan notification for ${childName}.`);
        return null;
      } catch (error) {
        console.error("Error sending fee challan notification:", error);
        return null;
      }
    }
    return null;
  });

/**
 * Scheduled Cloud Function: Runs every Monday at 9:00 AM.
 * Checks for warriors who haven't logged activity in 7+ days
 * and sends an FCM push notification to their parents.
 */
exports.sendWeeklyInactivityReminders = functions.pubsub
  .schedule("every monday 09:00")
  .timeZone("Asia/Karachi")
  .onRun(async (context) => {
    const db = admin.firestore();
    const messaging = admin.messaging();

    const now = new Date();
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

    try {
      const childrenSnapshot = await db.collection("children").get();

      if (childrenSnapshot.empty) {
        console.log("No children found in database.");
        return null;
      }

      const notifications = [];

      for (const childDoc of childrenSnapshot.docs) {
        const childData = childDoc.data();
        const lastActiveTs = childData.lastActive || childData.updatedAt || childData.createdAt;
        const lastActiveDate = lastActiveTs ? lastActiveTs.toDate() : new Date(0);

        if (lastActiveDate < sevenDaysAgo) {
          const parentId = childData.parentId;
          const childName = childData.name || "Warrior";

          if (!parentId) continue;

          const parentDoc = await db.collection("users").doc(parentId).get();
          if (!parentDoc.exists) continue;

          const fcmToken = parentDoc.data().fcmToken;
          if (!fcmToken) continue;

          const payload = {
            token: fcmToken,
            notification: {
              title: `Keep ${childName}'s Practice Going! 🥋`,
              body: `${childName} hasn't completed a Warrior Code in over a week. Log in to review home practice!`,
            },
            data: {
              click_action: "FLUTTER_NOTIFICATION_CLICK",
              childId: childDoc.id,
              type: "inactivity_reminder",
            },
          };

          notifications.push(messaging.send(payload));
        }
      }

      const results = await Promise.all(notifications);
      console.log(`Successfully sent ${results.length} inactivity reminder notifications.`);
      return null;
    } catch (error) {
      console.error("Error sending weekly inactivity reminders:", error);
      return null;
    }
  });