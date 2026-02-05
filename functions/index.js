/**
 * Firebase Cloud Functions for Health Reporter
 * Push Notifications for Friend Requests
 * Using 2nd Generation Functions
 */

const {onDocumentCreated, onDocumentUpdated, onDocumentWritten} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore();

// ============================================================================
// FRIEND REQUEST NOTIFICATIONS
// ============================================================================

/**
 * Trigger: When a new friend request is created
 * Action: Send push notification to the recipient
 */
exports.onFriendRequestCreated = onDocumentCreated(
    "friendRequests/{requestId}",
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) {
        console.log("No data associated with the event");
        return;
      }

      const requestData = snapshot.data();
      const toUid = requestData.toUid;
      const fromDisplayName = requestData.fromDisplayName || "מישהו";

      console.log(`New friend request from ${fromDisplayName} to ${toUid}`);

      // Get recipient's FCM token
      const recipientDoc = await db.collection("users").doc(toUid).get();
      const fcmToken = recipientDoc.data()?.fcmToken;

      if (!fcmToken) {
        console.log(`No FCM token for user ${toUid}`);
        return null;
      }

      // Send notification
      const message = {
        token: fcmToken,
        notification: {
          title: "בקשת חברות חדשה",
          body: `${fromDisplayName} רוצה להיות חבר שלך`,
        },
        data: {
          type: "friend_request_received",
          requestId: event.params.requestId,
          fromUid: requestData.fromUid,
          fromDisplayName: fromDisplayName,
        },
        apns: {
          payload: {
            aps: {
              badge: 1,
              sound: "default",
            },
          },
        },
      };

      try {
        await getMessaging().send(message);
        console.log(`Notification sent to ${toUid}`);
        return {success: true};
      } catch (error) {
        console.error(`Error sending notification: ${error}`);
        // If token is invalid, remove it
        if (error.code === "messaging/invalid-registration-token" ||
            error.code === "messaging/registration-token-not-registered") {
          const {FieldValue} = require("firebase-admin/firestore");
          await db.collection("users").doc(toUid).update({
            fcmToken: FieldValue.delete(),
          });
          console.log(`Removed invalid FCM token for user ${toUid}`);
        }
        return {success: false, error: error.message};
      }
    },
);

// ============================================================================
// MORNING NOTIFICATION FUNCTIONS
// ============================================================================

/**
 * Scheduled job: Runs every minute to check for users who need morning notifications
 * Sends silent push notifications to wake up their apps for fresh health data
 */
exports.sendMorningNotifications = onSchedule(
    {
      schedule: "* * * * *", // Every minute
      timeZone: "Asia/Jerusalem", // Israel timezone
      retryCount: 0, // Don't retry failed runs
    },
    async () => {
      const now = new Date();
      const currentHour = now.getHours();
      const currentMinute = now.getMinutes();

      console.log(`🔔 Morning notification check: ${currentHour}:${currentMinute}`);

      // Query users who have morning notifications enabled for this exact time
      const usersSnapshot = await db.collection("users")
          .where("morningNotification.enabled", "==", true)
          .where("morningNotification.hour", "==", currentHour)
          .where("morningNotification.minute", "==", currentMinute)
          .get();

      if (usersSnapshot.empty) {
        console.log("No users scheduled for this time");
        return;
      }

      console.log(`Found ${usersSnapshot.docs.length} users for morning notification`);

      const sendPromises = usersSnapshot.docs.map(async (userDoc) => {
        const userData = userDoc.data();
        const fcmToken = userData.fcmToken;
        const userId = userDoc.id;

        if (!fcmToken) {
          console.log(`No FCM token for user ${userId}`);
          return;
        }

        // Send silent push to wake the app
        const message = {
          token: fcmToken,
          data: {
            type: "morning_health_trigger",
            userId: userId,
            timestamp: now.toISOString(),
          },
          apns: {
            payload: {
              aps: {
                "content-available": 1, // Silent push for iOS
              },
            },
            headers: {
              "apns-priority": "5", // Low priority for silent push
              "apns-push-type": "background",
            },
          },
        };

        try {
          await getMessaging().send(message);
          console.log(`✅ Silent push sent to user ${userId}`);

          // Update last notification time
          await db.collection("users").doc(userId).update({
            "morningNotification.lastSent": now,
          });

          return {userId, success: true};
        } catch (error) {
          console.error(`❌ Failed to send to user ${userId}: ${error}`);

          // Handle invalid tokens
          if (error.code === "messaging/invalid-registration-token" ||
              error.code === "messaging/registration-token-not-registered") {
            const {FieldValue} = require("firebase-admin/firestore");
            await db.collection("users").doc(userId).update({
              fcmToken: FieldValue.delete(),
            });
            console.log(`Removed invalid FCM token for user ${userId}`);
          }

          return {userId, success: false, error: error.message};
        }
      });

      const results = await Promise.allSettled(sendPromises);
      const successful = results.filter((r) => r.status === "fulfilled" && r.value?.success).length;
      console.log(`Morning notifications sent: ${successful}/${usersSnapshot.docs.length}`);
    },
);

