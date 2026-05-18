//
//  LivityHeader.swift
//  Health Reporter
//
//  Overview header: "OVERVIEW" label + date pill dropdown, plus optional AI and activity-status buttons.
//

import SwiftUI

private extension VerticalAlignment {
    /// Aligns the right-side button row with the vertical center of the date pill,
    /// so the buttons don't end up floating between the OVERVIEW label and the pill.
    enum DatePillCenter: AlignmentID {
        static func defaultValue(in d: ViewDimensions) -> CGFloat { d[VerticalAlignment.center] }
    }
    static let datePillCenter = VerticalAlignment(DatePillCenter.self)
}

struct LivityOverviewHeader: View {
    @Binding var selectedDate: Date
    @Binding var showDatePicker: Bool
    let onAITap: () -> Void
    let onActivityStatusTap: () -> Void
    let onNotificationsTap: () -> Void
    var notificationBadge: Int = 0

    var body: some View {
        HStack(alignment: .datePillCenter) {
            VStack(alignment: .leading, spacing: 6) {
                Text("livity.overview.title".localized)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LivityTheme.textSecondary)
                    .tracking(0.5)

                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                        showDatePicker.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(Self.pillFormatter.string(from: selectedDate).uppercased())
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(LivityTheme.textPrimary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(LivityTheme.textPrimary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(LivityTheme.chipFill))
                }
                .buttonStyle(.plain)
                .alignmentGuide(.datePillCenter) { d in d[VerticalAlignment.center] }
            }
            Spacer()

            HStack(spacing: 10) {
                Button(action: onAITap) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(LivityTheme.info)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(LivityTheme.infoTint))
                }
                .buttonStyle(.plain)

                Button(action: onActivityStatusTap) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(LivityTheme.good)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(LivityTheme.goodTint))
                }
                .buttonStyle(.plain)

                Button(action: onNotificationsTap) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(LivityTheme.warning)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(LivityTheme.warningTint))
                        .overlay(alignment: .topTrailing) {
                            if notificationBadge > 0 {
                                Text(notificationBadge > 9 ? "9+" : "\(notificationBadge)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(LivityTheme.bad))
                                    .offset(x: 4, y: -2)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
            .alignmentGuide(.datePillCenter) { d in d[VerticalAlignment.center] }
        }
        .padding(.horizontal, LivityTheme.horizontalPadding)
        .padding(.vertical, 12)
        .background(LivityTheme.background)
    }

    private static let pillFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MM-dd"
        return f
    }()
}

// MARK: - Detail screen header (back button + small label + pill)

struct LivityDetailHeader: View {
    let title: String
    let selectedDate: Date
    let onBack: () -> Void
    let onDateTap: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(LivityTheme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(LivityTheme.chipFill))
            }
            .buttonStyle(.plain)

            VStack(alignment: .center, spacing: 4) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LivityTheme.textSecondary)
                Button(action: onDateTap) {
                    HStack(spacing: 4) {
                        Text(Self.pillFormatter.string(from: selectedDate).uppercased())
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(LivityTheme.textPrimary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(LivityTheme.textPrimary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(LivityTheme.chipFill))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)

            // Spacer equivalent to back button width
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, LivityTheme.horizontalPadding)
        .padding(.vertical, 12)
    }

    private static let pillFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MM-dd"
        return f
    }()
}
