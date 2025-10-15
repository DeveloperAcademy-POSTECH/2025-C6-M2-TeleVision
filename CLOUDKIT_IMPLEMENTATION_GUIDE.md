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
- 도메인 모델 (`Patient`, `Case`, `ModelFile`)

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
- name: String
- sex: String (male/female/other/unknown)
- birthDate: Date (Optional)
- mrn: String (Optional)
- updatedAt: Date
```

**2. Case Record**
```swift
// Record Type: "Case"
- id: String (Primary Key)
- patientID: Reference<Patient>
- title: String
- diagnosis: String
- scheduledAt: Date (Optional)
- detail: String (Optional)
- updatedAt: Date
```

**3. ModelFile Record**
```swift
// Record Type: "ModelFile"
- id: String (Primary Key)
- caseID: Reference<Case>
- fileName: String
- format: String (usdz/reality/obj/fbx/stl/dicom)
- sizeBytes: Int64 (Optional)
- remoteURL: String (Optional)
- fileAsset: CKAsset (3D 파일)
- createdAt: Date
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
        let recordID = CKRecord.ID(recordName: id.value)
        let record = CKRecord(recordType: "Patient", recordID: recordID)

        record["name"] = name as CKRecordValue
        record["sex"] = sex.rawValue as CKRecordValue
        record["birthDate"] = birthDate as? CKRecordValue
        record["mrn"] = mrn as? CKRecordValue
        record["updatedAt"] = updatedAt as CKRecordValue

        return record
    }
}

extension CKRecord {
    /// CKRecord → Domain Model 변환
    func toPatient() throws -> Patient {
        guard let name = self["name"] as? String,
              let sexRaw = self["sex"] as? String,
              let sex = Sex(rawValue: sexRaw),
              let updatedAt = self["updatedAt"] as? Date else {
            throw CKRecordError.missingRequiredField
        }

        return Patient(
            id: PatientID(value: recordID.recordName),
            name: name,
            sex: sex,
            birthDate: self["birthDate"] as? Date,
            mrn: self["mrn"] as? String,
            cases: [], // Cases는 별도 쿼리로 가져오기
            updatedAt: updatedAt
        )
    }
}

// MARK: - Case Extensions

extension Case {
    func toCKRecord(patientID: PatientID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.value)
        let record = CKRecord(recordType: "Case", recordID: recordID)

        let patientRecordID = CKRecord.ID(recordName: patientID.value)
        let patientReference = CKRecord.Reference(recordID: patientRecordID, action: .deleteSelf)

        record["patientID"] = patientReference
        record["title"] = title as CKRecordValue
        record["diagnosis"] = diagnosis as CKRecordValue
        record["scheduledAt"] = scheduledAt as? CKRecordValue
        record["detail"] = detail as? CKRecordValue
        record["updatedAt"] = updatedAt as CKRecordValue

        return record
    }
}

extension CKRecord {
    func toCase() throws -> Case {
        guard let title = self["title"] as? String,
              let diagnosis = self["diagnosis"] as? String,
              let updatedAt = self["updatedAt"] as? Date else {
            throw CKRecordError.missingRequiredField
        }

        return Case(
            id: CaseID(value: recordID.recordName),
            title: title,
            diagnosis: diagnosis,
            scheduledAt: self["scheduledAt"] as? Date,
            detail: self["detail"] as? String,
            models: [], // Models는 별도 쿼리로 가져오기
            updatedAt: updatedAt
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

            // 각 Patient의 Cases 가져오기
            patient.cases = try await fetchCases(for: patient.id)

            patients.append(patient)
        }

        return patients
    }

    public func push(_ patient: Patient) async throws {
        // 1. Patient 레코드 저장
        let patientRecord = patient.toCKRecord()
        _ = try await database.save(patientRecord)

        // 2. 각 Case 레코드 저장
        for `case` in patient.cases {
            let caseRecord = `case`.toCKRecord(patientID: patient.id)
            _ = try await database.save(caseRecord)

            // 3. 각 ModelFile 레코드 저장
            for model in `case`.models {
                let modelRecord = model.toCKRecord(caseID: `case`.id)
                _ = try await database.save(modelRecord)
            }
        }
    }

    public func remove(id: PatientID) async throws {
        let recordID = CKRecord.ID(recordName: id.value)
        // deleteSelf action으로 인해 연관된 Case, ModelFile도 자동 삭제
        _ = try await database.deleteRecord(withID: recordID)
    }

    // MARK: - Private Helpers

    private func fetchCases(for patientID: PatientID) async throws -> [Case] {
        let patientRecordID = CKRecord.ID(recordName: patientID.value)
        let patientReference = CKRecord.Reference(recordID: patientRecordID, action: .none)
        let predicate = NSPredicate(format: "patientID == %@", patientReference)

        let query = CKQuery(recordType: "Case", predicate: predicate)
        let results = try await database.records(matching: query)

        var cases: [Case] = []
        for (_, result) in results.matchResults {
            let record = try result.get()
            var `case` = try record.toCase()

            // 각 Case의 ModelFiles 가져오기
            `case`.models = try await fetchModels(for: `case`.id)

            cases.append(`case`)
        }

        return cases
    }

    private func fetchModels(for caseID: CaseID) async throws -> [ModelFile] {
        let caseRecordID = CKRecord.ID(recordName: caseID.value)
        let caseReference = CKRecord.Reference(recordID: caseRecordID, action: .none)
        let predicate = NSPredicate(format: "caseID == %@", caseReference)

        let query = CKQuery(recordType: "ModelFile", predicate: predicate)
        let results = try await database.records(matching: query)

        var models: [ModelFile] = []
        for (_, result) in results.matchResults {
            let record = try result.get()
            let model = try record.toModelFile()
            models.append(model)
        }

        return models
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
- [ ] `Case.toCKRecord()` 구현
- [ ] `CKRecord.toCase()` 구현
- [ ] `ModelFile.toCKRecord()` 구현
- [ ] `CKRecord.toModelFile()` 구현

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

## 참고 자료

- [CloudKit Documentation](https://developer.apple.com/documentation/cloudkit)
- [CKRecord Reference](https://developer.apple.com/documentation/cloudkit/ckrecord)
- [CloudKit Best Practices](https://developer.apple.com/videos/play/wwdc2021/10086/)

---

**Last Updated**: 2025-10-16
**Status**: Phase 1 완료 / Phase 2 대기 중
