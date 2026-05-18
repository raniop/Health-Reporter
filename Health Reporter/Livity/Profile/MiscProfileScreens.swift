//
//  MiscProfileScreens.swift
//  Health Reporter
//
//  Remaining Profile screens: Privacy & Data, Help & Support, Account,
//  Vote for Features.
//

import SwiftUI
import SafariServices
import FirebaseAuth

// MARK: - Privacy & Data

struct LivityPrivacyDataScreen: View {
    @StateObject private var store = ProfileStore.shared
    @State private var showPrivacy = false
    @State private var showTerms = false

    private let privacyURL = URL(string: "https://healthreporter.app/privacy")!
    private let termsURL   = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    var body: some View {
        LivityScreenChrome(title: "Privacy & Data") {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    LivityGroupLabel(icon: "hand.raised", text: "Consent")
                    LivityGroupedCard {
                        LivityListRow(
                            icon: "chart.bar.fill",
                            iconColor: LivityTheme.info,
                            title: "Allow Data Comparison",
                            accessory: .toggle(Binding(
                                get: { store.allowDataCompare },
                                set: { store.allowDataCompare = $0 }
                            ))
                        )
                        LivityRowSeparator()
                        LivityListRow(
                            icon: "sparkles",
                            iconColor: LivityTheme.info,
                            title: "AI Insights",
                            accessory: .toggle(Binding(
                                get: { store.aiInsights },
                                set: { store.aiInsights = $0 }
                            ))
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 0) {
                    LivityGroupLabel(icon: "doc.text", text: "Legal")
                    LivityGroupedCard {
                        LivityListRow(
                            icon: "lock.shield.fill",
                            iconColor: LivityTheme.info,
                            title: "Privacy Policy",
                            subtitle: "Read our privacy policy",
                            accessory: .chevron
                        ) { showPrivacy = true }
                        LivityRowSeparator()
                        LivityListRow(
                            icon: "doc.plaintext.fill",
                            iconColor: LivityTheme.textSecondary,
                            title: "Terms & Conditions",
                            subtitle: "View terms of service",
                            accessory: .chevron
                        ) { showTerms = true }
                    }
                }
            }
        }
        .sheet(isPresented: $showPrivacy) { SafariView(url: privacyURL) }
        .sheet(isPresented: $showTerms)   { SafariView(url: termsURL) }
    }
}

// MARK: - Help & Support

struct LivityHelpSupportScreen: View {
    private let manualURL = URL(string: "https://healthreporter.app/manual")!
    private let feedbackURL = URL(string: "mailto:support@healthreporter.app")!
    @State private var showManual = false

    var body: some View {
        LivityScreenChrome(title: "Help & Support") {
            VStack(alignment: .leading, spacing: 16) {
                LivityGroupedCard {
                    LivityListRow(
                        icon: "book.fill",
                        iconColor: LivityTheme.info,
                        title: "User Manual",
                        subtitle: "Learn how to use every feature",
                        accessory: .chevron
                    ) { showManual = true }
                    LivityRowSeparator()
                    LivityListRow(
                        icon: "envelope.fill",
                        iconColor: LivityTheme.info,
                        title: "Send Feedback",
                        subtitle: "Tell us what's working and what's not",
                        accessory: .chevron
                    ) {
                        UIApplication.shared.open(feedbackURL)
                    }
                    LivityRowSeparator()
                    LivityListRow(
                        icon: "bubble.left.fill",
                        iconColor: LivityTheme.good,
                        title: "Contact Us",
                        subtitle: "Reach our support team",
                        accessory: .chevron
                    ) {
                        UIApplication.shared.open(feedbackURL)
                    }
                }
            }
        }
        .sheet(isPresented: $showManual) { SafariView(url: manualURL) }
    }
}

// MARK: - Account

struct LivityAccountScreen: View {
    @State private var showDeleteAlert = false
    private let customerID: String = {
        // Placeholder customer ID mirroring the screenshot. Replace with
        // actual RevenueCat anonymous ID when that plumbing is ready.
        "$RCAnonymousID:\(Auth.auth().currentUser?.uid.prefix(32) ?? "9c87041e329b4f25a53f5a72c53d7319")"
    }()

    var body: some View {
        LivityScreenChrome(title: "Account") {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    LivityGroupLabel(icon: "person.crop.circle", text: "Account")
                    LivityGroupedCard {
                        LivityListRow(
                            icon: "trash.fill",
                            iconColor: LivityTheme.bad,
                            title: "Delete Account",
                            subtitle: "Permanently delete your account and all data",
                            accessory: .chevron
                        ) { showDeleteAlert = true }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Customer ID")
                            .font(.system(size: 13))
                            .foregroundStyle(LivityTheme.textSecondary)
                        Spacer()
                        Button {
                            UIPasteboard.general.string = customerID
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(LivityTheme.textSecondary)
                        }
                    }
                    HStack {
                        Text(customerID)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(LivityTheme.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer()
                        Button {
                            UIPasteboard.general.string = customerID
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(LivityTheme.textSecondary)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(LivityTheme.chipFill)
                    )
                }
            }
        }
        .alert("Delete Account?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                // Placeholder — actual delete flow wired elsewhere.
                try? Auth.auth().signOut()
            }
        } message: {
            Text("This will permanently remove your Livity data. This can't be undone.")
        }
    }
}

// MARK: - Vote for Features

struct LivityVoteForFeaturesScreen: View {
    private let url = URL(string: "https://livityapp.canny.io")!
    @State private var showSafari = false

    var body: some View {
        LivityScreenChrome(title: "Vote for Features") {
            VStack(alignment: .leading, spacing: 16) {
                LivityHeroBlock(
                    icon: "hand.thumbsup.fill",
                    tint: LivityTheme.info,
                    title: "Help shape the future of Livity",
                    subtitle: "Upvote what matters to you. Every vote helps us prioritize what we build next."
                )

                Button {
                    showSafari = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.thumbsup.fill")
                        Text("Open the feedback board")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: LivityTheme.cardInnerRadius, style: .continuous)
                            .fill(LivityTheme.info)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showSafari) { SafariView(url: url) }
    }
}

// MARK: - SFSafariViewController wrapper

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
