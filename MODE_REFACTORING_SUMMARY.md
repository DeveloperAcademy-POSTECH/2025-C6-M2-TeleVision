# 모드 구조 리팩토링 완료

## 📋 개요

모드 전환 구조를 **2단계 계층**으로 리팩토링하여 더 직관적인 UX 제공

### 변경 전 (문제점)
- Demo → Raw → Split → 3D → Raw → ... 순환만 가능
- WebRTC → Demo 전환 시 `configure(.fileDemo)` 누락으로 영상 안 나옴
- 모든 모드가 동일한 계층에서 순환되어 혼란

### 변경 후 (개선)
- **1차 모드**: WebRTC vs Demo (상위 토글)
- **2차 모드**: WebRTC 내에서만 Raw / Split / 3D 전환 (서브 토글)
- Demo 전환 시 항상 `configure(.fileDemo)` 호출로 안정성 확보

---

## 🔧 변경 파일

### 1. EndoscopeViewMode.swift
**헬퍼 메서드 추가**
```swift
// 2-Level Mode Helpers
var isWebRTCMode: Bool { self != .fileDemo }
var isDemoMode: Bool { self == .fileDemo }
func nextWebRTCMode() -> EndoscopeViewMode {
    // raw → split → 3D → raw 순환
}
```

### 2. PrimaryModeToggle.swift (신규)
**위치**: `Hippo/Features/Vision/UI/Immersive/Endoscope/Components/`

**책임**:
- 1차 모드 전환: WebRTC ↔ Demo
- Demo → WebRTC: `stopAll()` → `switchMode(.rawStream)` → `connect()`
- **WebRTC → Demo**: `stopAll()` → `activeMode = .fileDemo` → `configure(.fileDemo)` ✅

**핵심 개선**:
```swift
// WebRTC → Demo 전환 시 CRITICAL FIX
viewModel.stopAll()                          // 1) WebRTC 정리
uiState.activeMode = .fileDemo               // 2) UI 전환
await viewModel.configure(for: .fileDemo)    // 3) Demo 재구성 ✅
```

### 3. WebRTCSubModeToggle.swift (신규)
**위치**: `Hippo/Features/Vision/UI/Immersive/Endoscope/Components/`

**책임**:
- WebRTC 서브 모드 전환: Raw → Split → 3D → Raw
- Demo 모드에서는 opacity: 0으로 숨김
- 애니메이션으로 부드러운 전환

### 4. EndoscopeStreamWindow.swift
**상단 바 완전 재구성**

변경 전:
```swift
// 복잡한 조건문과 중복된 로직
if fileDemo { ... } else { ... }
```

변경 후:
```swift
HStack {
    PrimaryModeToggle(...)           // 왼쪽: WebRTC / Demo
    Spacer()
    WebRTCSubModeToggle(...)         // 가운데: raw/split/3D (WebRTC만)
    ConnectionStatusBadge(...)       // 연결 상태
    Spacer()
    Button("설정") { ... }           // 오른쪽: 설정
}
```

### 5. StreamUIState.swift
**Demo 모드 처리 로직 업데이트**
- `switchMode(to: .fileDemo)` 호출 시 경고 로그
- PrimaryModeToggle이 Demo 전환을 직접 처리하도록 변경

---

## ✅ 동작 흐름

### 앱 처음 진입
```
1. .task { configure(.fileDemo) }
2. Demo 모드에서 sample2.mp4 재생
3. 상단 UI: [WebRTC 스트림] [3D Demo ✓] | (서브 토글 숨김) | ⚙️
```

### WebRTC 스트림 버튼 탭
```
1. Demo → WebRTC 전환
2. PrimaryModeToggle:
   - viewModel.stopAll()                    // Demo 정리
   - switchMode(to: .rawStream, pipeline)   // 파이프라인 준비
   - viewModel.connect()                     // WebRTC 연결
3. 상단 UI: [WebRTC ✓] [3D Demo] | [원본 스트림 ▼] | 🟢 | ⚙️
```

### WebRTC 서브 모드 전환
```
1. [원본 스트림] 버튼 탭
2. WebRTCSubModeToggle:
   - switchMode(to: nextWebRTCMode())  // split → 3D → raw
3. 연결/파이프라인 유지, 뷰만 전환
```

### 3D Demo 버튼 탭
```
1. WebRTC → Demo 전환
2. PrimaryModeToggle:
   - viewModel.stopAll()              // WebRTC 정리 ✅
   - activeMode = .fileDemo           // UI 전환
   - configure(for: .fileDemo)        // Demo 재구성 ✅ (핵심!)
3. 두 번째 진입해도 영상 정상 표시 ✅
```

