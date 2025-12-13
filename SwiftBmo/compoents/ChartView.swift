import SwiftUI
import Charts

struct ChartView: View {
    @Environment(\.managedObjectContext) private var viewContext
    var body: some View {
        TabView {
            MonthlyChartView()
                .environment(\.managedObjectContext, viewContext)
                .tabItem { Label("月", systemImage: "calendar") }

            WeeklyChartView()
                .environment(\.managedObjectContext, viewContext)
                .tabItem { Label("周", systemImage: "calendar.circle") }
        }
    }
}


struct MonthlyChartView: View {
    @Environment(\.managedObjectContext) private var viewContext
    // Fetch all tasks and filter in view for the current month
    @FetchRequest(entity: Tasks.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \Tasks.finished_at, ascending: true)]) private var allTasks: FetchedResults<Tasks>

    struct DayData: Identifiable {
        let id = UUID()
        let day: Int
        let date: Date
        let minutes: Double
        let totalSeconds: Int64
    }

    private var calendar: Calendar { Calendar.current }

    private func monthBounds(for date: Date) -> (start: Date, end: Date) {
        let components = calendar.dateComponents([.year, .month], from: date)
        let start = calendar.date(from: components) ?? date
        var comps = DateComponents()
        comps.month = 1
        comps.second = -1
        let end = calendar.date(byAdding: comps, to: start) ?? date
        return (start: start, end: end)
    }

    private func groupedDayData(for date: Date) -> [DayData] {
        let bounds = monthBounds(for: date)
        let monthTasks = allTasks.filter { task in
            guard let finished = task.finished_at else { return false }
            return finished >= bounds.start && finished <= bounds.end
        }

        // Group by day start
        let grouped = Dictionary(grouping: monthTasks) { (task) -> Date in
            guard let finished = task.finished_at else { return Date.distantPast }
            return calendar.startOfDay(for: finished)
        }

        // Prepare array with one entry per day in month
        // calendar.range returns Range<Int>? so provide a Range<Int> fallback
        let range = calendar.range(of: .day, in: .month, for: bounds.start) ?? (1..<32)
        var result: [DayData] = []
        for day in range {
            var comps = calendar.dateComponents([.year, .month], from: bounds.start)
            comps.day = day
            let dayDate = calendar.date(from: comps) ?? bounds.start
            let startOfDay = calendar.startOfDay(for: dayDate)
            let tasksForDay = grouped[startOfDay] ?? []
            let totalSeconds = tasksForDay.reduce(into: Int64(0)) { $0 += $1.total_time }
            let minutes = Double(totalSeconds) / 60.0
            result.append(DayData(day: day, date: startOfDay, minutes: minutes, totalSeconds: totalSeconds))
        }

        return result
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("月度图表视图")
                .font(.title)
                .padding(.horizontal)

            let data = groupedDayData(for: Date())

            Chart {
                ForEach(data) { d in
                    BarMark(
                        x: .value("Day", d.date, unit: .day),
                        y: .value("Minutes", d.minutes)
                    )
                    .foregroundStyle(.blue)
                    .annotation(position: .top) {
                        if d.totalSeconds > 0 {
                            Text(formatSeconds(d.totalSeconds))
                                .font(.caption2)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: max(1, data.count / 6))) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .padding()
        }
    }

    private func formatSeconds(_ seconds: Int64) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm", minutes)
        } else {
            return String(format: "%ds", totalSeconds % 60)
        }
    }
}


struct WeeklyChartView: View {
    @Environment(\.managedObjectContext) private var viewContext

    // Add published data property
    @State private var data: [DaySubjectData] = []

    struct DaySubjectData: Identifiable {
        let id = UUID()
        let dayIndex: Int
        let date: Date
        let subjectName: String
        let minutes: Double
        let totalSeconds: Int64
    }

    private var calendar: Calendar { Calendar.current }

