import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = PDFSplitterViewModel()

    var body: some View {
        ZStack {
            mainContent
        }
        .frame(minWidth: 800, minHeight: 560)
        .sheet(isPresented: $viewModel.showExportSummary) {
            ExportSummaryView(
                groups: viewModel.groups,
                totalPages: viewModel.pageCount,
                onConfirm: { viewModel.performExport() },
                onCancel: { viewModel.showExportSummary = false }
            )
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch viewModel.state {
        case .idle:
            DropZoneView { url in
                viewModel.loadPDF(from: url)
            }

        case .loaded, .exporting, .exported:
            VStack(spacing: 0) {
                PageAssignmentTableView(viewModel: viewModel)

                if !viewModel.warningMessage.isEmpty {
                    warningBar
                }

                if !viewModel.exportMessage.isEmpty {
                    successBar
                }

                if viewModel.state == .exporting {
                    ProgressView("Exporting...")
                        .padding()
                }
            }

        case .error(let message):
            errorView(message)
        }
    }

    private var warningBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(viewModel.warningMessage)
                .font(.callout)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.08))
    }

    private var successBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.exportMessage)
                    .font(.callout)
                    .fontWeight(.medium)

                if let folder = viewModel.outputFolderURL {
                    Text(folder.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let zip = viewModel.zipFileURL {
                    Text("ZIP: \(zip.lastPathComponent)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if viewModel.outputFolderURL != nil {
                Button("Open Folder") {
                    viewModel.openOutputFolder()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.green.opacity(0.08))
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.red)

            Text("Error")
                .font(.title2)
                .fontWeight(.semibold)

            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Reset") {
                viewModel.reset()
            }
            .buttonStyle(.bordered)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
