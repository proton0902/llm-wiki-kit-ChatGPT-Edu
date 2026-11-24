#!/usr/bin/env bash
# LLM Wiki Kit 설치 스크립트 (macOS / Linux)
#
#   연구자용:  curl -fsSL https://raw.githubusercontent.com/proton0902/llm-wiki-kit-ChatGPT-Edu/main/install.sh | bash
#   학습용:    curl -fsSL https://raw.githubusercontent.com/proton0902/llm-wiki-kit-ChatGPT-Edu/main/install.sh | bash -s -- --study
#
# 옵션:  --research | --study      어떤 판을 설치할지 (안 쓰면 물어봄, 물어볼 수 없으면 연구자용)
#        --with-obsidian           Obsidian 설치(가능하면)와 보관소 등록까지
#        --no-obsidian             Obsidian 관련 질문 생략
#        경로                       설치 위치 (기본: ~/LLM-Wiki 또는 ~/Study-Wiki)
set -euo pipefail

OWNER="proton0902"
REPO="llm-wiki-kit-ChatGPT-Edu"
BRANCH="main"
RAW_URL="https://raw.githubusercontent.com/$OWNER/$REPO/$BRANCH/install.sh"

EDITION="${LLM_WIKI_EDITION:-}"
OBSIDIAN="${LLM_WIKI_OBSIDIAN:-}"
DEST="${LLM_WIKI_DIR:-}"
for arg in "$@"; do
  case "$arg" in
    --study) EDITION="study" ;;
    --research) EDITION="research" ;;
    --with-obsidian) OBSIDIAN="yes" ;;
    --no-obsidian) OBSIDIAN="no" ;;
    -*) printf '알 수 없는 옵션: %s\n' "$arg" >&2; exit 1 ;;
    *) DEST="$arg" ;;
  esac
done

say()  { printf '%s\n' "$*"; }
fail() { printf '\n[설치 중단] %s\n' "$*" >&2; exit 1; }
# curl | bash 로 실행해도 키보드 입력을 받을 수 있으면 물어본다
ask()  {
  local prompt="$1" default="$2" ans=""
  if [ -r /dev/tty ] && [ -z "${LLM_WIKI_NONINTERACTIVE:-}" ]; then
    printf '%s' "$prompt" > /dev/tty
    read -r ans < /dev/tty || ans=""
  fi
  printf '%s' "${ans:-$default}"
}

say ""
say "LLM Wiki Kit 설치를 시작합니다."

if [ -z "$EDITION" ]; then
  say ""
  say "  1) 연구자용 - 논문 정리, 선행연구 비교, 연구 동향"
  say "  2) 학습용   - 강의자료·교재 정리, 개념 카드, 퀴즈, 시험 대비"
  case "$(ask '어떤 판을 설치할까요? [1/2, 기본 1]: ' 1)" in
    2|s|study|학습*) EDITION="study" ;;
    *) EDITION="research" ;;
  esac
fi
case "$EDITION" in research|study) ;; *) fail "판 이름은 research 또는 study 입니다." ;; esac
if [ "$EDITION" = "study" ]; then LABEL="학습용"; DEFAULT_DEST="$HOME/Study-Wiki"; else LABEL="연구자용"; DEFAULT_DEST="$HOME/LLM-Wiki"; fi
DEST="${DEST:-$DEFAULT_DEST}"
case "$DEST" in "~"*) DEST="$HOME${DEST#\~}" ;; esac

say "판: $LABEL"
say "설치 위치: $DEST"

# 1. 기존 폴더 보호
if [ -e "$DEST" ] && [ -n "$(ls -A "$DEST" 2>/dev/null)" ]; then
  fail "'$DEST' 폴더가 이미 있고 비어 있지 않습니다. 다른 위치를 지정하세요.
  예) curl -fsSL $RAW_URL | bash -s -- --$EDITION ~/My-Wiki"
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
EDIR="$SRC/editions/$EDITION"
[ -f "$EDIR/AGENTS.md" ] || fail "템플릿 파일($EDITION/AGENTS.md)을 찾지 못했습니다."

# 3. 복사
mkdir -p "$DEST"
( cd "$EDIR" && tar -cf - . ) | ( cd "$DEST" && tar -xf - )
TODAY="$(date +%Y-%m-%d)"
if [ -f "$DEST/wiki/log.md" ]; then
  sed -i.bak "s/^- 설치 | install |/- $TODAY | install |/" "$DEST/wiki/log.md" && rm -f "$DEST/wiki/log.md.bak"
fi

# 4. Obsidian (선택)
OBS_APP=""
if [ -d "/Applications/Obsidian.app" ] || [ -d "$HOME/Applications/Obsidian.app" ] || command -v obsidian >/dev/null; then
  OBS_APP="yes"
fi
if [ -z "$OBSIDIAN" ]; then
  if [ -n "$OBS_APP" ]; then
    q="Obsidian 보관소로 등록하고 바로 열까요? [Y/n]: "
  else
    q="위키를 그래프로 보는 Obsidian(무료)을 설치할까요? [y/N]: "
  fi
  def="n"; [ -n "$OBS_APP" ] && def="y"
  case "$(ask "$q" "$def")" in y|Y|yes|예|ㅇ) OBSIDIAN="yes" ;; *) OBSIDIAN="no" ;; esac