    private func weekBounds(for date: Date) -> (start: Date, end: Date) {
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) ?? date
        var comps = DateComponents()
        comps.weekOfYear = 1
        comps.second = -1
        let endOfWeek = calendar.date(byAdding: comps, to: startOfWeek) ?? date
        return (start: startOfWeek, end: endOfWeek)
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading) {
            Text("周度图表视图")
                .font(.title)
                .padding()

            // Chart view
            Chart {
                ForEach(data) { d in
                    BarMark(
                        x: .value("Day", d.date, unit: .day),
                        y: .value("Minutes", d.minutes)
                    )
                    .foregroundStyle(.blue)
                    .annotation(position: .top) {
                        if d.totalSeconds > 0 {
                            Text(formatSeconds(d.totalSeconds))
                                .font(.caption2)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: max(1, data.count / 6))) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .padding()
        }
        .task {
            // Perform the fetch when the view appears
            await self.refresh(context: viewContext, for: Date())
        }
    }

    // MARK: - Data Fetching

    func refresh(context: NSManagedObjectContext, for date: Date) async {
        let bounds = weekBounds(for: date)

        // Attempt to create a private background context from the same persistent store coordinator
        guard let psc = context.persistentStoreCoordinator else {
            // fallback to using provided context perform
            await fetchUsingContext(context: context, bounds: bounds)
            return
        }

        let bgContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        bgContext.persistentStoreCoordinator = psc

        // Define a lightweight struct to carry task info across threads
        struct RawTask {
            let finishedAt: Date?
            let totalTime: Int64
            let subjectName: String?
        }

        let rawTasks: [RawTask] = await withCheckedContinuation { cont in
            bgContext.perform {
                let fetch: NSFetchRequest<Tasks> = Tasks.fetchRequest()
                fetch.predicate = NSPredicate(format: "finished_at >= %@ AND finished_at <= %@", bounds.start as NSDate, bounds.end as NSDate)
                fetch.sortDescriptors = [NSSortDescriptor(keyPath: \Tasks.finished_at, ascending: true)]

                do {
                    let tasks = try bgContext.fetch(fetch)
                    var mapped: [RawTask] = []
                    mapped.reserveCapacity(tasks.count)
                    for t in tasks {
                        let finished = t.finished_at
                        let total = t.total_time
                        let sname = t.subject?.name
                        mapped.append(RawTask(finishedAt: finished, totalTime: total, subjectName: sname))
                    }
                    cont.resume(returning: mapped)
                } catch {
                    cont.resume(returning: [])
                }
            }
        }

        // Now aggregate on the main actor using plain data
        var subjectNames: [String] = []
        var subjectOrder: [String: Int] = [:]
        for r in rawTasks {
            if let name = r.subjectName {
                if subjectOrder[name] == nil {
                    subjectOrder[name] = subjectNames.count
                    subjectNames.append(name)
                }
            }
        }

        // Group by day start using finishedAt
        let groupedByDay = Dictionary(grouping: rawTasks) { (r) -> Date in
            guard let f = r.finishedAt else { return Date.distantPast }
            return calendar.startOfDay(for: f)
        }

        var result: [DaySubjectData] = []
        for i in 0..<7 {
            guard let dayDate = calendar.date(byAdding: .day, value: i, to: calendar.startOfDay(for: bounds.start)) else { continue }
            let tasksForDay = groupedByDay[calendar.startOfDay(for: dayDate)] ?? []

            if subjectNames.isEmpty {
                let tasksForUnknown = tasksForDay.filter { $0.subjectName == nil }
                let totalSeconds = tasksForUnknown.reduce(into: Int64(0)) { $0 += $1.totalTime }
                if totalSeconds > 0 {
                    let minutes = Double(totalSeconds) / 60.0
                    result.append(DaySubjectData(dayIndex: i, date: calendar.startOfDay(for: dayDate), subjectName: "未知", minutes: minutes, totalSeconds: totalSeconds))
                }
                continue
            }

            for name in subjectNames {
                let tasksForSubject = tasksForDay.filter { $0.subjectName == name }
                let totalSeconds = tasksForSubject.reduce(into: Int64(0)) { $0 += $1.totalTime }
                if totalSeconds > 0 {
                    let minutes = Double(totalSeconds) / 60.0
                    result.append(DaySubjectData(dayIndex: i, date: calendar.startOfDay(for: dayDate), subjectName: name, minutes: minutes, totalSeconds: totalSeconds))
                }
            }
        }

        // Update view state on main actor
        await MainActor.run { self.data = result }
    }

    // fallback fetch that uses the provided context's perform (keeps previous behavior if no PSC available)
    private func fetchUsingContext(context: NSManagedObjectContext, bounds: (start: Date, end: Date)) async {
        struct RawTask {
            let finishedAt: Date?
            let totalTime: Int64
            let subjectName: String?
        }

        let rawTasks: [RawTask] = await withCheckedContinuation { cont in
            context.perform {
                let fetch: NSFetchRequest<Tasks> = Tasks.fetchRequest()
                fetch.predicate = NSPredicate(format: "finished_at >= %@ AND finished_at <= %@", bounds.start as NSDate, bounds.end as NSDate)
                fetch.sortDescriptors = [NSSortDescriptor(keyPath: \Tasks.finished_at, ascending: true)]
                do {
                    let tasks = try context.fetch(fetch)
                    var mapped: [RawTask] = []
                    mapped.reserveCapacity(tasks.count)
                    for t in tasks {
                        let finished = t.finished_at
                        let total = t.total_time
                        let sname = t.subject?.name
                        mapped.append(RawTask(finishedAt: finished, totalTime: total, subjectName: sname))
                    }
                    cont.resume(returning: mapped)
                } catch {
                    cont.resume(returning: [])
                }
            }
        }

        // aggregate
        var subjectNames: [String] = []
        var subjectOrder: [String: Int] = [:]
        for r in rawTasks {
            if let name = r.subjectName {
                if subjectOrder[name] == nil {
                    subjectOrder[name] = subjectNames.count
                    subjectNames.append(name)
                }
            }
        }

        let groupedByDay = Dictionary(grouping: rawTasks) { (r) -> Date in
            guard let f = r.finishedAt else { return Date.distantPast }
            return calendar.startOfDay(for: f)
        }

        var result: [DaySubjectData] = []
        for i in 0..<7 {
            guard let dayDate = calendar.date(byAdding: .day, value: i, to: calendar.startOfDay(for: bounds.start)) else { continue }
            let tasksForDay = groupedByDay[calendar.startOfDay(for: dayDate)] ?? []
            if subjectNames.isEmpty {
                let tasksForUnknown = tasksForDay.filter { $0.subjectName == nil }
                let totalSeconds = tasksForUnknown.reduce(into: Int64(0)) { $0 += $1.totalTime }
                if totalSeconds > 0 {
                    let minutes = Double(totalSeconds) / 60.0
                    result.append(DaySubjectData(dayIndex: i, date: calendar.startOfDay(for: dayDate), subjectName: "未知", minutes: minutes, totalSeconds: totalSeconds))
                }
                continue
            }
            for name in subjectNames {
                let tasksForSubject = tasksForDay.filter { $0.subjectName == name }
                let totalSeconds = tasksForSubject.reduce(into: Int64(0)) { $0 += $1.totalTime }
                if totalSeconds > 0 {
                    let minutes = Double(totalSeconds) / 60.0
                    result.append(DaySubjectData(dayIndex: i, date: calendar.startOfDay(for: dayDate), subjectName: name, minutes: minutes, totalSeconds: totalSeconds))
                }
            }
        }

        await MainActor.run { self.data = result }
    }

    // MARK: - Helpers

    private func formatSeconds(_ seconds: Int64) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm", minutes)
        } else {
            return String(format: "%ds", totalSeconds % 60)
        }
    }
}


struct ChartView_Previews: PreviewProvider {
    static var previews: some View {
        ChartView()
            .environment(
                \.managedObjectContext,
                 PersistenceController.preview.container.viewContext
            )

    }
}
