# מפרט מדדים – משמעות ולא נתונים גולמיים

**מטרה:** חישובים שמייצרים משמעות (מצב, סיבה, טרנד, החלטה) ולא הצגת נתונים גולמיים.

**כללים:** כל מדד עובד עם נתונים חסרים (nil/0 = חסר). לא להעניש על חוסר מדידה.  
**0 = תמיד חסר, לעולם לא ערך.**

---

## שמות לתצוגה בממשק (Display Titles)

**מה להציג למשתמש – לא שמות קוד.** השתמש בטקסטים האלה בטאבים, בכותרות ובכרטיסי מדדים.

| Key (קוד) | עברית (תצוגה) | English (Display) |
|-----------|----------------|-------------------|
| **טאבים ראשיים** | | |
| tab.dashboard | בית | Home |
| tab.unified | פעילות ומגמות | Activity & Trends |
| tab.insights | תובנות | Insights |
| tab.social | חברים | Social |
| tab.profile | פרופיל | Profile |
| **קטעים במסך "פעילות ומגמות"** | | |
| unified.summary | סיכום בריאות | Health Summary |
| unified.activity | פעילות | Activity |
| unified.trends | מגמות | Trends |
| **מדדים יומיים (להצגה בכרטיס)** | | |
| nervousSystemBalance | איזון מערכת העצבים | Nervous System Balance |
| recoveryReadiness | מוכנות התאוששות | Recovery Readiness |
| recoveryDebt | חוב התאוששות | Recovery Debt |
| stressLoadIndex | עומס מתח | Stress Load |
| morningFreshness | רעננות בוקר | Morning Freshness |
| sleepQuality | איכות שינה | Sleep Quality |
| sleepConsistency | עקביות שינה | Sleep Consistency |
| sleepDebt | חוב שינה | Sleep Debt |
| trainingStrain | עומס אימון | Training Strain |
| loadBalance | איזון עומס | Load Balance |
| energyForecast | תחזית אנרגיה | Energy Forecast |
| workoutReadiness | מוכנות לאימון | Workout Readiness |
| activityScore | ציון פעילות | Activity Score |
| dailyGoals | יעדים יומיים | Daily Goals |
| cardioFitnessTrend | מגמת כושר אירובי | Cardio Fitness Trend |

**בקוד:** השתמש במפתחות לוקליזציה (למשל `metrics.nervousSystemBalance`). **בממשק:** הצג את הטקסט מהעמודה "עברית (תצוגה)" או "English (Display)" – לא את מפתח הקוד.

---

## A) Daily Metrics (מדדים יומיים)

### 1. איזון מערכת העצבים (Nervous System Balance)
- **Name:** איזון מערכת העצבים / Nervous System Balance  
- **Category:** recovery  
- **Output:** 0–100 (score)  
- **Calculation:**  
  - MVP: z-score של HRV יומי מול baseline רולינג 14–28 יום, נורמל ל־0–100 (sigmoid).  
  - V2: שילוב HRV + RHR (RHR נמוך = חיובי), משקל 70% HRV, 30% RHR הפוך.  
- **Required data:** HRV (RMSSD או SDNN) ליום הנוכחי; baseline מ־14+ ימים.  
- **Fallbacks:** אם חסר HRV – השתמש רק ב־RHR (הפוך); אם חסר גם RHR – insufficient.  
- **UX label:** נמוך: "מערכת עצבים מתוחה" + "ה־HRV נמוך מהבסיס"; בינוני: "איזון בינוני"; גבוה: "מערכת עצבים רגועה".  
- **Debug fields:** hrvRaw, hrvBaseline, rhrRaw, zScore, finalScore.

---

### 2. מוכנות התאוששות (Recovery Readiness)
- **Name:** מוכנות התאוששות / Recovery Readiness  
- **Category:** recovery  
- **Output:** 0–100  
- **Calculation:** שילוב HRV (40%), RHR (30%), Sleep Score (30%). ממוצע משוקלל עם נורמליזציה ל־0–100.  
- **Required data:** לפחות 2 מתוך 3: HRV, RHR, שינה.  
- **Fallbacks:** אם רק אחד – הצג עם אמינות נמוכה; אם אפס – insufficient.  
- **UX label:** "הגוף מוכן להתאושש" / "התאוששות חלקית" / "מומלץ להפחית עומס".  
- **Debug fields:** hrvComponent, rhrComponent, sleepComponent, weightsUsed.

---

