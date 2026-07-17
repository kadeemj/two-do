import Foundation
import SwiftUI

enum NotesFormatting {
    /// Renders notes for the read-only task view: URLs become tappable links
    /// whose visible text is shortened to the host and leading path.
    static func attributedNotes(_ notes: String) -> AttributedString {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return AttributedString(notes)
        }

        let source = notes as NSString
        var result = AttributedString()
        var cursor = 0

        for match in detector.matches(in: notes, range: NSRange(location: 0, length: source.length)) {
            guard let url = match.url else { continue }
            if match.range.location > cursor {
                let plain = source.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
                result += AttributedString(plain)
            }
            var link = AttributedString(shortLabel(for: url))
            link.link = url
            link.underlineStyle = .single
            result += link
            cursor = match.range.location + match.range.length
        }

        if cursor < source.length {
            result += AttributedString(source.substring(from: cursor))
        }
        return result
    }

    /// "https://www.example.com/some/long/path?x=1" -> "example.com/some/…"
    static func shortLabel(for url: URL) -> String {
        if url.scheme == "mailto" {
            return String(url.absoluteString.dropFirst("mailto:".count))
        }
        guard var host = url.host else { return url.absoluteString }
        if host.hasPrefix("www.") { host = String(host.dropFirst(4)) }

        let components = url.pathComponents.filter { $0 != "/" }
        guard var first = components.first else { return host }
        if first.count > 24 {
            first = String(first.prefix(24)) + "…"
        }
        let hasMore = components.count > 1 || url.query != nil || url.fragment != nil
        return "\(host)/\(first)" + (hasMore ? "/…" : "")
    }
}
