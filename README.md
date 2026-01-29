# Health Reporter - דוח בריאות אישי

אפליקציית iOS ב-Swift UIKit שמחברת נתוני בריאות מ-HealthKit ומנתחת אותם באמצעות Gemini AI.

## תכונות

- ✅ גישה לנתוני HealthKit (צעדים, דופק, לחץ דם, שינה, משקל, ועוד)
- ✅ ניתוח נתונים באמצעות Google Gemini AI
- ✅ הצגת תובנות והמלצות מותאמות אישית
- ✅ ממשק משתמש בעברית
- ✅ תצוגה מאורגנת של כל נתוני הבריאות החשובים

## דרישות

- iOS 16.0+
- Xcode 14.0+
- מפתח API של Google Gemini (כבר מוגדר ב-Config.plist)

## התקנה

1. פתח את הפרויקט ב-Xcode
2. ודא שה-HealthKit capability מופעל בפרויקט:
   - בחר את ה-target "Health Reporter"
   - לך ל-Signing & Capabilities
   - הוסף HealthKit capability (אם לא קיים)
   - ודא שקובץ ה-entitlements מוגדר: `Health Reporter.entitlements`
3. **Firebase והתחברות Google** (חובה להתחברות):
   - צור פרויקט ב-[Firebase Console](https://console.firebase.google.com) והוסף אפליקציית iOS עם Bundle ID `com.rani.Health-Reporter`
   - הפעל **Authentication** > **Sign-in method** > **Google**
   - הפעל **Firestore Database** (Create database). עבור כללי אבטחה, השתמש ב־rules שמאפשרים קריאה/כתיבה רק למשתמש המחובר ב־`users/{userId}`.
   - הורד `GoogleService-Info.plist` והחלף את הקובץ בתיקיית `Health Reporter/`
   - ב-Info.plist, עדכן את ה-URL Scheme ב-`CFBundleURLTypes` ל־`REVERSED_CLIENT_ID` מהקובץ שהורדת (ראה `GoogleService-Info.plist.example`)
4. בנה והרץ את האפליקציה

## הרשאות

האפליקציה מבקשת גישה לנתוני בריאות הבאים:
- צעדים ומרחק
- דופק (כולל דופק במנוחה)
- לחץ דם
- ריווי חמצן
- משקל ו-BMI
- נתוני שינה
- נתונים תזונתיים
- סוכר בדם
- VO2 Max
- ועוד...

## שימוש

1. פתח את האפליקציה
2. **התחבר**: בחר "הכנס פרטים" (אימייל וסיסמה) או "התחבר עם Google"
3. אשר את בקשת הגישה לנתוני בריאות
4. לחץ על "רענן נתונים" כדי לטעון את הנתונים
5. האפליקציה תציג את כל נתוני הבריאות ותבצע ניתוח באמצעות Gemini
6. קרא את התובנות וההמלצות

## מבנה הפרויקט

- `HealthKitManager.swift` - ניהול גישה לנתוני HealthKit
- `GeminiService.swift` - אינטגרציה עם Gemini API
- `HealthDataModel.swift` - מודל נתונים לנתוני בריאות
- `HealthDashboardViewController.swift` - מסך ראשי להצגת נתונים
- `LoginViewController.swift` - מסך התחברות (אימייל/סיסמה + Google)
- `AnalysisFirestoreSync.swift` - סנכרון נתוני ניתוח ל-Firestore (לפי משתמש מחובר)
- `Config.plist` - קובץ הגדרות עם מפתח API של Gemini
- `GoogleService-Info.plist` - קונפיגורציית Firebase (להוריד מ-Firebase Console)
- `Health Reporter.entitlements` - הרשאות HealthKit

## סנכרון נתונים בענן (Firestore)

כאשר המשתמש מחובר (אימייל או Google), נתוני הניתוח (תובנות + המלצות) נשמרים גם ב-**Firestore** תחת `users/{userId}`. בכניסה ממכשיר אחר, האפליקציה טוענת את הנתונים מהענן (עם timeout קצר) ומציגה אותם אם הם עדכניים (פחות מ־24 שעות). כך התובנות וההמלצות זמינות **מכל מכשיר** בו מתחברים עם אותו חשבון.

## הערות

- האפליקציה קוראת נתונים מ-30 הימים האחרונים
- ניתוח הנתונים מתבצע באמצעות Gemini Pro
- כל הנתונים נשארים במכשיר ולא נשלחים לשרתים חיצוניים מלבד Gemini

## רישיון

פרויקט זה נוצר לשימוש אישי.
