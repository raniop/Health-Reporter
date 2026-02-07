# Metrics Specification – Meaning, Not Raw Data

**Goal:** Calculations that produce meaning (status, cause, trend, decision), not raw data display.

**Rules:** Every metric works with missing data (nil/0 = missing). Do not penalize for lack of measurement.
**0 = always missing, never a value.**

---

## Display Titles in the Interface

**What to show the user – not code names.** Use these texts in tabs, headings, and metric cards.

| Key (Code) | Hebrew (Display) | English (Display) |
|-----------|----------------|-------------------|
| **Main Tabs** | | |
| tab.dashboard | Home | Home |
| tab.unified | Activity & Trends | Activity & Trends |
| tab.insights | Insights | Insights |
| tab.social | Social | Social |
| tab.profile | Profile | Profile |
| **Sections in "Activity & Trends" screen** | | |
| unified.summary | Health Summary | Health Summary |
| unified.activity | Activity | Activity |
| unified.trends | Trends | Trends |
| **Daily Metrics (for card display)** | | |
| nervousSystemBalance | Nervous System Balance | Nervous System Balance |
| recoveryReadiness | Recovery Readiness | Recovery Readiness |
| recoveryDebt | Recovery Debt | Recovery Debt |
| stressLoadIndex | Stress Load | Stress Load |
| morningFreshness | Morning Freshness | Morning Freshness |
| sleepQuality | Sleep Quality | Sleep Quality |
| sleepConsistency | Sleep Consistency | Sleep Consistency |
| sleepDebt | Sleep Debt | Sleep Debt |
| trainingStrain | Training Strain | Training Strain |
| loadBalance | Load Balance | Load Balance |
| energyForecast | Energy Forecast | Energy Forecast |
| workoutReadiness | Workout Readiness | Workout Readiness |
| activityScore | Activity Score | Activity Score |
| dailyGoals | Daily Goals | Daily Goals |
| cardioFitnessTrend | Cardio Fitness Trend | Cardio Fitness Trend |

**In code:** Use localization keys (e.g. `metrics.nervousSystemBalance`). **In the UI:** Display the text from the "Hebrew (Display)" or "English (Display)" column – not the code key.

---

## A) Daily Metrics

### 1. Nervous System Balance
- **Name:** Nervous System Balance
- **Category:** recovery
- **Output:** 0–100 (score)
- **Calculation:**
  - MVP: z-score of daily HRV against a rolling 14–28 day baseline, normalized to 0–100 (sigmoid).
  - V2: Combine HRV + RHR (low RHR = positive), weight 70% HRV, 30% inverse RHR.
- **Required data:** HRV (RMSSD or SDNN) for the current day; baseline from 14+ days.
- **Fallbacks:** If HRV is missing – use only RHR (inverse); if RHR is also missing – insufficient.
- **UX label:** Low: "Nervous system is strained" + "HRV is below baseline"; Medium: "Moderate balance"; High: "Nervous system is relaxed".
- **Debug fields:** hrvRaw, hrvBaseline, rhrRaw, zScore, finalScore.

---

### 2. Recovery Readiness
- **Name:** Recovery Readiness
- **Category:** recovery
- **Output:** 0–100
- **Calculation:** Combine HRV (40%), RHR (30%), Sleep Score (30%). Weighted average normalized to 0–100.
- **Required data:** At least 2 out of 3: HRV, RHR, sleep.
- **Fallbacks:** If only one – display with low confidence; if none – insufficient.
- **UX label:** "Body is ready to recover" / "Partial recovery" / "Recommended to reduce load".
- **Debug fields:** hrvComponent, rhrComponent, sleepComponent, weightsUsed.

---

### 3. Recovery Debt
- **Name:** Recovery Debt
- **Category:** recovery
- **Output:** 0–100 (higher = more debt)
- **Calculation:** Days where Recovery Readiness < 50 in the last 7 days; normalized by number of days (0–7 -> 0–100).
- **Required data:** Recovery Readiness for 7 days (or proxy from HRV/sleep).
- **Fallbacks:** If fewer than 3 days – insufficient.
- **UX label:** "Low debt" / "Debt accumulating" / "High debt – rest day recommended".
- **Debug fields:** daysUnder50, last7Readiness.

---

