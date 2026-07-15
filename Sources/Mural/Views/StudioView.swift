import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The Mural Studio: sketch a wallpaper from a drawn style or your own photo,
/// decorate it with stickers, then save or apply it.
struct StudioView: View {
    @ObservedObject var store: WallpaperStore

    @State private var name = ""
    @State private var selectedStickerID: UUID?
    @State private var isChoosingPhoto = false

    /// The draft lives on the store, not in view state, so switching sidebar
    /// sections and coming back doesn't discard an in-progress design.
    private var design: StudioDesign {
        get { store.studioDesign }
        nonmutating set { store.studioDesign = newValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            SketchyLine(seed: 3.7)
                .stroke(Paper.inkHairline, lineWidth: 1.2)
                .frame(height: 3)

            ScrollView {
                VStack(spacing: 26) {
                    easel

                    if selectedSticker != nil {
                        stickerControls
                    }

                    backdropSection

                    if design.style != nil {
                        paletteSection
                        HStack(alignment: .top, spacing: 34) {
                            colorSection
                            variationSection
                        }
                    }

                    stickerTray
                    saveBar
                }
                .frame(maxWidth: 780)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 30)
                .padding(.top, 32)
                .padding(.bottom, 36)
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

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Mural Studio")
                    .font(.virgil(28))
                    .foregroundStyle(Paper.ink)
                    .background(alignment: .bottom) {
                        SketchyLine(seed: sketchSeed(for: LibraryFilter.studio.rawValue), roughness: 1.6)
                            .stroke(Paper.accent.opacity(0.75), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                            .frame(height: 4)
                            .offset(y: 3)
                    }
                Text("Sketch a wallpaper of your own")
                    .font(.virgil(13.5))
                    .foregroundStyle(Paper.inkSecondary)
            }

            Spacer()

            Button {
                var random = StudioDesign.random()
                random.stickers = design.stickers
                design = random
            } label: {
                Label("Surprise Me", systemImage: "wand.and.stars")
            }
            .buttonStyle(SketchyButtonStyle(variant: .outline, seed: 7.7))
            .help("Random style, palette, and variation")
        }
        .padding(.horizontal, 30)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    // MARK: - Canvas

    private var easel: some View {
        Color.clear
            .aspectRatio(16 / 10, contentMode: .fit)
            .overlay {
                GeometryReader { geometry in
                    ZStack {
                        StudioCanvas(design: backdropOnlyDesign)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedStickerID = nil }

                        ForEach(design.stickers) { placement in
                            interactiveSticker(placement, canvasSize: geometry.size)
                        }
                    }
                }
            }
            .clipShape(SketchyRoundedRectangle(cornerRadius: 10, seed: 2.2))
            .padding(10)
            .background {
                SketchyRoundedRectangle(cornerRadius: 14, seed: 5.9)
                    .fill(Paper.raised)
            }
            .sketchyBorder(cornerRadius: 14, color: Paper.ink.opacity(0.75), seed: 5.9)
            .sketchyShadow(cornerRadius: 14, seed: 5.9, offset: CGSize(width: 4, height: 5))
            .overlay(alignment: .top) {
                TapeView(rotation: -2, tint: Paper.sunshine)
                    .offset(y: -9)
            }
            .frame(maxWidth: 720)
            .accessibilityLabel("Wallpaper preview")
    }

    private var backdropOnlyDesign: StudioDesign {
        var design = design
        design.stickers = []
        return design
    }

