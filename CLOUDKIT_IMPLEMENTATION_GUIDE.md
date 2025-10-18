# CloudKit 구현 가이드

## 개요

현재 Hippo 프로젝트는 **Phase 1 (JSON 로컬 저장소)**까지 완료되었습니다.
이 문서는 **Phase 2 (CloudKit 동기화)** 구현을 위한 가이드입니다.

## 현재 상태 (Phase 1)

### [완료] 구현된 기능
- JSON 기반 로컬 저장소 (`PatientLocalDataSourceJSON`)
- Offline-First 아키텍처
- Repository 패턴 구현
- CRUD 작업 (Create, Read, Update, Delete)
- 도메인 모델 (`Patient`, `Operation`, `OperationAsset`, `OperationRecording`)
- Value Objects (`Gender`, `OperationStatus`, `OperationAssetExtension`)

### [TODO] Phase 2 구현 대기
- CloudKit 동기화
- 충돌 해결 (Conflict Resolution)
- 네트워크 상태 모니터링
- 에러 핸들링 및 재시도 로직

---

## CloudKit 구현 계획

### Step 1: CloudKit 스키마 설계

#### Record Types 정의

**1. Patient Record**
```swift
// Record Type: "Patient"
- id: String (Primary Key)
- patientNumber: String
- name: String
- gender: String (male/female)
- birthDate: Date
- createdAt: Date
- updatedAt: Date
```

**2. Operation Record**
```swift
// Record Type: "Operation"
- id: String (Primary Key)
- patientID: Reference<Patient>
- title: String
- diagnosis: String
- surgeon: String
- date: Date
- details: String
- status: String (planned/inProgress/completed/cancelled)
```

**3. OperationAsset Record**
```swift
// Record Type: "OperationAsset"
- id: String (Primary Key)
- operationID: Reference<Operation>
- name: String
- fileExtension: String (usdz/usdc/others)
- fileAsset: CKAsset (3D 파일)
```

**4. OperationRecording Record**
```swift
// Record Type: "OperationRecording"
- id: String (Primary Key)
- operationID: Reference<Operation>
- recordingAsset: CKAsset (Recording 파일)
```

### Step 2: CKRecord Extensions 구현

```swift
// Hippo/Shared/Data/Patients/DataSources/Remote/CKRecordExtensions.swift

import CloudKit
import Foundation

// MARK: - Patient Extensions

extension Patient {
    /// Domain Model → CKRecord 변환
    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: "Patient", recordID: recordID)

        record["patientNumber"] = patientNumber as CKRecordValue
        record["name"] = name as CKRecordValue
        record["gender"] = gender.rawValue as CKRecordValue
        record["birthDate"] = birthDate as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        record["updatedAt"] = updatedAt as CKRecordValue

        return record
    }
}

extension CKRecord {
    /// CKRecord → Domain Model 변환
    func toPatient() throws -> Patient {
        guard let patientNumber = self["patientNumber"] as? String,
              let name = self["name"] as? String,
              let genderRaw = self["gender"] as? String,
              let gender = Gender(rawValue: genderRaw),
              let birthDate = self["birthDate"] as? Date,
              let createdAt = self["createdAt"] as? Date,
              let updatedAt = self["updatedAt"] as? Date else {
            throw CKRecordError.missingRequiredField
        }

        return Patient(
            id: recordID.recordName,
            patientNumber: patientNumber,
            name: name,
            gender: gender,
            birthDate: birthDate,
            operations: [], // Operations는 별도 쿼리로 가져오기
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - Operation Extensions

extension Operation {
    func toCKRecord(patientID: String) -> CKRecord {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: "Operation", recordID: recordID)

        let patientRecordID = CKRecord.ID(recordName: patientID)
        let patientReference = CKRecord.Reference(recordID: patientRecordID, action: .deleteSelf)

        record["patientID"] = patientReference
        record["title"] = title as CKRecordValue
        record["diagnosis"] = diagnosis as CKRecordValue
        record["surgeon"] = surgeon as CKRecordValue
        record["date"] = date as CKRecordValue
        record["details"] = details as CKRecordValue
        record["status"] = status.rawValue as CKRecordValue

        return record
    }
}

extension CKRecord {
    func toOperation() throws -> Operation {
        guard let title = self["title"] as? String,
              let diagnosis = self["diagnosis"] as? String,
              let surgeon = self["surgeon"] as? String,
              let date = self["date"] as? Date,
              let details = self["details"] as? String,
              let statusRaw = self["status"] as? String,
              let status = OperationStatus(rawValue: statusRaw) else {
            throw CKRecordError.missingRequiredField
        }

        return Operation(
            id: recordID.recordName,
            title: title,
            diagnosis: diagnosis,
            surgeon: surgeon,
            date: date,
            details: details,
            operationAssets: [], // Assets는 별도 쿼리로 가져오기
            recordings: [], // Recordings는 별도 쿼리로 가져오기
            status: status
        )
    }
}

// MARK: - OperationAsset Extensions

extension OperationAsset {
    func toCKRecord(operationID: String, fileData: Data) -> CKRecord {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: "OperationAsset", recordID: recordID)

        let operationRecordID = CKRecord.ID(recordName: operationID)
        let operationReference = CKRecord.Reference(recordID: operationRecordID, action: .deleteSelf)

        record["operationID"] = operationReference
        record["name"] = name as CKRecordValue
        record["fileExtension"] = fileExtension.rawValue as CKRecordValue

        // CKAsset 생성
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? fileData.write(to: tempURL)
        record["fileAsset"] = CKAsset(fileURL: tempURL)

        return record
    }
}

extension CKRecord {
    func toOperationAsset() throws -> OperationAsset {
        guard let name = self["name"] as? String,
              let fileExtRaw = self["fileExtension"] as? String,
              let fileExtension = OperationAssetExtension(rawValue: fileExtRaw),
              let fileAsset = self["fileAsset"] as? CKAsset,
              let fileURL = fileAsset.fileURL else {
            throw CKRecordError.missingRequiredField
        }

        return OperationAsset(
            id: recordID.recordName,
            name: name,
            fileExtension: fileExtension,
            fileURL: fileURL
        )
    }
}

// MARK: - Error Types

enum CKRecordError: Error {
    case missingRequiredField
    case invalidDataType
}
```

