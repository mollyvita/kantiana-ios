import Foundation

public enum AccountType: String, Codable, Sendable { case student, employee }

/// Normalises "ivanov", "ivanov@stud.kantiana.ru" or "ivanov@kantiana.ru" to a full LK login.
public func normalizeLogin(_ login: String, type: AccountType = .student) -> String {
    let trimmed = login.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.contains("@") { return trimmed }
    return "\(trimmed)@\(type == .student ? "stud.kantiana.ru" : "kantiana.ru")"
}

/// LK dates are in university local time (Kaliningrad).
public let universityTimeZone = TimeZone(identifier: "Europe/Kaliningrad")!

public func isoDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = universityTimeZone
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: date)
}

let snakeDecoder: JSONDecoder = {
    let d = JSONDecoder()
    d.keyDecodingStrategy = .convertFromSnakeCase
    return d
}()

/// Client for the lk.kantiana.ru JSON backend (`/backend/*`).
public struct LKAPI: Sendable {
    public static let defaultBaseURL = URL(string: "https://lk.kantiana.ru")!

    public let baseURL: URL
    let http: HTTPClient

    var host: String { baseURL.host ?? "" }

    public var isAuthenticated: Bool { get async { await http.hasCookie("LK", host: host) } }

    func raw<T: Decodable>(_ method: String, _ path: String, query: [String: String?] = [:], json: [String: Any?]? = nil,
                           as: T.Type = T.self) async throws -> LKEnvelope<T> {
        if !(await http.hasCookie("session-cookie", host: host)) { _ = try await http.request(baseURL.appendingPathComponent("")) }
        let url = baseURL.appendingPathComponent("backend" + path).appending(query: query)
        var headers = ["Accept": "application/json, text/plain, */*"]
        var body: Data?
        if let json {
            headers["Content-Type"] = "application/json"
            body = try JSONSerialization.data(withJSONObject: json.mapValues { $0 ?? NSNull() })
        }
        let res = try await http.request(url, method: method, headers: headers, body: body)
        let env: LKEnvelope<T>
        do {
            env = try snakeDecoder.decode(LKEnvelope<T>.self, from: res.body)
        } catch {
            if !(200..<300).contains(res.status) {
                throw KantianaError("LK \(method) \(path) → HTTP \(res.status): \(res.text.prefix(200))", status: res.status)
            }
            throw KantianaError("LK \(method) \(path): unexpected response (\(error))", status: res.status)
        }
        if !(200..<300).contains(res.status) || (env.response?.status ?? 0) >= 400 {
            throw KantianaError("LK \(method) \(path) → \(res.status): \(env.response?.message ?? res.text.prefix(200).description)",
                                status: res.status, code: env.response.map { String($0.status) })
        }
        return env
    }

    func payload<T: Decodable>(_ method: String, _ path: String, query: [String: String?] = [:], json: [String: Any?]? = nil) async throws -> T {
        let env: LKEnvelope<T> = try await raw(method, path, query: query, json: json)
        guard let p = env.payload else { throw KantianaError("LK \(path): empty payload") }
        return p
    }

    func paged<T: Decodable & Sendable>(_ path: String, query: [String: String?]) async throws -> LKPaged<T> {
        let env: LKEnvelope<[T]> = try await raw("GET", path, query: query)
        let items = env.payload ?? []
        return LKPaged(items: items, total: env.additional?.total ?? items.count)
    }

    public func login(_ login: String, password: String, type: AccountType = .student) async throws {
        _ = try await http.request(baseURL.appendingPathComponent(""))
        let _: LKEnvelope<[String: AnyDecodable]> = try await raw("POST", "/login", json: ["login": normalizeLogin(login, type: type), "password": password])
        if !(await isAuthenticated) { throw KantianaError("LK login failed: no session cookie returned", status: 401) }
    }

    public func profile() async throws -> LKProfile { try await payload("GET", "/profile") }

    /// SSO launch URLs for linked services (eios, mfc, communities, ...).
    public func services() async throws -> LKServices { try await payload("GET", "/profile/refresh") }

    public func notices(count: Int = 20, offset: Int = 0, active: Bool? = nil) async throws -> LKPaged<LKNotice> {
        try await paged("/notices", query: ["count": String(count), "offset": String(offset), "active": active.map { $0 ? "1" : "0" }])
    }

    public func dismissNotice(id: String) async throws {
        let _: LKEnvelope<AnyDecodable> = try await raw("PUT", "/notices", json: ["id": id])
    }

    public func news(count: Int = 20, offset: Int = 0) async throws -> LKPaged<LKNewsItem> {
        try await paged("/news", query: ["count": String(count), "offset": String(offset)])
    }

    public func schedule(date: Date = Date()) async throws -> [LKScheduleDay] {
        try await payload("GET", "/schedule", query: ["date": isoDate(date)])
    }

    /// Personal schedule for `days` consecutive days starting at `from`.
    public func schedule(from: Date, days: Int) async throws -> [LKScheduleDay] {
        try await withThrowingTaskGroup(of: (Int, [LKScheduleDay]).self) { group in
            for i in 0..<days {
                let d = from.addingTimeInterval(Double(i) * 86_400)
                group.addTask { (i, try await schedule(date: d)) }
            }
            var out: [(Int, [LKScheduleDay])] = []
            for try await r in group { out.append(r) }
            return out.sorted { $0.0 < $1.0 }.flatMap { $0.1 }
        }
    }

    public func groups() async throws -> [String] { try await payload("GET", "/schedule/group/list") }

    public func groupSchedule(group: String, date: Date = Date()) async throws -> [LKScheduleDay] {
        try await payload("GET", "/schedule/group", query: ["group_id": group, "date": isoDate(date)])
    }

    public func searchTeachers(_ query: String) async throws -> [LKTeacher] {
        let env: LKEnvelope<[LKTeacher]> = try await raw("POST", "/schedule/teachers", json: ["query": query])
        return env.payload ?? []
    }

    public func teacherSchedule(teacherId: String, date: Date = Date()) async throws -> [LKScheduleDay] {
        try await payload("GET", "/schedule/teachers", query: ["onec_univer_id": teacherId, "date": isoDate(date)])
    }
}

/// Decodes and discards any JSON value.
public struct AnyDecodable: Decodable, Sendable {
    public init(from decoder: Decoder) throws {}
}
