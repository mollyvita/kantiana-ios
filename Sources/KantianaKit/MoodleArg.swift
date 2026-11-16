import Foundation

/// A Moodle REST argument. Nested values are flattened to `a[0][b]=c` form encoding.
public indirect enum MoodleArg: Sendable, Equatable, ExpressibleByStringLiteral, ExpressibleByIntegerLiteral,
    ExpressibleByBooleanLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral, ExpressibleByFloatLiteral {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([MoodleArg])
    case object([String: MoodleArg])

    public init(stringLiteral value: String) { self = .string(value) }
    public init(integerLiteral value: Int) { self = .int(value) }
    public init(floatLiteral value: Double) { self = .double(value) }
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(arrayLiteral elements: MoodleArg...) { self = .array(elements) }
    public init(dictionaryLiteral elements: (String, MoodleArg)...) { self = .object(Dictionary(uniqueKeysWithValues: elements)) }

    /// Converts JSON-like values (e.g. from `JSONSerialization`) into Moodle args.
    public init?(json: Any) {
        switch json {
        case let v as Bool where type(of: json) == type(of: true): self = .bool(v)
        case let v as Int: self = .int(v)
        case let v as Double: self = .double(v)
        case let v as String: self = .string(v)
        case let v as [Any]: self = .array(v.compactMap { MoodleArg(json: $0) })
        case let v as [String: Any]: self = .object(v.compactMapValues { MoodleArg(json: $0) })
        default: return nil
        }
    }
}

public typealias MoodleArgs = [String: MoodleArg]

public func encodeMoodleArgs(_ args: MoodleArgs) -> [(String, String)] {
    var out: [(String, String)] = []
    func walk(_ name: String, _ value: MoodleArg) {
        switch value {
        case .string(let s): out.append((name, s))
        case .int(let i): out.append((name, String(i)))
        case .double(let d): out.append((name, String(d)))
        case .bool(let b): out.append((name, b ? "1" : "0"))
        case .array(let items): for (i, v) in items.enumerated() { walk("\(name)[\(i)]", v) }
        case .object(let dict): for (k, v) in dict.sorted(by: { $0.key < $1.key }) { walk("\(name)[\(k)]", v) }
        }
    }
    for (k, v) in args.sorted(by: { $0.key < $1.key }) { walk(k, v) }
    return out
}

func formEncode(_ pairs: [(String, String)]) -> Data {
    let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
    let s = pairs.map { k, v in
        "\(k.addingPercentEncoding(withAllowedCharacters: allowed)!)=\(v.addingPercentEncoding(withAllowedCharacters: allowed)!)"
    }.joined(separator: "&")
    return Data(s.utf8)
}
