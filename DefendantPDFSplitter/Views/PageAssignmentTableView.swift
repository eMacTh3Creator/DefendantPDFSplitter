import SwiftUI

struct PageAssignmentTableView: View {
    @ObservedObject var viewModel: PDFSplitterViewModel
    @State private var selectedPageIndex: Int? = nil

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            tableContent
        }
    }

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.pdfFilename)
                    .font(.headline)
                Text("\(viewModel.pageCount) pages")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button(viewModel.isDetecting ? "Detecting..." : "Auto Detect Names") {
                    viewModel.autoDetectNames()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isDetecting)

                Button("Export PDFs") {
                    viewModel.prepareExport()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.state == .exporting || viewModel.isDetecting)

                if viewModel.outputFolderURL != nil {
                    Button("Open Output Folder") {
                        viewModel.openOutputFolder()
                    }
                    .buttonStyle(.bordered)
                }

                Button("Reset") {
                    viewModel.reset()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var tableContent: some View {
        HSplitView {
            // Left: page list
            pageList
                .frame(minWidth: 500)

            // Right: page thumbnail preview
            thumbnailPreview
                .frame(minWidth: 250, idealWidth: 300)
        }
    }

    private var pageList: some View {
        VStack(spacing: 0) {
            // Column headers
            HStack(spacing: 0) {
                Text("Page")
                    .frame(width: 50, alignment: .center)
                Text("Suggested Name")
                    .frame(minWidth: 150, alignment: .leading)
                    .padding(.leading, 8)
                Text("Defendant Name")
                    .frame(minWidth: 200, alignment: .leading)
                    .padding(.leading, 8)
                Text("Status")
                    .frame(width: 80, alignment: .center)
                Spacer()
            }
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            ScrollViewReader { proxy in
                List(Array(viewModel.assignments.enumerated()), id: \.element.id) { index, assignment in
                    PageRow(
                        assignment: assignment,
                        isSelected: selectedPageIndex == index,
                        onNameChange: { name in
                            viewModel.updateDefendantName(for: assignment.id, name: name)
                        },
                        onApplyDown: {
                            viewModel.applyNameToFollowingBlanks(from: index)
                        },
                        onSelect: {
                            selectedPageIndex = index
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4))
                }
                .listStyle(.plain)
            }
        }
    }

    private var thumbnailPreview: some View {
        ZoomablePreview(
            pageIndex: selectedPageIndex,
            viewModel: viewModel
        )
    }
}

// MARK: - Zoomable Page Preview

private struct ZoomablePreview: View {
    let pageIndex: Int?
    @ObservedObject var viewModel: PDFSplitterViewModel

    @State private var zoom: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var dragStart: CGSize = .zero
    private let minZoom: CGFloat = 0.5
    private let maxZoom: CGFloat = 5.0

    var body: some View {
        VStack(spacing: 0) {
            if let index = pageIndex {
                header(index: index)
                Divider()
                imageScroller(index: index)
            } else {
                emptyState
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .onChange(of: pageIndex) { _ in
            zoom = 1.0
            offset = .zero
        }
    }

    private func header(index: Int) -> some View {
        HStack(spacing: 8) {
            Text("Page \(index + 1)")
                .font(.headline)

            Spacer()

            // Zoom controls
            Button {
                zoom = max(minZoom, zoom - 0.25)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help("Zoom out")
            .disabled(zoom <= minZoom)

            Text("\(Int(zoom * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 44)

            Button {
                zoom = min(maxZoom, zoom + 0.25)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help("Zoom in")
            .disabled(zoom >= maxZoom)

            Button {
                zoom = 1.0
                offset = .zero
            } label: {
                Image(systemName: "1.magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help("Reset zoom")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func imageScroller(index: Int) -> some View {
        // Render at higher resolution as zoom grows so the OCR text stays legible.
        let baseSize = CGSize(width: 800, height: 1100)
        let renderScale = max(1.0, zoom)
        let renderSize = CGSize(
            width: baseSize.width * renderScale,
            height: baseSize.height * renderScale
        )

        if let image = viewModel.thumbnail(for: index, size: renderSize) {
            ScrollView([.vertical, .horizontal], showsIndicators: true) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 380 * zoom, height: 520 * zoom)
                    .border(Color.secondary.opacity(0.3), width: 1)
                    .shadow(radius: 2)
                    .padding(8)
                    .gesture(
                        // Two-finger pinch / trackpad pinch
                        MagnificationGesture()
                            .onChanged { scale in
                                let proposed = zoom * scale
                                zoom = min(maxZoom, max(minZoom, proposed))
                            }
                    )
                    .onTapGesture(count: 2) {
                        // Double-click toggles between fit and 2x
                        zoom = (zoom >= 1.5) ? 1.0 : 2.0
                    }
            }
            .background(Color(nsColor: .windowBackgroundColor))
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("Select a page to preview")
                .foregroundStyle(.secondary)
            Text("Double-click image to zoom · pinch to scale")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Page Row

private struct PageRow: View {
    let assignment: PageAssignment
    let isSelected: Bool
    let onNameChange: (String) -> Void
    let onApplyDown: () -> Void
    let onSelect: () -> Void

    @State private var editedName: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            Text("\(assignment.pageNumber)")
                .frame(width: 40, alignment: .center)
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
                .onTapGesture { onSelect() }

            Text(assignment.suggestedName.isEmpty ? "—" : assignment.suggestedName)
                .frame(minWidth: 140, alignment: .leading)
                .foregroundStyle(assignment.suggestedName.isEmpty ? .tertiary : .secondary)
                .font(.caption)
                .padding(.leading, 8)
                .contentShape(Rectangle())
                .onTapGesture { onSelect() }

            TextField("Enter defendant name", text: $editedName)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 190)
                .padding(.leading, 8)
                .focused($isFocused)
                .onAppear { editedName = assignment.defendantName }
                .onChange(of: editedName) { newValue in
                    onNameChange(newValue)
                }
                .onChange(of: isFocused) { focused in
                    if focused { onSelect() }
                }
                .onSubmit {
                    onApplyDown()
                }

            // Status indicator
            Group {
                if assignment.hasName || !editedName.trimmingCharacters(in: .whitespaces).isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                }
            }
            .frame(width: 30, alignment: .center)
            .contentShape(Rectangle())
            .onTapGesture { onSelect() }

            // Apply-down button
            Button(action: onApplyDown) {
                Image(systemName: "arrow.down.to.line")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("Apply this name to following blank pages")
            .frame(width: 30)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(4)
    }
}
