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
            gender: gender.displayText,
            genderIcon: gender.iconName,
            age: age,
            ageText: "\(age) years",
            birthDateText: birthDate.formatted(date: .abbreviated, time: .omitted),
            operations: operations.map { $0.toDisplayModel() },
            operationCount: operations.count,
            lastestOperation: operations.sorted(by: { $0.date > $1.date }).first?.toDisplayModel(),
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
            date: date,
            dateText: date.formatted(date: .abbreviated, time: .omitted),
            details: details,
            status: status,
            statusText: status.displayText,
            statusColor: status.colorName,
            assets: operationAssets.map { $0.toDisplayModel() },
            assetCount: operationAssets.count
        )
    }
}

public extension OperationAsset {
    /// Domain 모델을 View Display 모델로 변환
    func toDisplayModel() -> OperationAssetDisplayModel {
        OperationAssetDisplayModel(
            id: id,
            name: name,
            fileExtension: fileExtension.rawValue,
            fileURL: fileURL,
            iconName: fileExtension.iconName
        )
    }
}
