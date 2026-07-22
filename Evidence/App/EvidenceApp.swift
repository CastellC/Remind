import SwiftUI
import SwiftData

@main
struct EvidenceApp: App {
    @State private var container: AppContainer
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let environment = AppEnvironment()
        let modelContainer: ModelContainer
        do {
            modelContainer = try ModelContainer.evidence()
        } catch {
            // Last-resort in-memory store so launch remains possible if disk store fails.
            modelContainer = (try? ModelContainer.evidence(inMemory: true))
                ?? ModelContainer.evidencePreviewContainer
        }
        _container = State(initialValue: AppContainer(environment: environment, modelContainer: modelContainer))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container)
                .environmentObject(container.environment)
                .modelContainer(container.modelContainer)
                .task {
                    await container.bootstrap()
                    _ = await container.ensureProfile()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    handleScenePhase(newPhase)
                }
        }
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            container.handleScenePhaseBackground()
        case .active:
            Task {
                await container.handleScenePhaseActive()
            }
        case .inactive:
            break
        @unknown default:
            break
        }
    }
}
