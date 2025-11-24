import SwiftUI

struct HomeViewSideBar: View {
    @Binding var rootVM: MacRootViewModel
    @Binding var hoveredPatientID: String?

    var body: some View {
        List {
            TodaysSurgeryButton(rootVM: $rootVM)
                .padding(.top)

            // Patient List 타이틀 위해서 section 추가함
            Section {
                // 환자 리스트에 데이터가 있는 경우
                ForEach(rootVM.loadedPatients, id: \.id) { data in
                    PatientSelectButton(rootVM: $rootVM, data: data)
                }
            } header: {
                HStack {
                    Text("Patient List")
                        .font(.title3)
                        .fontWeight(.bold)

                    Spacer()

                    Button {
                        rootVM.openPatientCreateSheet()
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .font(.title3)
                            .foregroundColor(.hippoPrimary)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 12)
                }
                .padding(8)
            }
//            .padding(.top, 8)
        }
    }
}

#Preview {
    RootView()
}