### 4. Stress Load Index
- **Name:** Stress Load Index
- **Category:** stress
- **Output:** 0–100 (high = more stress)
- **Calculation:** z-score of HRV and RHR against baseline + sigmoid; includes "high stress" minutes (deviations below baseline).
- **Required data:** HRV and/or RHR for the day; baseline 14–28 days.
- **Fallbacks:** Missing HRV – RHR only; missing all – insufficient.
- **UX label:** "Low stress" / "Moderate stress" / "High stress – consider reducing stimulation".
- **Debug fields:** stressZ, highStressMinutes, baselineHrv, baselineRhr.

---

### 5. Morning Freshness
- **Name:** Morning Freshness
- **Category:** recovery
- **Output:** 0–100
- **Calculation:** MVP: Average HRV/RHR in the 30–90 minute window after waking. V2: Combine sleep quality + morning HRV.
- **Required data:** HRV or RHR in the morning (or sleep + general HRV).
- **Fallbacks:** Missing – insufficient or estimate from sleep only (low confidence).
- **UX label:** "Good start" / "Moderate morning" / "Morning fatigue".
- **Debug fields:** morningHrv, morningRhr, windowUsed.

---

### 6. Sleep Quality
- **Name:** Sleep Quality
- **Category:** sleep
- **Output:** 0–100
- **Calculation:** MVP: Duration + bedtime consistency; V2: + sleep stages (deep/REM), efficiency, awakenings.
- **Required data:** Sleep duration; preferably also stages and efficiency.
- **Fallbacks:** Duration only – partial score; missing sleep – insufficient.
- **UX label:** "Good sleep" / "Moderate sleep" / "Insufficient sleep".
- **Debug fields:** durationHours, efficiency, deepPercent, remPercent.

---

### 7. Sleep Consistency
- **Name:** Sleep Consistency
- **Category:** sleep / habit
- **Output:** 0–100
- **Calculation:** Standard deviation of bedtime and duration over 14 days; low = consistent. Inverted to 0–100.
- **Required data:** Sleep for 7+ days (preferably 14).
- **Fallbacks:** Fewer than 5 days – insufficient.
- **UX label:** "Stable sleep routine" / "Inconsistency" / "Irregular routine".
- **Debug fields:** stdBedtime, stdDuration, daysUsed.

---

### 8. Sleep Debt
- **Name:** Sleep Debt
- **Category:** sleep
- **Output:** Hours (or 0–100 normalized)
- **Calculation:** Sum of (target - actual duration) for 7 days; only positive values.
- **Required data:** Sleep duration for 7 days; target (default 7–8 hours).
- **Fallbacks:** Fewer than 3 days – insufficient.
- **UX label:** "X hours of debt this week" / "Within target".
- **Debug fields:** targetHours, actualPerDay, totalDebtHours.

---

### 9. Training Strain
- **Name:** Training Strain
- **Category:** load
- **Output:** Daily TRIMP (or 0–100 normalized)
- **Calculation:** TRIMP based on heart rate (time x intensity); or active calories + exercise minutes as proxy.
- **Required data:** Exercise heart rate or active calories + exercise minutes.
- **Fallbacks:** Steps/calories only – rough estimate (low confidence).
- **UX label:** "Light workout" / "Moderate load" / "High load".
- **Debug fields:** trimpRaw, activeCalories, workoutMinutes.

---

### 10. Load Balance
- **Name:** Load Balance
- **Category:** load
- **Output:** ACWR (7d/28d) or 0–100 "balance"
- **Calculation:** Training Load 7d / Training Load 28d; ideal 0.8–1.3. Normalized to 0–100 (centered around 1.0).
- **Required data:** TRIMP or proxy for 7 and 28 days.
- **Fallbacks:** Missing workouts – insufficient or "no load".
- **UX label:** "Good balance" / "Load too high" / "Can increase load".
- **Debug fields:** load7d, load28d, acwr.

---

### 11. Energy Forecast
- **Name:** Energy Forecast
- **Category:** performance
- **Output:** 0–100
- **Calculation:** Combine Recovery Readiness + Body Battery-style (charge from sleep, drain from stress + training).
- **Required data:** Sleep, HRV/RHR, training load.
- **Fallbacks:** Missing – insufficient or from sleep + load only.
- **UX label:** "High energy" / "Moderate energy" / "Consider resting".
- **Debug fields:** chargeScore, drainScore, netEnergy.

---

