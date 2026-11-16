import SwiftUI
import KantianaKit

struct GradesView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        NavigationStack {
            AsyncContent(load: { try await model.withEios { try await $0.courses() } }) { courses in
                List(courses) { c in
                    NavigationLink(c.fullname) { CourseGradesView(course: c) }
                }
            }
            .navigationTitle("Оценки")
        }
    }
}

struct CourseGradesView: View {
    @EnvironmentObject var model: AppModel
    let course: MoodleCourse

    var body: some View {
        AsyncContent(load: { try await model.withEios { try await $0.courseGrades(courseId: course.id) } }) { grades in
            List(grades.usergrades.first?.gradeitems ?? []) { item in
                HStack {
                    Text(item.itemtype == "course" ? "Итог курса" : (item.itemname ?? "—"))
                        .fontWeight(item.itemtype == "course" ? .semibold : .regular)
                    Spacer()
                    Text(item.gradeformatted ?? "—").monospacedDigit()
                    if let p = item.percentageformatted, p != "-" { Text(p).foregroundStyle(.secondary).font(.caption) }
                }
            }
        }
        .navigationTitle(course.fullname)
        .navigationBarTitleDisplayMode(.inline)
    }
}