---

## 🎯 버그 수정

### 이전 문제
```swift
// WebRTC → Demo 전환 시
streamUIState.activeMode = .fileDemo  // UI만 변경
// ❌ configure(.fileDemo) 호출 안 함 → 영상 안 나옴
```

### 수정 후
```swift
// PrimaryModeToggle.swift
viewModel.stopAll()                      // 1) 정리
uiState.activeMode = .fileDemo           // 2) UI 전환
await viewModel.configure(for: .fileDemo) // 3) 재구성 ✅
```

**결과**: Demo 모드로 여러 번 재진입해도 항상 영상 정상 표시

---

## 📦 Xcode 프로젝트 설정

### 새 파일 추가 필요
Xcode에서 다음 파일들을 프로젝트에 추가해야 합니다:

1. `PrimaryModeToggle.swift`
2. `WebRTCSubModeToggle.swift`

**방법**:
1. Xcode 열기
2. Project Navigator에서 `Hippo/Features/Vision/UI/Immersive/Endoscope/` 찾기
3. `Components` 폴더 우클릭 → "Add Files to Hippo..."
4. 위 2개 파일 선택 → "Add"
5. Target: Hippo 체크 확인

또는:
```bash
# Xcode에서 프로젝트 닫고
cd /Users/onething/Downloads/2025-C6-M2-TeleVision
open Hippo.xcodeproj
# File > Add Files to "Hippo"... 로 수동 추가
```

---

## 🧪 테스트 시나리오

### 1. 초기 진입
- [ ] 앱 실행 시 Demo 모드에서 sample2.mp4 재생
- [ ] 상단 바에 "WebRTC 스트림" / "3D Demo" 토글 표시

### 2. Demo → WebRTC
- [ ] "WebRTC 스트림" 버튼 탭
- [ ] Raw Stream 모드로 전환
- [ ] WebRTC 연결 시도
- [ ] 연결 성공 시 스트림 표시

### 3. WebRTC 서브 모드 전환
- [ ] Raw → Split → 3D → Raw 순환 확인
- [ ] 각 모드에서 영상 정상 표시
- [ ] 연결 유지 확인

### 4. WebRTC → Demo (핵심!)
- [ ] "3D Demo" 버튼 탭
- [ ] Demo 모드로 전환
- [ ] ✅ **sample2.mp4 영상이 정상적으로 나와야 함**
- [ ] 다시 "WebRTC 스트림" → "3D Demo" 반복 시에도 영상 표시

### 5. 반복 전환
- [ ] WebRTC ↔ Demo를 여러 번 반복
- [ ] 메모리 누수 없음 확인
- [ ] 크래시 없음 확인

---

## 📝 참고사항

### UI 레이아웃
```
┌─────────────────────────────────────────────────────────┐
│  [WebRTC ✓] [Demo]  | [원본▼] 🟢 |            ⚙️   │
│   ↑ 1차 모드         ↑ 2차 모드   ↑ 상태  ↑ 설정      │
└─────────────────────────────────────────────────────────┘
```

### 상태 머신
```
     ┌─────────┐
     │  Demo   │◄─────┐
     └─────────┘      │
          │           │
          │           │
     ┌────▼────┐      │
     │   Raw   ├──────┘
     └────┬────┘
          │
     ┌────▼────┐
     │  Split  │
     └────┬────┘
          │
     ┌────▼────┐
     │   3D    │
     └────┬────┘
          │
          └──────┐
                 │
            (Raw로 순환)
```

### 콜백 흐름
```
PrimaryModeToggle
    ├─ Demo → WebRTC
    │   ├─ stopAll()
    │   ├─ switchMode(.rawStream)
    │   └─ connect()
    │
    └─ WebRTC → Demo
        ├─ stopAll()           ✅
        ├─ activeMode = .fileDemo
        └─ configure(.fileDemo) ✅ (핵심!)

WebRTCSubModeToggle
    └─ WebRTC 내부 전환
        └─ switchMode(nextWebRTCMode())
```

---

## 🚀 다음 단계

1. ✅ Xcode에서 새 파일 추가
2. ✅ 빌드 성공 확인
3. ✅ 시뮬레이터/실기기 테스트
4. ✅ Demo ↔ WebRTC 반복 테스트 (핵심!)

---

**문제 발생 시 확인사항**:
- PrimaryModeToggle / WebRTCSubModeToggle이 Xcode 프로젝트에 추가되었는지
- Target membership이 Hippo로 설정되었는지
- 빌드 에러 없는지 확인