### 12. Workout Readiness
- **Name:** Workout Readiness
- **Category:** performance
- **Output:** 0–100 + level (skip/light/moderate/full/push)
- **Calculation:** Combine Nervous System Balance, Sleep Quality, Recovery Readiness, yesterday's load.
- **Required data:** At least HRV or sleep; preferably also RHR and yesterday's load.
- **Fallbacks:** Missing – insufficient or "cannot assess".
- **UX label:** "Recommended to skip" / "Light workout only" / "Suitable for full workout" / "Can push hard".
- **Debug fields:** components, yesterdayLoad, recommendation.

---

### 13. Activity Score
- **Name:** Activity Score
- **Category:** load / habit
- **Output:** 0–100
- **Calculation:** Steps + active calories + active minutes, compared to personal 90-day baseline.
- **Required data:** Steps or calories; preferably 14+ days for baseline.
- **Fallbacks:** Missing – insufficient.
- **UX label:** "Active" / "Moderate" / "Low activity".
- **Debug fields:** steps, activeCal, baselineSteps.

---

### 14. Daily Goals
- **Name:** Daily Goals
- **Category:** habit
- **Output:** 0–100 (% of goals achieved)
- **Calculation:** % of goals achieved: sleep, steps, workout (if applicable).
- **Required data:** At least one metric with a defined goal.
- **Fallbacks:** No goals – do not display or N/A.
- **UX label:** "X out of Y goals" / "All goals achieved".
- **Debug fields:** goalsSet, goalsHit, list.

---

### 15. Cardio Fitness Trend
- **Name:** Cardio Fitness Trend
- **Category:** performance
- **Output:** improving / stable / declining
- **Calculation:** Compare RHR and/or VO2max (if available) 7d vs 28d; or resting HRV.
- **Required data:** RHR or VO2max for 7+ days.
- **Fallbacks:** Missing – insufficient.
- **UX label:** "Positive trend" / "Stable" / "Declining – consider recovery".
- **Debug fields:** rhr7, rhr28, vo2IfAvailable, slope.

---

## B) Weekly Metrics

### 1. Weekly Recovery Average
- **Name:** Weekly Recovery Average
- **Category:** recovery
- **Output:** 0–100 (median of 7 days)
- **Aggregation:** median(daily Recovery Readiness x 7).
- **Comparison to previous week:** Delta vs previous week; "improved/declined/stable".
- **Fallbacks:** Fewer than 3 days with data – insufficient.

---

### 2. Weekly Consistency Score
- **Name:** Weekly Consistency Score
- **Category:** habit
- **Output:** 0–100
- **Calculation:** How many days out of 7 were "good" (e.g. Recovery > 60, sleep >= 6 hours).
- **Aggregation:** count(good days) / 7 x 100.
- **Fallbacks:** Fewer than 5 days – insufficient.

---

### 3. Weekly Training Load
- **Name:** Weekly Training Load
- **Category:** load
- **Output:** Weekly TRIMP (sum of 7 days)
- **Aggregation:** sum(daily TRIMP).
- **Comparison:** Delta vs previous week; "high load/low load/similar".

---

### 4. Strain vs Recovery (Weekly)
- **Name:** Strain vs Recovery
- **Category:** load / recovery
- **Output:** 0–100 or ratio
- **Calculation:** Weekly Load vs Weekly Recovery Average; balance = no overload and no underload.
- **Aggregation:** load7d, recoveryMedian7d; ratio or band.

---

### 5. Weekly Stress Index
- **Name:** Weekly Stress Index
- **Category:** stress
- **Output:** 0–100 (daily average/median)
- **Aggregation:** median(daily Stress Load Index).
- **Comparison:** Against previous week.

---

### 6. Weekly Sleep Summary
- **Name:** Weekly Sleep Summary
- **Category:** sleep
- **Output:** Average hours + consistency (0–100)
- **Aggregation:** mean(duration), std(bedtime) -> Consistency.
- **Fallbacks:** Fewer than 4 nights – insufficient.

---

### 7. Good Days Count
- **Name:** Good Days Count
- **Category:** habit
- **Output:** 0–7
- **Calculation:** Days with Recovery > 60 and Sleep Quality > 50 (configurable).
- **UX label:** "X out of 7 days in good condition".

---

### 8. Weekly HRV Trend
- **Name:** Weekly HRV Trend
- **Category:** recovery
- **Output:** improving / stable / declining
- **Aggregation:** Slope of daily HRV over 7 days; comparison to previous 7 days.

---

## C) Monthly Metrics

