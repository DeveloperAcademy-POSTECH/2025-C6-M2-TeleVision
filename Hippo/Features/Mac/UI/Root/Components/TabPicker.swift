import SwiftUI

struct TabPicker: View {
    @Binding var selectedTab: Tabs

    var body: some View {
        HStack(spacing: 0) {
            tabButton(tab: .Home, title: "Patients")
            tabButton(tab: .StreamingControl, title: "Streaming")
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color.white)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 2, y: 4)
        )
        .frame(width: 240)
    }

    private func tabButton(tab: Tabs, title: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(selectedTab == tab ? .white : .hippoGray500)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    if selectedTab == tab {
                        Capsule()
                            .fill(Color.hippoPrimary)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    // For preview, create a local state wrapper to bind to TabPicker
    RootView()
}
