import SwiftUI

struct ContentView: View {
    @ObservedObject var store: WallpaperStore

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(store: store)
                .frame(width: 232)
                .background(Paper.sunken.ignoresSafeArea())

            SketchyLine(seed: 2.4)
                .stroke(Paper.inkHairline, lineWidth: 1.2)
                .frame(width: 3)
                .ignoresSafeArea()

            LibraryView(store: store)
                .frame(maxWidth: .infinity)

            SketchyLine(seed: 6.1)
                .stroke(Paper.inkHairline, lineWidth: 1.2)
                .frame(width: 3)
                .ignoresSafeArea()

            InspectorView(store: store)
                .frame(width: 332)
                .background(Paper.raised.ignoresSafeArea())
        }
        .background(Paper.base.ignoresSafeArea())
        .frame(minWidth: 1060, minHeight: 660)
        .alert("Mural", isPresented: errorPresented) {
            Button("OK") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "Something went wrong.")
        }
        .overlay(alignment: .bottom) {
            if let message = store.message {
                toast(message)
            }
        }
    }

    private func toast(_ message: String) -> some View {
        Text(message)
            .font(.virgil(14))
            .foregroundStyle(Paper.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                SketchyRoundedRectangle(cornerRadius: 12, seed: 8.8)
                    .fill(Paper.raised)
            }
            .sketchyBorder(cornerRadius: 12, seed: 8.8)
            .sketchyShadow(cornerRadius: 12, seed: 8.8)
            .padding(.bottom, 20)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .task {
                try? await Task.sleep(for: .seconds(3))
                withAnimation { store.message = nil }
            }
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )
    }
}