### Step 3: RemoteDataSource 구현

```swift
// Hippo/Shared/Data/Patients/DataSources/Remote/PatientRemoteDataSource.swift

import CloudKit
import Foundation

public actor PatientRemoteDataSourceCloudKit: PatientRemoteDataSource {
    private let container: CKContainer
    private let database: CKDatabase

    public init(containerIdentifier: String? = nil) {
        if let identifier = containerIdentifier {
            self.container = CKContainer(identifier: identifier)
        } else {
            self.container = CKContainer.default()
        }
        self.database = container.privateCloudDatabase
    }

    // MARK: - Patient Operations

    public func pullAll() async throws -> [Patient] {
        let query = CKQuery(recordType: "Patient", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]

        let results = try await database.records(matching: query)

        var patients: [Patient] = []
        for (_, result) in results.matchResults {
            let record = try result.get()
            var patient = try record.toPatient()

            // 각 Patient의 Operations 가져오기
            patient.operations = try await fetchOperations(for: patient.id)

            patients.append(patient)
        }

        return patients
    }

    public func push(_ patient: Patient) async throws {
        // 1. Patient 레코드 저장
        let patientRecord = patient.toCKRecord()
        _ = try await database.save(patientRecord)

        // 2. 각 Operation 레코드 저장
        for operation in patient.operations {
            let operationRecord = operation.toCKRecord(patientID: patient.id)
            _ = try await database.save(operationRecord)

            // 3. 각 OperationAsset 레코드 저장
            for asset in operation.operationAssets {
                // 파일 데이터 로드 (실제 구현 시 fileURL에서 데이터 읽기)
                let fileData = try Data(contentsOf: asset.fileURL)
                let assetRecord = asset.toCKRecord(operationID: operation.id, fileData: fileData)
                _ = try await database.save(assetRecord)
            }

            // 4. 각 OperationRecording 레코드 저장 (구현 필요)
            // for recording in operation.recordings {
            //     let recordingRecord = recording.toCKRecord(operationID: operation.id)
            //     _ = try await database.save(recordingRecord)
            // }
        }
    }

    public func remove(id: String) async throws {
        let recordID = CKRecord.ID(recordName: id)
        // deleteSelf action으로 인해 연관된 Operation, OperationAsset도 자동 삭제
        _ = try await database.deleteRecord(withID: recordID)
    }

    // MARK: - Private Helpers

    private func fetchOperations(for patientID: String) async throws -> [Operation] {
        let patientRecordID = CKRecord.ID(recordName: patientID)
        let patientReference = CKRecord.Reference(recordID: patientRecordID, action: .none)
        let predicate = NSPredicate(format: "patientID == %@", patientReference)

        let query = CKQuery(recordType: "Operation", predicate: predicate)
        let results = try await database.records(matching: query)

        var operations: [Operation] = []
        for (_, result) in results.matchResults {
            let record = try result.get()
            var operation = try record.toOperation()

            // 각 Operation의 OperationAssets 가져오기
            operation.operationAssets = try await fetchAssets(for: operation.id)

            // 각 Operation의 Recordings 가져오기 (구현 필요)
            // operation.recordings = try await fetchRecordings(for: operation.id)

            operations.append(operation)
        }

        return operations
    }

    private func fetchAssets(for operationID: String) async throws -> [OperationAsset] {
        let operationRecordID = CKRecord.ID(recordName: operationID)
        let operationReference = CKRecord.Reference(recordID: operationRecordID, action: .none)
        let predicate = NSPredicate(format: "operationID == %@", operationReference)

        let query = CKQuery(recordType: "OperationAsset", predicate: predicate)
        let results = try await database.records(matching: query)

        var assets: [OperationAsset] = []
        for (_, result) in results.matchResults {
            let record = try result.get()
            let asset = try record.toOperationAsset()
            assets.append(asset)
        }

        return assets
    }
}
```

