//
//  OverviewSheets.swift
//  Health Reporter
//
//  Sheets shown from Overview: AI enable onboarding + Activity Status selector.
//

import SwiftUI

// MARK: - AI Enable Sheet ("AION NOW HAS AI")

struct LivityAIEnableSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 40)

            Circle()
                .fill(LivityTheme.infoTint.opacity(0.7))
                .frame(width: 110, height: 110)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(LivityTheme.info)
                )

            Spacer(minLength: 28)

            Text("livity.aiSheet.title".localized)
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(LivityTheme.textPrimary)

            Spacer(minLength: 18)

            Text("livity.aiSheet.subtitle".localized)
                .font(.system(size: 16))
                .foregroundStyle(LivityTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Spacer(minLength: 28)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(LivityTheme.info)
                    Text("livity.aiSheet.privacy".localized)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LivityTheme.textPrimary)
                    Spacer()
                }
                privacyRow(icon: "xmark.circle", text: "livity.aiSheet.privacy1".localized)
                privacyRow(icon: "eye.slash", text: "livity.aiSheet.privacy2".localized)
                privacyRow(icon: "arrow.up.circle", text: "livity.aiSheet.privacy3".localized)
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 18).fill(LivityTheme.cardFill))
            .padding(.horizontal, 20)

            Spacer()

            VStack(spacing: 16) {
                Button {
                    dismiss()
                } label: {
                    Text("livity.aiSheet.enable".localized)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Capsule().fill(LivityTheme.info))
                }
                .buttonStyle(.plain)

                Button("livity.aiSheet.noThanks".localized) { dismiss() }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(LivityTheme.textSecondary)

                Text("livity.aiSheet.note".localized)
                    .font(.system(size: 13))
                    .foregroundStyle(LivityTheme.textTertiary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(LivityTheme.background.ignoresSafeArea())
    }

    private func privacyRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(LivityTheme.textSecondary)
                .frame(width: 22)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(LivityTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Activity Status sheet

enum ActivityStatus: String, CaseIterable, Identifiable {
    case active, injury, sickness, rest
    var id: String { rawValue }
    var title: String {
        switch self {
        case .active: return "livity.activity.active".localized
        case .injury: return "livity.activity.injury".localized
        case .sickness: return "livity.activity.sickness".localized
        case .rest: return "livity.activity.rest".localized
        }
    }
    var subtitle: String {
        switch self {
        case .active: return "livity.activity.active.sub".localized
        case .injury: return "livity.activity.injury.sub".localized
        case .sickness: return "livity.activity.sickness.sub".localized
        case .rest: return "livity.activity.rest.sub".localized
        }
    }
    var icon: String {
        switch self {
        case .active: return "figure.run"
        case .injury: return "cross.case.fill"
        case .sickness: return "pills.fill"
        case .rest: return "bed.double.fill"
        }
    }
    var color: Color {
        switch self {
        case .active: return LivityTheme.good
        case .injury: return LivityTheme.bad
        case .sickness: return LivityTheme.warning
        case .rest: return LivityTheme.info
        }
    }
}

struct LivityActivityStatusSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selection: ActivityStatus = .active

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.black.opacity(0.85)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)

                VStack(alignment: .center, spacing: 12) {
                    Text("livity.activity.title".localized)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(LivityTheme.textPrimary)
                    Text("livity.activity.subtitle".localized)
                        .font(.system(size: 15))
                        .foregroundStyle(LivityTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                HStack(spacing: 6) {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(LivityTheme.info)
                    Text("livity.activity.question".localized)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(LivityTheme.textPrimary)
                }

                VStack(spacing: 10) {
                    ForEach(ActivityStatus.allCases) { status in
                        statusRow(status)
                    }
                }

                Spacer(minLength: 20)

                Button {
                    dismiss()
                } label: {
                    Text("livity.activity.save".localized)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Capsule().fill(LivityTheme.info))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(LivityTheme.background.ignoresSafeArea())
    }

    private func statusRow(_ status: ActivityStatus) -> some View {
        let isSelected = selection == status
        return Button {
            selection = status
        } label: {
            HStack(spacing: 14) {
                Image(systemName: status.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(status.color))

                VStack(alignment: .leading, spacing: 4) {
                    Text(status.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(LivityTheme.textPrimary)
                    Text(status.subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(LivityTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()

                Circle()
                    .strokeBorder(isSelected ? status.color : LivityTheme.textTertiary, lineWidth: 2)
                    .background(Circle().fill(isSelected ? status.color : Color.clear))
                    .frame(width: 22, height: 22)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? status.color.opacity(0.15) : LivityTheme.cardFill)
            )
        }
        .buttonStyle(.plain)
    }
}
