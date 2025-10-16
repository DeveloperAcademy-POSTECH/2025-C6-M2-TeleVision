# Hippo 프로젝트 아키텍처 문서

## 프로젝트 구조

```
Hippo/
┣ Shared/                              # 공통 코드 (HippoVision + HippoMac)
┃ ┣ Domain/                            # 도메인 레이어
┃ ┃ ┣ Patients/                        # Patient 도메인
┃ ┃ ┃ ┣ Entities/                      # 도메인 엔티티
┃ ┃ ┃ ┃ ┣ Patient.swift                # 환자 엔티티 (Codable)
┃ ┃ ┃ ┃ ┣ Case.swift                   # 케이스 엔티티 (Codable)
┃ ┃ ┃ ┃ ┗ ModelFile.swift              # 3D 모델 파일 엔티티
┃ ┃ ┃ ┗ Repositories/                  # Repository 인터페이스
┃ ┃ ┃   ┗ PatientRepository.swift
┃ ┃ ┗ ...                               # 다른 도메인
┃ ┃
┃ ┣ Data/                              # 데이터 레이어
┃ ┃ ┗ Patients/                        # Patient 데이터 구현
┃ ┃   ┣ DataSources/                   # 데이터 소스
┃ ┃   ┃ ┣ Local/                       # 로컬 저장소 (JSON/SwiftData)
┃ ┃   ┃ ┃ ┗ PatientLocalDataSource.swift
┃ ┃   ┃ ┗ Remote/                      # 원격 저장소 (CloudKit)
┃ ┃   ┃   ┗ PatientRemoteDataSource.swift
┃ ┃   ┗ Repository/                    # Repository 구현체
┃ ┃     ┗ PatientRepositoryImpl.swift
┃ ┃
┃ ┗ Presentation/                      # 공통 프레젠테이션 로직
┃   ┗ Patients/                        # Patient 화면 상태
┃     ┣ PatientState.swift             # 상태 모델
┃     ┗ PatientViewModel.swift         # 뷰모델
┃
┣ Features/                            # 플랫폼별 UI
┃ ┣ VisionUI/                          # visionOS 전용 (HippoVision만)
┃ ┃ ┣ ContentView.swift
┃ ┃ ┣ ImmersiveView.swift
┃ ┃ ┗ ToggleImmersiveSpaceButton.swift
┃ ┃
┃ ┗ MacUI/                             # macOS 전용 (HippoMac만)
┃   ┗ ContentView.swift
┃
┣ Applications/                        # 앱 엔트리 포인트
┃ ┣ VisionApp/                         # visionOS 앱 (HippoVision만)
┃ ┃ ┣ HippoVisionApp.swift
┃ ┃ ┗ Info.plist
┃ ┃
┃ ┗ MacApp/                            # macOS 앱 (HippoMac만)
┃   ┣ HippoMacApp.swift
┃   ┗ Info.plist
┃
┗ Resources/                           # 리소스 파일
  ┣ VisionAssets.xcassets              # visionOS 에셋 (HippoVision만)
  ┗ MacAssets.xcassets                 # macOS 에셋 (HippoMac만)
```

---

## Clean Architecture 레이어

### 1. Domain Layer (Shared/Domain)
**책임**: 비즈니스 로직과 엔티티 정의

```swift
// Entity - Codable을 채택한 도메인 모델
public struct Patient: Codable, Sendable, Identifiable, Equatable {
    public let id: PatientID
    public var name: String
    public var sex: Sex
    public var birthDate: Date?
    public var mrn: String?  // Medical Record Number
    public var cases: [Case]
    public var updatedAt: Date
}

public struct Case: Codable, Sendable, Identifiable, Equatable {
    public let id: CaseID
    public var title: String
    public var diagnosis: String
    public var models: [ModelFile]  // 3D 모델 파일들
}

// Repository Protocol - 데이터 접근 인터페이스
public protocol PatientRepository: Sendable {
    func listPatients() async throws -> [Patient]
    func getPatient(id: PatientID) async throws -> Patient
    func upsertPatient(_ patient: Patient) async throws -> Patient
    func deletePatient(id: PatientID) async throws
}
```

**특징**:
- 외부 의존성 없음 (SwiftUI, CloudKit, SwiftData 등)
- 플랫폼 독립적
- Codable 채택으로 직접 직렬화 가능 (Mapper 불필요)
- 테스트 용이

---

### 2. Data Layer (Shared/Data)
**책임**: 데이터 소스 관리 및 Repository 구현

