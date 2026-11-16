import Foundation
import KantianaKit

// Live check against the real services: LK_LOGIN=... LK_PASSWORD=... swift run kantiana-smoke
let env = ProcessInfo.processInfo.environment
guard let login = env["LK_LOGIN"], let password = env["LK_PASSWORD"] else {
    print("Set LK_LOGIN and LK_PASSWORD")
    exit(1)
}

let c = KantianaClient()
try await c.login(login, password: password)
let profile = try await c.lk.profile()
print("profile:", profile.people.type, profile.people.mainOnecUniverData?.group ?? "-")
let week = try await c.lk.schedule(from: Date(), days: 7)
print("schedule days:", week.filter { !$0.classes.isEmpty }.count, "classes:", week.reduce(0) { $0 + $1.classes.count })
print("notices:", try await c.lk.notices(count: 5).total, "news:", try await c.lk.news(count: 3).items.first?.title ?? "-")
print("groups:", try await c.lk.groups().count)
let teachers = try await c.lk.searchTeachers("Иван")
print("teachers:", teachers.count)
if let t = teachers.first { print("teacher days:", try await c.lk.teacherSchedule(teacherId: t.id).count) }

try await c.connectEios()
let site = try await c.eios.siteInfo()
print("eios:", site.release ?? "-", "functions:", site.functions?.count ?? 0)
let courses = try await c.eios.courses()
print("courses:", courses.map(\.fullname))
if let course = courses.first {
    let sections = try await c.eios.courseContents(courseId: course.id)
    print("sections:", sections.count, "modules:", sections.reduce(0) { $0 + $1.modules.count })
    if let file = sections.flatMap(\.modules).compactMap({ $0.contents?.first(where: { $0.type == "file" }) }).first,
       let url = file.fileurl.flatMap(URL.init(string:)) {
        let res = try await c.eios.download(url)
        print("download:", res.status, res.header("Content-Type") ?? "-", res.body.count, "bytes")
    }
    let grades = try await c.eios.courseGrades(courseId: course.id)
    print("grade items:", grades.usergrades.first?.gradeitems.count ?? 0)
}
print("overview:", try await c.eios.gradesOverview().grades.count)
print("deadlines:", try await c.eios.actionEvents().count, "upcoming:", try await c.eios.upcomingEvents().count)
print("assignments courses:", try await c.eios.assignments().courses.count)
let convs = try await c.eios.conversations()
print("conversations:", convs.count)
if let conv = convs.first { print("messages:", try await c.eios.conversationMessages(conversationId: conv.id).messages.count) }
print("notifications:", try await c.eios.notifications().notifications.count)

try await c.connectLms(login: login, password: password)
print("lms courses:", try await c.lms.courses().count)

let restored = KantianaClient(session: await c.exportSession())
print("restored profile ok:", (try? await restored.lk.profile()) != nil, "eios ok:", (try? await restored.eios.courses()) != nil)