### 3. חוב התאוששות (Recovery Debt)
- **Name:** חוב התאוששות / Recovery Debt  
- **Category:** recovery  
- **Output:** 0–100 (ככל שגבוה יותר – יותר חוב)  
- **Calculation:** ימים שבהם Recovery Readiness < 50 ב־7 הימים האחרונים; נורמל לפי מספר ימים (0–7 → 0–100).  
- **Required data:** Recovery Readiness ל־7 ימים (או proxy מ־HRV/שינה).  
- **Fallbacks:** אם פחות מ־3 ימים – insufficient.  
- **UX label:** "חוב נמוך" / "הצטברות חוב" / "חוב גבוה – מומלץ יום מנוחה".  
- **Debug fields:** daysUnder50, last7Readiness.

---

### 4. מדד עומס מתח (Stress Load Index)
- **Name:** מדד עומס מתח / Stress Load Index  
- **Category:** stress  
- **Output:** 0–100 (גבוה = יותר מתח)  
- **Calculation:** z של HRV ו־RHR מול baseline + sigmoid; כולל דקות "high stress" (סטיות מתחת ל־baseline).  
- **Required data:** HRV ו/או RHR ליום; baseline 14–28 יום.  
- **Fallbacks:** חסר HRV – רק RHR; חסר הכל – insufficient.  
- **UX label:** "מתח נמוך" / "מתח בינוני" / "מתח גבוה – שקול הפחתת גירויים".  
- **Debug fields:** stressZ, highStressMinutes, baselineHrv, baselineRhr.

---

### 5. רעננות בוקר (Morning Freshness)
- **Name:** רעננות בוקר / Morning Freshness  
- **Category:** recovery  
- **Output:** 0–100  
- **Calculation:** MVP: ממוצע HRV/RHR בחלון 30–90 דקות אחרי יקיצה. V2: שילוב איכות שינה + HRV בוקר.  
- **Required data:** HRV או RHR בבוקר (או שינה + HRV כללי).  
- **Fallbacks:** חסר – insufficient או הערכה משינה בלבד (אמינות נמוכה).  
- **UX label:** "התחלה טובה" / "בוקר בינוני" / "עייפות בוקר".  
- **Debug fields:** morningHrv, morningRhr, windowUsed.

---

### 6. איכות שינה (Sleep Quality)
- **Name:** איכות שינה / Sleep Quality  
- **Category:** sleep  
- **Output:** 0–100  
- **Calculation:** MVP: משך + עקביות שעת שינה; V2: + שלבי שינה (עמוק/REM), יעילות, יקיצות.  
- **Required data:** משך שינה; רצוי גם שלבים ויעילות.  
- **Fallbacks:** רק משך – ציון חלקי; חסר שינה – insufficient.  
- **UX label:** "שינה טובה" / "שינה בינונית" / "שינה לא מספקת".  
- **Debug fields:** durationHours, efficiency, deepPercent, remPercent.

---

### 7. עקביות שינה (Sleep Consistency)
- **Name:** עקביות שינה / Sleep Consistency  
- **Category:** sleep / habit  
- **Output:** 0–100  
- **Calculation:** סטיית תקן של שעת השינה ו־משך ב־14 ימים; נמוך = עקבי. הפוך ל־0–100.  
- **Required data:** שינה ל־7+ ימים (רצוי 14).  
- **Fallbacks:** פחות מ־5 ימים – insufficient.  
- **UX label:** "שגרת שינה יציבה" / "חוסר עקביות" / "שגרה לא סדירה".  
- **Debug fields:** stdBedtime, stdDuration, daysUsed.

---

### 8. חוב שינה (Sleep Debt)
- **Name:** חוב שינה / Sleep Debt  
- **Category:** sleep  
- **Output:** שעות (או 0–100 נורמל)  
- **Calculation:** סכום (יעד − משך בפועל) ל־7 ימים; רק ערכים חיוביים.  
- **Required data:** משך שינה ל־7 ימים; יעד (ברירת מחדל 7–8 שעות).  
- **Fallbacks:** פחות מ־3 ימים – insufficient.  
- **UX label:** "חוב X שעות השבוע" / "במסגרת היעד".  
- **Debug fields:** targetHours, actualPerDay, totalDebtHours.

---

### 9. עומס אימון (Training Strain)
- **Name:** עומס אימון / Training Strain  
- **Category:** load  
- **Output:** TRIMP יומי (או 0–100 נורמל)  
- **Calculation:** TRIMP מבוסס דופק (זמן × עצימות); או קלוריות פעילות + דקות אימון כ־proxy.  
- **Required data:** דופק אימון או קלוריות פעילות + דקות אימון.  
- **Fallbacks:** רק צעדים/קלוריות – הערכה גסה (אמינות נמוכה).  
- **UX label:** "אימון קל" / "עומס בינוני" / "עומס גבוה".  
- **Debug fields:** trimpRaw, activeCalories, workoutMinutes.

