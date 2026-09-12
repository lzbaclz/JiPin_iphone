import SwiftUI
import Combine
import UIKit
import JiPinCore

@main
struct JiPinApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .tint(JiPinTheme.accent)
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: AppTab = .create
    @Published var editor: EditorSession?
    @Published var isClosingEditor = false
    @Published var showSettings = false
    @Published var showIDPhoto = false
    @Published var pendingIDPhotoDraftID: UUID?
    @Published var draftRefreshID = UUID()
    @Published var pendingDraftID: UUID?
    @Published var quickCollage: QuickCollageLaunch?
    @Published var modePickerLaunch: ModePickerLaunch?
    let drafts = DraftStore.shared
    let favorites = FavoriteStore()
    private var favoriteChanges: AnyCancellable?

    init() {
        favoriteChanges = favorites.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }
    }

    enum AppTab: Hashable {
        case create, drafts
    }

    func openEditor(_ session: EditorSession) {
        editor = session
    }

    func openIDPhoto(draftID: UUID? = nil) {
        pendingIDPhotoDraftID = draftID
        showIDPhoto = true
    }

    func closeEditor() {
        guard !isClosingEditor else { return }
        isClosingEditor = true
        Task {
            defer { isClosingEditor = false }
            guard let closing = editor else { return }
            if await closing.persistNow(), editor === closing { editor = nil }
        }
    }
}

struct QuickCollageLaunch: Identifiable {
    let id = UUID()
    var photos: [ImportedPhoto]
    var failed: [ImportedPhoto] = []
    var overflowCount: Int = 0
}

struct ModePickerLaunch: Identifiable {
    let id = UUID()
    var photos: [ImportedPhoto]
}

enum JiPinTheme {
    static let accent = Color(red: 1.0, green: 0.353, blue: 0.212)
    static let canvas = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0.12, green: 0.11, blue: 0.10, alpha: 1)
        }
        return UIColor(red: 0.957, green: 0.945, blue: 0.918, alpha: 1)
    })
    static let ink = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(white: 0.96, alpha: 1)
        }
        return UIColor(red: 0.110, green: 0.102, blue: 0.090, alpha: 1)
    })
    static let muted = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(white: 0.68, alpha: 1)
        }
        return UIColor(red: 0.45, green: 0.41, blue: 0.38, alpha: 1)
    })
    static let surface = Color(uiColor: .systemBackground)
    static let grouped = Color(uiColor: .systemGroupedBackground)
    static let elevated = Color(uiColor: .secondarySystemBackground)
}
