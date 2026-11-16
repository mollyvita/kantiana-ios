import Foundation

/// Serializable auth state (cookies + Moodle tokens). Store it in the Keychain to skip re-login.
public struct KantianaSession: Codable, Sendable {
    public var cookies: CookieJar
    public var eiosToken: String?
    public var lmsToken: String?
}

/// Entry point: `lk` (lk.kantiana.ru), `eios` (courses Moodle, via LK SSO) and `lms` (lms.kantiana.ru).
public final class KantianaClient: Sendable {
    public let http: HTTPClient
    public let lk: LKAPI
    public let eios: MoodleAPI
    public let lms: MoodleAPI

    public init(session: KantianaSession? = nil, lkURL: URL = LKAPI.defaultBaseURL,
                eiosURL: URL = MoodleAPI.eiosURL, lmsURL: URL = MoodleAPI.lmsURL) {
        http = HTTPClient(jar: session?.cookies ?? CookieJar())
        lk = LKAPI(baseURL: lkURL, http: http)
        eios = MoodleAPI(http: http, baseURL: eiosURL, token: session?.eiosToken)
        lms = MoodleAPI(http: http, baseURL: lmsURL, token: session?.lmsToken)
    }

    /// Logs into LK, dropping any previous account's cookies and tokens.
    public func login(_ login: String, password: String, type: AccountType = .student) async throws {
        await http.clearCookies()
        await eios.reset()
        await lms.reset()
        try await lk.login(login, password: password, type: type)
    }

    /// Gets an eios.kantiana.ru web-service token through the LK SSO link.
    @discardableResult
    public func connectEios() async throws -> String {
        if let t = await eios.token { return t }
        guard await lk.isAuthenticated else { throw KantianaError("Log in to LK before connecting eios", status: 401) }
        let services = try await lk.services().services
        guard let s = services.first(where: { $0.name == "eios" }), let raw = s.url, let url = URL(string: raw) else {
            throw KantianaError("eios is not available for this account", status: 404)
        }
        return try await eios.login(ssoURL: url)
    }

    /// Gets an lms.kantiana.ru token (direct password login with the full e-mail).
    @discardableResult
    public func connectLms(login: String, password: String, type: AccountType = .student) async throws -> String {
        if let t = await lms.token { return t }
        return try await lms.login(username: normalizeLogin(login, type: type), password: password)
    }

    public func exportSession() async -> KantianaSession {
        KantianaSession(cookies: await http.jar, eiosToken: await eios.token, lmsToken: await lms.token)
    }
}
