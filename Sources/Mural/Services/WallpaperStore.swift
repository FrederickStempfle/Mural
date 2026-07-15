import AppKit
import Combine
import Foundation
import os
import UniformTypeIdentifiers

private let logger = Logger(subsystem: "local.mural.wallpapers", category: "library")

@MainActor
final class WallpaperStore: ObservableObject {
    @Published private(set) var wallpapers: [Wallpaper] = []
    @Published var selectedFilter: LibraryFilter = .all
    @Published var selectedID: Wallpaper.ID?
    @Published var searchText = ""
    @Published var displayTarget: DisplayTarget = .all
    @Published var isApplying = false
    @Published var message: String?
    @Published var errorMessage: String?

    /// The Mural Studio draft. Lives on the store so switching sidebar
    /// sections doesn't discard an unsaved design.
    @Published var studioDesign: StudioDesign = .initial

    @Published private(set) var favoriteIDs: Set<String>
    @Published private(set) var recentIDs: [String]

    private let defaults: UserDefaults
    private let fileManager: FileManager
    private let wallpaperService = WallpaperService()
    private var importPanel: NSOpenPanel?

    init(defaults: UserDefaults = .standard, fileManager: FileManager = .default) {
        self.defaults = defaults
        self.fileManager = fileManager
        favoriteIDs = Set(defaults.stringArray(forKey: "favoriteWallpaperIDs") ?? [])
        recentIDs = defaults.stringArray(forKey: "recentWallpaperIDs") ?? []
        reload()
    }

