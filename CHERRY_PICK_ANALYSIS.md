# hotfix/demo 브랜치 Cherry-Pick 분석

> **Linear Issue**: ACA-128
> **분석 일자**: 2026-03-12
> **분석 대상**: `hotfix/demo` 브랜치 (vs `develop`)

---

## 1. 브랜치 개요

| 항목 | 값 |
|------|-----|
| 총 커밋 수 | 351 |
| 머지 커밋 | 107 |
| 실제 패치 커밋 | 244 |
| patch-id 생성 가능 | 243 |
| develop와 중복 | 241 |
| **고유 패치** | **2** |

## 2. 분석 방법

`git patch-id --stable`을 사용하여 두 브랜치의 실제 diff 내용을 비교했습니다.
커밋 메시지나 해시가 아닌 **코드 변경 내용 자체**를 기준으로 중복 여부를 판단합니다.

```bash
# 각 브랜치의 patch-id 생성
git log origin/hotfix/demo --no-merges --format="%H" | while read hash; do
  git diff-tree -p "$hash" | git patch-id --stable
done > hotfix_patchids.txt

git log origin/develop --no-merges --format="%H" | while read hash; do
  git diff-tree -p "$hash" | git patch-id --stable
done > develop_patchids.txt

# hotfix/demo에만 존재하는 patch-id 필터링
```

## 3. 커밋 분류 (전체 351건)

| 카테고리 | 커밋 수 | 비율 |
|----------|:-------:|:----:|
| Patient Data (환자 데이터) | 79 | 22.5% |
| 3D Model (공간 모델) | 46 | 13.1% |
| UI/UX | 38 | 10.8% |
| Bug Fix | 34 | 9.7% |
| Refactoring | 23 | 6.6% |
| Other | 22 | 6.3% |
| Streaming/WebRTC | 18 | 5.1% |
| Merge Commits | 18 | 5.1% |
| Feature (General) | 16 | 4.6% |
| Mac App | 15 | 4.3% |
| Voice Control | 14 | 4.0% |
| Video Pipeline | 12 | 3.4% |
| Recording | 4 | 1.1% |
| Mode/Demo | 4 | 1.1% |
| CloudKit | 3 | 0.9% |
| Config/Build | 3 | 0.9% |
| Test | 2 | 0.6% |

## 4. 고유 패치 상세 (Cherry-Pick 후보)

### 4.1 `b1d27fe` — 2D 영상 재생 모드 추가

```
feat: #195 2D 영상 재생 모드 추가 및 기본값 설정
Author: OneThing <freesky111@naver.com>
Date:   2025-11-25
Files:  12 files changed, +369, -71
```

**주요 변경 사항:**
- `fileDemo2D` 모드 추가 (demo-2d.mp4 기반, AVPlayer + VideoMaterial)
- 기존 3D Demo 모드와 별도의 2D 데모 재생 경로
- `PrimaryModeToggle`에 [WebRTC] [2D Demo] [3D Demo] 3개 버튼 추가
- `FileDemo2DView` 신규 생성 (파이프라인 우회, 단순 2D 재생)
- `EndoscopeViewMode`에 `renderConfig` 프로퍼티 추가
- 44MB `demo-2d.mp4` 리소스 포함

**변경 파일:**
- `Hippo.xcodeproj/project.pbxproj`
- `HippoVisionApp.swift`
- `EndoscopeRenderPipeline.swift`
- `PrimaryModeToggle.swift`
- `WebRTCSubModeToggle.swift`
- `EndoscopeStreamView.swift`
- `EndoscopeStreamWindow.swift`
- `EndoscopeViewMode.swift`
- `ModeViews/FileDemo2DView.swift` *(신규)*
- `StreamUIState.swift`
- `RecordingPlayerView.swift`
- `Resources/demo-2d.mp4` *(신규, 44MB)*

### 4.2 `0999388` — Vision 3D Demo 모드 추가

