import SwiftUI

struct InspectorView: View {
    @ObservedObject var store: WallpaperStore

    var body: some View {
        if let wallpaper = store.selectedWallpaper {
            VStack(spacing: 0) {
                detailHeader(for: wallpaper)

                SketchyLine(seed: 5.2)
                    .stroke(Paper.inkHairline, lineWidth: 1.2)
                    .frame(height: 3)
                    .padding(.horizontal, 20)

                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        polaroid(for: wallpaper)
                            .padding(.top, 18)
                            .frame(maxWidth: .infinity)

                        if !wallpaper.isVideo {
                            displayTargetPicker
                        }

                        statusNote(for: wallpaper)

                        if wallpaper.isImported {
                            Button("Remove from Library") {
                                store.remove(wallpaper)
                            }
                            .buttonStyle(.plain)
                            .font(.virgil(13.5))
                            .foregroundStyle(Paper.accent)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 20)
                }

                SketchyLine(seed: 7.9)
                    .stroke(Paper.inkHairline, lineWidth: 1.2)
                    .frame(height: 3)
                    .padding(.horizontal, 20)

                applyButton(for: wallpaper)
                    .padding(18)
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "hand.point.up.left")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(Paper.inkFaint)
                Text("Pick a wallpaper")
                    .font(.virgil(20))
                    .foregroundStyle(Paper.inkSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func detailHeader(for wallpaper: Wallpaper) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(wallpaper.title)
                    .font(.virgil(21))
                    .foregroundStyle(Paper.ink)
                    .lineLimit(2)
                Text(wallpaper.collection)
                    .font(.virgil(13))
                    .foregroundStyle(Paper.inkSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button {
                store.toggleFavorite(wallpaper)
            } label: {
                Image(systemName: store.isFavorite(wallpaper) ? "heart.fill" : "heart")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(store.isFavorite(wallpaper) ? Paper.accent : Paper.inkSecondary)
            }
            .buttonStyle(.plain)
            .help(store.isFavorite(wallpaper) ? "Remove from Favorites" : "Add to Favorites")
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    private func polaroid(for wallpaper: Wallpaper) -> some View {
        let seed = sketchSeed(for: wallpaper.id)
        return Color.clear
            .frame(width: 176 * 1.6, height: 176)
            .overlay { WallpaperPreview(wallpaper: wallpaper) }
            .clipShape(SketchyRoundedRectangle(cornerRadius: 8, seed: seed + 1.2))
            .padding(9)
            .background {
                SketchyRoundedRectangle(cornerRadius: 12, seed: seed + 5.5)
                    .fill(Paper.base)
            }
            .sketchyBorder(cornerRadius: 12, color: Paper.ink.opacity(0.75), seed: seed + 5.5)
            .sketchyShadow(cornerRadius: 12, seed: seed + 5.5)
            .overlay(alignment: .top) {
                TapeView(rotation: 2.5, tint: Paper.sunshine)
                    .offset(y: -8)
            }
            .rotationEffect(.degrees(-0.8))
            .padding(.top, 6)
    }

    private var displayTargetPicker: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Apply to")
                .font(.virgil(15))
                .foregroundStyle(Paper.ink)

            HStack(spacing: 8) {
                ForEach(DisplayTarget.allCases) { target in
                    SketchySegment(
                        title: target.rawValue,
                        isSelected: store.displayTarget == target,
                        seed: sketchSeed(for: target.rawValue),
                        select: { store.displayTarget = target }
                    )
                }
            }
        }
    }

    private func statusNote(for wallpaper: Wallpaper) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(statusTitle(for: wallpaper), systemImage: statusSymbol(for: wallpaper))
                .font(.virgil(15))
                .foregroundStyle(Paper.ink)
            Text(statusDescription(for: wallpaper))
                .font(.virgil(13))
                .foregroundStyle(Paper.inkSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            SketchyRoundedRectangle(cornerRadius: 11, seed: 6.6)
                .fill(Paper.sunshine.opacity(0.13))
        }
        .overlay {
            SketchyRoundedRectangle(cornerRadius: 11, seed: 6.6)
                .stroke(Paper.sunshine.opacity(0.55), lineWidth: 1.2)
        }
    }

    private func applyButton(for wallpaper: Wallpaper) -> some View {
        Button {
            store.applySelected()
        } label: {
            HStack(spacing: 8) {
                if store.isApplying {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(store.isApplying ? "Preparing…" : applyButtonTitle(for: wallpaper))
                    .font(.virgil(16.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(SketchyButtonStyle(seed: 3.3))
        .disabled(store.isApplying)
    }

    private func statusTitle(for wallpaper: Wallpaper) -> String {
        wallpaper.isVideo ? "Native motion wallpaper" : "Desktop & Lock Screen"
    }

    private func statusSymbol(for wallpaper: Wallpaper) -> String {
        wallpaper.isVideo ? "play.rectangle.on.rectangle" : "lock.desktopcomputer"
    }

    private func statusDescription(for wallpaper: Wallpaper) -> String {
        if wallpaper.isVideo {
            return "Mural installs this video into WallpaperAgent and sets it across your displays and Spaces automatically."
        }
        return "macOS uses your active desktop wallpaper on the Lock Screen and may add its own blur."
    }

    private func applyButtonTitle(for wallpaper: Wallpaper) -> String {
        wallpaper.isVideo ? "Set Animated Wallpaper" : "Set Desktop & Lock Screen"
    }
}

private struct SketchySegment: View {
    let title: String
    let isSelected: Bool
    let seed: Double
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            Text(title)
                .font(.virgil(13.5))
                .foregroundStyle(isSelected ? Paper.raised : Paper.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            SketchyRoundedRectangle(cornerRadius: 9, seed: seed)
                .fill(isSelected ? Paper.navy : Paper.raised)
        }
        .overlay {
            SketchyRoundedRectangle(cornerRadius: 9, seed: seed)
                .stroke(isSelected ? Paper.navy : Paper.ink.opacity(0.5), lineWidth: 1.3)
        }
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
