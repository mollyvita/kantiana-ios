import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct KantianaError: LocalizedError, Sendable {
    public let message: String
    public let status: Int?
    public let code: String?

    public init(_ message: String, status: Int? = nil, code: String? = nil) {
        self.message = message
        self.status = status
        self.code = code
    }

    public var errorDescription: String? { message }
    public var isAuthError: Bool { status == 401 || code == "invalidtoken" || code == "servicerequireslogin" }
}

/// Per-host cookie store. Codable so a session can be persisted (e.g. in the Keychain).
public struct CookieJar: Codable, Sendable, Equatable {
    public private(set) var hosts: [String: [String: String]] = [:]

    public init() {}

    public mutating func store(_ cookies: [HTTPCookie], host: String) {
        for cookie in cookies {
            let expired = (cookie.expiresDate.map { $0 <= Date() } ?? false) || cookie.value == "deleted"
            if expired { hosts[host]?[cookie.name] = nil } else { hosts[host, default: [:]][cookie.name] = cookie.value }
        }
    }

    public func header(for host: String) -> String? {
        guard let cookies = hosts[host], !cookies.isEmpty else { return nil }
        return cookies.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
    }

    public func has(_ name: String, host: String) -> Bool { hosts[host]?[name] != nil }

    public mutating func clear() { hosts = [:] }
}

private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

public struct HTTPResponse: Sendable {
    public let status: Int
    public let headers: [String: String]
    public let body: Data
    public let url: URL

    public func header(_ name: String) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    public var text: String { String(decoding: body, as: UTF8.self) }
}

/// URLSession wrapper that follows redirects itself so cookies are kept across hosts
/// (the LK → eios SSO hop) and the `moodlemobile://` launch redirect can be read.
public actor HTTPClient {
    public static let defaultUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"

    public var jar: CookieJar
    private let session: URLSession
    private let userAgent: String

    public init(jar: CookieJar = CookieJar(), userAgent: String = HTTPClient.defaultUserAgent) {
        self.jar = jar
        self.userAgent = userAgent
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.httpCookieStorage = nil
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config, delegate: NoRedirectDelegate(), delegateQueue: nil)
    }

    public func setJar(_ jar: CookieJar) { self.jar = jar }
    public func clearCookies() { jar.clear() }
    public func hasCookie(_ name: String, host: String) -> Bool { jar.has(name, host: host) }

    public func request(
        _ url: URL,
        method: String = "GET",
        headers: [String: String] = [:],
        body: Data? = nil,
        followRedirects: Bool = true,
        maxRedirects: Int = 10
    ) async throws -> HTTPResponse {
        var current = url
        var method = method
        var body = body
        var extraHeaders = headers
        var remaining = maxRedirects

        while true {
            var req = URLRequest(url: current)
            req.httpMethod = method
            req.httpBody = body
            req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            req.setValue("ru-RU,ru;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
            for (k, v) in extraHeaders { req.setValue(v, forHTTPHeaderField: k) }
            let host = current.host ?? ""
            if let cookie = jar.header(for: host) { req.setValue(cookie, forHTTPHeaderField: "Cookie") }

            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else { throw KantianaError("Not an HTTP response") }
            var headerMap: [String: String] = [:]
            for (k, v) in http.allHeaderFields { headerMap[String(describing: k)] = String(describing: v) }
            jar.store(HTTPCookie.cookies(withResponseHeaderFields: headerMap, for: current), host: host)

            let result = HTTPResponse(status: http.statusCode, headers: headerMap, body: data, url: current)
            guard followRedirects, (300..<400).contains(http.statusCode),
                  let location = result.header("Location"),
                  let next = URL(string: location, relativeTo: current)?.absoluteURL,
                  next.scheme == "http" || next.scheme == "https"
            else { return result }

            remaining -= 1
            if remaining < 0 { throw KantianaError("Too many redirects for \(url)") }
            if next.host != current.host || next.scheme != current.scheme || next.port != current.port {
                extraHeaders = extraHeaders.filter { !["authorization", "cookie"].contains($0.key.lowercased()) }
            }
            if http.statusCode != 307 && http.statusCode != 308 {
                method = "GET"
                body = nil
                extraHeaders = extraHeaders.filter { $0.key.lowercased() != "content-type" }
            }
            current = next
        }
    }
}

extension URL {
    func appending(query: [String: String?]) -> URL {
        var comps = URLComponents(url: self, resolvingAgainstBaseURL: false)!
        var items = comps.queryItems ?? []
        for (k, v) in query.sorted(by: { $0.key < $1.key }) { if let v { items.append(URLQueryItem(name: k, value: v)) } }
        comps.queryItems = items.isEmpty ? nil : items
        return comps.url!
    }
}