### 1. Monthly Recovery Trend
- **Name:** Monthly Recovery Trend
- **Category:** recovery
- **Output:** slope + improving/stable/declining
- **Calculation:** Linear regression of daily Recovery Readiness over 30 days.
- **Comparison:** This month vs previous month.

---

### 2. Monthly Load Summary
- **Name:** Monthly Load Summary
- **Category:** load
- **Output:** Total TRIMP, weekly average, comparison to previous month.
- **Aggregation:** sum(TRIMP 30d), mean(weekly loads).

---

### 3. Overreaching / Burnout Risk
- **Name:** Overreaching Risk
- **Category:** load / recovery
- **Output:** 0–100 (risk)
- **Calculation:** High ACWR + declining Recovery + declining sleep; simple rules or model.
- **UX label:** "Low risk" / "High load – be careful" / "Signs of burnout".

---

### 4. Monthly Cardio Trend
- **Name:** Monthly Cardio Trend
- **Category:** performance
- **Output:** Improving/stable/declining
- **Calculation:** VO2max or average RHR 30d vs previous 30d; or HRV baseline.

---

### 5. Monthly Sleep Summary
- **Name:** Monthly Sleep Summary
- **Category:** sleep
- **Output:** Average hours, consistency, cumulative sleep debt.
- **Aggregation:** mean, std, sum(sleep debt) over 30 days.

---

### 6. Monthly Goals Progress
- **Name:** Monthly Goals Progress
- **Category:** habit
- **Output:** % achievement per goal (sleep, workouts, consistency).
- **Aggregation:** count(days that met the goal) / 30.

---

## D) 5 Star Metrics

### 1. Nervous System Balance
- **Explanation:** Shows how relaxed or stressed the autonomic system is.
- **Action driver:** "When the metric is low – prefer light workout or rest."
- **Examples:**
  - High: "Relaxed system – suitable for a full workout."
  - Medium: "Moderate balance – stick to a moderate workout."
  - Low: "Strained system – prefer walking/stretching or rest."

---

### 2. Recovery Debt
- **Explanation:** How many consecutive days the body has not recovered enough.
- **Action driver:** "High debt = rest day or very light workout."
- **Examples:** Low – "No debt"; Medium – "Continue as usual with attention"; High – "Recovery day recommended."

---

### 3. Stress Load Index
- **Explanation:** Cumulative stress load on the body.
- **Action driver:** "High – reduce stimulation, sleep, breathing exercises."
- **Examples:** Low – "Low stress"; Medium – "Maintain routine"; High – "Reduce load and ensure sleep."

---

### 4. Energy Forecast
- **Explanation:** Energy prediction based on charge and drain.
- **Action driver:** "Plan your workout/work according to the forecast."
- **Examples:** High – "Good energy"; Medium – "Save energy for important activity"; Low – "Rest or light activity."

---

### 5. Consistency Score
- **Explanation:** How many days out of the week/month were "consistent" (sleep, recovery, activity).
- **Action driver:** "Consistency is more important than a single intense effort."
- **Examples:** High – "Stable routine"; Medium – "Room for improvement"; Low – "Try to stabilize sleep and activity."

---

## E) Scoring & Missing Data Rules

### Insufficient data
- **Definition:** Less than the minimum required for each metric (e.g. < 3 days for sleep, < 5 for HRV baseline).
- **Action:** Do not display a numeric value; show "Insufficient data" or hide the metric.

### Low confidence
- **When:** Data exists but from a partial source (e.g. only RHR without HRV, or only 5 days).
- **Action:** Display the metric with a marking (icon/color) "Estimate" or "Low confidence".

### Source consolidation (Apple + Garmin + Whoop)
- **Rule:** One source per day per metric; priority: Whoop/Garmin if synced today, otherwise Apple Health.
- **Duplicates:** Do not sum the same metric from two sources on the same day.

### Handling zeros
- **0 = always missing:** Do not use 0 as a valid value (e.g. 0 HRV = no measurement).
- **In formulas:** If value = 0 or nil – treat as missing; do not include in average/baseline calculation.

### Uniform output scale
- **Score metrics:** 0–100, where generally higher = better (except Stress, Recovery Debt – where higher = worse).
- **Trend metrics:** improving / stable / declining.
- **Quantity metrics:** hours, minutes, TRIMP – with clear units.

---

*This document serves as an implementation specification for the developer; formula fallbacks can be expanded in V2 (RR intervals, sleep stages, etc.).*
