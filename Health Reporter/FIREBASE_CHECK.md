# בדיקה לפני הרצה – Firebase & Google Sign-In

## 1. GoogleService-Info.plist

- **תוקן:** ערכי `true`/`false` ב-plist (למשל `IS_ADS_ENABLED`) – הוחלפו מ-`<false></false>` ל-`<false/>`.
- **חסר – חובה להשלים:** ב-plist **חסרים** `CLIENT_ID` ו-`REVERSED_CLIENT_ID`. בלי them התחברות Google **לא תעבוד**.

### איך להשיג אותם

1. היכנס ל-[Firebase Console](https://console.firebase.google.com) → הפרויקט **health-reporter-a7b03**.
2. **Authentication** → **Sign-in method** → וודא ש-**Google** מופעל (Enable).
3. **Project Settings** (גלגל) → **Your apps** → בחר את האפליקציה iOS.
4. הורד שוב את **GoogleService-Info.plist** (הקובץ המעודכן יכלול `CLIENT_ID` ו-`REVERSED_CLIENT_ID`).
5. החלף את `Health Reporter/GoogleService-Info.plist` בקובץ שהורדת.

אם ה-plist שהורד עדיין בלי המפתחות האלה: כבה את Google Sign-In, שמור, הפעל שוב, והורד מחדש.

---

## 2. Info.plist – URL Scheme

- כרגע ב-`CFBundleURLTypes` מופיע ה-placeholder:  
  `com.googleusercontent.apps.000000000000-xxxxxxxx`
- **חובה:** לאחר הוספת `REVERSED_CLIENT_ID` ל-GoogleService-Info.plist, עדכן ב-Info.plist את ה-URL Scheme לערך **המדויק** של `REVERSED_CLIENT_ID` מהקובץ (דומה ל-`com.googleusercontent.apps.87919242294-xxxxxxxx`).

---

## 3. סיכום

| פריט | סטטוס |
|------|--------|
| GoogleService-Info – תקן XML | ✅ תוקן |
| GoogleService-Info – CLIENT_ID, REVERSED_CLIENT_ID | ❌ חסר – להוריד plist מעודכן מ-Firebase |
| Info.plist – URL Scheme | ⚠️ placeholder – לעדכן לפי REVERSED_CLIENT_ID |
| בניית הפרויקט | ✅ עוברת |

אחרי עדכון ה-plist וה-URL Scheme – התחברות אימייל/סיסמה אמורה לעבוד. התחברות Google תעבוד רק לאחר הוספת `CLIENT_ID` ו-`REVERSED_CLIENT_ID` ועדכון ה-URL Scheme.
