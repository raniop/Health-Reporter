//
//  ProfileComponents.swift
//  Health Reporter
//
//  Shared list-row primitives used across every Profile screen/sheet.
//  Matches the dark "Apple Settings"-style look from the video: rounded
//  grouped cards, icon + title + subtitle, right-side accessory (chevron,
//  toggle, checkmark, radio, value text, NEW badge).
//

import SwiftUI

// MARK: - Screen scaffolding

/// Dark-first screen chrome with back button + centered title.
struct LivityScreenChrome<Content: View>: View {
    let title: String
    let showBack: Bool
    let trailing: AnyView?
    let content: Content

    init(
        title: String,
        showBack: Bool = true,
        trailing: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.showBack = showBack
        self.trailing = trailing
        self.content = content()
    }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            LivityTheme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView {
                    content
                        .padding(.horizontal, LivityTheme.horizontalPadding)
                        .padding(.top, 8)
                        .padding(.bottom, 100)
                }
            }
        }
        .navigationBarHidden(true)
    }

    private var header: some View {
        ZStack {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(LivityTheme.textPrimary)
                .frame(maxWidth: .infinity)
            HStack {
                if showBack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(LivityTheme.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(LivityTheme.chipFill))
                    }
                    .padding(.leading, 8)
                }
                Spacer()
                if let trailing {
                    trailing.padding(.trailing, 12)
                }
            }
        }
        .frame(height: 44)
        .padding(.vertical, 4)
    }
}

/// Sheet chrome: centered title + close (X) button on trailing side.
struct LivitySheetChrome<Content: View>: View {
    let title: String
    let trailingActionLabel: String?
    let trailingAction: (() -> Void)?
    let content: Content

    init(
        title: String,
        trailingActionLabel: String? = nil,
        trailingAction: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.trailingActionLabel = trailingActionLabel
        self.trailingAction = trailingAction
        self.content = content()
    }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            LivityTheme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView {
                    content
                        .padding(.horizontal, LivityTheme.horizontalPadding)
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                }
            }
        }
    }

    private var header: some View {
        ZStack {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(LivityTheme.textPrimary)
                .frame(maxWidth: .infinity)
            HStack {
                if let label = trailingActionLabel, let action = trailingAction {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(LivityTheme.textPrimary)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(LivityTheme.chipFill))
                    }
                    .padding(.leading, 12)
                    Spacer()
                    Button(label, action: action)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(LivityTheme.good)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(LivityTheme.good.opacity(0.18)))
                        .padding(.trailing, 12)
                } else {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(LivityTheme.textPrimary)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(LivityTheme.chipFill))
                    }
                    .padding(.trailing, 12)
                }
            }
        }
        .frame(height: 44)
        .padding(.vertical, 4)
    }
}

// MARK: - Grouped card

/// Rounded grouped container. Children should be `LivityListRow`s or similar.
/// Separators are drawn automatically between children.
struct LivityGroupedCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    var body: some View {
        VStack(spacing: 0) { content }
            .background(
                RoundedRectangle(cornerRadius: LivityTheme.cardRadius, style: .continuous)
                    .fill(LivityTheme.cardFill)
            )
    }
}

/// Small uppercase grey label shown above a grouped card (e.g. "CONSENT").
struct LivityGroupLabel: View {
    let icon: String?
    let text: String
    init(icon: String? = nil, text: String) {
        self.icon = icon
        self.text = text
    }
    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LivityTheme.textSecondary)
            }
            Text(text)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(LivityTheme.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }
}

// MARK: - Row accessory

enum LivityRowAccessory {
    case chevron
    case none
    case toggle(Binding<Bool>)
    case checkmark(Bool)             // shown when true
    case radio(Bool)                 // filled when true
    case value(String)               // right-aligned value text
    case newBadge                    // "NEW" pill
}

/// Single list row. Icon in a tinted circle (optional), title, subtitle, accessory.
struct LivityListRow: View {
    let icon: String?
    let iconColor: Color
    let title: String
    let subtitle: String?
    let accessory: LivityRowAccessory
    let tapAction: (() -> Void)?

