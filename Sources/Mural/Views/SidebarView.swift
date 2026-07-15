import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: WallpaperStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            logotype
                .padding(.top, 14)
                .padding(.bottom, 26)
                .frame(maxWidth: .infinity)

            section("Library", filters: [.all, .builtIn, .imported])
            section("Personal", filters: [.favorites, .recent])
                .padding(.top, 22)

            Spacer(minLength: 0)

            Button {
                store.importWallpapers()
            } label: {
                Label("Add Wallpapers…", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SketchyButtonStyle(variant: .outline, seed: 5.5))
            .padding(.horizontal, 16)
            .padding(.bottom, 18)
        }
        .padding(.horizontal, 4)
    }

    private var logotype: some View {
        Group {
            if let url = ResourceLocator.url(
                forResource: colorScheme == .dark ? "WordmarkDark" : "WordmarkLight",
                withExtension: "png"
            ), let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 132)
            } else {
                Text("Mural")
                    .font(.virgil(30))
                    .foregroundStyle(Paper.ink)
            }
        }
        .accessibilityLabel("Mural")
        .accessibilityAddTraits(.isHeader)
    }

    private func section(_ title: String, filters: [LibraryFilter]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.virgil(12.5))
                .foregroundStyle(Paper.inkSecondary)
                .padding(.horizontal, 26)
                .padding(.bottom, 4)

            ForEach(filters) { filter in
                SidebarRow(
                    filter: filter,
                    isSelected: store.selectedFilter == filter,
                    select: { store.selectedFilter = filter }
                )
            }
        }
    }
}

private struct SidebarRow: View {
    let filter: LibraryFilter
    let isSelected: Bool
    let select: () -> Void

    @State private var isHovering = false

    private var seed: Double { sketchSeed(for: filter.rawValue) }

    var body: some View {
        Button(action: select) {
            HStack(spacing: 10) {
                Image(systemName: filter.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? Paper.accent : Paper.inkSecondary)
                    .frame(width: 20)
                Text(filter.rawValue)
                    .font(.virgil(15.5))
                    .foregroundStyle(Paper.ink)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            if isSelected {
                SketchyRoundedRectangle(cornerRadius: 10, seed: seed)
                    .fill(Paper.accent.opacity(0.13))
            } else if isHovering {
                SketchyRoundedRectangle(cornerRadius: 10, seed: seed)
                    .fill(Paper.ink.opacity(0.05))
            }
        }
        .overlay {
            if isSelected {
                SketchyRoundedRectangle(cornerRadius: 10, seed: seed)
                    .stroke(Paper.accent.opacity(0.85), lineWidth: 1.3)
            }
        }
        .padding(.horizontal, 12)
        .onHover { isHovering = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
