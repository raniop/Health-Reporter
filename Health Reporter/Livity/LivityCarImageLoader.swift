//
//  LivityCarImageLoader.swift
//  Health Reporter
//
//  Async loader for the user's Wikipedia-sourced car thumbnail. Mirrors the fetch
//  flow used by InsightsTabViewController but as a small ObservableObject so SwiftUI
//  views (LivityCarTierCard, LivityCarTierDetailSheet) can render the real photo.
//

import SwiftUI
import UIKit
import Combine

@MainActor
final class LivityCarImageLoader: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var isLoading = false
    private var lastWikiName: String?

    func load(wikiName: String?) {
        let trimmed = wikiName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else {
            image = nil
            lastWikiName = nil
            return
        }
        if trimmed == lastWikiName, image != nil { return }
        lastWikiName = trimmed

        // Fast path: shared cache populated by the legacy dashboard.
        if let cached = WidgetDataManager.shared.loadCachedCarImage(forWikiName: trimmed) {
            image = cached
            return
        }

        isLoading = true
        Task { [weak self] in
            let fetched = await Self.fetchWikipediaImage(for: trimmed)
            await MainActor.run {
                guard let self else { return }
                self.isLoading = false
                guard self.lastWikiName == trimmed else { return } // user switched car mid-flight
                if let fetched {
                    self.image = fetched
                    WidgetDataManager.shared.cacheCarImage(fetched, forWikiName: trimmed)
                }
            }
        }
    }

    // MARK: - Wikipedia fetch

    private static func fetchWikipediaImage(for wikiName: String) async -> UIImage? {
        let words = wikiName.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return nil }

        // Progressive candidates: full name → trim trailing words (min 2).
        var candidates: [String] = []
        let minCount = max(2, words.count > 3 ? 2 : words.count)
        for count in stride(from: words.count, through: minCount, by: -1) {
            candidates.append(words.prefix(count).joined(separator: " "))
        }
        var seen = Set<String>()
        candidates = candidates.filter { seen.insert($0).inserted }

        for candidate in candidates {
            if let image = await fetchWikipediaSummaryImage(title: candidate) {
                return image
            }
        }
        return nil
    }

    private static func fetchWikipediaSummaryImage(title: String) async -> UIImage? {
        let wikiTitle = title.replacingOccurrences(of: " ", with: "_")
        let api = "https://en.wikipedia.org/api/rest_v1/page/summary/\(wikiTitle)"
        guard let encoded = api.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encoded) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let thumb = json["thumbnail"] as? [String: Any],
                  let source = thumb["source"] as? String else {
                return nil
            }
            let hiRes = source
                .replacingOccurrences(of: "/320px-", with: "/640px-")
                .replacingOccurrences(of: "/330px-", with: "/640px-")
            guard let imageURL = URL(string: hiRes) else { return nil }
            let (imgData, _) = try await URLSession.shared.data(from: imageURL)
            return UIImage(data: imgData)
        } catch {
            return nil
        }
    }
}
