import Foundation
import KantianaKit

@MainActor
final class AppModel: ObservableObject {
    enum State { case loading, loggedOut, loggedIn }

    @Published var state: State = .loading
    @Published var profile: LKProfile?
    @Published private(set) var client = KantianaClient()

    private struct Credentials: Codable { let login: String; let password: String }

    func restore() async {
        guard state == .loading else { return }
        guard let creds: Credentials = Keychain.load("credentials") else { state = .loggedOut; return }
        if let session: KantianaSession = Keychain.load("session") { client = KantianaClient(session: session) }
        do {
            profile = try await client.lk.profile()
        } catch {
            // Session expired: log in again with the stored credentials.
            do { try await login(creds.login, password: creds.password); return } catch { state = .loggedOut; return }
        }
        state = .loggedIn
    }

    func login(_ login: String, password: String) async throws {
        let c = KantianaClient()
        try await c.login(login, password: password)
        profile = try await c.lk.profile()
        client = c
        Keychain.save(Credentials(login: login, password: password), as: "credentials")
        await persist()
        state = .loggedIn
    }

    func logout() {
        Keychain.delete("credentials")
        Keychain.delete("session")
        client = KantianaClient()
        profile = nil
        state = .loggedOut
    }

    /// eios Moodle API, connecting via LK SSO on first use.
    func eios() async throws -> MoodleAPI {
        if await client.eios.isAuthenticated { return client.eios }
        do {
            try await client.connectEios()
        } catch let e as KantianaError where e.isAuthError {
            try await relogin()
            try await client.connectEios()
        }
        await persist()
        return client.eios
    }

    /// Runs an eios call, re-authenticating once if the token expired.
    func withEios<T>(_ body: (MoodleAPI) async throws -> T) async throws -> T {
        do {
            return try await body(try await eios())
        } catch let e as KantianaError where e.isAuthError {
            await client.eios.reset()
            return try await body(try await eios())
        }
    }

    /// Runs an LK call, re-authenticating once if the cookie expired.
    func withLK<T>(_ body: (LKAPI) async throws -> T) async throws -> T {
        do {
            return try await body(client.lk)
        } catch let e as KantianaError where e.isAuthError || e.status == 403 {
            try await relogin()
            return try await body(client.lk)
        }
    }

    private func relogin() async throws {
        guard let creds: Credentials = Keychain.load("credentials") else { logout(); throw KantianaError("Logged out", status: 401) }
        try await client.login(creds.login, password: creds.password)
        await persist()
    }

    private func persist() async {
        Keychain.save(await client.exportSession(), as: "session")
    }
}
