# איך לבדוק למה משתמש (למשל ליאור) לא מקבל התראות

## איך לראות לוגים באפליקציה

1. חבר את המכשיר (או סימולטור) והרץ מהאפליקציה מ־Xcode.
2. בתחתית Xcode פתח את **Console** (View → Debug Area → Activate Console).
3. בשדה החיפוש של הקונסול הקלד **`[FCM]`** – כל הלוגים של טוקן והתראות יופיעו שם.

**מה לחפש:**
- `✅` = הצעד עבד (טוקן התקבל, נשמר, הרשאה אושרה).
- `❌` = משהו נכשל (אין טוקן, שמירה נכשלה, הרשאה נדחתה).
- `⚠️` = אזהרה (למשל טוקן התקבל אבל אין משתמש מחובר – יישמר אחרי לוגין).

## 1. שגיאת `third-party-auth-error` (NewFollower / כל שליחת FCM)

**תסמין:** בלוגים: `[NewFollower] SEND FAILED: messaging/third-party-auth-error ... Expected OAuth 2 access token`.

**פתרון:**
- ב־**Google Cloud Console** → פרויקט Health Reporter → **APIs & Services** → **Enabled APIs**: וודא ש־**Firebase Cloud Messaging API** מופעל.
- ב־**IAM & Admin** → **IAM**: וודא שלחשבון השירות של Cloud Functions (למשל `...@appspot.gserviceaccount.com`) יש תפקיד שמאפשר שליחת FCM (למשל גישה ל־Firebase Cloud Messaging).
- אחרי שינוי ב־Functions: `firebase deploy --only functions`.

בקוד ה־Functions הוספנו `credential: admin.credential.applicationDefault()` כדי ש־ADC ישמש במפורש.

---

## 2. התראות בוקר – "No users at this time"

**תסמין:** בלוגים: `[MorningNotif] No users at this time` (בשעה X:XX).

**משמעות:** בשעה הזו אף משתמש לא התאים ל־query: `morningNotification.enabled == true` **ו** `morningNotification.hour == h` **ו** `morningNotification.minute == m` (שעון ישראל).

**מה לבדוק ב־Firestore עבור ליאור:**

1. **מסמך המשתמש:** `users/{ליאור_uid}`.
2. **שדות חובה:**
   - `fcmToken` – מחרוזת (לא ריק). אם חסר – השליחה תדלג עם "no token".
   - `morningNotification.enabled` = `true`.
   - `morningNotification.hour` = מספר (0–23), למשל 7.
   - `morningNotification.minute` = מספר (0–59), למשל 55.

**אם חסר `fcmToken`:**
- ליאור צריכה לפתוח את האפליקציה **מחוברת לאינטרנט**, לאפשר התראות, ולהיכנס להגדרות → התראת בוקר (זה מרענן FCM ושומר הגדרות).
- אחרי התקנה מחדש – להיכנס לחשבון, לאשר הרשאות התראות, ולפתוח פעם אחת את מסך "התראת בוקר".

**אם השעה לא תואמת:**
- ה־Cloud Function רץ כל דקה (שעון ישראל). אם ליאור בחרה 7:55, המסמך שלה חייב להכיל `hour: 7`, `minute: 55` בדיוק.

---

## 3. סיכום פעולות באפליקציה (Swift)

- **Logout:** מוחקים את ה־FCM token מ־Firestore (`removeFCMToken`) כדי שלא יישלחו התראות למכשיר הישן.
- **כניסה להגדרות התראת בוקר:** מרעננים FCM token ושומרים שוב את הגדרות הבוקר ל־Firestore (`refreshAndSaveFCMToken` + `syncSettingsToFirestore`).

אם ליאור תפתח **הגדרות → התראת בוקר**, הטוקן וההגדרות אמורים להישמר מחדש; אם אחרי זה עדיין "No users at this time", לבדוק את המסמך שלה ב־Firestore above.
