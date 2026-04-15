import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct CommuteProvider: TimelineProvider {
    typealias Entry = CommuteEntry

    func placeholder(in context: Context) -> CommuteEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (CommuteEntry) -> Void) {
        completion(context.isPreview ? .placeholder : .fromStore())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CommuteEntry>) -> Void) {
        let entry = CommuteEntry.fromStore()

        // Refresh at the next sensible time: 07:00, 12:00, or 17:00.
        // The main app also calls WidgetCenter.shared.reloadAllTimelines() after
        // any price refresh, so the widget typically gets fresher data than this schedule alone.
        let refreshDate = nextScheduledRefresh()
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }

    /// Returns the next refresh time from a fixed schedule: 07:00, 12:00, 17:00.
    private func nextScheduledRefresh() -> Date {
        let hours = [7, 12, 17]
        let cal   = Calendar.current
        let now   = Date()

        for hour in hours {
            if let candidate = cal.nextDate(
                after: now,
                matching: DateComponents(hour: hour, minute: 0, second: 0),
                matchingPolicy: .nextTime
            ), candidate > now {
                return candidate
            }
        }
        // Fallback: 4 hours from now
        return now.addingTimeInterval(4 * 3600)
    }
}

// MARK: - Widget configuration

struct CommuteWidget: Widget {
    let kind = "CommuteWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CommuteProvider()) { entry in
            CommuteWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Commute Fuel Check")
        .description("Shows whether it's worth stopping for fuel on your commute to Heriot-Watt.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
