//
//  DataSourceSheets.swift
//  Health Reporter
//
//  Sleep Data Sources (draggable priority list) + Health Data Sources
//  (per-metric row list like Apple Health settings).
//

import SwiftUI

// MARK: - Sleep Data Sources

struct LivitySleepDataSourcesSheet: View {
    @StateObject private var store = ProfileStore.shared
    @State private var editMode: EditMode = .active

    var body: some View {
        LivitySheetChrome(title: "Sleep Data Sources") {
            VStack(alignment: .leading, spacing: 16) {
                LivityHeroBlock(
                    icon: "bed.double.fill",
                    tint: LivityTheme.info,
                    title: "Prioritize Sleep Data Sources",
                    subtitle: "Drag to reorder your sleep data sources. The order determines which source takes priority when multiple devices report conflicting data."
                )

                Button {
                    // placeholder
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(LivityTheme.info)
                        Text("Why does prioritization matter?")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(LivityTheme.info)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)

                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LivityTheme.info)
                    Text("Prioritize Data Sources")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LivityTheme.textPrimary)
                    Spacer()
                }
                .padding(.top, 6)

                Text("Drag to reorder your sources. Data from higher sources will be prioritized when conflicts occur.")
                    .font(.system(size: 13))
                    .foregroundStyle(LivityTheme.textSecondary)

                List {
                    ForEach(Array(store.sleepSources.enumerated()), id: \.element.id) { idx, source in
                        sourceRow(index: idx + 1, source: source)
                            .listRowBackground(LivityTheme.cardFill)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                    }
                    .onMove { from, to in
                        store.sleepSources.move(fromOffsets: from, toOffset: to)
                        store.saveSleepSources()
                    }
                }
                .frame(minHeight: CGFloat(max(1, store.sleepSources.count)) * 90)
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, $editMode)
            }
        }
    }

    @ViewBuilder
    private func sourceRow(index: Int, source: LivitySleepSource) -> some View {
        HStack(spacing: 12) {
            Text("#\(index)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LivityTheme.textSecondary)

            ZStack {
                Circle().fill(Color.white.opacity(0.12)).frame(width: 36, height: 36)
                Image(systemName: "applewatch")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(LivityTheme.textPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(source.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(LivityTheme.textPrimary)
                Text("(\(source.subtitle))")
                    .font(.system(size: 13))
                    .foregroundStyle(LivityTheme.textSecondary)
                Text(source.lastSync)
                    .font(.system(size: 12))
                    .foregroundStyle(LivityTheme.textTertiary)
                if source.isValid {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(LivityTheme.good)
                        Text("Valid data available")
                            .font(.system(size: 12))
                            .foregroundStyle(LivityTheme.good)
                    }
                }
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: LivityTheme.cardInnerRadius, style: .continuous)
                .fill(LivityTheme.cardFill)
        )
    }
}

// MARK: - Health Data Sources

struct LivityHealthDataSourcesSheet: View {
    @StateObject private var store = ProfileStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        LivitySheetChrome(
            title: "Health Data Sources",
            trailingActionLabel: "Done",
            trailingAction: { dismiss() }
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Manage which data sources are used for each health metric.")
                    .font(.system(size: 14))
                    .foregroundStyle(LivityTheme.textSecondary)
                Text("Disable sources you don't want included in your data.")
                    .font(.system(size: 13))
                    .foregroundStyle(LivityTheme.textTertiary)

                HStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle.portrait")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LivityTheme.info)
                    Text("Metrics")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LivityTheme.textPrimary)
                    Spacer()
                }
                .padding(.top, 6)

                LivityGroupedCard {
                    ForEach(Array(LivityHealthMetric.allCases.enumerated()), id: \.element.id) { idx, metric in
                        metricRow(metric)
                        if idx < LivityHealthMetric.allCases.count - 1 { LivityRowSeparator() }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func metricRow(_ metric: LivityHealthMetric) -> some View {
        let (active, total) = metric.defaultActiveOfTotal
        LivityListRow(
            icon: metric.icon,
            iconColor: metric.color,
            title: metric.title,
            subtitle: "\(active) of \(total) sources active",
            accessory: .chevron
        ) {
            store.setMetricEnabled(metric, !(store.metricEnabled[metric] ?? true))
        }
    }
}
