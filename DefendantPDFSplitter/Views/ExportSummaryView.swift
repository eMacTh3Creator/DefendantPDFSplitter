import SwiftUI

struct ExportSummaryView: View {
    let groups: [DefendantGroup]
    let totalPages: Int
    let originalFilename: String
    let saveDestination: URL?
    let onChooseLocation: () -> Void
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private var outputFolderName: String {
        let baseName = (originalFilename as NSString).deletingPathExtension
        return "split_defendants_\(baseName)"
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Export Summary")
                .font(.title2)
                .fontWeight(.semibold)

            Text("This will export \(groups.count) PDFs from \(totalPages) pages.")
                .font(.body)

            // Save location chooser
            destinationSection

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(groups) { group in
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundColor(.accentColor)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(group.filename)
                                    .fontWeight(.medium)
                                Text(group.pageRange)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("\(group.pageCount) pg")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.secondary.opacity(0.1)))
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                    }
                }
            }
            .frame(maxHeight: 280)

            Divider()

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Export \(groups.count) PDFs") {
                    onConfirm()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(saveDestination == nil)
            }
        }
        .padding(24)
        .frame(width: 540)
    }

    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Save to:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Button("Choose...") {
                    onChooseLocation()
                }
                .controlSize(.small)
            }

            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .foregroundColor(.accentColor)
                    .font(.caption)

                if let dest = saveDestination {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(dest.path)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.head)
                        Text("→ \(outputFolderName)/")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("No location selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.08))
            )
        }
    }
}
