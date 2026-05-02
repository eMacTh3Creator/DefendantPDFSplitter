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
                Button("Auto Detect Names") {
                    viewModel.autoDetectNames()
                }
                .buttonStyle(.bordered)

                Button("Export PDFs") {
                    viewModel.prepareExport()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.state == .exporting)

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
        VStack {
            if let index = selectedPageIndex,
               let image = viewModel.thumbnail(for: index, size: CGSize(width: 400, height: 560)) {
                Text("Page \(index + 1)")
                    .font(.headline)
                    .padding(.top, 8)

                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .border(Color.secondary.opacity(0.3), width: 1)
                    .padding(8)
                    .shadow(radius: 2)

                Spacer()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("Select a page to preview")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
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

            Text(assignment.suggestedName.isEmpty ? "—" : assignment.suggestedName)
                .frame(minWidth: 140, alignment: .leading)
                .foregroundStyle(assignment.suggestedName.isEmpty ? .tertiary : .secondary)
                .font(.caption)
                .padding(.leading, 8)

            TextField("Enter defendant name", text: $editedName)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 190)
                .padding(.leading, 8)
                .focused($isFocused)
                .onAppear { editedName = assignment.defendantName }
                .onChange(of: editedName) { newValue in
                    onNameChange(newValue)
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
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }
}
