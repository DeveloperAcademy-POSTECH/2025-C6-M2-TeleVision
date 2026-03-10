# HIPPO Legacy — Linear 프로젝트 기획서

> **프로젝트명**: HIPPO Legacy
> **Fork 명칭**: HIPPO Lingo
> **원본 리포지토리**: `DeveloperAcademy-POSTECH/2025-C6-M2-TeleVision`
> **대상 플랫폼**: visionOS (Apple Vision Pro) + macOS (Companion App)
> **목적**: 내시경 비전프로 프로젝트를 의료 프로젝트의 공통 기반(Legacy)으로 재구축

---

## 1. 프로젝트 개요

### 1.1 배경

Hippo는 Apple Vision Pro 기반 수술실 내시경 스트리밍 플랫폼이다. WebRTC를 통해 Mac에서 Vision Pro로 실시간 내시경 영상을 전송하고, 3D 모델 오버레이, 음성 제어, 수술 기록 등을 지원한다.

HIPPO Legacy 프로젝트는 이 코드베이스를 분석하여 **다른 의료 프로젝트의 기반 프레임워크**로 발전시키는 것을 목표로 한다. 새로운 코드는 `HIPPO Lingo` fork에서 개발한다.

### 1.2 핵심 가치

| 가치 | 설명 |
|------|------|
| **재사용성** | 의료 영상 스트리밍의 공통 모듈화 |
| **확장성** | 내시경 외 다른 의료 장비 지원 가능 |
| **안정성** | WebRTC 재연결, 오프라인 퍼스트 아키텍처 |
| **규격 준수** | HIPAA 대응 가능한 데이터 레이어 설계 |

---

## 2. 원본 리포지토리 브랜치 분석

### 2.1 브랜치 현황 요약

| 분류 | 총 브랜치 | Merged | Unmerged |
|------|:---------:|:------:|:--------:|
| 전체 | 18 | 13 | 5 |

### 2.2 Merged 브랜치 (develop에 통합 완료)

이 브랜치들의 작업은 이미 `develop`에 반영되었다.

| 브랜치 | 카테고리 | 주요 변경사항 |
|--------|----------|---------------|
| `feat/#201-server` | Feature | Mac 앱 내장 시그널링 서버, Bonjour 탐색, WebRTC 재연결 |
| `feature/#195-2d-video` | Feature | 2D 영상 재생 모드 추가 |
| `feature/demo-image-mode` | Feature | 이미지 모드, 3D 데모 루프, bird-demo 추가 |
| `feature/#107-HomeView-UI-HiFi` | Feature | HomeView Hi-Fi UI |
| `enhance/#190-Mac-HiFi-UI` | Enhancement | Mac 환자 리스트 UI 개선, 스트리밍 컨트롤 |
| `enhance/panel-position` | Enhancement | 패널 위치 조정 |
| `modify/#199-showcase` | Modification | 영상 윈도우 크기 조정, 음성 인식 타임아웃 조정 |
| `bug/#193-mode` | Bug Fix | 모드 전환시 영상 미표시 이슈 수정 |
| `fix/#161-fix-EndoscopeStreamWindow` | Bug Fix | 내시경 스트림 윈도우 수정 |
| `fix/#172-OpeartionAsset-Update&Delete` | Bug Fix | 수술 에셋 업데이트/삭제 |
| `fix/SurgeryMenuBar-Button-fix` | Bug Fix | 수술 메뉴바 버튼 수정 |
| `refactor/#170-head-controller` | Refactor | 헤드 컨트롤러 리팩토링 |
| `main` | Release | develop보다 361 커밋 뒤처짐 (사실상 미사용) |

### 2.3 Unmerged 브랜치 (미통합 작업)

#### `Design/#133-headAnchorLottie` — 4 commits ahead
- **분류**: Design
- **내용**: 헤드 앵커 Lottie 애니메이션 에셋 및 컴포넌트
- **평가**: 소규모 독립 작업, 충돌 위험 낮음
- **Legacy 활용**: 의료 시각화에서 애니메이션 피드백 패턴으로 재사용 가능

#### `feat/#119-change-OpacityControlPanel-UI` — 5 commits ahead
- **분류**: Feature
- **내용**: OpacityControlPanel UI 리워크, Window→Sheet 전환, EntitySettingPanel 도입
- **평가**: UI 아키텍처 개선, 충돌 위험 중간
- **Legacy 활용**: 패널 기반 설정 UI 패턴의 표준화

#### `feat/#204-Enterprise-API` — 1 commit ahead
- **분류**: Feature
- **내용**: Apple Enterprise API를 통한 화면 녹화 기능
- **평가**: 최소 변경, 독립적
- **Legacy 활용**: 의료 기록/녹화 기능의 핵심 모듈

