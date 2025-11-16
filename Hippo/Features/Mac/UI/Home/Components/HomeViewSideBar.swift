import SwiftUI

struct HomeViewSideBar: View {
    @Binding var rootVM: MacRootViewModel
    @Binding var hoveredPatientID: String?

    var body: some View {
        VStack(alignment: .leading) {
            List {
                TodaysSurgeryButton(rootVM: $rootVM)

                //Patient List 타이틀 위해서 section 추가함
                Section {
                    //TODO: 환자 리스트에 데이터가 없는 경우

                    //환자 리스트에 데이터가 있는 경우
                    ForEach(rootVM.loadedPatients, id: \.id) { data in
                        PatientSelectButton(rootVM: $rootVM, data: data)
                    }
                } header: {
                    HStack {
                        //헤더 텍스트
                            Text("Patient List")
                                .font(.body)
                                .fontWeight(.bold)
                        
                        Spacer()

                        //환자 추가 버튼
                        Button {
                            rootVM.openPatientCreateSheet()
                        } label: {
                            Image(systemName: "person.badge.plus")
                                .font(.title2)
                                .padding(12)
                                .foregroundColor(.hippoPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                }
            }
        }
        .padding(4)
    }
}

#Preview {
    RootView()
}
