import SwiftData
import SwiftUI

@main
struct CalmMapApp: App {
    @State private var router = AppRouter()
    @State private var toasts = ToastCenter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(toasts)
        }
        .modelContainer(for: SoundMeasurement.self)
    }
}
