import SwiftUI
import KantianaKit

struct TodayView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                Section("Расписание") {
                    AsyncContent(load: { try await model.withLK { try await $0.schedule(date: Date()) } }) { days in
                        let classes = days.flatMap(\.classes)
                        if classes.isEmpty { Text("Сегодня занятий нет").foregroundStyle(.secondary) }
                        ForEach(classes, id: \.self) { ClassRow(item: $0) }
                    }
                    NavigationLink("Всё расписание") {
                        ScheduleView { d in try await model.withLK { try await $0.schedule(date: d) } }.navigationTitle("Расписание")
                    }
                }
                Section("Дедлайны") {
                    AsyncContent(load: { try await model.withEios { try await $0.actionEvents(days: 30) } }) { events in
                        if events.isEmpty { Text("Ближайших дедлайнов нет").foregroundStyle(.secondary) }
                        ForEach(events) { e in
                            VStack(alignment: .leading) {
                                Text(e.name)
                                Text("\(Fmt.unix(e.timesort ?? e.timestart)) · \(e.course?.fullname ?? "")")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(Fmt.dayTitle.string(from: Date()).capitalized)
        }
    }
}
