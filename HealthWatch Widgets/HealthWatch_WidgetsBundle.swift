//
//  HealthWatch_WidgetsBundle.swift
//  HealthWatch Widgets
//
//  Widget bundle for Apple Watch complications
//

import WidgetKit
import SwiftUI

@main
struct HealthWatch_WidgetsBundle: WidgetBundle {
    var body: some Widget {
        HealthScoreComplication()
        ActivityRingsComplication()
        CarTierComplication()
        DailyMetricsComplication()
    }
}
