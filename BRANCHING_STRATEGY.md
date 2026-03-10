# HIPPO Lingo — 브랜치 전략

> **Fork**: [lingostar/HIPPO-Lingo](https://github.com/lingostar/HIPPO-Lingo)
> **Upstream**: [DeveloperAcademy-POSTECH/2025-C6-M2-TeleVision](https://github.com/DeveloperAcademy-POSTECH/2025-C6-M2-TeleVision)

---

## 1. Remote 구조

```
origin   → lingostar/HIPPO-Lingo          (Fork — 작업 공간)
upstream → DeveloperAcademy-POSTECH/...    (원본 — 읽기 전용 참조)
```

## 2. 핵심 브랜치

| 브랜치 | 역할 | 보호 규칙 |
|--------|------|-----------|
| `main` | 안정 릴리스 (태그 기준) | PR 필수, 리뷰 1명 이상, CI 통과 |
| `develop` | 개발 통합 라인 | PR 필수, CI 통과 |

## 3. 브랜치 네이밍 컨벤션

### 형식

```
<type>/<linear-id>-<short-description>
```

### 타입 목록

| Type | 용도 | 예시 |
|------|------|------|
| `feat/` | 새로운 기능 | `feat/ACA-131-core-streaming-module` |
| `fix/` | 버그 수정 | `fix/ACA-141-webrtc-reconnection` |
| `refactor/` | 리팩토링 | `refactor/ACA-136-swift-package` |
| `enhance/` | 기존 기능 개선 | `enhance/ACA-155-opacity-panel-ui` |
| `test/` | 테스트 추가 | `test/ACA-138-domain-unit-tests` |
| `docs/` | 문서 작업 | `docs/ACA-130-readme-contributing` |
| `chore/` | 빌드/설정/CI | `chore/ACA-129-github-actions` |
| `design/` | UI/UX 디자인 변경 | `design/ACA-156-lottie-animation` |
| `hotfix/` | 긴급 수정 (main 기반) | `hotfix/critical-crash-fix` |

### 규칙

- 소문자 + 케밥 케이스 (`kebab-case`)
- Linear 이슈 ID 포함 (추적 용이)
- 설명은 3~5 단어 이내
- 한글 금지 (Git 호환성)

## 4. 워크플로우

### 일반 기능 개발

```
develop → feat/ACA-xxx-description → PR → develop
```

1. `develop`에서 브랜치 생성
2. 작업 후 커밋 (Conventional Commits)
3. `develop`으로 PR 생성
4. 코드 리뷰 + CI 통과
5. Squash Merge

### 릴리스

```
develop → main (태그: v0.x.x)
```

1. `develop`이 안정 상태 확인
2. `main`으로 PR 생성
3. 머지 후 태그 (`v0.2.0` 등)

### 핫픽스

```
main → hotfix/description → PR → main + develop
```

1. `main`에서 `hotfix/` 브랜치 생성
2. 수정 후 `main`과 `develop` 양쪽에 머지

## 5. 커밋 메시지 컨벤션

[Conventional Commits](https://www.conventionalcommits.org/) 기반:

```
<type>(<scope>): <description>

[optional body]

[optional footer: ACA-xxx]
```

### 타입

| 타입 | 설명 |
|------|------|
| `feat` | 새 기능 추가 |
| `fix` | 버그 수정 |
| `refactor` | 코드 리팩토링 (기능 변경 없음) |
| `test` | 테스트 추가/수정 |
| `docs` | 문서 변경 |
| `chore` | 빌드/설정 변경 |
| `style` | 코드 포맷팅 (기능 변경 없음) |
| `perf` | 성능 개선 |

### 스코프 (선택)

`streaming`, `voice`, `data`, `ui`, `server`, `3d`, `mac`, `vision`

### 예시

```
feat(streaming): add multi-camera WebRTC support

Implements multiple PeerConnection management for
simultaneous video streams from different cameras.

ACA-152
```

## 6. PR 규칙

### 머지 전략

- **develop 머지**: Squash Merge (커밋 히스토리 깔끔하게)
- **main 머지**: Merge Commit (릴리스 히스토리 보존)

### PR 크기 가이드

| 크기 | 변경 파일 수 | 권장 |
|------|:-----------:|------|
| Small | 1~5 | 즉시 리뷰 |
| Medium | 6~15 | 1일 내 리뷰 |
| Large | 16+ | 분할 검토 |

## 7. Upstream 동기화

원본 리포의 변경사항을 주기적으로 반영:

```bash
# upstream 최신 가져오기
git fetch upstream

# develop에 머지
git checkout develop
git merge upstream/develop

# fork에 푸시
git push origin develop
```

---

*이 전략은 HIPPO Legacy 프로젝트(ACA-125)의 일부로 작성되었습니다.*