/**
 * Trigger: When user updates their morning notification settings
 * Action: Log the change for debugging
 */
exports.onMorningNotificationSettingsChanged = onDocumentWritten(
    "users/{userId}",
    async (event) => {
      const beforeData = event.data?.before?.data();
      const afterData = event.data?.after?.data();

      if (!afterData) return; // Document deleted

      const beforeSettings = beforeData?.morningNotification;
      const afterSettings = afterData?.morningNotification;

      // Check if morning notification settings changed
      if (JSON.stringify(beforeSettings) !== JSON.stringify(afterSettings)) {
        console.log(`🔔 User ${event.params.userId} updated morning notification settings:`, {
          enabled: afterSettings?.enabled,
          hour: afterSettings?.hour,
          minute: afterSettings?.minute,
        });
      }
    },
);

// ============================================================================
// FRIEND REQUEST NOTIFICATIONS (existing)
// ============================================================================

/**
 * Trigger: When a friend request status changes to "accepted"
 * Action: Send push notification to the original sender
 */
exports.onFriendRequestAccepted = onDocumentUpdated(
    "friendRequests/{requestId}",
    async (event) => {
      const beforeData = event.data?.before?.data();
      const afterData = event.data?.after?.data();

      if (!beforeData || !afterData) {
        console.log("No data associated with the event");
        return;
      }

      // Only trigger when status changes to "accepted"
      if (beforeData.status === "accepted" || afterData.status !== "accepted") {
        return null;
      }

      const fromUid = afterData.fromUid;
      const toUid = afterData.toUid;

      console.log(`Friend request accepted by ${toUid} for ${fromUid}`);

      // Get the accepting user's display name
      const acceptingUserDoc = await db.collection("users").doc(toUid).get();
      const acceptingDisplayName =
        acceptingUserDoc.data()?.displayName || "מישהו";

      // Get sender's FCM token
      const senderDoc = await db.collection("users").doc(fromUid).get();
      const fcmToken = senderDoc.data()?.fcmToken;

      if (!fcmToken) {
        console.log(`No FCM token for user ${fromUid}`);
        return null;
      }

      // Send notification
      const message = {
        token: fcmToken,
        notification: {
          title: "בקשת החברות אושרה!",
          body: `${acceptingDisplayName} אישר/ה את בקשת החברות שלך`,
        },
        data: {
          type: "friend_request_accepted",
          requestId: event.params.requestId,
          acceptedByUid: toUid,
          acceptedByDisplayName: acceptingDisplayName,
        },
        apns: {
          payload: {
            aps: {
              badge: 0,
              sound: "default",
            },
          },
        },
      };

      try {
        await getMessaging().send(message);
        console.log(`Acceptance notification sent to ${fromUid}`);
        return {success: true};
      } catch (error) {
        console.error(`Error sending notification: ${error}`);
        // If token is invalid, remove it
        if (error.code === "messaging/invalid-registration-token" ||
            error.code === "messaging/registration-token-not-registered") {
          const {FieldValue} = require("firebase-admin/firestore");
          await db.collection("users").doc(fromUid).update({
            fcmToken: FieldValue.delete(),
          });
          console.log(`Removed invalid FCM token for user ${fromUid}`);
        }
        return {success: false, error: error.message};
      }
    },
);
