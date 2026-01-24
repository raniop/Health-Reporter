//
//  GeminiService.swift
//  Health Reporter
//
//  Created on 24/01/2026.
//

import Foundation

class GeminiService {
    static let shared = GeminiService()
    
    private var apiKey: String {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let key = plist["GeminiAPIKey"] as? String,
              key != "YOUR_GEMINI_API_KEY_HERE" else {
            fatalError("אנא הגדר את מפתח ה-API של Gemini ב-Config.plist")
        }
        return key
    }
    
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent"
    
    private init() {}
    
    /// מנתח נתוני בריאות ומחזיר תובנות
    func analyzeHealthData(_ healthData: HealthDataModel, completion: @escaping (String?, [String]?, [String]?, Error?) -> Void) {
        guard let summary = createHealthSummary(from: healthData),
              let jsonString = summary.toJSONString() else {
            completion(nil, nil, nil, NSError(domain: "GeminiService", code: -1, userInfo: [NSLocalizedDescriptionKey: "שגיאה ביצירת סיכום נתונים"]))
            return
        }
        
        let prompt = """
        אתה מומחה רפואי ומומחה לניתוח נתוני בריאות. נתח את נתוני הבריאות הבאים והצג:
        
        1. תובנות כלליות על מצב הבריאות (בעברית)
        2. המלצות ספציפיות לשיפור (רשימה)
        3. גורמי סיכון פוטנציאליים (אם יש)
        
        נתוני הבריאות:
        \(jsonString)
        
        אנא תן תשובה מפורטת בעברית, מקצועית ומועילה. התמקד בנתונים החשובים ביותר והצג המלצות מעשיות.
        """
        
        sendRequest(prompt: prompt) { response, error in
            if let error = error {
                completion(nil, nil, nil, error)
                return
            }
            
            guard let response = response else {
                completion(nil, nil, nil, NSError(domain: "GeminiService", code: -2, userInfo: [NSLocalizedDescriptionKey: "לא התקבלה תשובה מ-Gemini"]))
                return
            }
            
            // פענוח התשובה לחלקים
            let (insights, recommendations, riskFactors) = self.parseResponse(response)
            completion(insights, recommendations, riskFactors, nil)
        }
    }
    
    private func createHealthSummary(from healthData: HealthDataModel) -> HealthSummary? {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        let dateRange = DateInterval(start: startDate, end: endDate)
        
        var keyMetrics: [String: Any] = [:]
        
        if let steps = healthData.steps {
            keyMetrics["steps"] = steps
        }
        if let heartRate = healthData.heartRate {
            keyMetrics["heart_rate"] = heartRate
        }
        if let bmi = healthData.bodyMassIndex {
            keyMetrics["bmi"] = bmi
        }
        if let sleepHours = healthData.sleepHours {
            keyMetrics["sleep_hours"] = sleepHours
        }
        
        return HealthSummary(dataModel: healthData, dateRange: dateRange, keyMetrics: keyMetrics)
    }
    
    private func sendRequest(prompt: String, completion: @escaping (String?, Error?) -> Void) {
        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            completion(nil, NSError(domain: "GeminiService", code: -3, userInfo: [NSLocalizedDescriptionKey: "URL לא תקין"]))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": prompt
                        ]
                    ]
                ]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(nil, error)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let data = data else {
                completion(nil, NSError(domain: "GeminiService", code: -4, userInfo: [NSLocalizedDescriptionKey: "אין נתונים בתשובה"]))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let candidates = json["candidates"] as? [[String: Any]],
                   let firstCandidate = candidates.first,
                   let content = firstCandidate["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let firstPart = parts.first,
                   let text = firstPart["text"] as? String {
                    completion(text, nil)
                } else {
                    completion(nil, NSError(domain: "GeminiService", code: -5, userInfo: [NSLocalizedDescriptionKey: "פורמט תשובה לא תקין"]))
                }
            } catch {
                completion(nil, error)
            }
        }.resume()
    }
    
    private func parseResponse(_ response: String) -> (insights: String, recommendations: [String], riskFactors: [String]) {
        var insights = response
        var recommendations: [String] = []
        var riskFactors: [String] = []
        
        // ניסיון לפרק את התשובה לחלקים
        let lines = response.components(separatedBy: .newlines)
        var currentSection: String? = nil
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.contains("המלצות") || trimmed.contains("המלצה") || trimmed.lowercased().contains("recommendation") {
                currentSection = "recommendations"
            } else if trimmed.contains("גורמי סיכון") || trimmed.contains("סיכון") || trimmed.lowercased().contains("risk") {
                currentSection = "risks"
            } else if trimmed.hasPrefix("-") || trimmed.hasPrefix("•") || trimmed.hasPrefix("*") || trimmed.range(of: "^\\d+\\.", options: .regularExpression) != nil {
                let item = trimmed.replacingOccurrences(of: "^[-•*]\\s*", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "^\\d+\\.\\s*", with: "", options: .regularExpression)
                
                if currentSection == "recommendations" && !item.isEmpty {
                    recommendations.append(item)
                } else if currentSection == "risks" && !item.isEmpty {
                    riskFactors.append(item)
                }
            }
        }
        
        // אם לא מצאנו המלצות או גורמי סיכון מובנים, נשתמש בכל התשובה כתובנות
        if recommendations.isEmpty && riskFactors.isEmpty {
            insights = response
        }
        
        return (insights, recommendations, riskFactors)
    }
}
