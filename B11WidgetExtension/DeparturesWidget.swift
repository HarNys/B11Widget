import SwiftUI
import WidgetKit

struct DeparturesEntry: TimelineEntry {
    let date: Date
    let departures: [Departure]
    let disruptions: [Disruption]
    let error: String?
}

struct DeparturesProvider: TimelineProvider {
    func placeholder(in context: Context) -> DeparturesEntry {
        DeparturesEntry(date: .now, departures: Self.sample, disruptions: [], error: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (DeparturesEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        Task {
            let board = (try? await Entur.fetchBoard()) ?? Board(departures: Self.sample, disruptions: [])
            completion(DeparturesEntry(date: .now, departures: board.departures,
                                       disruptions: board.disruptions, error: nil))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DeparturesEntry>) -> Void) {
        Task {
            let now = Date()
            do {
                let board = try await Entur.fetchBoard()
                // One entry per minute so the countdown ticks between network refreshes.
                let start = Calendar.current.dateInterval(of: .minute, for: now)?.start ?? now
                let entries = (0..<15).map { offset in
                    let date = start.addingTimeInterval(TimeInterval(offset * 60))
                    return DeparturesEntry(
                        date: date,
                        departures: board.departures.filter { $0.expected > date },
                        disruptions: board.disruptions,
                        error: nil
                    )
                }
                completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(10 * 60))))
            } catch {
                let entry = DeparturesEntry(date: now, departures: [], disruptions: [],
                                            error: "Couldn't reach Entur")
                completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(5 * 60))))
            }
        }
    }

    static let sample: [Departure] = [4, 23, 42, 61].map { minutes in
        let date = Date().addingTimeInterval(TimeInterval(minutes * 60))
        return Departure(aimed: date, expected: date, realtime: true, cancelled: false,
                         destination: "Nesoddtangen", quay: "L")
    }
}

struct DeparturesWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DeparturesEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            if let disruption = entry.disruptions.first {
                disruptionBanner(disruption)
            }
            if let error = entry.error {
                Spacer()
                Label(error, systemImage: "wifi.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            } else if entry.departures.isEmpty {
                Spacer()
                Text("No more sailings today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            } else if family == .systemSmall {
                smallBody
            } else {
                listBody
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(colors: [Color(red: 0.0, green: 0.36, blue: 0.62),
                                    Color(red: 0.0, green: 0.22, blue: 0.42)],
                           startPoint: .top, endPoint: .bottom)
        }
        .foregroundStyle(.white)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text("B11")
                .font(.caption.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
            Image(systemName: "ferry.fill")
                .font(.caption)
            Text("Lysaker → Nesoddtangen")
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func disruptionBanner(_ disruption: Disruption) -> some View {
        let more = entry.disruptions.count - 1
        return HStack(alignment: .top, spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(more > 0 ? "\(disruption.summary) (+\(more) more)" : disruption.summary)
                .lineLimit(family == .systemSmall ? 2 : 1)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.yellow)
    }

    @ViewBuilder
    private var smallBody: some View {
        // Count down to the next boat that actually sails; mention cancelled ones before it.
        if let index = entry.departures.firstIndex(where: { !$0.cancelled }) {
            let next = entry.departures[index]
            let skipped = entry.departures[..<index]
            let later = entry.departures[(index + 1)...].filter { !$0.cancelled }
            VStack(alignment: .leading, spacing: 2) {
                Spacer(minLength: 0)
                Text(countdown(to: next))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(statusLine(for: next))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                Spacer(minLength: 0)
                if !skipped.isEmpty {
                    Text(skipped.map { $0.aimed.formatted(date: .omitted, time: .shortened) }
                        .joined(separator: ", ") + " cancelled")
                        .font(.caption2.bold())
                        .foregroundStyle(.orange)
                } else if !later.isEmpty {
                    Text("Then " + later.prefix(2)
                        .map { $0.expected.formatted(date: .omitted, time: .shortened) }
                        .joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        } else {
            Spacer()
            Text("Upcoming sailings cancelled")
                .font(.caption.bold())
                .foregroundStyle(.orange)
            Spacer()
        }
    }

    private var listBody: some View {
        let rows = (family == .systemLarge ? 8 : 4) - (entry.disruptions.isEmpty ? 0 : 1)
        return VStack(spacing: 4) {
            ForEach(entry.departures.prefix(rows), id: \.self) { departure in
                HStack {
                    Text(departure.expected.formatted(date: .omitted, time: .shortened))
                        .font(.body.monospacedDigit().bold())
                    if departure.delayMinutes > 0 {
                        Text("+\(departure.delayMinutes)")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                    }
                    if departure.realtime {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                    Text(departure.cancelled ? "Cancelled" : countdown(to: departure))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(departure.cancelled ? .red : .white.opacity(0.75))
                }
                .strikethrough(departure.cancelled)
            }
            Spacer(minLength: 0)
        }
    }

    private func countdown(to departure: Departure) -> String {
        let minutes = Int(departure.expected.timeIntervalSince(entry.date) / 60)
        if minutes < 1 { return "Now" }
        if minutes < 60 { return "\(minutes) min" }
        let rest = minutes % 60
        return rest == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(rest) min"
    }

    private func statusLine(for departure: Departure) -> String {
        let time = departure.expected.formatted(date: .omitted, time: .shortened)
        if departure.delayMinutes > 0 { return "\(time) · \(departure.delayMinutes) min late" }
        return departure.realtime ? "\(time) · live" : "\(time) · scheduled"
    }
}

struct DeparturesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "B11Departures", provider: DeparturesProvider()) { entry in
            DeparturesWidgetView(entry: entry)
        }
        .configurationDisplayName("B11 from Lysaker brygge")
        .description("Next boat departures to Nesoddtangen.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct B11WidgetBundle: WidgetBundle {
    var body: some Widget {
        DeparturesWidget()
    }
}