#### 2.1 Local Data Source (JSON → 향후 SwiftData)
```swift
// JSON 기반 로컬 저장소 (현재 구현)
public actor PatientLocalDataSourceJSON: PatientLocalDataSource {
    private let fileManager: FileManager
    private let storageURL: URL

    public func fetchAll() async throws -> [Patient] {
        let data = try Data(contentsOf: storageURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Patient].self, from: data)
    }

    public func saveAll(_ patients: [Patient]) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(patients)
        try data.write(to: storageURL)
    }
}

// TODO: SwiftData 마이그레이션 예정
```

#### 2.2 Remote Data Source (CloudKit Stub)
```swift
public actor PatientRemoteDataSourceCloudKit: PatientRemoteDataSource {
    private let container: CKContainer
    private let database: CKDatabase

    public func pullAll() async throws -> [Patient] {
        // TODO: CloudKit 구현
        return []
    }

    public func push(_ patient: Patient) async throws {
        // TODO: CloudKit 구현
    }
}
```

#### 2.3 Repository Implementation (Offline-First)
```swift
public actor PatientRepositoryImpl: PatientRepository {
    private let localDataSource: PatientLocalDataSource
    private let remoteDataSource: PatientRemoteDataSource

    public func listPatients() async throws -> [Patient] {
        // 1. 로컬에서 즉시 반환 (Offline-First)
        let localPatients = try await localDataSource.fetchAll()

        // 2. 백그라운드에서 원격 동기화
        Task.detached {
            await self?.syncFromRemote()
        }

        return localPatients.sorted { $0.updatedAt > $1.updatedAt }
    }
}
```

**핵심 설계 결정**:
- **Mapper 없음**: Domain Entity가 Codable이므로 직접 직렬화
- **Offline-First**: 로컬 데이터 우선, 백그라운드 동기화
- **단순화**: DTO, Entity 없이 Domain Model만 사용

---

### 3. Presentation Layer (Shared/Presentation + Features)

#### 공통 상태 관리 (Shared/Presentation)
```swift
// 도메인별 상태 모델
public struct PatientState: Equatable, Sendable {
    public var items: [Patient]
    public var isLoading: Bool
    public var alert: String?
}

// ViewModel
@Observable
public final class PatientViewModel: Sendable {
    private let repository: PatientRepository
    public private(set) var state: PatientState

    public func loadPatients() async {
        state.isLoading = true
        do {
            let patients = try await repository.listPatients()
            state.items = patients
        } catch {
            state.alert = error.localizedDescription
        }
        state.isLoading = false
    }
}
```

#### 플랫폼별 UI (Features)
- **VisionUI**: visionOS 전용 뷰 (ImmersiveView, 3D 모델 렌더링)
- **MacUI**: macOS 전용 뷰 (전통적인 윈도우 UI)

---

## 데이터 흐름

```
┌─────────────────────────────────────────────────────────┐
│                      UI Layer                           │
│              (VisionUI / MacUI)                         │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────┐
│              ViewModel + State                           │
│              (Shared/Presentation)                       │
└──────────────────────┬─────────────────────────────────-─┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────┐
│              Repository Interface                        │
│              (Shared/Domain)                             │
└──────────────────────┬───────────────────────────────-───┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────┐
│            Repository Implementation                     │
│              (Shared/Data/Repository)                    │
│                                                          │
│   ┌────────────────┐        ┌────────────────┐           │
│   │ Remote Source  │  ◄───► │  Local Source  │           │
│   │   (CloudKit)   │        │     (JSON)     │           │
│   │    [TODO]      │        │   [구현완료]   │             │
│   └────────────────┘        └────────────────┘           │
│           │                         │                    │
│           │   Mapper 없음           │                     │
│           │   (Codable 직접 사용)   │                      │
│           │                         │                    │
│           └──────────┬──────────────┘                    │
│                      ▼                                   │
│                   Patient                                │
│            (Domain Entity - Codable)                     │
└──────────────────────────────────────────────────────────┘
```

### 실제 데이터 흐름 예시

#### 1. 데이터 가져오기 (Offline-First)
```
UI (PatientView)
  → ViewModel.loadPatients()
    → Repository.listPatients()
      → LocalDataSource.fetchAll() → [Patient] (JSON 디코딩)
        → UI에 즉시 반환 [완료]
      → Task.detached { syncFromRemote() } (백그라운드)
        → RemoteDataSource.pullAll() → [Patient]
          → 로컬과 병합 (updatedAt 기준)
            → LocalDataSource.saveAll() (JSON 인코딩)
```

