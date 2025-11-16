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
                Text("Cancel")
                    .font(.callout)
                    .padding(12)
            }
            .background(.hippoBackground)
            .foregroundColor(.hippoGray500)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .buttonStyle(.plain)

            Button {
                if canSave {
                    Task { await onSave() }
                    isPresenting = false
                } 
            } label: {
                Text("Save")
                    .font(.callout)
                    .padding(12)
            }
            .background(.hippoPrimary)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
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
