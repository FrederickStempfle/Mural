import SwiftUI

@main
struct MuralApp: App {
    @StateObject private var store = WallpaperStore()

    init() {
        VirgilFont.register()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1220, height: 760)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Add Wallpapers…") {
                    store.importWallpapers()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            CommandMenu("Wallpaper") {
                Button("Set Desktop & Lock Screen") {
                    store.applySelected()
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(store.selectedWallpaper == nil || store.isApplying)
            }
        }

        Settings {
            SettingsView()
        }
    }
}

private struct SettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Lock Screen", systemImage: "lock")
                .font(.virgil(16))
                .foregroundStyle(Paper.ink)
            Text("Follows the active Desktop wallpaper.")
                .font(.virgil(13.5))
                .foregroundStyle(Paper.inkSecondary)
            Text("Mural uses Apple’s public Desktop wallpaper API. macOS carries that image to the Lock Screen and controls its blur and crop.")
                .font(.virgil(12.5))
                .foregroundStyle(Paper.inkSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(width: 460, alignment: .leading)
        .background(Paper.base)
    }
}
