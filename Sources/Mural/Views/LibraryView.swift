import SwiftUI

struct LibraryView: View {
    @ObservedObject var store: WallpaperStore

    private let columns = [
        GridItem(.adaptive(minimum: 240, maximum: 360), spacing: 26)
    ]

    var body: some View {
        VStack(spacing: 0) {
            header

            SketchyLine(seed: 3.7)
                .stroke(Paper.inkHairline, lineWidth: 1.2)
                .frame(height: 3)

            if store.filteredWallpapers.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 34) {
                        ForEach(store.filteredWallpapers) { wallpaper in
                            WallpaperCard(
                                wallpaper: wallpaper,
                                isSelected: wallpaper.id == store.selectedID,
                                isFavorite: store.isFavorite(wallpaper),
                                select: { store.selectedID = wallpaper.id },
                                favorite: { store.toggleFavorite(wallpaper) }
                            )
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 32)
                }
            }
        }
        .background {
            ZStack {
                Paper.base
                DotGridBackground()
            }
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.selectedFilter.rawValue)
                    .font(.virgil(28))
                    .foregroundStyle(Paper.ink)
                    .background(alignment: .bottom) {
                        SketchyLine(seed: sketchSeed(for: store.selectedFilter.rawValue), roughness: 1.6)
                            .stroke(Paper.accent.opacity(0.75), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                            .frame(height: 4)
                            .offset(y: 3)
                    }
                Text(resultDescription)
                    .font(.virgil(13.5))
                    .foregroundStyle(Paper.inkSecondary)
            }

            Spacer()

            searchField
                .frame(width: 236)
        }
        .padding(.horizontal, 30)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Paper.inkSecondary)
            TextField("", text: $store.searchText, prompt: Text("Search wallpapers").font(.virgil(14)))
                .textFieldStyle(.plain)
                .font(.virgil(14))
                .foregroundStyle(Paper.ink)
            if !store.searchText.isEmpty {
                Button {
                    store.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Paper.inkFaint)
                }
                .buttonStyle(.plain)
                .help("Clear Search")
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 32)
        .background {
            SketchyRoundedRectangle(cornerRadius: 10, seed: 9.4)
                .fill(Paper.raised)
        }
        .sketchyBorder(cornerRadius: 10, color: Paper.ink.opacity(0.7), lineWidth: 1.2, seed: 9.4)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: store.selectedFilter.symbol)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Paper.inkFaint)
            Text(emptyTitle)
                .font(.virgil(22))
                .foregroundStyle(Paper.ink)
            Text(emptyDescription)
                .font(.virgil(14.5))
                .foregroundStyle(Paper.inkSecondary)
            if store.selectedFilter == .imported, !searchIsActive {
                Button("Add Wallpapers…") { store.importWallpapers() }
                    .buttonStyle(SketchyButtonStyle(seed: 4.8))
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultDescription: String {
        let count = store.filteredWallpapers.count
        return "\(count) \(count == 1 ? "wallpaper" : "wallpapers")"
    }

    private var emptyTitle: String {
        searchIsActive ? "No matches" : "Nothing here yet"
    }

    private var emptyDescription: String {
        if searchIsActive { return "Try a different search." }
        return switch store.selectedFilter {
        case .favorites: "Heart a wallpaper to keep it here."
        case .recent: "Wallpapers you apply will appear here."
        case .imported: "Add images from your Mac to build your library."
        default: "Add a wallpaper to get started."
        }
    }

    private var searchIsActive: Bool {
        !store.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct WallpaperCard: View {
    let wallpaper: Wallpaper
    let isSelected: Bool
    let isFavorite: Bool
    let select: () -> Void
    let favorite: () -> Void

    @State private var isHovering = false

    private var seed: Double { sketchSeed(for: wallpaper.id) }
    private var restingTilt: Double { (seed / 12 - 0.5) * 2.4 }
    private var tapeTint: Color {
        [Paper.sunshine, Paper.accent, Paper.leaf, Paper.navy][Int(seed * 10) % 4]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .topTrailing) {
                Color.clear
                    .aspectRatio(16 / 10, contentMode: .fit)
                    .overlay { WallpaperPreview(wallpaper: wallpaper) }
                    .clipShape(SketchyRoundedRectangle(cornerRadius: 9, seed: seed + 1.2))

                if isHovering || isFavorite {
                    Button(action: favorite) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isFavorite ? Paper.accent : Paper.ink)
                            .frame(width: 30, height: 30)
                            .background {
                                SketchyRoundedRectangle(cornerRadius: 15, seed: seed + 2.6)
                                    .fill(Paper.raised.opacity(0.94))
                            }
                            .sketchyBorder(cornerRadius: 15, lineWidth: 1.1, seed: seed + 2.6)
                    }
                    .buttonStyle(.plain)
                    .padding(9)
                    .transition(.opacity)
                    .help(isFavorite ? "Remove from Favorites" : "Add to Favorites")
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(wallpaper.title)
                        .font(.virgil(16))
                        .foregroundStyle(Paper.ink)
                        .lineLimit(1)
                    Text(wallpaper.collection)
                        .font(.virgil(12.5))
                        .foregroundStyle(Paper.inkSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if wallpaper.isVideo {
                    HStack(spacing: 3) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 8, weight: .bold))
                        Text("motion")
                            .font(.virgil(11.5))
                    }
                    .foregroundStyle(Paper.navy)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .overlay {
                        SketchyRoundedRectangle(cornerRadius: 8, seed: seed + 4.4)
                            .stroke(Paper.navy.opacity(0.7), lineWidth: 1.1)
                    }
                    .help("Video wallpaper")
                }
            }
            .padding(.horizontal, 3)
        }
        .padding(9)
        .background {
            SketchyRoundedRectangle(cornerRadius: 13, seed: seed)
                .fill(Paper.raised)
        }
        .sketchyBorder(
            cornerRadius: 13,
            color: isSelected ? Paper.accent : Paper.ink.opacity(0.75),
            lineWidth: isSelected ? 2 : 1.3,
            seed: seed
        )
        .sketchyShadow(
            cornerRadius: 13,
            seed: seed,
            offset: isHovering || isSelected ? CGSize(width: 5, height: 6) : CGSize(width: 3, height: 4)
        )
        .overlay(alignment: .top) {
            TapeView(rotation: restingTilt * 3 - 2, tint: tapeTint)
                .offset(y: -9)
        }
        .rotationEffect(.degrees(isHovering || isSelected ? 0 : restingTilt))
        .scaleEffect(isHovering ? 1.02 : 1)
        .animation(.spring(duration: 0.28), value: isHovering)
        .animation(.spring(duration: 0.28), value: isSelected)
        .contentShape(Rectangle())
        .onTapGesture(perform: select)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button(isFavorite ? "Remove from Favorites" : "Add to Favorites", action: favorite)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
