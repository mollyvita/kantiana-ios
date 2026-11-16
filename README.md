# kantiana-ios

A native SwiftUI app for BFU Kantiana. It talks directly to **lk.kantiana.ru** and **eios.kantiana.ru** (Moodle), so no server is needed.

- **Сегодня**: today's classes, the full schedule by date, and eios deadlines
- **Курсы**: courses, sections and activities. Files open in Quick Look. Assignments show status and grade, and you can submit a text answer.
- **Оценки**: the grade report for each course
- **Входящие**: LK notices (swipe to dismiss), eios notifications, news, and Moodle messages (read and reply)
- **Профиль**: profile and program, group and teacher schedule search, logout

The login and session are stored in the Keychain. When a session expires, the app logs in again with the stored login.

## Layout

- `Sources/KantianaKit`: the Swift API client (Linux and Apple). It is a port of [kantiana-api](https://github.com/mollyvita/kantiana-api): `KantianaClient` → `lk` / `eios` / `lms`, with manual redirects and a per-host cookie jar for the LK → eios SSO and the `moodlemobile://` token launch.
- `Sources/kantiana-smoke`: a live smoke test (`LK_LOGIN=… LK_PASSWORD=… swift run kantiana-smoke`)
- `App/`: the SwiftUI app
- `project.yml`: the [XcodeGen](https://github.com/yonaskolb/XcodeGen) project spec

## Build

```bash
swift test                       # KantianaKit unit tests (macOS or Linux)
brew install xcodegen && xcodegen generate
open Kantiana.xcodeproj          # run the Kantiana scheme on an iOS 17+ simulator
```