---

### 10. איזון עומס (Load Balance)
- **Name:** איזון עומס / Load Balance  
- **Category:** load  
- **Output:** ACWR (7d/28d) או 0–100 "איזון"  
- **Calculation:** Training Load 7d / Training Load 28d; אידיאלי 0.8–1.3. נורמל ל־0–100 (מרכז סביב 1.0).  
- **Required data:** TRIMP או proxy ל־7 ו־28 ימים.  
- **Fallbacks:** חסר אימונים – insufficient או "אין עומס".  
- **UX label:** "איזון טוב" / "עומס גבוה מדי" / "יכול להעלות עומס".  
- **Debug fields:** load7d, load28d, acwr.

---

### 11. תחזית אנרגיה (Energy Forecast)
- **Name:** תחזית אנרגיה / Energy Forecast  
- **Category:** performance  
- **Output:** 0–100  
- **Calculation:** שילוב Recovery Readiness + Body Battery–style (charge משינה, drain ממתח+אימון).  
- **Required data:** שינה, HRV/RHR, עומס אימון.  
- **Fallbacks:** חסר – insufficient או רק משינה+עומס.  
- **UX label:** "אנרגיה גבוהה" / "אנרגיה בינונית" / "שקול מנוחה".  
- **Debug fields:** chargeScore, drainScore, netEnergy.

---

### 12. מוכנות לאימון (Workout Readiness)
- **Name:** מוכנות לאימון / Workout Readiness  
- **Category:** performance  
- **Output:** 0–100 + רמה (skip/light/moderate/full/push)  
- **Calculation:** שילוב Nervous System Balance, Sleep Quality, Recovery Readiness, אתמול load.  
- **Required data:** לפחות HRV או שינה; רצוי גם RHR ו־אתמול load.  
- **Fallbacks:** חסר – insufficient או "לא ניתן להעריך".  
- **UX label:** "מומלץ לדלג" / "אימון קל בלבד" / "מתאים לאימון מלא" / "יכול לדחוף".  
- **Debug fields:** components, yesterdayLoad, recommendation.

---

### 13. ציון פעילות (Activity Score)
- **Name:** ציון פעילות / Activity Score  
- **Category:** load / habit  
- **Output:** 0–100  
- **Calculation:** צעדים + קלוריות פעילות + דקות פעילות, מול baseline אישי 90 יום.  
- **Required data:** צעדים או קלוריות; רצוי 14+ ימים ל־baseline.  
- **Fallbacks:** חסר – insufficient.  
- **UX label:** "פעיל" / "בינוני" / "פעילות נמוכה".  
- **Debug fields:** steps, activeCal, baselineSteps.

---

### 14. יעדים יומיים (Daily Goals)
- **Name:** יעדים יומיים / Daily Goals  
- **Category:** habit  
- **Output:** 0–100 (% השגת יעדים)  
- **Calculation:** % יעדים שהושגו: שינה, צעדים, אימון (אם רלוונטי).  
- **Required data:** לפחות מדד אחד עם יעד מוגדר.  
- **Fallbacks:** אין יעדים – לא מציג או N/A.  
- **UX label:** "X מתוך Y יעדים" / "כל היעדים הושגו".  
- **Debug fields:** goalsSet, goalsHit, list.

---

### 15. מגמת כושר אירובי (Cardio Fitness Trend)
- **Name:** מגמת כושר אירובי / Cardio Fitness Trend  
- **Category:** performance  
- **Output:** improving / stable / declining  
- **Calculation:** השוואת RHR ו/או VO2max (אם קיים) 7d vs 28d; או HRV במנוחה.  
- **Required data:** RHR או VO2max ל־7+ ימים.  
- **Fallbacks:** חסר – insufficient.  
- **UX label:** "מגמה חיובית" / "יציב" / "ירידה – שקול התאוששות".  
- **Debug fields:** rhr7, rhr28, vo2IfAvailable, slope.

---

## B) Weekly Metrics (מדדים שבועיים)

### 1. ממוצע מוכנות התאוששות (Weekly Recovery Average)
- **Name:** ממוצע מוכנות התאוששות / Weekly Recovery Average  
- **Category:** recovery  
- **Output:** 0–100 (median של 7 ימים)  
- **Aggregation:** median(Recovery Readiness יומי × 7).  
- **השוואה לשבוע קודם:** Δ מול שבוע קודם; "עלה/ירד/יציב".  
- **Fallbacks:** פחות מ־3 ימים עם נתון – insufficient.