fi

register_vault() {
  # Obsidian 보관소 목록(obsidian.json)에 이 폴더를 추가한다. 기존 파일은 .bak으로 백업.
  local cfg
  if [ "$(uname)" = "Darwin" ]; then cfg="$HOME/Library/Application Support/obsidian/obsidian.json"
  else cfg="${XDG_CONFIG_HOME:-$HOME/.config}/obsidian/obsidian.json"; fi
  command -v python3 >/dev/null || return 1
  if pgrep -xq Obsidian 2>/dev/null || pgrep -x obsidian >/dev/null 2>&1; then
    say "  [안내] Obsidian이 실행 중이라 자동 등록을 건너뜁니다. Obsidian에서 '폴더를 보관소로 열기'로 여세요."
    return 1
  fi
  python3 - "$cfg" "$DEST" <<'PY' || return 1
import json, os, secrets, shutil, sys, time
cfg, dest = sys.argv[1], os.path.abspath(sys.argv[2])
data = {}
if os.path.exists(cfg):
    try:
        data = json.load(open(cfg, encoding="utf-8"))
    except Exception:
        sys.exit(1)          # 알 수 없는 형식이면 건드리지 않는다
    shutil.copy2(cfg, cfg + ".bak")
vaults = data.setdefault("vaults", {})
if not any(v.get("path") == dest for v in vaults.values()):
    for v in vaults.values():
        v.pop("open", None)
    vaults[secrets.token_hex(8)] = {"path": dest, "ts": int(time.time() * 1000), "open": True}
os.makedirs(os.path.dirname(cfg), exist_ok=True)
json.dump(data, open(cfg, "w", encoding="utf-8"))
PY
}

if [ "$OBSIDIAN" = "yes" ]; then
  say ""
  say "Obsidian 설정"
  if [ -z "$OBS_APP" ]; then
    if [ "$(uname)" = "Darwin" ] && command -v brew >/dev/null; then
      say "  Homebrew로 Obsidian을 설치합니다..."
      brew install --cask obsidian >/dev/null && OBS_APP="yes" || say "  [안내] 자동 설치에 실패했습니다. https://obsidian.md/download 에서 받아 주세요."
    else
      say "  [안내] https://obsidian.md/download 에서 Obsidian을 받아 설치해 주세요."
    fi
  fi
  if register_vault; then
    say "  [OK] Obsidian 보관소로 등록했습니다."
    if [ -n "$OBS_APP" ] && [ "$(uname)" = "Darwin" ] && [ -z "${LLM_WIKI_NO_OPEN:-}" ]; then
      open "obsidian://open?path=$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))' "$DEST/wiki/index.md")" 2>/dev/null || true
    fi
  fi
fi

# 5. 환경 점검 (설치는 하지 않고 안내만)
say ""
say "환경 점검"
if command -v python3 >/dev/null; then
  if python3 -c "import pypdf" 2>/dev/null || command -v pdftotext >/dev/null; then
    say "  [OK] PDF 읽기 도구"
  else
    say "  [권장] PDF 읽기 도구가 없습니다:  python3 -m pip install --user pypdf"
  fi
else
  say "  [권장] Python 3이 없습니다. PDF·PPT를 쪽/슬라이드 번호와 함께 읽으려면 설치하세요 (https://www.python.org)."
fi
if command -v codex >/dev/null; then
  say "  [OK] Codex CLI"
else
  say "  [안내] Codex CLI가 없습니다. ChatGPT 데스크톱 앱의 Codex나 VS Code 확장으로도 쓸 수 있습니다."
fi

if [ "$EDITION" = "study" ]; then
  PUT="강의자료는 $DEST/raw/lectures/<과목>/ , 교재는 $DEST/raw/textbooks/"
  NEXT='$wiki-quiz      ← 퀴즈로 복습,   $wiki-exam ← 시험 대비 요약'
else
  PUT="논문 PDF는 $DEST/raw/papers/"
  NEXT='$wiki-compare   ← 선행연구 비교표,   $wiki-novelty ← 아이디어 중복 확인'
fi

cat <<MSG

설치 완료 ($LABEL): $DEST

다음 단계 (3분)
  1. 자료를 넣습니다: $PUT
  2. Codex에서 이 폴더를 엽니다. (학교 ChatGPT Edu 계정으로 로그인)
       - ChatGPT 데스크톱 앱: Codex > 폴더 열기 > $DEST
       - 터미널:  cd "$DEST" && codex
  3. Codex에 입력합니다:
       \$wiki-setup     ← 처음 한 번 맞춤 설정
       \$wiki-ingest    ← 넣은 자료 소화
       $NEXT
     그다음엔 그냥 질문하면 됩니다.
  4. Obsidian 사용법: $DEST/Obsidian 사용법.md

MSG

if [ "$(uname)" = "Darwin" ] && [ -z "${LLM_WIKI_NO_OPEN:-}" ] && [ "$OBSIDIAN" != "yes" ]; then
  open "$DEST" 2>/dev/null || true
fi
