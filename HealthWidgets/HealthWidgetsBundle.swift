//
//  HealthWidgetsBundle.swift
//  HealthWidgets
//
//  Created by Rani Ophir on 29/01/2026.
//

import WidgetKit
import SwiftUI

@main
struct HealthWidgetsBundle: WidgetBundle {
    var body: some Widget {
        HealthScoreWidget()
        ActivityRingsWidget()
        DailySummaryWidget()
        CarTierWidget()
    }
}