---

### 2. עקביות שבועית (Weekly Consistency Score)
- **Name:** עקביות שבועית / Weekly Consistency Score  
- **Category:** habit  
- **Output:** 0–100  
- **Calculation:** כמה ימים מתוך 7 היו "טובים" (למשל Recovery > 60, שינה ≥ 6 שעות).  
- **Aggregation:** count(good days) / 7 × 100.  
- **Fallbacks:** פחות מ־5 ימים – insufficient.

---

### 3. עומס שבועי (Weekly Training Load)
- **Name:** עומס אימון שבועי / Weekly Training Load  
- **Category:** load  
- **Output:** TRIMP שבועי (סכום 7 ימים)  
- **Aggregation:** sum(TRIMP יומי).  
- **השוואה:** Δ מול שבוע קודם; "עומס גבוה/נמוך/דומה".

---

### 4. Strain vs Recovery (שבועי)
- **Name:** Strain vs Recovery / Strain vs Recovery  
- **Category:** load / recovery  
- **Output:** 0–100 או יחס  
- **Calculation:** Weekly Load מול Weekly Recovery Average; איזון = לא overload ולא underload.  
- **Aggregation:** load7d, recoveryMedian7d; יחס או band.

---

### 5. מדד מתח שבועי (Weekly Stress Index)
- **Name:** מדד מתח שבועי / Weekly Stress Index  
- **Category:** stress  
- **Output:** 0–100 (ממוצע/חציון יומי)  
- **Aggregation:** median(Stress Load Index יומי).  
- **השוואה:** מול שבוע קודם.

---

### 6. שינה שבועית (Weekly Sleep Summary)
- **Name:** סיכום שינה שבועי / Weekly Sleep Summary  
- **Category:** sleep  
- **Output:** ממוצע שעות + עקביות (0–100)  
- **Aggregation:** mean(duration), std(bedtime) → Consistency.  
- **Fallbacks:** פחות מ־4 לילות – insufficient.

---

### 7. ימים "טובים" מתוך 7 (Good Days Count)
- **Name:** ימים טובים / Good Days Count  
- **Category:** habit  
- **Output:** 0–7  
- **Calculation:** ימים עם Recovery > 60 ו־Sleep Quality > 50 (ניתן להגדיר).  
- **UX label:** "X מתוך 7 ימים במצב טוב".

---

### 8. מגמת HRV שבועית (Weekly HRV Trend)
- **Name:** מגמת HRV שבועית / Weekly HRV Trend  
- **Category:** recovery  
- **Output:** improving / stable / declining  
- **Aggregation:** slope של HRV יומי על 7 ימים; השוואה ל־7 ימים קודמים.

---

## C) Monthly Metrics (מדדים חודשיים)

### 1. מגמת התאוששות חודשית (Monthly Recovery Trend)
- **Name:** מגמת התאוששות חודשית / Monthly Recovery Trend  
- **Category:** recovery  
- **Output:** slope + improving/stable/declining  
- **Calculation:** רגרסיה לינארית של Recovery Readiness יומי על 30 יום.  
- **השוואה:** החודש vs החודש הקודם.

---

### 2. סיכום עומס חודשי (Monthly Load Summary)
- **Name:** סיכום עומס חודשי / Monthly Load Summary  
- **Category:** load  
- **Output:** סה"כ TRIMP, ממוצע שבועי, השוואה לחודש קודם.  
- **Aggregation:** sum(TRIMP 30d), mean(weekly loads).

---

### 3. סיכון Overreaching / Burnout
- **Name:** סיכון עומס יתר / Overreaching Risk  
- **Category:** load / recovery  
- **Output:** 0–100 (סיכון)  
- **Calculation:** ACWR גבוה + Recovery יורד + שינה יורדת; חוקים פשוטים או מודל.  
- **UX label:** "סיכון נמוך" / "עומס גבוה – היזהר" / "סימני שחיקה".

---

### 4. מגמת כושר אירובי חודשית (Monthly Cardio Trend)
- **Name:** מגמת כושר אירובי חודשית / Monthly Cardio Trend  
- **Category:** performance  
- **Output:** שיפור/יציב/ירידה  
- **Calculation:** VO2max או RHR ממוצע 30d vs 30d קודם; או HRV baseline.

---