```
feat: Vision 3D Demo 모드 추가 및 스트리밍 설정 개선
Author: OneThing <freesky111@naver.com>
Date:   2025-11-23
Files:  21 files changed, +1303, -72
```

**주요 변경 사항:**
- 파일 기반 3D Demo 모드 (endoscope-demo.mp4 이용)
- `FilePlayback` 파이프라인 구현 (`FileDemoFrameSource`, `SerialProcessor`)
- WebRTC 연결 없이 독립적 3D 영상 재생
- WebRTC ↔ Demo 모드 간 실시간 전환 지원
- VideoPlayer 초기화 순서 최적화 (모드 전환 시 영상 누락 해결)
- UI 컴포넌트 구조 개선 (Components, ModeViews 폴더 분리)
- Mac 기본 비트레이트 15Mbps로 변경
- `MODE_REFACTORING_SUMMARY.md` 문서 생성

**변경 파일:**
- `Hippo.xcodeproj/project.pbxproj`
- `ScalingSectionView.swift`, `StreamingControlViewModel.swift`
- `EndoscopeFrameSource.swift` *(신규 프로토콜)*
- `FileDemoFrameSource.swift` *(신규)*
- `SerialProcessor.swift` *(신규, 267 LOC)*
- `WebRTCReceiver.swift`
- `EndoscopeRenderPipeline.swift`
- `StereoVideoPlayer.swift`
- `ConnectionOverlay.swift` (폴더 이동)
- `PrimaryModeToggle.swift` *(신규, 122 LOC)*
- `WebRTCSubModeToggle.swift` *(신규, 70 LOC)*
- `EndoscopeStreamView.swift`, `EndoscopeStreamViewModel.swift` *(신규)*
- `EndoscopeStreamWindow.swift`, `EndoscopeViewMode.swift`
- `RawStreamView.swift`, `SplitSBSView.swift`, `Stereo3DView.swift` (폴더 이동)
- `StreamUIState.swift`
- `MODE_REFACTORING_SUMMARY.md` *(신규)*

## 5. 결론 및 권고

### 핵심 결론

`hotfix/demo`는 `develop`와 **거의 동일한 코드 변경을 포함**하는 병렬 개발 라인입니다.

- 243개 패치 중 **241개(99.2%)**가 develop에 이미 존재
- **단 2개(0.8%)**만이 고유한 변경사항
- 두 브랜치는 공통 merge-base가 없어, 직접 merge는 불가능

### Cherry-Pick 권고

| 커밋 | 권고 | 이유 |
|------|------|------|
| `b1d27fe` (2D Demo) | ⚠️ **검토 후 결정** | 2D 데모 기능은 유용하나, 44MB 바이너리 포함. develop의 현재 코드와 충돌 가능성 높음 |
| `0999388` (3D Demo) | ⚠️ **검토 후 결정** | 3D Demo + FilePlayback 파이프라인은 이미 develop에 유사 구현 존재. 구조 개선(폴더 분리)은 develop에서 이미 반영됨 |

### 최종 권고

> **cherry-pick 대신 기능 재구현을 권장합니다.**
>
> 두 고유 패치 모두 develop의 현재 코드베이스와 상당한 충돌이 예상되며,
> 새로운 이슈(ACA-164~173 Stereo Video Pipeline)에서
> 2D/3D 데모 모드를 클린 아키텍처에 맞게 재설계하는 것이 더 효율적입니다.

### `hotfix/demo` 브랜치 처리

- **보존**: 참조용으로 원격 브랜치 유지 (읽기 전용)
- **주의**: 직접 merge/cherry-pick 시도 금지
- **향후**: Stereo Video Pipeline 이슈 완료 후 삭제 검토

---

*이 문서는 ACA-128 (hotfix/demo 브랜치 cherry-pick 대상 목록 작성)의 일부로 작성되었습니다.*
