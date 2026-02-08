/**
 * Firebase Cloud Functions for Health Reporter
 * Push Notifications
 * Gen 1 Functions
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");

// Use Application Default Credentials so FCM send works (fixes third-party-auth-error).
// Ensure "Firebase Cloud Messaging API" is enabled in Google Cloud Console for this project.
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});
const db = admin.firestore();
const messaging = admin.messaging();
const FieldValue = admin.firestore.FieldValue;

// ─── Helper: send FCM and handle invalid tokens ───

async function sendFCM(fcmToken, message, recipientUid, tag) {
  try {
    const msgId = await messaging.send(message);
    console.log(`${tag} Sent OK, messageId=${msgId}`);
    return {success: true, messageId: msgId};
  } catch (err) {
    console.error(`${tag} SEND FAILED:`, err.code, err.message);
    if (
      err.code === "messaging/invalid-registration-token" ||
      err.code === "messaging/registration-token-not-registered"
    ) {
      await db.collection("users").doc(recipientUid).update({
        fcmToken: FieldValue.delete(),
      });
      console.log(`${tag} Removed stale token for ${recipientUid}`);
    }
    return {success: false, error: err.message};
  }
}

async function getToken(uid, tag) {
  const snap = await db.collection("users").doc(uid).get();
  if (!snap.exists) {
    console.error(`${tag} User doc missing: ${uid}`);
    return null;
  }
  const token = snap.data()?.fcmToken;
  if (!token) {
    console.error(`${tag} No fcmToken for ${uid}`);
    return null;
  }
  return token;
}

// ─── Helper: save notification to Firestore ───

async function saveNotification(recipientUid, type, title, body, data, tag) {
  try {
    await db.collection("users").doc(recipientUid)
        .collection("notifications").add({
          type,
          title,
          body,
          data: data || {},
          read: false,
          createdAt: FieldValue.serverTimestamp(),
        });
    console.log(`${tag} Notification saved for ${recipientUid}`);
  } catch (err) {
    console.error(`${tag} Failed to save notification:`, err.message);
  }
}

// ============================================================================
// 1) FOLLOW REQUEST CREATED
// ============================================================================

exports.onFollowRequestCreated = functions.firestore
    .document("followRequests/{requestId}")
    .onCreate(async (snap, context) => {
      const TAG = "[FollowReqCreated]";
      const d = snap.data();
      const toUid = d.toUid;
      const fromName = d.fromDisplayName || "Someone";
      const fromUid = d.fromUid || "";
      console.log(`${TAG} ${fromName} -> ${toUid}`);

      const title = "New follow request";
      const body = `${fromName} wants to follow you`;

      // Save to notification history
      await saveNotification(toUid, "follow_request", title, body, {
        requestId: context.params.requestId,
        fromUid,
        fromDisplayName: fromName,
      }, TAG);

      const token = await getToken(toUid, TAG);
      if (!token) return null;

      return sendFCM(token, {
        token,
        notification: {title, body},
        data: {
          type: "follow_request_received",
          requestId: context.params.requestId,
          fromUid,
          fromDisplayName: fromName,
        },
        apns: {payload: {aps: {badge: 1, sound: "default"}}},
      }, toUid, TAG);
    });

// ============================================================================
// 2) FOLLOW REQUEST ACCEPTED
// ============================================================================

exports.onFollowRequestAccepted = functions.firestore
    .document("followRequests/{requestId}")
    .onUpdate(async (change, context) => {
      const TAG = "[FollowReqAccepted]";
      const before = change.before.data();
      const after = change.after.data();
      if (!before || !after) return;
      if (before.status === "accepted" || after.status !== "accepted") return;

      const fromUid = after.fromUid;
      const toUid = after.toUid;
      console.log(`${TAG} ${toUid} accepted ${fromUid}`);

      const acceptorSnap = await db.collection("users").doc(toUid).get();
      const acceptorName = acceptorSnap.data()?.displayName || "Someone";

      const title = "Follow request accepted!";
      const body = `${acceptorName} accepted your follow request`;

      // Save to notification history
      await saveNotification(fromUid, "follow_accepted", title, body, {
        requestId: context.params.requestId,
        acceptedByUid: toUid,
        acceptedByDisplayName: acceptorName,
      }, TAG);

      const token = await getToken(fromUid, TAG);
      if (!token) return null;

      return sendFCM(token, {
        token,
        notification: {title, body},
        data: {
          type: "follow_request_accepted",
          requestId: context.params.requestId,
          acceptedByUid: toUid,
          acceptedByDisplayName: acceptorName,
        },
        apns: {payload: {aps: {badge: 0, sound: "default"}}},
      }, fromUid, TAG);
    });

// ============================================================================
// 3) NEW FOLLOWER (direct / open privacy)
// ============================================================================

exports.onNewFollower = functions.firestore
    .document("users/{userId}/followers/{followerId}")
    .onCreate(async (snap, context) => {
      const TAG = "[NewFollower]";
      const userId = context.params.userId;
      const followerId = context.params.followerId;
      console.log(`${TAG} ${followerId} -> ${userId}`);

      const followerSnap = await db.collection("users").doc(followerId).get();
      const followerName = followerSnap.data()?.displayName || "Someone";

      const title = "New follower!";
      const body = `${followerName} started following you`;

      // Save to notification history
      await saveNotification(userId, "new_follower", title, body, {
        followerUid: followerId,
        followerDisplayName: followerName,
      }, TAG);

      const token = await getToken(userId, TAG);
      if (!token) return null;

      return sendFCM(token, {
        token,
        notification: {title, body},
        data: {
          type: "new_follower",
          followerUid: followerId,
          followerDisplayName: followerName,
        },
        apns: {payload: {aps: {badge: 1, sound: "default"}}},
      }, userId, TAG);
    });

// ============================================================================
// 4) MORNING NOTIFICATIONS (scheduled every minute)
// ============================================================================

exports.sendMorningNotifications = functions.pubsub
    .schedule("* * * * *")
    .timeZone("Asia/Jerusalem")
    .onRun(async () => {
      const TAG = "[MorningNotif]";
      const now = new Date();
      const h = now.getHours();
      const m = now.getMinutes();
      console.log(`${TAG} Check ${h}:${String(m).padStart(2, "0")}`);

      const snap = await db.collection("users")
          .where("morningNotification.enabled", "==", true)
          .where("morningNotification.hour", "==", h)
          .where("morningNotification.minute", "==", m)
          .get();

      if (snap.empty) {
        console.log(`${TAG} No users at this time`);
        return null;
      }

      console.log(`${TAG} ${snap.docs.length} user(s) matched`);

      const results = await Promise.allSettled(
          snap.docs.map(async (doc) => {
            const uid = doc.id;
            const token = doc.data().fcmToken;
            if (!token) {
              console.log(`${TAG} ${uid}: no token`);
              return {uid, success: false};
            }

            // Save morning notification to history
            await saveNotification(uid, "morning_summary",
                "Good morning!", "Your daily health report is ready",
                {timestamp: now.toISOString()}, TAG);

            const res = await sendFCM(token, {
              token,
              data: {
                type: "morning_health_trigger",
                userId: uid,
                timestamp: now.toISOString(),
              },
              apns: {
                payload: {aps: {"content-available": 1}},
                headers: {
                  "apns-priority": "5",
                  "apns-push-type": "background",
                },
              },
            }, uid, TAG);

            if (res.success) {
              await db.collection("users").doc(uid).update({
                "morningNotification.lastSent": now,
              });
            }
            return {uid, ...res};
          }),
      );

      const ok = results.filter((r) => r.status === "fulfilled" && r.value?.success).length;
      console.log(`${TAG} Done: ${ok}/${snap.docs.length} sent`);
      return null;
    });

// ============================================================================
// 5) SETTINGS CHANGE LOGGER
// ============================================================================

exports.onSettingsChanged = functions.firestore
    .document("users/{userId}")
    .onWrite(async (change, context) => {
      const TAG = "[SettingsChanged]";
      const before = change.before.data();
      const after = change.after.data();
      if (!after) return;

      const bSettings = before?.morningNotification;
      const aSettings = after?.morningNotification;
      if (JSON.stringify(bSettings) !== JSON.stringify(aSettings)) {
        console.log(`${TAG} ${context.params.userId} morning: ${JSON.stringify(aSettings)}`);
      }

      const bBedtime = before?.bedtimeNotification;
      const aBedtime = after?.bedtimeNotification;
      if (JSON.stringify(bBedtime) !== JSON.stringify(aBedtime)) {
        console.log(`${TAG} ${context.params.userId} bedtime: ${JSON.stringify(aBedtime)}`);
      }
    });

// ============================================================================
// 6) BEDTIME NOTIFICATIONS (scheduled every minute)
// ============================================================================

exports.sendBedtimeNotifications = functions.pubsub
    .schedule("* * * * *")
    .timeZone("Asia/Jerusalem")
    .onRun(async () => {
      const TAG = "[BedtimeNotif]";
      const now = new Date();
      const h = now.getHours();
      const m = now.getMinutes();
      console.log(`${TAG} Check ${h}:${String(m).padStart(2, "0")}`);

      const snap = await db.collection("users")
          .where("bedtimeNotification.enabled", "==", true)
          .where("bedtimeNotification.hour", "==", h)
          .where("bedtimeNotification.minute", "==", m)
          .get();

      if (snap.empty) {
        console.log(`${TAG} No users at this time`);
        return null;
      }

      console.log(`${TAG} ${snap.docs.length} user(s) matched`);

      const results = await Promise.allSettled(
          snap.docs.map(async (doc) => {
            const uid = doc.id;
            const token = doc.data().fcmToken;
            if (!token) {
              console.log(`${TAG} ${uid}: no token`);
              return {uid, success: false};
            }

            await saveNotification(uid, "bedtime_recommendation",
                "Bedtime Recommendation", "Your personalized bedtime is ready",
                {timestamp: now.toISOString()}, TAG);

            const res = await sendFCM(token, {
              token,
              data: {
                type: "bedtime_trigger",
                userId: uid,
                timestamp: now.toISOString(),
              },
              apns: {
                payload: {aps: {"content-available": 1}},
                headers: {
                  "apns-priority": "5",
                  "apns-push-type": "background",
                },
              },
            }, uid, TAG);

            if (res.success) {
              await db.collection("users").doc(uid).update({
                "bedtimeNotification.lastSent": now,
              });
            }
            return {uid, ...res};
          }),
      );

      const ok = results.filter((r) => r.status === "fulfilled" && r.value?.success).length;
      console.log(`${TAG} Done: ${ok}/${snap.docs.length} sent`);
      return null;
    });
