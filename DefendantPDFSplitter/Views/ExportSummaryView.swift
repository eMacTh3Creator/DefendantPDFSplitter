import SwiftUI

struct ExportSummaryView: View {
    let groups: [DefendantGroup]
    let totalPages: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Export Summary")
                .font(.title2)
                .fontWeight(.semibold)

            Text("This will export \(groups.count) PDFs from \(totalPages) pages.")
                .font(.body)

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
            .frame(maxHeight: 300)

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
            }
        }
        .padding(24)
        .frame(width: 480)
    }
}
