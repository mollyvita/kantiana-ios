import Foundation

/// Moodle web-service client (REST protocol, `moodle_mobile_app` service).
public actor MoodleAPI {
    public static let eiosURL = URL(string: "https://eios.kantiana.ru")!
    public static let lmsURL = URL(string: "https://lms.kantiana.ru")!

    public nonisolated let baseURL: URL
    public private(set) var token: String?
    private var site: MoodleSiteInfo?
    private let http: HTTPClient
    private let decoder = JSONDecoder()

    init(http: HTTPClient, baseURL: URL, token: String? = nil) {
        self.http = http
        self.baseURL = baseURL
        self.token = token
    }

    public var isAuthenticated: Bool { token != nil }

    public func reset() {
        token = nil
        site = nil
    }

    func setToken(_ token: String?) {
        self.token = token
        site = nil
    }

    /// Password login via /login/token.php (works on lms.kantiana.ru with the full e-mail).
    @discardableResult
    public func login(username: String, password: String) async throws -> String {
        let res = try await http.request(baseURL.appendingPathComponent("login/token.php"), method: "POST",
                                         headers: ["Content-Type": "application/x-www-form-urlencoded"],
                                         body: formEncode([("username", username), ("password", password), ("service", "moodle_mobile_app")]))
        struct R: Decodable { let token: String?; let error: String?; let errorcode: String? }
        let r = try decoder.decode(R.self, from: res.body)
        guard let t = r.token else { throw KantianaError("Moodle login failed: \(r.error ?? String(res.status))", status: 401, code: r.errorcode) }
        setToken(t)
        return t
    }

    /// SSO login: open an authenticated launch URL (the LK `eios` service URL), then exchange the
    /// MoodleSession for a mobile web-service token via tool_mobile/launch.php.
    @discardableResult
    public func login(ssoURL: URL) async throws -> String {
        _ = try await http.request(ssoURL)
        guard await http.hasCookie("MoodleSession", host: baseURL.host ?? "") else {
            throw KantianaError("Moodle SSO failed: no MoodleSession cookie", status: 401)
        }
        let passport = String(Int.random(in: 100_000_000...999_999_999))
        // The WAF in front of eios rejects `urlscheme=moodlemobile`; the default scheme is used then.
        let launch = baseURL.appendingPathComponent("admin/tool/mobile/launch.php")
            .appending(query: ["service": "moodle_mobile_app", "passport": passport])
        let res = try await http.request(launch, followRedirects: false)
        let location = res.header("Location") ?? ""
        guard let range = location.range(of: #"token=([A-Za-z0-9+/=]+)"#, options: .regularExpression) else {
            throw KantianaError("Moodle SSO launch failed (HTTP \(res.status))", status: res.status)
        }
        let b64 = String(location[range].dropFirst("token=".count))
        guard let decoded = Data(base64Encoded: b64).map({ String(decoding: $0, as: UTF8.self) }) else {
            throw KantianaError("Moodle SSO: bad token encoding", status: 401)
        }
        let parts = decoded.components(separatedBy: ":::")
        guard parts.count >= 2, !parts[1].isEmpty else { throw KantianaError("Moodle SSO returned an empty token", status: 401) }
        setToken(parts[1])
        return parts[1]
    }

    /// Calls any Moodle web-service function and returns the raw JSON.
    public func callRaw(_ function: String, _ args: MoodleArgs = [:]) async throws -> Data {
        guard let token else { throw KantianaError("Moodle: not authenticated", status: 401) }
        var pairs = encodeMoodleArgs(args)
        pairs += [("wstoken", token), ("wsfunction", function), ("moodlewsrestformat", "json")]
        let res = try await http.request(baseURL.appendingPathComponent("webservice/rest/server.php"), method: "POST",
                                         headers: ["Content-Type": "application/x-www-form-urlencoded"], body: formEncode(pairs))
        if let err = try? decoder.decode(MoodleException.self, from: res.body) {
            throw KantianaError("Moodle \(function): \(err.message ?? err.exception)", status: res.status, code: err.errorcode)
        }
        guard (200..<300).contains(res.status) else {
            throw KantianaError("Moodle \(function) → HTTP \(res.status): \(res.text.prefix(200))", status: res.status)
        }
        return res.body
    }

    public func call<T: Decodable>(_ function: String, _ args: MoodleArgs = [:], as: T.Type = T.self) async throws -> T {
        let data = try await callRaw(function, args)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw KantianaError("Moodle \(function): cannot decode response (\(error))")
        }
    }

    /// Adds the token to a pluginfile.php URL on this site. Other origins are returned unchanged.
    public func fileURL(_ url: URL) -> URL {
        guard let token, url.host == baseURL.host, url.scheme == baseURL.scheme else { return url }
        var s = url.absoluteString
        if !s.contains("/webservice/pluginfile.php/") {
            s = s.replacingOccurrences(of: "/pluginfile.php/", with: "/webservice/pluginfile.php/")
        }
        return URL(string: s)!.appending(query: ["token": token])
    }

    public func download(_ url: URL) async throws -> HTTPResponse {
        let res = try await http.request(fileURL(url))
        guard (200..<300).contains(res.status) else { throw KantianaError("Download failed: HTTP \(res.status)", status: res.status) }
        return res
    }

    /// Uploads a file to the user's draft area; returns the draft itemid for use in submissions.
    public func uploadFile(filename: String, data: Data, mimeType: String = "application/octet-stream", itemid: Int = 0) async throws -> Int {
        guard let token else { throw KantianaError("Moodle: not authenticated", status: 401) }
        let boundary = "kantiana-\(UUID().uuidString)"
        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8))
        }
        field("token", token)
        field("filearea", "draft")
        field("itemid", String(itemid))
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file_1\"; filename=\"\(filename)\"\r\nContent-Type: \(mimeType)\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        let res = try await http.request(baseURL.appendingPathComponent("webservice/upload.php"), method: "POST",
                                         headers: ["Content-Type": "multipart/form-data; boundary=\(boundary)"], body: body)
        struct Item: Decodable { let itemid: Int }
        guard let items = try? decoder.decode([Item].self, from: res.body), let first = items.first else {
            throw KantianaError("Moodle upload failed: \(res.text.prefix(200))", status: res.status)
        }
        return first.itemid
    }

    // MARK: - Convenience wrappers

    public func siteInfo(refresh: Bool = false) async throws -> MoodleSiteInfo {
        if let site, !refresh { return site }
        let s: MoodleSiteInfo = try await call("core_webservice_get_site_info")
        site = s
        return s
    }

    public func userId() async throws -> Int { try await siteInfo().userid }

    public func courses() async throws -> [MoodleCourse] {
        try await call("core_enrol_get_users_courses", ["userid": .int(try await userId()), "returnusercount": 0])
    }

    public func courseContents(courseId: Int) async throws -> [MoodleSection] {
        try await call("core_course_get_contents", ["courseid": .int(courseId)])
    }

    public func assignments(courseIds: [Int] = []) async throws -> MoodleAssignmentsResponse {
        try await call("mod_assign_get_assignments", ["courseids": .array(courseIds.map { .int($0) })])
    }

    public func submissionStatus(assignId: Int) async throws -> MoodleSubmissionStatus {
        try await call("mod_assign_get_submission_status", ["assignid": .int(assignId)])
    }

    /// Saves (draft) an assignment submission with online text and/or a draft file area.
    public func saveSubmission(assignmentId: Int, text: String? = nil, fileItemId: Int? = nil) async throws {
        var plugindata: [String: MoodleArg] = [:]
        if let text { plugindata["onlinetext_editor"] = ["text": .string(text), "format": 1, "itemid": 0] }
        if let fileItemId { plugindata["files_filemanager"] = .int(fileItemId) }
        _ = try await callRaw("mod_assign_save_submission", ["assignmentid": .int(assignmentId), "plugindata": .object(plugindata)])
    }

    public func submitForGrading(assignmentId: Int) async throws {
        _ = try await callRaw("mod_assign_submit_for_grading", ["assignmentid": .int(assignmentId), "acceptsubmissionstatement": true])
    }

    public func gradesOverview() async throws -> MoodleGradeOverview { try await call("gradereport_overview_get_course_grades") }

    public func courseGrades(courseId: Int) async throws -> MoodleCourseGrades {
        try await call("gradereport_user_get_grade_items", ["courseid": .int(courseId), "userid": .int(try await userId())])
    }

    public func upcomingEvents() async throws -> [MoodleEvent] {
        try await call("core_calendar_get_calendar_upcoming_view", as: MoodleEventsResponse.self).events
    }

    /// Deadlines / actionable events on the timeline.
    public func actionEvents(from: Date = Date(), days: Int = 30, limit: Int = 50) async throws -> [MoodleEvent] {
        let start = Int(from.timeIntervalSince1970)
        return try await call("core_calendar_get_action_events_by_timesort",
                              ["timesortfrom": .int(start), "timesortto": .int(start + days * 86_400), "limitnum": .int(limit)],
                              as: MoodleEventsResponse.self).events
    }

    public func conversations(limit: Int = 20, offset: Int = 0) async throws -> [MoodleConversation] {
        try await call("core_message_get_conversations",
                       ["userid": .int(try await userId()), "limitfrom": .int(offset), "limitnum": .int(limit)],
                       as: MoodleConversationsResponse.self).conversations
    }

    public func conversationMessages(conversationId: Int, limit: Int = 50, offset: Int = 0) async throws -> MoodleConversationMessages {
        try await call("core_message_get_conversation_messages",
                       ["currentuserid": .int(try await userId()), "convid": .int(conversationId),
                        "limitfrom": .int(offset), "limitnum": .int(limit), "newest": true])
    }

    public func sendMessage(toUserId: Int, text: String) async throws {
        _ = try await callRaw("core_message_send_instant_messages", ["messages": [["touserid": .int(toUserId), "text": .string(text)]]])
    }

    public func notifications(limit: Int = 20, offset: Int = 0) async throws -> MoodleNotificationsResponse {
        try await call("message_popup_get_popup_notifications",
                       ["useridto": .int(try await userId()), "limit": .int(limit), "offset": .int(offset)])
    }

    public func markModuleComplete(cmid: Int, completed: Bool = true) async throws {
        _ = try await callRaw("core_completion_update_activity_completion_status_manually", ["cmid": .int(cmid), "completed": .bool(completed)])
    }
}