### 5. שינה חודשית (Monthly Sleep Summary)
- **Name:** סיכום שינה חודשי / Monthly Sleep Summary  
- **Category:** sleep  
- **Output:** ממוצע שעות, עקביות, חוב שינה מצטבר.  
- **Aggregation:** mean, std, sum(sleep debt) על 30 יום.

---

### 6. יעדים חודשיים (Monthly Goals Progress)
- **Name:** התקדמות יעדים חודשיים / Monthly Goals Progress  
- **Category:** habit  
- **Output:** % השגה לכל יעד (שינה, אימונים, עקביות).  
- **Aggregation:** count(ימים שעמדו ביעד) / 30.

---

## D) 5 Star Metrics (מדדי כוכב)

### 1. איזון מערכת העצבים (Nervous System Balance)
- **הסבר:** מראה עד כמה המערכת האוטונומית רגועה או במתח.  
- **מניע לפעולה:** "כשהמדד נמוך – עדיף אימון קל או מנוחה."  
- **דוגמאות:**  
  - גבוה: "מערכת רגועה – מתאים לאימון מלא."  
  - בינוני: "איזון בינוני – היצמד לאימון בינוני."  
  - נמוך: "מערכת מתוחה – עדיף הליכה/מתיחות או מנוחה."

---

### 2. חוב התאוששות (Recovery Debt)
- **הסבר:** כמה ימים ברצף הגוף לא התאושש מספיק.  
- **מניע:** "חוב גבוה = יום מנוחה או אימון קל מאוד."  
- **דוגמאות:** נמוך – "אין חוב"; בינוני – "המשך כרגיל עם תשומת לב"; גבוה – "מומלץ יום התאוששות."

---

### 3. מדד עומס מתח (Stress Load Index)
- **הסבר:** עומס מתח מצטבר על הגוף.  
- **מניע:** "גבוה – הפחת גירויים, שינה, נשימות."  
- **דוגמאות:** נמוך – "מתח נמוך"; בינוני – "שמור על שגרה"; גבוה – "הפחת עומס וודא שינה."

---

### 4. תחזית אנרגיה (Energy Forecast)
- **הסבר:** צפי לאנרגיה בהתבסס על טעינה והתרוקנות.  
- **מניע:** "תכנן את האימון/עבודה לפי התחזית."  
- **דוגמאות:** גבוה – "אנרגיה טובה"; בינוני – "חסוך אנרגיה לפעילות חשובה"; נמוך – "מנוחה או פעילות קלה."

---

### 5. ציון עקביות (Consistency Score)
- **הסבר:** כמה ימים מתוך השבוע/חודש היו "עקביים" (שינה, התאוששות, פעילות).  
- **מניע:** "עקביות חשובה יותר מאינטנסיביות בודדת."  
- **דוגמאות:** גבוה – "שגרה יציבה"; בינוני – "יש מקום לשיפור"; נמוך – "נסה לייצב שינה ופעילות."

---

## E) Scoring & Missing Data Rules

### Insufficient data
- **הגדרה:** פחות מהמינימום הנדרש לכל מדד (למשל < 3 ימים לשינה, < 5 ל־HRV baseline).  
- **פעולה:** לא מציגים ערך מספרי; מציגים "נתונים לא מספיקים" או מסתירים את המדד.

### אמינות נמוכה
- **מתי:** יש נתון אבל ממקור חלקי (למשל רק RHR בלי HRV, או רק 5 ימים).  
- **פעולה:** מציגים את המדד עם סימון (אייקון/צבע) "הערכה" או "אמינות נמוכה".

### איחוד מקורות (Apple + Garmin + Whoop)
- **כלל:** מקור אחד ליום למדד; עדיפות: Whoop/Garmin אם סונקו היום, אחרת Apple Health.  
- **כפילויות:** לא מסכמים אותו מדד משני מקורות באותו יום.

### התייחסות ל־0
- **0 = תמיד חסר:** לא להשתמש ב־0 כערך תקף (למשל 0 HRV = אין מדידה).  
- **בנוסחאות:** אם ערך = 0 או nil – treat as missing; לא כוללים בחישוב ממוצע/baseline.

### סקלת פלט אחידה
- **מדדי ציון:** 0–100, כאשר בדרך כלל גבוה = טוב (מלבד Stress, Recovery Debt – שם גבוה = רע).  
- **מדדי מגמה:** improving / stable / declining.  
- **מדדי כמות:** שעות, דקות, TRIMP – עם יחידות ברורות.

---

*מסמך זה משמש כמפרט יישום למפתח; נוסחאות Fallbacks ניתנים להרחבה ב־V2 (RR intervals, שלבי שינה, וכו').*