#### 2. 데이터 저장하기 (Local-First)
```
UI (PatientForm)
  → ViewModel.savePatient(patient)
    → Repository.upsertPatient(patient)
      → patient.updatedAt = Date() (타임스탬프 갱신)
        → LocalDataSource.saveAll() (즉시 JSON 저장) [완료]
      → Task.detached { RemoteDataSource.push(patient) } (백그라운드)
```

**핵심 특징**:
- Mapper 없이 Codable로 직접 직렬화/역직렬화
- 로컬 우선 → 즉각적인 반응성
- 백그라운드 동기화 → 네트워크 영향 최소화

---

## 타겟 구성

### HippoVision (visionOS)
```
Applications/VisionApp/
Features/VisionUI/
Shared/ (전체)
Resources/VisionAssets.xcassets
```

### HippoMac (macOS)
```
Applications/MacApp/
Features/MacUI/
Shared/ (전체)
Resources/MacAssets.xcassets
```

### 공통 (Both Targets)
```
Shared/Domain/
Shared/Data/
Shared/Presentation/
```

---

## iCloud & CloudKit 구성

### Container Identifier
```
iCloud.com.television.hippo
```

### 데이터 동기화 전략
1. **Offline-First**: 로컬 SwiftData를 우선 사용
2. **Background Sync**: CloudKit과 백그라운드에서 동기화
3. **Conflict Resolution**: 최신 타임스탬프 우선 (Last-Write-Wins)

---

## 의존성 관리

### 외부 프레임워크
- **SwiftUI**: UI 레이어
- **SwiftData**: 로컬 퍼시스턴스
- **CloudKit**: 원격 동기화
- **Combine**: 반응형 프로그래밍 (필요시)

### 의존성 방향
```
UI → Presentation → Domain ← Data → Infrastructure
                      ▲
                      │
                (의존성 역전)
```

**원칙**:
- Domain은 어떤 레이어에도 의존하지 않음
- Data는 Domain에만 의존
- Presentation은 Domain에만 의존
- UI는 Presentation과 Domain에 의존

---

## 테스트 전략

### 1. Domain Layer 테스트
```swift
// 순수 로직 테스트 - 의존성 없음
func testPatientValidation() {
    let patient = Patient(name: "John", age: 30, ...)
    XCTAssertTrue(patient.isValid)
}
```

### 2. Data Layer 테스트
```swift
// Repository 테스트 - Mock 사용
class MockRemoteDataSource: PatientRemoteDataSource {
    var mockData: [PatientDTO] = []
}

func testRepositoryFetch() async {
    let mockRemote = MockRemoteDataSource()
    let repository = PatientRepositoryImpl(
        localDataSource: mockLocal,
        remoteDataSource: mockRemote
    )
    let patients = try await repository.fetchAllPatients()
    XCTAssertEqual(patients.count, 3)
}
```

### 3. Presentation Layer 테스트
```swift
// ViewModel 테스트 - Repository Mock
@MainActor
func testLoadPatients() async {
    let mockRepository = MockPatientRepository()
    let viewModel = PatientListViewModel(repository: mockRepository)
    await viewModel.loadPatients()
    XCTAssertEqual(viewModel.patients.count, 5)
}
```

---

## 확장 가능성

### 1. Infrastructure 레이어 분리
```swift
// Shared/Infrastructure/
protocol CloudStorageService {
    func upload(_ data: Data) async throws
}

class CloudKitService: CloudStorageService { }
class FirebaseService: CloudStorageService { }
```

### 2. UseCase 추가
```swift
// Shared/Domain/UseCases/
struct FetchPatientsUseCase {
    private let repository: PatientRepository

    func execute() async throws -> [Patient] {
        let patients = try await repository.fetchAllPatients()
        return patients.filter { $0.isActive }
    }
}
```

### 3. DI Container
```swift
// Shared/Infrastructure/DIContainer.swift
class DIContainer {
    static let shared = DIContainer()

    func makePatientRepository() -> PatientRepository {
        PatientRepositoryImpl(
            localDataSource: makeLocalDataSource(),
            remoteDataSource: makeRemoteDataSource()
        )
    }
}
```

---

## 참고 자료

- [Clean Architecture (Uncle Bob)](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [CloudKit Documentation](https://developer.apple.com/documentation/cloudkit)
- [SOLID Principles](https://en.wikipedia.org/wiki/SOLID)

---

Last Updated: 2025-10-16
Version: 1.0
