import SwiftUI

struct HostRootView: View {
    @StateObject private var state = HostAppState()

    var body: some View {
        NavigationStack(path: $state.navigationPath) {
            S001HomeView()
                .environmentObject(state)
                .navigationDestination(for: HostRoute.self) { route in
                    destination(for: route)
                }
        }
    }

    @ViewBuilder
    private func destination(for route: HostRoute) -> some View {
        switch route {
        case .textHabit(let questionIndex):
            S002TextHabitFlowView(initialQuestionIndex: questionIndex)
                .environmentObject(state)
        case .textHabitLoading:
            S002TextHabitLoadingView()
                .environmentObject(state)
        case .relation(let step):
            S003RelationFlowView(initialStep: step)
                .environmentObject(state)
        case .keyboardPermission:
            S004PermissionGuideView()
                .environmentObject(state)
        case .keyboardComplete:
            S004CompleteView()
                .environmentObject(state)
        case .tutorial:
            S004TutorialView()
                .environmentObject(state)
        }
    }
}
