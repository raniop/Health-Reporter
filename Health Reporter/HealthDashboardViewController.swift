//
//  HealthDashboardViewController.swift
//  Health Reporter
//
//  Created on 24/01/2026.
//

import UIKit
import HealthKit

class HealthDashboardViewController: UIViewController {
    
    // MARK: - UI Components
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()
    
    private let contentView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "דוח בריאות אישי"
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textAlignment = .right
        label.textColor = .label
        return label
    }()
    
    private let refreshButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("רענן נתונים", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private let dataContainer: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 15
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private let insightsLabel: UILabel = {
        let label = UILabel()
        label.text = "תובנות וניתוח"
        label.font = .systemFont(ofSize: 22, weight: .bold)
        label.textAlignment = .right
        label.textColor = .label
        return label
    }()
    
    private let insightsTextView: UITextView = {
        let textView = UITextView()
        textView.font = .systemFont(ofSize: 16)
        textView.textAlignment = .right
        textView.isEditable = false
        textView.backgroundColor = .systemGray6
        textView.layer.cornerRadius = 10
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()
    
    private let recommendationsLabel: UILabel = {
        let label = UILabel()
        label.text = "המלצות"
        label.font = .systemFont(ofSize: 22, weight: .bold)
        label.textAlignment = .right
        label.textColor = .label
        return label
    }()
    
    private let recommendationsTextView: UITextView = {
        let textView = UITextView()
        textView.font = .systemFont(ofSize: 16)
        textView.textAlignment = .right
        textView.isEditable = false
        textView.backgroundColor = .systemGray6
        textView.layer.cornerRadius = 10
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()
    
    private var healthData: HealthDataModel?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        checkHealthKitAuthorization()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        navigationItem.title = "Health Reporter"
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addArrangedSubview(titleLabel)
        contentView.addArrangedSubview(refreshButton)
        contentView.addArrangedSubview(loadingIndicator)
        contentView.addArrangedSubview(dataContainer)
        contentView.addArrangedSubview(insightsLabel)
        contentView.addArrangedSubview(insightsTextView)
        contentView.addArrangedSubview(recommendationsLabel)
        contentView.addArrangedSubview(recommendationsTextView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),
            
            refreshButton.heightAnchor.constraint(equalToConstant: 50),
            insightsTextView.heightAnchor.constraint(equalToConstant: 200),
            recommendationsTextView.heightAnchor.constraint(equalToConstant: 200)
        ])
    }
    
    private func setupActions() {
        refreshButton.addTarget(self, action: #selector(refreshData), for: .touchUpInside)
    }
    
    // MARK: - HealthKit
    private func checkHealthKitAuthorization() {
        guard HealthKitManager.shared.isHealthDataAvailable() else {
            showAlert(title: "שגיאה", message: "HealthKit לא זמין במכשיר זה")
            return
        }
        
        HealthKitManager.shared.requestAuthorization { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.loadHealthData()
                } else {
                    self?.showAlert(title: "הרשאה נדחתה", message: "אנא אפשר גישה לנתוני בריאות בהגדרות")
                }
            }
        }
    }
    
    @objc private func refreshData() {
        loadHealthData()
    }
    
    private func loadHealthData() {
        loadingIndicator.startAnimating()
        refreshButton.isEnabled = false
        clearDataDisplay()
        
        HealthKitManager.shared.fetchAllHealthData { [weak self] healthData, error in
            DispatchQueue.main.async {
                self?.loadingIndicator.stopAnimating()
                self?.refreshButton.isEnabled = true
                
                if let error = error {
                    self?.showAlert(title: "שגיאה", message: "שגיאה בטעינת נתונים: \(error.localizedDescription)")
                    return
                }
                
                guard let healthData = healthData else {
                    self?.showAlert(title: "שגיאה", message: "לא התקבלו נתונים")
                    return
                }
                
                self?.healthData = healthData
                self?.displayHealthData(healthData)
                self?.analyzeWithGemini(healthData)
            }
        }
    }
    
    // MARK: - Display
    private func clearDataDisplay() {
        dataContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
        insightsTextView.text = ""
        recommendationsTextView.text = ""
    }
    
    private func displayHealthData(_ data: HealthDataModel) {
        dataContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // צעדים
        if let steps = data.steps {
            addDataCard(title: "צעדים", value: String(format: "%.0f", steps), unit: "צעדים")
        }
        
        // מרחק
        if let distance = data.distance {
            addDataCard(title: "מרחק", value: String(format: "%.2f", distance), unit: "ק\"מ")
        }
        
        // אנרגיה פעילה
        if let energy = data.activeEnergy {
            addDataCard(title: "אנרגיה פעילה", value: String(format: "%.0f", energy), unit: "קלוריות")
        }
        
        // דופק
        if let heartRate = data.heartRate {
            addDataCard(title: "דופק", value: String(format: "%.0f", heartRate), unit: "bpm")
        }
        
        // דופק במנוחה
        if let restingHeartRate = data.restingHeartRate {
            addDataCard(title: "דופק במנוחה", value: String(format: "%.0f", restingHeartRate), unit: "bpm")
        }
        
        // לחץ דם
        if let systolic = data.bloodPressureSystolic, let diastolic = data.bloodPressureDiastolic {
            addDataCard(title: "לחץ דם", value: "\(Int(systolic))/\(Int(diastolic))", unit: "mmHg")
        }
        
        // ריווי חמצן
        if let oxygen = data.oxygenSaturation {
            addDataCard(title: "ריווי חמצן", value: String(format: "%.1f", oxygen * 100), unit: "%")
        }
        
        // משקל
        if let weight = data.bodyMass {
            addDataCard(title: "משקל", value: String(format: "%.1f", weight), unit: "ק\"ג")
        }
        
        // BMI
        if let bmi = data.bodyMassIndex {
            addDataCard(title: "BMI", value: String(format: "%.1f", bmi), unit: "")
        }
        
        // אחוז שומן
        if let bodyFat = data.bodyFatPercentage {
            addDataCard(title: "אחוז שומן", value: String(format: "%.1f", bodyFat * 100), unit: "%")
        }
        
        // שינה
        if let sleepHours = data.sleepHours {
            addDataCard(title: "שינה", value: String(format: "%.1f", sleepHours), unit: "שעות")
        }
        
        // קלוריות תזונתיות
        if let calories = data.dietaryEnergy {
            addDataCard(title: "קלוריות תזונתיות", value: String(format: "%.0f", calories), unit: "קלוריות")
        }
        
        // סוכר בדם
        if let glucose = data.bloodGlucose {
            addDataCard(title: "סוכר בדם", value: String(format: "%.2f", glucose), unit: "mmol/L")
        }
        
        // VO2 Max
        if let vo2Max = data.vo2Max {
            addDataCard(title: "VO2 Max", value: String(format: "%.1f", vo2Max), unit: "ml/kg/min")
        }
        
        if dataContainer.arrangedSubviews.isEmpty {
            let noDataLabel = UILabel()
            noDataLabel.text = "אין נתונים זמינים"
            noDataLabel.textAlignment = .center
            noDataLabel.textColor = .secondaryLabel
            dataContainer.addArrangedSubview(noDataLabel)
        }
    }
    
    private func addDataCard(title: String, value: String, unit: String) {
        let cardView = UIView()
        cardView.backgroundColor = .systemGray6
        cardView.layer.cornerRadius = 10
        cardView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.textAlignment = .right
        titleLabel.textColor = .secondaryLabel
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let valueLabel = UILabel()
        valueLabel.text = "\(value) \(unit)"
        valueLabel.font = .systemFont(ofSize: 24, weight: .bold)
        valueLabel.textAlignment = .right
        valueLabel.textColor = .label
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        cardView.addSubview(titleLabel)
        cardView.addSubview(valueLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 15),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -15),
            
            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            valueLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 15),
            valueLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -15),
            valueLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -10),
            
            cardView.heightAnchor.constraint(equalToConstant: 80)
        ])
        
        dataContainer.addArrangedSubview(cardView)
    }
    
    // MARK: - Gemini Analysis
    private func analyzeWithGemini(_ healthData: HealthDataModel) {
        loadingIndicator.startAnimating()
        
        GeminiService.shared.analyzeHealthData(healthData) { [weak self] insights, recommendations, riskFactors, error in
            DispatchQueue.main.async {
                self?.loadingIndicator.stopAnimating()
                
                if let error = error {
                    self?.showAlert(title: "שגיאה", message: "שגיאה בניתוח נתונים: \(error.localizedDescription)")
                    return
                }
                
                var insightsText = insights ?? "לא התקבלו תובנות"
                
                if let recommendations = recommendations, !recommendations.isEmpty {
                    insightsText += "\n\nהמלצות:\n"
                    for (index, recommendation) in recommendations.enumerated() {
                        insightsText += "\(index + 1). \(recommendation)\n"
                    }
                }
                
                if let riskFactors = riskFactors, !riskFactors.isEmpty {
                    insightsText += "\n\nגורמי סיכון:\n"
                    for (index, risk) in riskFactors.enumerated() {
                        insightsText += "\(index + 1). \(risk)\n"
                    }
                }
                
                self?.insightsTextView.text = insightsText
                
                if let recommendations = recommendations, !recommendations.isEmpty {
                    self?.recommendationsTextView.text = recommendations.joined(separator: "\n\n")
                } else {
                    self?.recommendationsTextView.text = "אין המלצות זמינות כרגע"
                }
            }
        }
    }
    
    // MARK: - Helpers
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "אישור", style: .default))
        present(alert, animated: true)
    }
}
