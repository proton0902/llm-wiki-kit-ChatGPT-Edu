---
type: guide
---
# Obsidian 사용법

Obsidian은 이 위키 폴더를 **읽기 좋게 보여 주는 무료 노트 앱**입니다. 위키를 쓰는 것은 Codex, 둘러보고 연결을 확인하는 것은 Obsidian이 맡습니다. Obsidian이 없어도 위키는 동작하지만, 있으면 논문과 개념이 어떻게 이어지는지 한눈에 보입니다.

## 1. 설치

| 운영체제 | 방법 |
| --- | --- |
| macOS | [obsidian.md/download](https://obsidian.md/download)에서 받아 응용 프로그램 폴더로 옮기기. Homebrew가 있으면 `brew install --cask obsidian` |
| Windows | [obsidian.md/download](https://obsidian.md/download)에서 설치 파일 실행. 또는 PowerShell에서 `winget install -e --id Obsidian.Obsidian` |
| Linux | [obsidian.md/download](https://obsidian.md/download)의 AppImage 또는 Flatpak |

설치 스크립트로 위키를 만들 때 Obsidian 질문에 "예"라고 답했다면 설치와 보관소 등록까지 자동으로 끝나 있습니다.

## 2. 위키를 보관소(vault)로 열기

1. Obsidian을 엽니다.
2. 첫 화면에서 **"폴더를 보관소로 열기"**(Open folder as vault)를 누릅니다.
3. 위키 폴더(기본 `LLM-Wiki` 또는 `Study-Wiki`)를 고릅니다.
4. 왼쪽에 `wiki`, `raw` 폴더가 보이면 성공입니다. **`wiki/index.md`부터 여세요.**

> 이 템플릿은 커뮤니티 플러그인을 쓰지 않습니다. "플러그인을 신뢰하시겠습니까?" 같은 창이 뜨면 기본(제한 모드)으로 두어도 됩니다.

## 3. 꼭 알아야 할 기능 6가지

| 기능 | 하는 법 (Windows는 Ctrl, macOS는 Cmd) | 언제 쓰나 |
| --- | --- | --- |
| 링크로 이동 | 보라색 `[[링크]]` 클릭. 뒤로 가기는 Ctrl+Alt+← | 논문·강의 → 개념 → 관련 페이지로 따라가기 |
| 빠른 열기 | Ctrl+O 후 페이지 이름 몇 글자 | 원하는 페이지 바로 열기 |
| 그래프 뷰 | Ctrl+G 또는 왼쪽 막대의 그래프 아이콘 | 위키 전체 연결 구조 보기 |
| 로컬 그래프 | 페이지를 연 상태에서 Ctrl+P → "로컬 그래프 열기" | 지금 페이지와 직접 연결된 것만 보기 |
| 백링크 | 오른쪽 사이드바의 "백링크" 탭 | 이 페이지를 가리키는 다른 페이지 찾기 |
| 전체 검색 | Ctrl+Shift+F | 단어, 태그(`tag:#energy-harvesting`), 폴더(`path:wiki/papers`)로 찾기 |

페이지 맨 위의 **속성(Properties)** 칸에는 연도·학회·주차·태그·숙련도 같은 정보가 표로 보입니다.

## 4. 그래프 색 범례

이 템플릿은 그래프 뷰 색이 미리 정해져 있습니다.

**연구자용**

| 색 | 폴더 |
| --- | --- |
| 보라 | `wiki/papers` 논문 |
| 청록 | `wiki/concepts` 개념 |
| 주황 | `wiki/groups` 연구 그룹 |
| 파랑 | `wiki/metrics` 지표·FoM |
| 빨강 | `wiki/questions` 열린 연구 질문 |
| 회색 | `wiki/answers` 저장한 답변 |

**학습용**

| 색 | 폴더 |
| --- | --- |
| 빨강 | `wiki/courses` 과목 |
| 파랑 | `wiki/lectures` 강의(주차) |
| 보라 | `wiki/chapters` 교재 |
| 청록 | `wiki/concepts` 개념 카드 |
| 주황 | `wiki/problems` 문제 |
| 회색 | `wiki/review` 복습·오답노트 |

그래프가 너무 복잡하면 그래프 오른쪽 위 설정에서 검색칸에 `path:wiki/concepts`처럼 입력해 일부만 보세요.

## 5. Codex와 함께 쓰는 법

- **쓰는 건 Codex, 보는 건 Obsidian**이 기본입니다. 위키 페이지를 직접 고쳐도 되지만, 고친 뒤에는 Codex에게 `$wiki-lint`를 한 번 시키면 링크와 출처가 맞는지 확인해 줍니다.
- **Codex가 작업 중일 때 같은 페이지를 Obsidian에서 고치지 마세요.** 한쪽 수정이 덮어써질 수 있습니다.
- **내 메모는 `raw/notes/`에** 쓰세요. Obsidian에서 새 노트를 만들면 기본으로 이 폴더에 생깁니다. 그다음 Codex에게 "notes에 쓴 메모 반영해줘"라고 하면 됩니다.
- `raw/`의 PDF는 Obsidian에서도 바로 열립니다. 위키의 출처 쪽 번호를 확인할 때 편합니다.
- Obsidian의 파일 이름 바꾸기는 링크를 자동으로 고쳐 줍니다(이 템플릿에서 켜 둠). 파일 탐색기나 Finder에서 이름을 바꾸면 링크가 깨지니 Obsidian 안에서 바꾸세요.

## 6. 자주 묻는 문제

| 증상 | 해결 |
| --- | --- |
| 링크를 눌렀는데 빈 페이지가 생김 | 아직 없는 페이지입니다. 새로 생긴 빈 파일은 지우고 Codex에게 `$wiki-lint` |
| 그래프에 점이 하나도 없음 | 아직 소화한 자료가 없습니다. Codex에서 `$wiki-ingest`를 먼저 하세요 |
| 수식이 깨져 보임 | Obsidian은 `$...$`, `$$...$$` 수식을 지원합니다. 깨진 곳은 Codex에게 "수식 표기 고쳐줘" |
| 다른 기기에서도 보고 싶음 | 폴더를 iCloud·OneDrive 등으로 동기화하거나 Obsidian Sync(유료)를 쓰세요. 미발표 연구나 강의자료가 클라우드에 올라간다는 점을 먼저 고려하세요 |
