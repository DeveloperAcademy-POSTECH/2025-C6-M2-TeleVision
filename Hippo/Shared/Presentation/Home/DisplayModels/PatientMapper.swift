import Foundation

// MARK: - Patient Mapper

/// Domain 모델 → Display 모델 변환

public extension Patient {
    /// Domain 모델을 View Display 모델로 변환
    func toDisplayModel() -> PatientDisplayModel {
        PatientDisplayModel(
            id: id,
            patientNumber: patientNumber,
            name: name,
            gender: gender,
            genderText: gender.displayText,
            genderIcon: gender.iconName,
            age: age,
            ageText: "\(age) years",
            birthDate: birthDate,
            birthDateText: birthDate.formatted(date: .abbreviated, time: .omitted),
            operations: operations.map { $0.toDisplayModel() },
            operationCount: operations.count,
            latestOperation: operations.sorted(by: { $0.date > $1.date }).first?.toDisplayModel(),
            updatedAt: updatedAt,
            updatedAtText: updatedAt.formatted()
        )
    }
}

public extension Operation {
    /// Domain 모델을 View Display 모델로 변환
    func toDisplayModel() -> OperationDisplayModel {
        OperationDisplayModel(
            id: id,
            title: title,
            diagnosis: diagnosis,
            surgeon: surgeon,
            surgicalSite: surgicalSite,
            date: date,
            dateText: date.toOperationDateString(),
            details: details,
            status: status,
            assets: operationAssets.map { $0.toDisplayModel() },
            assetCount: operationAssets.count,
            records: recordings
        )
    }
}

public extension OperationAsset {
    /// Domain 모델을 View Display 모델로 변환
    func toDisplayModel() -> OperationAssetDisplayModel {
        return OperationAssetDisplayModel(
            id: id,
            fileName: originalFileName,
            createdAt: createdAt,
            fileURL: getResolvedURL() ?? URL(fileURLWithPath: ""),
        )
    }
}