#### `hotfix/demo` — 351 commits ahead, 366 behind
- **분류**: Hotfix / 병렬 개발 라인
- **내용**: 전체 프로젝트 기능의 병렬 구현 (CloudKit, 음성제어, 녹화, 스트리밍, 3D 모델, UI 전체)
- **평가**: develop과 극심한 분기, 머지 불가에 가까움
- **Legacy 활용**: Cherry-pick으로 개별 기능 추출 필요

#### `vip` — 2 commits ahead
- **분류**: Presentation
- **내용**: 데모 기본값을 2D standard로 설정
- **평가**: develop의 얇은 오버레이
- **Legacy 활용**: 환경별 기본 설정 패턴

---

## 3. 아키텍처 분석

### 3.1 현재 아키텍처: Clean Architecture

```
┌──────────────────────────────────────────────┐
│                  UI Layer                     │
│         (SwiftUI - visionOS / macOS)          │
├──────────────────────────────────────────────┤
│             Presentation Layer                │
│          (ViewModels + State)                 │
├──────────────────────────────────────────────┤
│              Domain Layer                     │
│      (Entities, Protocols, UseCases)          │
├──────────────────────────────────────────────┤
│               Data Layer                      │
│      (Repository Impl, DataSources)           │
├──────────────────────────────────────────────┤
│            Infrastructure                     │
│   (SignalingClient, Bonjour, CoreVideo)        │
└──────────────────────────────────────────────┘
```

### 3.2 핵심 기술 스택

| 기술 | 용도 | 상태 |
|------|------|------|
| **LiveKitWebRTC** | P2P 영상 스트리밍 | 안정 |
| **Node.js + ws** | WebSocket 시그널링 서버 | 안정 |
| **Bonjour/mDNS** | 로컬 네트워크 자동 탐색 | 안정 |
| **SwiftData** | 로컬 데이터 영속화 | Phase 3 진행 중 |
| **CloudKit** | iCloud 동기화 | Phase 2 계획됨 |
| **RealityKit** | 3D 모델 렌더링 | 안정 |
| **Speech Framework** | 음성 인식/제어 | 안정 |
| **AVFoundation** | 비디오 캡처/렌더링 | 안정 |

### 3.3 구현 완료 상태

| Phase | 내용 | 상태 |
|-------|------|------|
| Phase 1 | JSON 로컬 저장소 | 완료 |
| Phase 2 | CloudKit 동기화 | 가이드 문서화, 미구현 |
| Phase 3 | SwiftData 마이그레이션 | 시작됨 |

### 3.4 아키텍처 강점

1. **Clean Architecture**: Domain/Data/Presentation 명확 분리
2. **Offline-First**: 로컬 우선 → 백그라운드 동기화
3. **Actor 기반 동시성**: `PatientRepositoryImpl`이 actor로 스레드 안전
4. **DI 컨테이너**: 구현체 교체 용이
5. **크로스 플랫폼**: Shared 로직 + 플랫폼별 UI

### 3.5 개선 필요 사항

1. **테스트 부재**: `HippoTests/` 파일 존재하나 내용 비어 있음
2. **CI/CD 미구축**: GitHub Actions 워크플로우 없음
3. **main 브랜치 방치**: develop과 361 커밋 차이
4. **hotfix/demo 분기**: 병렬 개발 라인 정리 필요
5. **문서 한국어 혼재**: 영어/한국어 코멘트 혼합

---

## 4. 기능 모듈 분석

### 4.1 WebRTC 스트리밍

```
Mac (Sender) ←→ SignalingServer (Node.js) ←→ Vision Pro (Receiver)
                      ↕
              Bonjour mDNS 자동 탐색
```

**지원 모드**:
- `rawStream` — 단일 영상 표시
- `splitSBS` — Side-by-Side 좌우 분할
- `stereo3D` — 스테레오 3D VideoPlayerComponent
- `fileDemo` — SBS 데모 파일 재생
- `fileDemo2D` — 2D 데모 재생
- `fileImage` — 정지 이미지 표시

**재연결 정책**: 지수 백오프 (최대 5회, 15초 keepalive)

### 4.2 음성 제어

- **웨이크 워드**: "Hippo"
- **명령**: 메뉴 열기/닫기, 비디오 표시/숨기기, 3D 회전
- **파싱**: RuleBasedCommandParser (현재) / LLMCommandParser (계획)
- **피드백**: 실시간 트랜스크립션 오버레이

### 4.3 3D 모델 관리

- RealityKit 기반 Immersive Space 렌더링
- 모델 투명도 제어 (OpacityControlPanel)
- 에셋 파일 형식: `.usdz`, `.usdc`, `.glb`
- 수술별 다중 에셋 연결

### 4.4 환자/수술 데이터

- 환자 CRUD (생성/조회/수정/삭제)
- 수술 관리 (오늘의 수술, 에셋, 녹화)
- SwiftData 영속화 + CloudKit 동기화 (계획)

