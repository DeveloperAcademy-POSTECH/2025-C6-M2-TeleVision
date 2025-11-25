import SwiftUI

struct FormActionBar: View {
    @Binding var isPresenting: Bool
    var canSave: Bool = true
    let onSave: () async -> Void

    var body: some View {
        HStack {
            Spacer()

            Button {
                isPresenting = false
            } label: {
                Text("취소")
                    .font(.callout)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 8)
                    .background(.hippoBackground)
                    .foregroundColor(.hippoGray500)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                if canSave {
                    Task { await onSave() }
                    isPresenting = false
                }
            } label: {
                Text("저장")
                    .font(.callout)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 8)
                    .background(.hippoPrimary)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    struct PreviewHost: View {
        @State private var presenting = true
        var body: some View {
            FormActionBar(isPresenting: $presenting, canSave: true) {
                // simulate save
            }
            .padding()
            .background(Color.gray.opacity(0.1))
        }
    }
    return PreviewHost()
}
