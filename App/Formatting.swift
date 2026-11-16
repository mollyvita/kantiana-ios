import Foundation

extension String {
    /// Rough HTML → plain text for Moodle/LK descriptions.
    var strippingHTML: String {
        var s = replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "</(p|div|li|h\\d)>", with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        for (entity, char) in ["&nbsp;": " ", "&quot;": "\"", "&laquo;": "«", "&raquo;": "»", "&mdash;": "—", "&ndash;": "–",
                               "&lt;": "<", "&gt;": ">", "&amp;": "&"] {
            s = s.replacingOccurrences(of: entity, with: char)
        }
        s = s.replacingOccurrences(of: "[ \\t\\r]+", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\n\\s*\\n+", with: "\n\n", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum Fmt {
    static let dateTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    static let dayTitle: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        return f
    }()

    static func unix(_ ts: Int?) -> String {
        guard let ts, ts > 0 else { return "—" }
        return dateTime.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }

    static func iso(_ s: String?) -> String {
        guard let s, let d = ISO8601DateFormatter().date(from: s) else { return s ?? "" }
        return dateTime.string(from: d)
    }
}