### 4.5 Mac 컴패니언 앱

- 환자 로스터 관리
- 수술 상세 편집
- 스트리밍 제어 (Start/Stop)
- 내장 시그널링 서버

---

## 5. HIPPO Lingo Fork 전략

### 5.1 Fork 구조

```
원본: DeveloperAcademy-POSTECH/2025-C6-M2-TeleVision (develop)
  └→ Fork: HIPPO Lingo
      ├── main (안정 릴리스)
      ├── develop (개발 통합)
      └── feature/* (기능별 브랜치)
```

### 5.2 초기 Fork 시 포함할 작업

1. **develop 브랜치 기준으로 fork**
2. 미머지 브랜치 중 채택:
   - `feat/#204-Enterprise-API` (화면 녹화) → 즉시 머지
   - `feat/#119-change-OpacityControlPanel-UI` (UI 개선) → 리뷰 후 머지
   - `Design/#133-headAnchorLottie` (애니메이션) → 선택적 머지
3. `hotfix/demo` → Cherry-pick 대상 선별 (CloudKit, 녹화 기능 등)
4. `main` 브랜치 → develop과 동기화

---

## 6. Linear 프로젝트: Epic & Issue 설계

### Epic 1: Foundation — 프로젝트 기반 구축

| ID | Issue | Priority | Estimate |
|----|-------|:--------:|:--------:|
| HIP-1 | Fork 생성 및 브랜치 전략 수립 | Urgent | 1d |
| HIP-2 | main/develop 브랜치 동기화 | Urgent | 0.5d |
| HIP-3 | 미머지 브랜치 평가 및 선별 머지 | High | 2d |
| HIP-4 | hotfix/demo 브랜치 cherry-pick 대상 목록 작성 | High | 1d |
| HIP-5 | CI/CD 파이프라인 구축 (GitHub Actions) | High | 2d |
| HIP-6 | 프로젝트 README 및 Contributing Guide 작성 | Medium | 1d |

### Epic 2: Modularization — 공통 모듈 추출

| ID | Issue | Priority | Estimate |
|----|-------|:--------:|:--------:|
| HIP-10 | Core Streaming 모듈 분리 (WebRTC + Signaling) | Urgent | 3d |
| HIP-11 | Core Networking 모듈 분리 (Bonjour + Reconnection) | High | 2d |
| HIP-12 | Core Data 모듈 분리 (Repository + DataSource 패턴) | High | 2d |
| HIP-13 | Core Voice 모듈 분리 (Speech + Command) | Medium | 2d |
| HIP-14 | Core 3D 모듈 분리 (RealityKit Rendering) | Medium | 2d |
| HIP-15 | Swift Package 구조로 모듈 재구성 | High | 3d |
| HIP-16 | 모듈 간 의존성 그래프 문서화 | Medium | 1d |

### Epic 3: Quality — 코드 품질 및 테스트

| ID | Issue | Priority | Estimate |
|----|-------|:--------:|:--------:|
| HIP-20 | Domain Layer 유닛 테스트 작성 | High | 3d |
| HIP-21 | Data Layer Mock Repository 테스트 | High | 2d |
| HIP-22 | ViewModel 테스트 (Presentation Layer) | Medium | 2d |
| HIP-23 | WebRTC 연결 라이프사이클 통합 테스트 | Medium | 2d |
| HIP-24 | SwiftLint/SwiftFormat 설정 및 적용 | Medium | 1d |
| HIP-25 | 코드 문서화 (DocC) 기반 구축 | Low | 2d |

### Epic 4: Data Layer 완성 — CloudKit & SwiftData

| ID | Issue | Priority | Estimate |
|----|-------|:--------:|:--------:|
| HIP-30 | SwiftData 마이그레이션 완료 (Phase 3) | High | 3d |
| HIP-31 | CloudKit 스키마 설계 및 Record 매핑 | High | 2d |
| HIP-32 | PatientRemoteDataSourceCloudKit 구현 | High | 3d |
| HIP-33 | 충돌 해결 전략 구현 (Last-Write-Wins) | Medium | 2d |
| HIP-34 | 네트워크 상태 모니터링 및 자동 동기화 | Medium | 2d |
| HIP-35 | HIPAA 대응 데이터 암호화 레이어 설계 | High | 3d |

### Epic 5: Streaming Enhancement — 스트리밍 고도화

| ID | Issue | Priority | Estimate |
|----|-------|:--------:|:--------:|
| HIP-40 | Enterprise API 화면 녹화 통합 | High | 2d |
| HIP-41 | 시그널링 서버 이중화 / 복원력 강화 | Medium | 3d |
| HIP-42 | 다중 스트림 지원 (멀티 카메라) | Medium | 5d |
| HIP-43 | 스트리밍 품질 적응형 제어 (ABR) | Low | 3d |
| HIP-44 | 녹화 영상 인라인 주석 기능 | Low | 3d |