    var filteredWallpapers: [Wallpaper] {
        wallpapers.filter { wallpaper in
            let matchesFilter: Bool
            switch selectedFilter {
            case .all: matchesFilter = true
            case .builtIn: matchesFilter = !wallpaper.isImported
            case .imported: matchesFilter = wallpaper.isImported
            case .studio: matchesFilter = false
            case .favorites: matchesFilter = favoriteIDs.contains(wallpaper.id)
            case .recent: matchesFilter = recentIDs.contains(wallpaper.id)
            }

            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            return matchesFilter && (query.isEmpty || wallpaper.title.localizedStandardContains(query))
        }
        .sorted { lhs, rhs in
            if selectedFilter == .recent {
                return (recentIDs.firstIndex(of: lhs.id) ?? .max) < (recentIDs.firstIndex(of: rhs.id) ?? .max)
            }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    var selectedWallpaper: Wallpaper? {
        wallpapers.first { $0.id == selectedID }
    }

    func reload() {
        var items = bundledWallpapers()
        items.append(contentsOf: WallpaperPreset.allCases.map {
            Wallpaper(id: "studio.\($0.rawValue)", title: $0.title, collection: $0.collection, source: .procedural($0))
        })
        items.append(contentsOf: importedWallpapers())
        wallpapers = items

        if selectedID == nil || !items.contains(where: { $0.id == selectedID }) {
            selectedID = items.first?.id
        }
    }

    private func bundledWallpapers() -> [Wallpaper] {
        var wallpapers: [Wallpaper] = []

        wallpapers.append(contentsOf: ResourceLocator.preMadeWallpaperURLs().map { url in
            let filename = url.deletingPathExtension().lastPathComponent
            return Wallpaper(
                id: "studio.file.\(filename)",
                title: filename
                    .replacingOccurrences(of: "-", with: " ")
                    .replacingOccurrences(of: "_", with: " ")
                    .localizedCapitalized,
                collection: "Mural Studio",
                source: .bundled(url)
            )
        })

        return wallpapers
    }

    func toggleFavorite(_ wallpaper: Wallpaper) {
        if favoriteIDs.contains(wallpaper.id) {
            favoriteIDs.remove(wallpaper.id)
        } else {
            favoriteIDs.insert(wallpaper.id)
        }
        defaults.set(Array(favoriteIDs), forKey: "favoriteWallpaperIDs")
    }

    func isFavorite(_ wallpaper: Wallpaper) -> Bool {
        favoriteIDs.contains(wallpaper.id)
    }

    func importWallpapers() {
        guard importPanel == nil else { return }

        let panel = NSOpenPanel()
        panel.title = "Add Wallpapers"
        panel.prompt = "Add"
        panel.allowedContentTypes = [.image, .movie, .video]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        importPanel = panel

        panel.begin { [weak self, weak panel] response in
            guard let self, let panel else { return }
            self.importPanel = nil
            guard response == .OK else { return }
            self.importWallpapers(at: panel.urls)
        }
    }

    private func importWallpapers(at urls: [URL]) {
        do {
            let directory = try importedDirectory()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

            var importedVideos: [URL] = []
            for source in urls {
                let destination = uniqueDestination(for: source.lastPathComponent, in: directory)
                try fileManager.copyItem(at: source, to: destination)
                if isVideo(destination) { importedVideos.append(destination) }
            }
            reload()
            selectedFilter = .imported
            message = urls.count == 1 ? "Wallpaper added" : "\(urls.count) wallpapers added"
            Task {
                for video in importedVideos {
                    do {
                        _ = try await NativeVideoWallpaperService.deploy(video)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Renders a studio design into the imported library so it behaves like
    /// any other wallpaper the user added, then optionally applies it.
    func saveStudioDesign(_ design: StudioDesign, named proposedName: String, apply: Bool = false) {
        guard !isApplying else { return }
        let trimmed = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = trimmed.isEmpty ? design.suggestedName : trimmed
        isApplying = true
        Task {
            defer { isApplying = false }
            do {
                let directory = try importedDirectory()
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                let filename = title
                    .replacingOccurrences(of: "/", with: "-")
                    .replacingOccurrences(of: ":", with: "-")
                let destination = uniqueDestination(for: "\(filename).png", in: directory)
                await yieldForApplyingStateToPaint()
                try await WallpaperRenderer.render(design, to: destination)
                reload()
                selectedID = "imported.\(destination.lastPathComponent)"
                if apply, let wallpaper = selectedWallpaper {
                    await self.apply(wallpaper)
                } else {
                    message = "“\(title)” saved to My Wallpapers"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func remove(_ wallpaper: Wallpaper) {
        let url: URL
        switch wallpaper.source {
        case .imported(let importedURL), .video(let importedURL): url = importedURL
        default: return
        }
        do {
            var keptActiveSystemCopy = false
            if wallpaper.isVideo {
                keptActiveSystemCopy = try !NativeVideoWallpaperService.removeIfUnused(
                    filename: url.lastPathComponent
                )
            }
            try fileManager.removeItem(at: url)
            favoriteIDs.remove(wallpaper.id)
            recentIDs.removeAll { $0 == wallpaper.id }
            reload()
            message = keptActiveSystemCopy
                ? "Removed from Mural. The copy currently used by macOS was kept."
                : "Removed from Mural"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func applySelected() {
        guard let wallpaper = selectedWallpaper, !isApplying else { return }

        isApplying = true
        Task {
            defer { isApplying = false }
            await apply(wallpaper)
        }
    }

    private func apply(_ wallpaper: Wallpaper) async {
        do {
            if case .video(let url) = wallpaper.source {
                try await applyVideo(url, for: wallpaper)
            } else {
                await yieldForApplyingStateToPaint()
                try await wallpaperService.apply(wallpaper, to: displayTarget)
                markRecentlyUsed(wallpaper)
                message = "“\(wallpaper.title)” is now on your Desktop and Lock Screen"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyVideo(_ url: URL, for wallpaper: Wallpaper) async throws {
        let choiceID = try await NativeVideoWallpaperService.deploy(url)
        do {
            try await NativeVideoWallpaperService.activate(choiceID: choiceID)
            markRecentlyUsed(wallpaper)
            message = "“\(wallpaper.title)” is now animating on your Desktop"
        } catch {
            // The store rewrite is best-effort private API; fall back to
            // the manual selection flow instead of failing the apply.
            markRecentlyUsed(wallpaper)
            NativeVideoWallpaperService.openWallpaperSettings()
            message = "Choose “\(wallpaper.title)” in Mural — Video Wallpapers"
        }
    }

    /// ImageRenderer can only run on the main actor, so give SwiftUI one full
    /// run-loop turn to commit the "Preparing…" state before the render blocks
    /// the next frames. A plain yield can resume before that commit happens.
    private func yieldForApplyingStateToPaint() async {
        try? await Task.sleep(for: .milliseconds(40))
    }

    private func importedWallpapers() -> [Wallpaper] {
        let urls: [URL]
        do {
            let directory = try importedDirectory()
            // A missing directory just means nothing was imported yet.
            guard fileManager.fileExists(atPath: directory.path) else { return [] }
            urls = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentTypeKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            // An alert at every reload would be noise; a log line is enough to
            // diagnose a broken Application Support folder.
            logger.error("Could not read the imported wallpaper library: \(error.localizedDescription, privacy: .public)")
            return []
        }

        return urls.compactMap { url in
            guard let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
                  type.conforms(to: .image) || type.conforms(to: .movie) || type.conforms(to: .video)
            else { return nil }
            let source: WallpaperSource = type.conforms(to: .movie) || type.conforms(to: .video)
                ? .video(url)
                : .imported(url)
            return Wallpaper(
                id: "imported.\(url.lastPathComponent)",
                title: url.deletingPathExtension().lastPathComponent,
                collection: "My Wallpapers",
                source: source
            )
        }
    }

    private func importedDirectory() throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base
            .appendingPathComponent("Mural", isDirectory: true)
            .appendingPathComponent("Library", isDirectory: true)
    }

    private func uniqueDestination(for filename: String, in directory: URL) -> URL {
        let source = URL(fileURLWithPath: filename)
        let stem = source.deletingPathExtension().lastPathComponent
        let ext = source.pathExtension
        var candidate = directory.appendingPathComponent(filename)
        var index = 2
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(stem) \(index).\(ext)")
            index += 1
        }
        return candidate
    }

    private func isVideo(_ url: URL) -> Bool {
        guard let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else { return false }
        return type.conforms(to: .movie) || type.conforms(to: .video)
    }

    private func markRecentlyUsed(_ wallpaper: Wallpaper) {
        recentIDs.removeAll { $0 == wallpaper.id }
        recentIDs.insert(wallpaper.id, at: 0)
        recentIDs = Array(recentIDs.prefix(12))
        defaults.set(recentIDs, forKey: "recentWallpaperIDs")
    }
}
