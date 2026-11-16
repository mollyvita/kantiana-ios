import SwiftUI
import KantianaKit

struct ClassRow: View {
    let item: LKClass

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .trailing) {
                Text(item.time.start).font(.subheadline.monospacedDigit().bold())
                Text(item.time.end).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            .frame(width: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.lesson.title).font(.body.weight(.medium))
                Text(item.lesson.type + (item.subgroup.map { $0 == "Общая" ? "" : " · \($0)" } ?? ""))
                    .font(.caption).foregroundStyle(.secondary)
                if !item.teachers.isEmpty { Text(item.teachers.joined(separator: ", ")).font(.caption) }
                if let room = item.location?.room, !room.isEmpty {
                    Label(room, systemImage: "mappin.and.ellipse").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// Week-strip date picker + schedule for any loader (personal, group or teacher schedule).
struct ScheduleView: View {
    let load: (Date) async throws -> [LKScheduleDay]
    @State private var date = Date()

    var body: some View {
        List {
            Section {
                DatePicker("Дата", selection: $date, displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "ru_RU"))
            }
            AsyncContent(load: { try await load(date) }) { days in
                let classes = days.flatMap(\.classes)
                if classes.isEmpty {
                    Text("Занятий нет").foregroundStyle(.secondary)
                } else {
                    ForEach(classes, id: \.self) { ClassRow(item: $0) }
                }
            }
            .id(isoDate(date))
        }
    }
}