### Epic 6: UX & Accessibility — 사용성 개선

| ID | Issue | Priority | Estimate |
|----|-------|:--------:|:--------:|
| HIP-50 | OpacityControlPanel UI 리팩토링 머지 | Medium | 1d |
| HIP-51 | 헤드 앵커 Lottie 애니메이션 통합 | Low | 1d |
| HIP-52 | LLM 기반 음성 명령 파서 구현 | Medium | 5d |
| HIP-53 | 수술실 환경 최적화 (장갑, 조명) | Medium | 3d |
| HIP-54 | 다국어 음성 명령 지원 (한/영) | Low | 3d |

### Epic 7: Platform Expansion — 플랫폼 확장

| ID | Issue | Priority | Estimate |
|----|-------|:--------:|:--------:|
| HIP-60 | 웹 대시보드 설계 (병원 시스템 연동) | Low | 5d |
| HIP-61 | iPad 컴패니언 앱 프로토타입 | Low | 5d |
| HIP-62 | 내시경 외 의료 장비 어댑터 인터페이스 설계 | Medium | 3d |
| HIP-63 | FHIR/HL7 의료 데이터 표준 연동 조사 | Low | 2d |

---

## 7. 마일스톤 & 로드맵

### Phase A: Legacy 기반 확보 (2~3주)
- Epic 1 (Foundation) 완료
- Epic 3 (Quality) 테스트 기반 구축
- Fork 안정화 및 CI/CD

### Phase B: 모듈화 (3~4주)
- Epic 2 (Modularization) 완료
- Swift Package 기반 모듈 구조 전환
- 모듈별 독립 테스트

### Phase C: 데이터 완성 (2~3주)
- Epic 4 (Data Layer) CloudKit + SwiftData
- HIPAA 대응 설계

### Phase D: 고도화 (4~6주)
- Epic 5 (Streaming Enhancement)
- Epic 6 (UX & Accessibility)

### Phase E: 확장 (계속)
- Epic 7 (Platform Expansion)
- 다른 의료 프로젝트에 모듈 제공

---

## 8. 기술 부채 & 리스크

### 기술 부채

| 항목 | 심각도 | 설명 |
|------|:------:|------|
| 테스트 전무 | High | 모든 테스트 파일이 비어 있음 |
| hotfix/demo 분기 | High | 351 커밋 분기된 병렬 개발 라인 |
| main 브랜치 방치 | Medium | develop과 361 커밋 차이 |
| CI/CD 부재 | Medium | 빌드 검증 자동화 없음 |
| CloudKit 미구현 | Medium | 가이드만 존재, 실제 구현 없음 |
| 한/영 코멘트 혼재 | Low | 일관성 부족 |

### 리스크

| 리스크 | 영향 | 대응 |
|--------|------|------|
| hotfix/demo cherry-pick 충돌 | 높음 | 기능별 격리 후 개별 cherry-pick |
| visionOS SDK 변경 | 중간 | 연 1회 WWDC 대응 계획 |
| WebRTC 라이브러리 업데이트 | 중간 | LiveKitWebRTC 버전 고정 후 점진적 업그레이드 |
| HIPAA 규제 요구사항 | 높음 | 초기부터 암호화 레이어 설계 |
| Enterprise API 접근 제한 | 중간 | Apple 승인 프로세스 선행 |

---

## 9. 팀 구성 권장

| 역할 | 인원 | 담당 영역 |
|------|:----:|-----------|
| iOS/visionOS Lead | 1 | 모듈화, 아키텍처 설계 |
| iOS Developer | 1~2 | UI, 기능 구현, 테스트 |
| Backend Developer | 1 | 시그널링 서버, CloudKit |
| QA Engineer | 1 | 테스트 자동화, 수술실 환경 테스트 |

---

## 10. 참고 문서

| 문서 | 경로 |
|------|------|
| 아키텍처 설계서 | `ARCHITECTURE.md` |
| CloudKit 구현 가이드 | `CLOUDKIT_IMPLEMENTATION_GUIDE.md` |
| 모드 리팩토링 요약 | `MODE_REFACTORING_SUMMARY.md` |
| 시그널링 서버 사용법 | `SignalingServer/README.md`, `SignalingServer/USAGE.md` |
| PR 템플릿 | `.github/pull_request_template.md` |
| 이슈 템플릿 | `.github/ISSUE_TEMPLATE/` |

---

*이 기획서는 `DeveloperAcademy-POSTECH/2025-C6-M2-TeleVision` 리포지토리의 `develop` 브랜치(b523107) 기준으로 작성되었습니다.*
*HIPPO Lingo fork에서의 개발은 이 기획서의 Epic/Issue 체계를 따릅니다.*
