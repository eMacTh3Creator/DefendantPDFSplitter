import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    let onDrop: (URL) -> Void
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("Drop a PDF Here")
                .font(.title2)
                .fontWeight(.semibold)

            Text("or click to browse")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                )
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary.opacity(0.4))
        )
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isTargeted ? Color.accentColor.opacity(0.05) : Color.clear)
        )
        .padding(24)
        .onDrop(of: [.pdf], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
        .onTapGesture {
            openFilePicker()
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        provider.loadItem(forTypeIdentifier: UTType.pdf.identifier, options: nil) { item, _ in
            if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                DispatchQueue.main.async { onDrop(url) }
            } else if let url = item as? URL {
                DispatchQueue.main.async { onDrop(url) }
            }
        }
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a PDF to split by defendant"

        if panel.runModal() == .OK, let url = panel.url {
            onDrop(url)
        }
    }
}