### Step 4: 충돌 해결 (Conflict Resolution)

```swift
// PatientRepositoryImpl.swift의 syncFromRemote() 개선

private func syncFromRemote() async {
    do {
        let remotePatients = try await remoteDataSource.pullAll()
        var localPatients = try await localDataSource.fetchAll()

        // Last-Write-Wins 전략
        for remotePatient in remotePatients {
            if let localIndex = localPatients.firstIndex(where: { $0.id == remotePatient.id }) {
                // 충돌 발생: updatedAt 비교
                if remotePatient.updatedAt > localPatients[localIndex].updatedAt {
                    // 원격이 더 최신 → 로컬 덮어쓰기
                    localPatients[localIndex] = remotePatient
                } else if remotePatient.updatedAt < localPatients[localIndex].updatedAt {
                    // 로컬이 더 최신 → 원격에 푸시
                    try? await remoteDataSource.push(localPatients[localIndex])
                }
                // updatedAt이 같으면 충돌 없음
            } else {
                // 원격에만 존재 → 로컬에 추가
                localPatients.append(remotePatient)
            }
        }

        // 로컬에만 존재하는 것들 → 원격에 푸시
        for localPatient in localPatients {
            if !remotePatients.contains(where: { $0.id == localPatient.id }) {
                try? await remoteDataSource.push(localPatient)
            }
        }

        try await localDataSource.saveAll(localPatients)
    } catch {
        print("Sync failed: \(error)")
    }
}
```

---

## 구현 체크리스트

### Phase 2.1: CloudKit 기본 설정
- [ ] iCloud.com.television.hippo 컨테이너 생성
- [ ] CloudKit Dashboard에서 스키마 설정
- [ ] Xcode Capabilities에서 iCloud 활성화
- [ ] Entitlements 파일 확인

### Phase 2.2: 매퍼 구현
- [ ] `Patient.toCKRecord()` 구현
- [ ] `CKRecord.toPatient()` 구현
- [ ] `Operation.toCKRecord()` 구현
- [ ] `CKRecord.toOperation()` 구현
- [ ] `OperationAsset.toCKRecord()` 구현
- [ ] `CKRecord.toOperationAsset()` 구현
- [ ] `OperationRecording.toCKRecord()` 구현 (선택)
- [ ] `CKRecord.toOperationRecording()` 구현 (선택)

### Phase 2.3: RemoteDataSource 구현
- [ ] `pullAll()` 구현 (전체 동기화)
- [ ] `push()` 구현 (개별 업로드)
- [ ] `remove()` 구현 (삭제)
- [ ] 에러 핸들링 추가
- [ ] 재시도 로직 추가

### Phase 2.4: 충돌 해결
- [ ] Last-Write-Wins 전략 구현
- [ ] 양방향 동기화 로직
- [ ] 네트워크 상태 모니터링
- [ ] 백그라운드 동기화 최적화

### Phase 2.5: 테스트
- [ ] 단위 테스트 (Mock CloudKit)
- [ ] 통합 테스트 (실제 CloudKit)
- [ ] 오프라인 → 온라인 전환 테스트
- [ ] 충돌 시나리오 테스트

---

## 도메인 모델 변경 사항 요약

### 주요 변경사항 (2025-10-19)
- **Patient**: 필드 변경
- **Case → Operation**: 엔티티 이름 변경, 필드 추가: `surgeon`, `status`, `recordings`
- **ModelFile → OperationAsset**: 엔티티 이름 변경
- **OperationRecording**: 새로운 엔티티 추가 (수술 녹화 영상 관리)
- **Value Objects**: `Gender`, `OperationStatus`, `OperationAssetExtension` 추가

---

## 참고 자료

- [CloudKit Documentation](https://developer.apple.com/documentation/cloudkit)
- [CKRecord Reference](https://developer.apple.com/documentation/cloudkit/ckrecord)
- [CloudKit Best Practices](https://developer.apple.com/videos/play/wwdc2021/10086/)

---

**Last Updated**: 2025-10-19
**Status**: Phase 1 완료 / Phase 2 대기 중 (도메인 모델 업데이트 완료)
