import SwiftUI

struct TabPicker: View {
    @Binding var selectedTab: Tabs

    var body: some View {
        HStack {
            Button("Patients") {
                selectedTab = .Home
            }
            .background(selectedTab == .Home ? .hippoPrimary : Color.clear)
            .foregroundColor(selectedTab == .Home ? Color.white : .hippoGray500)
            .clipShape(RoundedRectangle(cornerRadius: 20))

            
            Button("Streaming") {
                selectedTab = .StreamingControl
            }
            .background(selectedTab == .StreamingControl ? .hippoPrimary : Color.clear)
            .foregroundColor(selectedTab == .StreamingControl ? Color.white : .hippoGray500)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
}

#Preview {
    // For preview, create a local state wrapper to bind to TabPicker
    RootView()
}

