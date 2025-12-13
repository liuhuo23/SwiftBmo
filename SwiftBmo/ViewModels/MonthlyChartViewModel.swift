import Foundation
import CoreData
import Combine

@MainActor
final class MonthlyChartViewModel: ObservableObject {
    struct DayData: Identifiable {
        let id = UUID()
        let day: Int
        let minutes: Double
        let totalSeconds: Int64
    }

    @Published private(set) var data: [DayData] = []
    private let context: NSManagedObjectContext
    private var calendar: Calendar { Calendar.current }
    private var monthDate: Date

    init(context: NSManagedObjectContext, monthDate: Date = Date()) {
        self.context = context
        self.monthDate = monthDate
        Task { await refresh() }
    }

    func refresh(for date: Date? = nil) async {
        if let d = date { self.monthDate = d }
        let bounds = monthBounds(for: monthDate)

        let fetch: NSFetchRequest<Tasks> = Tasks.fetchRequest()
        fetch.predicate = NSPredicate(format: "finished_at >= %@ AND finished_at <= %@", bounds.start as NSDate, bounds.end as NSDate)
        fetch.sortDescriptors = [NSSortDescriptor(keyPath: \Tasks.finished_at, ascending: true)]

        do {
            let tasks = try context.fetch(fetch)

            // Group by day start
            let grouped = Dictionary(grouping: tasks) { (task) -> Date in
                guard let finished = task.finished_at else { return Date.distantPast }
                return calendar.startOfDay(for: finished)
            }

            // Prepare array with one entry per day in month
            let range = calendar.range(of: .day, in: .month, for: bounds.start) ?? (1..<32)
            var result: [DayData] = []
            for day in range {
                var comps = calendar.dateComponents([.year, .month], from: bounds.start)
                comps.day = day
                let dayDate = calendar.date(from: comps) ?? bounds.start
                let tasksForDay = grouped[calendar.startOfDay(for: dayDate)] ?? []
                let totalSeconds = tasksForDay.reduce(into: Int64(0)) { $0 += $1.total_time }
                let minutes = Double(totalSeconds) / 60.0
                result.append(DayData(day: day, minutes: minutes, totalSeconds: totalSeconds))
            }

            self.data = result
        } catch {
            // On error, set empty data
            self.data = []
        }
    }

    private func monthBounds(for date: Date) -> (start: Date, end: Date) {
        let components = calendar.dateComponents([.year, .month], from: date)
        let start = calendar.date(from: components) ?? date
        var comps = DateComponents()
        comps.month = 1
        comps.second = -1
        let end = calendar.date(byAdding: comps, to: start) ?? date
        return (start: start, end: end)
    }
}
