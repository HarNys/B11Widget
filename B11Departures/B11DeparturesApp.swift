import SwiftUI
import WidgetKit

@main
struct B11DeparturesApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 12) {
                Image(systemName: "ferry.fill")
                    .font(.system(size: 40))
                Text("B11 Departures")
                    .font(.title2.bold())
                Text("Right-click the desktop → Edit Widgets… and add \"B11 from Lysaker brygge\".")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Refresh widget now") {
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
            .padding(32)
            .frame(width: 360)
        }
        .windowResizability(.contentSize)
    }
}
