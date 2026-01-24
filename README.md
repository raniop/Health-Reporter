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
3. בנה והרץ את האפליקציה

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
2. אשר את בקשת הגישה לנתוני בריאות
3. לחץ על "רענן נתונים" כדי לטעון את הנתונים
4. האפליקציה תציג את כל נתוני הבריאות ותבצע ניתוח באמצעות Gemini
5. קרא את התובנות וההמלצות

## מבנה הפרויקט

- `HealthKitManager.swift` - ניהול גישה לנתוני HealthKit
- `GeminiService.swift` - אינטגרציה עם Gemini API
- `HealthDataModel.swift` - מודל נתונים לנתוני בריאות
- `HealthDashboardViewController.swift` - מסך ראשי להצגת נתונים
- `Config.plist` - קובץ הגדרות עם מפתח API של Gemini
- `Health Reporter.entitlements` - הרשאות HealthKit

## הערות

- האפליקציה קוראת נתונים מ-30 הימים האחרונים
- ניתוח הנתונים מתבצע באמצעות Gemini Pro
- כל הנתונים נשארים במכשיר ולא נשלחים לשרתים חיצוניים מלבד Gemini

## רישיון

פרויקט זה נוצר לשימוש אישי.