    private func interactiveSticker(_ placement: StickerPlacement, canvasSize: CGSize) -> some View {
        ZStack {
            if placement.id == selectedStickerID {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Paper.accent, style: StrokeStyle(lineWidth: 1.6, dash: [6, 4]))
                    .frame(
                        width: canvasSize.width * placement.width + 10,
                        height: stickerHeight(placement, canvasSize: canvasSize) + 10
                    )
                    .rotationEffect(.degrees(placement.rotation))
                    .position(
                        x: canvasSize.width * placement.centerX,
                        y: canvasSize.height * placement.centerY
                    )
            }
            StickerStamp(placement: placement, canvasSize: canvasSize)
        }
        .onTapGesture { selectedStickerID = placement.id }
        .gesture(
            DragGesture()
                .onChanged { value in
                    selectedStickerID = placement.id
                    updateSticker(placement.id) { sticker in
                        sticker.centerX = min(max(value.location.x / canvasSize.width, 0.02), 0.98)
                        sticker.centerY = min(max(value.location.y / canvasSize.height, 0.02), 0.98)
                    }
                }
        )
    }

    private func stickerHeight(_ placement: StickerPlacement, canvasSize: CGSize) -> Double {
        guard let image = StickerLibrary.image(at: placement.url) else { return 0 }
        return canvasSize.width * placement.width * image.size.height / max(image.size.width, 1)
    }

    // MARK: - Stickers

    private var stickerControls: some View {
        HStack(spacing: 14) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Paper.inkSecondary)
                .help("Sticker size")
            Slider(value: selectedStickerBinding(\.width), in: 0.06...0.5)
                .tint(Paper.accent)
                .controlSize(.small)
                .accessibilityLabel("Sticker size")

            Image(systemName: "rotate.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Paper.inkSecondary)
                .help("Sticker rotation")
            Slider(value: selectedStickerBinding(\.rotation), in: -60...60)
                .tint(Paper.accent)
                .controlSize(.small)
                .accessibilityLabel("Sticker rotation")

            Button {
                if let id = selectedStickerID {
                    design.stickers.removeAll { $0.id == id }
                    selectedStickerID = nil
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(SketchyButtonStyle(variant: .outline, cornerRadius: 9, seed: 3.4))
            .help("Remove sticker")
        }
        .frame(maxWidth: 720)
    }

    private var stickerTray: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionLabel("Stickers")
            if StickerLibrary.bundled.isEmpty {
                Text("No stickers bundled yet.")
                    .font(.virgil(13))
                    .foregroundStyle(Paper.inkSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(StickerLibrary.bundled, id: \.self) { url in
                            stickerTrayButton(url)
                        }
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Sticker cards stay light in both color schemes: the assets are ink and
    // paper cutouts, and dark doodles vanish on a dark backing.
    private static let stickerPaper = Color(red: 1, green: 0.988, blue: 0.953)
    private static let stickerInk = Color(red: 0.165, green: 0.149, blue: 0.125)

    private func stickerTrayButton(_ url: URL) -> some View {
        Button {
            addSticker(url)
        } label: {
            Group {
                if let image = StickerLibrary.image(at: url) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "questionmark.square.dashed")
                        .foregroundStyle(Paper.inkFaint)
                }
            }
            .frame(width: 54, height: 54)
            .padding(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            SketchyRoundedRectangle(cornerRadius: 10, seed: sketchSeed(for: url.lastPathComponent))
                .fill(Self.stickerPaper)
                .shadow(color: .black.opacity(0.18), radius: 2, x: 1, y: 2)
        }
        .sketchyBorder(
            cornerRadius: 10,
            color: Self.stickerInk.opacity(0.5),
            lineWidth: 1.1,
            seed: sketchSeed(for: url.lastPathComponent)
        )
        .help(StickerLibrary.displayName(for: url))
        .accessibilityLabel("Add \(StickerLibrary.displayName(for: url)) sticker")
    }

    private func addSticker(_ url: URL) {
        let placement = StickerPlacement(
            url: url,
            centerX: .random(in: 0.35...0.65),
            centerY: .random(in: 0.35...0.65),
            width: 0.16,
            rotation: .random(in: -8...8)
        )
        design.stickers.append(placement)
        selectedStickerID = placement.id
    }

    // MARK: - Backdrop

    private var backdropSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionLabel("Backdrop")
            FlowLayout(spacing: 8) {
                ForEach(StudioStyle.allCases) { style in
                    StudioChip(
                        title: style.title,
                        symbol: style.symbol,
                        isSelected: design.style == style,
                        select: { design.backdrop = .style(style) }
                    )
                }
                StudioChip(
                    title: "My Photo…",
                    symbol: "photo.badge.plus",
                    isSelected: isPhotoBackdrop,
                    select: choosePhoto
                )
            }
            .padding(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var isPhotoBackdrop: Bool {
        if case .photo = design.backdrop { true } else { false }
    }

    private func choosePhoto() {
        guard !isChoosingPhoto else { return }
        isChoosingPhoto = true

        let panel = NSOpenPanel()
        panel.title = "Choose a Photo"
        panel.prompt = "Use Photo"
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        panel.begin { response in
            isChoosingPhoto = false
            guard response == .OK, let url = panel.url else { return }
            design.backdrop = .photo(url)
        }
    }

    // MARK: - Controls

    private var variationSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionLabel("Variation")
            HStack(spacing: 10) {
                Slider(value: $store.studioDesign.seed, in: 0...1)
                    .tint(Paper.accent)
                    .controlSize(.small)
                    .accessibilityLabel("Variation")
                Button {
                    design.seed = .random(in: 0..<1)
                } label: {
                    Image(systemName: "dice")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(SketchyButtonStyle(variant: .outline, cornerRadius: 9, seed: 1.8))
                .help("Roll a new variation")
            }
            .frame(height: 34)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionLabel("Colors")
            HStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { index in
                    ColorPicker("", selection: $store.studioDesign.colors[index], supportsOpacity: false)
                        .labelsHidden()
                        .accessibilityLabel("Color \(index + 1)")
                }
                Button {
                    design.colors = StudioDesign.randomColors()
                } label: {
                    Image(systemName: "dice")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(SketchyButtonStyle(variant: .outline, cornerRadius: 9, seed: 6.4))
                .help("Roll a new palette")
            }
            .frame(height: 34)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var paletteSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionLabel("Palettes")
            FlowLayout(spacing: 9) {
                ForEach(StudioPalette.curated) { palette in
                    StudioPaletteSwatch(
                        palette: palette,
                        isSelected: design.colors == palette.colors,
                        select: { design.colors = palette.colors }
                    )
                }
            }
            .padding(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Save

    private var saveBar: some View {
        HStack(spacing: 12) {
            nameField

            Button("Save to Library") {
                store.saveStudioDesign(design, named: name)
            }
            .buttonStyle(SketchyButtonStyle(variant: .outline, seed: 4.1))
            .disabled(store.isApplying)

            Button(store.isApplying ? "Preparing…" : "Set as Wallpaper") {
                store.saveStudioDesign(design, named: name, apply: true)
            }
            .buttonStyle(SketchyButtonStyle(seed: 8.2))
            .disabled(store.isApplying)
        }
        .frame(maxWidth: 720)
    }

    private var nameField: some View {
        TextField("", text: $name, prompt: Text(design.suggestedName).font(.virgil(14)))
            .textFieldStyle(.plain)
            .font(.virgil(14))
            .foregroundStyle(Paper.ink)
            .padding(.horizontal, 11)
            .frame(height: 34)
            .frame(maxWidth: .infinity)
            .background {
                SketchyRoundedRectangle(cornerRadius: 10, seed: 9.1)
                    .fill(Paper.raised)
            }
            .sketchyBorder(cornerRadius: 10, color: Paper.ink.opacity(0.7), lineWidth: 1.2, seed: 9.1)
            .accessibilityLabel("Wallpaper name")
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.virgil(15))
            .foregroundStyle(Paper.ink)
    }

    // MARK: - Sticker state helpers

    private var selectedSticker: StickerPlacement? {
        design.stickers.first { $0.id == selectedStickerID }
    }

    private func updateSticker(_ id: UUID, _ transform: (inout StickerPlacement) -> Void) {
        guard let index = design.stickers.firstIndex(where: { $0.id == id }) else { return }
        transform(&design.stickers[index])
    }

    private func selectedStickerBinding(_ keyPath: WritableKeyPath<StickerPlacement, Double>) -> Binding<Double> {
        Binding(
            get: { selectedSticker?[keyPath: keyPath] ?? 0 },
            set: { newValue in
                if let id = selectedStickerID {
                    updateSticker(id) { $0[keyPath: keyPath] = newValue }
                }
            }
        )
    }
}

/// Places children at their natural size, wrapping onto new rows like text.
/// Keeps chip labels intact instead of truncating them to fit grid columns.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(subviews: subviews, width: proposal.width ?? .infinity).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let positions = arrange(subviews: subviews, width: bounds.width).positions
        for (subview, position) in zip(subviews, positions) {
            subview.place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(subviews: Subviews, width: CGFloat) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var cursorX: CGFloat = 0
        var cursorY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if cursorX > 0, cursorX + size.width > width {
                cursorX = 0
                cursorY += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: cursorX, y: cursorY))
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, cursorX + size.width)
            cursorX += size.width + spacing
        }
        return (CGSize(width: maxX, height: cursorY + rowHeight), positions)
    }
}

private struct StudioChip: View {
    let title: String
    let symbol: String
    let isSelected: Bool
    let select: () -> Void

    private var seed: Double { sketchSeed(for: title) }

    var body: some View {
        Button(action: select) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(.virgil(14.5))
                    .fixedSize()
            }
            .foregroundStyle(isSelected ? Paper.raised : Paper.ink)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
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

private struct StudioPaletteSwatch: View {
    let palette: StudioPalette
    let isSelected: Bool
    let select: () -> Void

    private var seed: Double { sketchSeed(for: palette.name) }

    var body: some View {
        Button(action: select) {
            HStack(spacing: 5) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(palette.colors[index])
                        .frame(width: 15, height: 15)
                        .overlay {
                            Circle().stroke(Paper.ink.opacity(0.25), lineWidth: 0.8)
                        }
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            SketchyRoundedRectangle(cornerRadius: 9, seed: seed)
                .fill(Paper.raised)
        }
        .overlay {
            SketchyRoundedRectangle(cornerRadius: 9, seed: seed)
                .stroke(isSelected ? Paper.accent : Paper.ink.opacity(0.4), lineWidth: isSelected ? 1.8 : 1.1)
        }
        .help(palette.name)
        .accessibilityLabel("\(palette.name) palette")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
