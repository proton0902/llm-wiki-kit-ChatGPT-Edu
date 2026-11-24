#!/usr/bin/env bash
# LLM Wiki Kit 설치 스크립트 (macOS / Linux)
# 사용법:  curl -fsSL https://raw.githubusercontent.com/proton0902/llm-wiki-kit-ChatGPT-Edu/main/install.sh | bash
# 다른 폴더에 설치:  curl -fsSL .../install.sh | bash -s -- ~/Documents/MyWiki
set -euo pipefail

OWNER="proton0902"
REPO="llm-wiki-kit-ChatGPT-Edu"
BRANCH="main"
DEST="${1:-${LLM_WIKI_DIR:-$HOME/LLM-Wiki}}"

say()  { printf '%s\n' "$*"; }
fail() { printf '\n[설치 중단] %s\n' "$*" >&2; exit 1; }

say ""
say "LLM Wiki Kit 설치를 시작합니다."
say "설치 위치: $DEST"

# 1. 기존 폴더 보호: 비어 있지 않으면 덮어쓰지 않는다
if [ -e "$DEST" ] && [ -n "$(ls -A "$DEST" 2>/dev/null)" ]; then
  fail "'$DEST' 폴더가 이미 있고 비어 있지 않습니다. 다른 위치를 지정하세요.
  예) curl -fsSL https://raw.githubusercontent.com/$OWNER/$REPO/$BRANCH/install.sh | bash -s -- ~/LLM-Wiki-2"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# 2. 템플릿 받기 (git 없이 압축 파일로)
if [ -n "${LLM_WIKI_SRC:-}" ]; then
  SRC="$LLM_WIKI_SRC"            # 테스트용: 로컬 폴더에서 설치
else
  command -v curl >/dev/null || fail "curl이 필요합니다."
  curl -fsSL "https://codeload.github.com/$OWNER/$REPO/tar.gz/refs/heads/$BRANCH" -o "$TMP/kit.tgz" \
    || fail "템플릿을 내려받지 못했습니다. 인터넷 연결을 확인하세요."
  tar -xzf "$TMP/kit.tgz" -C "$TMP"
  SRC="$(find "$TMP" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
fi
[ -f "$SRC/AGENTS.md" ] || fail "템플릿 파일(AGENTS.md)을 찾지 못했습니다."

# 3. 복사 (설치용 파일은 빼고)
mkdir -p "$DEST"
( cd "$SRC" && tar --exclude='./install.sh' --exclude='./install.ps1' --exclude='./docs' \
    --exclude='./.git' --exclude='./.github' --exclude='./tests' -cf - . ) | ( cd "$DEST" && tar -xf - )

# 설치 날짜 기록
TODAY="$(date +%Y-%m-%d)"
if [ -f "$DEST/wiki/log.md" ]; then
  sed -i.bak "s/^- 설치 | install |/- $TODAY | install |/" "$DEST/wiki/log.md" && rm -f "$DEST/wiki/log.md.bak"
fi

# 4. 환경 점검 (설치는 하지 않고 안내만)
say ""
say "환경 점검"
if command -v python3 >/dev/null; then
  if python3 -c "import pypdf" 2>/dev/null || command -v pdftotext >/dev/null; then
    say "  [OK] PDF 읽기 도구"
  else
    say "  [권장] PDF 읽기 도구가 없습니다:  python3 -m pip install --user pypdf"
  fi
else
  say "  [권장] Python 3이 없습니다. PDF를 쪽 번호와 함께 읽으려면 설치하세요 (https://www.python.org)."
fi
if command -v codex >/dev/null; then
  say "  [OK] Codex CLI"
else
  say "  [안내] Codex CLI가 없습니다. ChatGPT 데스크톱 앱의 Codex나 VS Code 확장으로도 쓸 수 있습니다."
fi
if [ -d "/Applications/Obsidian.app" ] || command -v obsidian >/dev/null; then
  say "  [OK] Obsidian"
else
  say "  [선택] 위키를 그래프로 보려면 Obsidian을 설치하세요 (https://obsidian.md)."
fi

cat <<MSG

설치 완료: $DEST

다음 단계 (3분)
  1. 논문 PDF를 넣습니다:   $DEST/raw/papers/
  2. Codex에서 이 폴더를 엽니다.
       - ChatGPT 데스크톱 앱: Codex > 폴더 열기 > $DEST
       - 터미널:  cd "$DEST" && codex
     학교 계정(ChatGPT Edu)으로 로그인하세요.
  3. Codex에 입력합니다:
       \$wiki-setup     ← 내 연구 분야에 맞게 설정 (처음 한 번)
       \$wiki-ingest    ← raw에 넣은 논문 소화
     그다음엔 그냥 질문하면 됩니다.
  4. (선택) Obsidian > "폴더를 보관소로 열기" > $DEST

MSG

# macOS면 폴더를 바로 열어 준다
if [ "$(uname)" = "Darwin" ] && [ -z "${LLM_WIKI_NO_OPEN:-}" ]; then
  open "$DEST" 2>/dev/null || true
fi