    init(
        icon: String? = nil,
        iconColor: Color = LivityTheme.info,
        title: String,
        subtitle: String? = nil,
        accessory: LivityRowAccessory = .none,
        tapAction: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory
        self.tapAction = tapAction
    }

    var body: some View {
        Button(action: { tapAction?() }) {
            HStack(spacing: 12) {
                if let icon {
                    ZStack {
                        Circle()
                            .fill(iconColor.opacity(0.18))
                            .frame(width: 30, height: 30)
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(iconColor)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(LivityTheme.textPrimary)
                        if case .newBadge = accessory {
                            newPill
                        }
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(LivityTheme.textSecondary)
                    }
                }
                Spacer(minLength: 8)
                accessoryView
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var accessoryView: some View {
        switch accessory {
        case .chevron:
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LivityTheme.textTertiary)
        case .none:
            EmptyView()
        case .toggle(let binding):
            Toggle("", isOn: binding).labelsHidden().tint(LivityTheme.info)
        case .checkmark(let on):
            if on {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(LivityTheme.info)
            }
        case .radio(let on):
            Image(systemName: on ? "circle.inset.filled" : "circle")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(on ? LivityTheme.info : LivityTheme.textTertiary)
        case .value(let v):
            Text(v).font(.system(size: 15, weight: .regular)).foregroundStyle(LivityTheme.textSecondary)
        case .newBadge:
            EmptyView()
        }
    }

    private var newPill: some View {
        Text("NEW")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(LivityTheme.info))
    }
}

/// Thin separator drawn between rows inside a grouped card.
struct LivityRowSeparator: View {
    var body: some View {
        Rectangle()
            .fill(LivityTheme.separator.opacity(0.5))
            .frame(height: 0.5)
            .padding(.leading, 56)
    }
}

// MARK: - Radio card (large selectable card with icon, title, subtitle, checkmark)

struct LivityRadioCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let isSelected: Bool
    let selectedBackground: Color
    let action: () -> Void

    init(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        isSelected: Bool,
        selectedBackground: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.selectedBackground = selectedBackground ?? LivityTheme.cardFill
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? iconColor : iconColor.opacity(0.18))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.white : iconColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(LivityTheme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(LivityTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? iconColor : LivityTheme.textTertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: LivityTheme.cardInnerRadius, style: .continuous)
                    .fill(isSelected
                          ? (iconColor.opacity(0.12))
                          : LivityTheme.cardFill)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Segmented control (Auto / Manual, % of Max / HRR / Custom)

struct LivitySegmented<Value: Hashable & CaseIterable & Identifiable>: View where Value.AllCases: RandomAccessCollection {
    @Binding var selection: Value
    let titleFor: (Value) -> String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(Value.allCases)) { option in
                Button {
                    selection = option
                } label: {
                    Text(titleFor(option))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(
                            selection == option
                            ? LivityTheme.textPrimary.opacity(0.95)
                            : LivityTheme.textSecondary
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selection == option ? Color.white : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LivityTheme.chipFill)
        )
    }
}

// MARK: - Hero block (icon in circle + title + subtitle) used in many sheets

struct LivityHeroBlock: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(tint.opacity(0.22)).frame(width: 68, height: 68)
                Circle().stroke(tint.opacity(0.9), lineWidth: 1.5).frame(width: 68, height: 68)
                Image(systemName: icon).font(.system(size: 26, weight: .semibold)).foregroundStyle(tint)
            }
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(LivityTheme.textPrimary)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(LivityTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: LivityTheme.cardRadius, style: .continuous)
                .fill(LivityTheme.cardFill)
        )
    }
}

// MARK: - Info banner (blue-tinted strip with lightbulb icon etc.)

struct LivityInfoBanner: View {
    let icon: String
    let iconColor: Color
    let title: String
    private let message: String

    init(icon: String, iconColor: Color, title: String, body: String) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.message = body
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(iconColor)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LivityTheme.textPrimary)
                Text(message)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(LivityTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: LivityTheme.cardInnerRadius, style: .continuous)
                .fill(iconColor.opacity(0.12))
        )
    }
}
