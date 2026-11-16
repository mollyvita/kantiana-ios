import XCTest
@testable import KantianaKit
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class KantianaKitTests: XCTestCase {
    func testNormalizeLogin() {
        XCTAssertEqual(normalizeLogin("ivanov"), "ivanov@stud.kantiana.ru")
        XCTAssertEqual(normalizeLogin("ivanov", type: .employee), "ivanov@kantiana.ru")
        XCTAssertEqual(normalizeLogin(" a@b.c "), "a@b.c")
    }

    func testEncodeMoodleArgs() {
        let pairs = encodeMoodleArgs(["courseids": [517, 1], "messages": [["touserid": 5, "text": "hi"]], "flag": true])
        XCTAssertEqual(pairs.map { "\($0.0)=\($0.1)" }, [
            "courseids[0]=517", "courseids[1]=1", "flag=1", "messages[0][text]=hi", "messages[0][touserid]=5",
        ])
    }

    func testFormEncodePercentEncodesCyrillic() {
        XCTAssertEqual(String(decoding: formEncode([("q", "Иван a&b")]), as: UTF8.self), "q=%D0%98%D0%B2%D0%B0%D0%BD%20a%26b")
    }

    func testCookieJarExpiry() {
        var jar = CookieJar()
        let url = URL(string: "https://lk.kantiana.ru/")!
        jar.store(HTTPCookie.cookies(withResponseHeaderFields: ["Set-Cookie": "LK=abc; Path=/"], for: url), host: "lk.kantiana.ru")
        XCTAssertTrue(jar.has("LK", host: "lk.kantiana.ru"))
        jar.store(HTTPCookie.cookies(withResponseHeaderFields: ["Set-Cookie": "LK=x; Path=/; Expires=Thu, 01 Jan 1970 00:00:00 GMT"], for: url),
                  host: "lk.kantiana.ru")
        XCTAssertFalse(jar.has("LK", host: "lk.kantiana.ru"))
    }

    func testFileURLOnlyForSameHost() async {
        let c = KantianaClient(session: KantianaSession(cookies: CookieJar(), eiosToken: "T", lmsToken: nil))
        let own = await c.eios.fileURL(URL(string: "https://eios.kantiana.ru/pluginfile.php/1/a.pdf")!)
        XCTAssertEqual(own.absoluteString, "https://eios.kantiana.ru/webservice/pluginfile.php/1/a.pdf?token=T")
        let ws = await c.eios.fileURL(URL(string: "https://eios.kantiana.ru/webservice/pluginfile.php/1/a.pdf?forcedownload=1")!)
        XCTAssertEqual(ws.absoluteString, "https://eios.kantiana.ru/webservice/pluginfile.php/1/a.pdf?forcedownload=1&token=T")
        let evil = await c.eios.fileURL(URL(string: "https://evil.example/pluginfile.php/1/a.pdf")!)
        XCTAssertEqual(evil.absoluteString, "https://evil.example/pluginfile.php/1/a.pdf")
    }

    func testIsoDateUsesKaliningrad() {
        // 23:30 UTC on Nov 16 is 01:30 on Nov 17 in Kaliningrad.
        XCTAssertEqual(isoDate(Date(timeIntervalSince1970: 1_794_871_800)), "2026-11-17")
    }
}
