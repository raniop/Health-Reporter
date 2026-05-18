//
//  LivityComponents.swift
//  Health Reporter
//
//  Reusable SwiftUI components for the Livity-style UI: tinted cards, progress rings, chips, section headers.
//

import SwiftUI

// MARK: - Tinted card

struct LivityCard<Content: View>: View {
    let status: LivityStatus
    let content: Content

    init(status: LivityStatus = .neutral, @ViewBuilder content: () -> Content) {
        self.status = status
        self.content = content()
    }

    var body: some View {
        content
            .padding(LivityTheme.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: LivityTheme.cardRadius, style: .continuous)
                    .fill(status.tint)
            )
    }
}

// MARK: - Section header ("ICON + TITLE" all caps)

struct LivitySectionHeader: View {
    let icon: String
    let iconColor: Color
    let title: String

    init(icon: String, iconColor: Color = LivityTheme.info, title: String) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor)
            Text(title.uppercased())
                .font(.livitySectionTitle)
                .foregroundStyle(LivityTheme.textPrimary)
            Spacer()
        }
    }
}

// MARK: - Card header (icon + title + optional chevron)

struct LivityCardHeader: View {
    let icon: String
    let iconColor: Color
    let title: String
    let showChevron: Bool

    init(icon: String, iconColor: Color, title: String, showChevron: Bool = true) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.showChevron = showChevron
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(iconColor)
            Text(title.uppercased())
                .font(.livityCardTitle)
                .foregroundStyle(LivityTheme.textPrimary)
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(LivityTheme.textTertiary)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Circular progress ring

struct LivityRing: View {
    let progress: Double  // 0.0 - 1.0
    let color: Color
    let lineWidth: CGFloat
    let size: CGFloat

    init(progress: Double, color: Color, lineWidth: CGFloat = 10, size: CGFloat = 92) {
        self.progress = max(0, min(1, progress))
        self.color = color
        self.lineWidth = lineWidth
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(LivityTheme.ringTrack, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.35), radius: 4, x: 0, y: 0)
            // End-cap dot
            if progress > 0 && progress < 1 {
                Circle()
                    .fill(color)
                    .frame(width: lineWidth * 1.25, height: lineWidth * 1.25)
                    .offset(y: -size / 2)
                    .rotationEffect(.degrees(progress * 360))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Ring with centered content

struct LivityRingWithContent<Content: View>: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat
    let size: CGFloat
    let content: Content

    init(progress: Double, color: Color, lineWidth: CGFloat = 10, size: CGFloat = 92, @ViewBuilder content: () -> Content) {
        self.progress = progress
        self.color = color
        self.lineWidth = lineWidth
        self.size = size
        self.content = content()
    }

    var body: some View {
        ZStack {
            LivityRing(progress: progress, color: color, lineWidth: lineWidth, size: size)
            content
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Status chip (e.g., "Afternoon Dip", "Relaxed")

struct LivityChip: View {
    let text: String
    let icon: String?
    let tint: Color

    init(text: String, icon: String? = nil, tint: Color = LivityTheme.chipFill) {
        self.text = text
        self.icon = icon
        self.tint = tint
    }

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
            }
            Text(text)
                .font(.livityChip)
                .foregroundStyle(LivityTheme.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(tint)
        )
    }
}

// MARK: - Number block (number + unit)

struct LivityNumberUnit: View {
    let number: String
    let unit: String?
    let color: Color

    init(number: String, unit: String? = nil, color: Color = LivityTheme.textPrimary) {
        self.number = number
        self.unit = unit
        self.color = color
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(number)
                .font(.livityCardNumber)
                .foregroundStyle(color)
            if let unit {
                Text(unit)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(color.opacity(0.9))
            }
        }
    }
}

// MARK: - Row metric (label + value aligned, like Stress Avg/Peak/Low)

struct LivityMetricRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    let valueColor: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 16)
            Text(label)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(LivityTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(valueColor)
        }
    }
}
