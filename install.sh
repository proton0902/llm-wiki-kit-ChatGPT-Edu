#!/usr/bin/env bash
# LLM Wiki Kit 설치 스크립트 (macOS / Linux)
#
#   연구자용:  curl -fsSL https://raw.githubusercontent.com/proton0902/llm-wiki-kit-ChatGPT-Edu/main/install.sh | bash
#   학습용:    curl -fsSL https://raw.githubusercontent.com/proton0902/llm-wiki-kit-ChatGPT-Edu/main/install.sh | bash -s -- --study
#
# 옵션:  --research | --study      어떤 판을 설치할지 (안 쓰면 물어봄, 물어볼 수 없으면 연구자용)
#        --with-obsidian           Obsidian 설치(가능하면)와 보관소 등록까지
#        환경 변수 LLM_WIKI_INSTALL_DEPS=yes|no (Python·pypdf 자동 설치), LLM_WIKI_EXAMPLES=yes|no (예시 자료)
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

# 예/아니오 질문. 환경 변수로 정해 두었으면 묻지 않고, 물어볼 수 없는 환경이면 "아니오".
ask_yes() {
  local prompt="$1" preset="${2:-}"
  if [ -n "$preset" ]; then case "$preset" in y|Y|yes|1|true) return 0 ;; *) return 1 ;; esac; fi
  if [ ! -r /dev/tty ] || [ -n "${LLM_WIKI_NONINTERACTIVE:-}" ]; then return 1; fi
  case "$(ask "$prompt [Y/n]: " y)" in y|Y|yes|예|ㅇ) return 0 ;; *) return 1 ;; esac
}
IS_MAC=""; [ "$(uname)" = "Darwin" ] && IS_MAC="yes"

# 진짜로 실행되는 python3인지 확인한다.
# macOS의 /usr/bin/python3는 Xcode 도구가 없으면 설치 창만 띄우는 바로가기이므로 먼저 걸러낸다.
has_python3() {
  command -v python3 >/dev/null 2>&1 || return 1
  if [ -n "$IS_MAC" ] && [ "$(command -v python3)" = "/usr/bin/python3" ]; then
    xcode-select -p >/dev/null 2>&1 || return 1
  fi
  python3 -c 'import sys' >/dev/null 2>&1
}

# 4. Obsidian (선택)
has_obsidian() {
  [ -d "/Applications/Obsidian.app" ] || [ -d "$HOME/Applications/Obsidian.app" ] || command -v obsidian >/dev/null 2>&1
}
OBS_APP=""; has_obsidian && OBS_APP="yes"
if [ -z "$OBSIDIAN" ]; then
  if [ -n "$OBS_APP" ]; then q="Obsidian 보관소로 등록하고 바로 열까요? [Y/n]: "
  else q="위키를 그래프로 보는 Obsidian(무료)을 설치하고 보관소로 등록할까요? [Y/n]: "; fi
  case "$(ask "$q" y)" in y|Y|yes|예|ㅇ) OBSIDIAN="yes" ;; *) OBSIDIAN="no" ;; esac
fi

install_obsidian_mac() {
  # Homebrew가 있으면 brew로, 없으면 공식 배포처(GitHub)의 dmg를 받아 ~/Applications에 복사한다.
  if command -v brew >/dev/null 2>&1; then
    say "  Homebrew로 Obsidian을 설치합니다..."
    brew install --cask obsidian >/dev/null 2>&1 && return 0
  fi
  say "  공식 배포처에서 Obsidian을 받습니다 (약 150MB)..."
  local url mnt
  url="$(curl -fsSL https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest 2>/dev/null \
        | grep -o '"browser_download_url": *"[^"]*Obsidian-[0-9.]*\.dmg"' | head -n 1 | sed 's/.*"\(https[^"]*\)"/\1/')" || true
  [ -n "$url" ] || return 1
  curl -fsSL "$url" -o "$TMP/Obsidian.dmg" || return 1
  mnt="$(hdiutil attach -nobrowse -readonly "$TMP/Obsidian.dmg" 2>/dev/null | grep -o '/Volumes/.*' | head -n 1)" || return 1
  [ -d "$mnt/Obsidian.app" ] || { hdiutil detach "$mnt" -quiet || true; return 1; }
  mkdir -p "$HOME/Applications"
  cp -R "$mnt/Obsidian.app" "$HOME/Applications/" || { hdiutil detach "$mnt" -quiet || true; return 1; }
  hdiutil detach "$mnt" -quiet || true
}

register_vault() {
  # Obsidian 보관소 목록(obsidian.json)에 이 폴더를 추가한다. 기존 파일은 .bak으로 백업.
  local cfg
  if [ -n "$IS_MAC" ]; then cfg="$HOME/Library/Application Support/obsidian/obsidian.json"
  else cfg="${XDG_CONFIG_HOME:-$HOME/.config}/obsidian/obsidian.json"; fi
  has_python3 || return 1
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

# 5. Python·pypdf (선택). 위키는 Python 없이도 쓸 수 있고, PDF를 쪽 번호와 함께 읽을 때 쓰인다.
# 보관소 등록에도 python3가 필요하므로 Obsidian 등록보다 먼저 한다.
install_python() {
  if command -v brew >/dev/null 2>&1; then
    say "  Homebrew로 Python을 설치합니다..."
    brew install python >/dev/null 2>&1 && hash -r && has_python3 && return 0
  fi
  if [ -n "$IS_MAC" ]; then
    say "  macOS 개발자 도구(Python 포함) 설치 창을 엽니다. 창에서 '설치'를 누르고 끝날 때까지 기다려 주세요."
    xcode-select --install >/dev/null 2>&1 || true
    local i=0
    while [ $i -lt 120 ] && ! has_python3; do sleep 5; i=$((i + 1)); done   # 최대 10분
    has_python3
    return
  fi
  local SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"
  if command -v apt-get >/dev/null 2>&1; then $SUDO apt-get install -y python3 python3-pip </dev/tty
  elif command -v dnf >/dev/null 2>&1; then $SUDO dnf install -y python3 python3-pip </dev/tty
  elif command -v pacman >/dev/null 2>&1; then $SUDO pacman -S --noconfirm python python-pip </dev/tty
  else return 1; fi
  hash -r; has_python3
}
install_pypdf() {
  python3 -m pip install --user --quiet --disable-pip-version-check pypdf >/dev/null 2>&1 \
    || python3 -m pip install --user --quiet --disable-pip-version-check --break-system-packages pypdf >/dev/null 2>&1 \
    || true
  python3 -c "import pypdf" >/dev/null 2>&1
}

say ""
say "PDF 읽기 도구 (Python, pypdf)"
if ! has_python3; then
  if ask_yes "  Python 3이 없습니다. PDF를 쪽 번호와 함께 읽도록 설치할까요?" "${LLM_WIKI_INSTALL_DEPS:-}"; then
    if install_python; then say "  [OK] Python을 설치했습니다."
    else say "  [안내] Python 자동 설치에 실패했습니다. https://www.python.org/downloads/ 에서 받아 설치해 주세요. (위키는 Python 없이도 쓸 수 있습니다.)"; fi
  else
    say "  [건너뜀] Python 없이도 위키는 쓸 수 있습니다. 나중에 https://www.python.org/downloads/ 에서 설치할 수 있습니다."
  fi
fi
if has_python3; then
  if python3 -c "import pypdf" >/dev/null 2>&1 || command -v pdftotext >/dev/null 2>&1; then
    say "  [OK] Python, PDF 읽기 도구"
  elif ask_yes "  PDF 읽기 도구(pypdf, 약 1MB)를 설치할까요?" "${LLM_WIKI_INSTALL_DEPS:-}"; then
    if install_pypdf; then say "  [OK] PDF 읽기 도구를 설치했습니다."
    else say "  [안내] 자동 설치에 실패했습니다. 나중에:  python3 -m pip install --user pypdf"; fi
  else
    say "  [건너뜀] 나중에 설치하려면:  python3 -m pip install --user pypdf"
  fi
fi
if command -v codex >/dev/null 2>&1; then
  say "  [OK] Codex CLI"
else
  say "  [안내] Codex CLI가 없습니다. ChatGPT 데스크톱 앱의 Codex나 VS Code 확장으로도 쓸 수 있습니다."
fi

VAULT_OK=""
if [ "$OBSIDIAN" = "yes" ]; then
  say ""
  say "Obsidian 설정"
  if [ -z "$OBS_APP" ]; then
    if [ -n "$IS_MAC" ]; then
      if install_obsidian_mac && has_obsidian; then OBS_APP="yes"; say "  [OK] Obsidian을 설치했습니다."
      else say "  [안내] Obsidian 자동 설치에 실패했습니다. https://obsidian.md/download 에서 받아 주세요."; fi
    else
      say "  [안내] https://obsidian.md/download 에서 Obsidian을 받아 설치해 주세요."
    fi
  fi
  if register_vault; then
    VAULT_OK="yes"
    say "  [OK] Obsidian 보관소로 등록했습니다."
  else
    say "  [안내] 자동 등록을 건너뛰었습니다. Obsidian에서 '폴더를 보관소로 열기'로 $DEST 를 여세요."
  fi
fi

# 6. 예시 자료 (선택). 파일은 이 키트에 들어 있지 않고, 원 출처(arXiv, MIT OpenCourseWare)에서 이 PC로 직접 받는다.
#    목록은 위키 폴더의 examples/*.tsv 에 함께 복사되므로, 나중에 Codex에서 $wiki-examples 로도 받을 수 있다.
GOT_EXAMPLES=0
CREDITS="$TMP/credits.md"
fetch_manifest() {  # $1 = 목록 파일
  local manifest="$1" dir file url title credit license
  [ -f "$CREDITS" ] || printf '# 예시 자료 출처\n\n아래 원 출처에서 이 PC로 직접 내려받은 자료입니다. 개인 학습·연구 체험용으로만 쓰고, 다시 배포할 때는 각 라이선스를 따르세요.\n\n' > "$CREDITS"
  while IFS="$(printf '\t')" read -r dir file url title credit license; do
    case "$dir" in ''|'#'*) continue ;; esac
    mkdir -p "$DEST/$dir"
    if curl -fsSL -A "llm-wiki-kit-installer" "$url" -o "$DEST/$dir/$file" 2>/dev/null \
       && [ "$(wc -c < "$DEST/$dir/$file")" -gt 10000 ]; then
      say "  [OK] $dir/$file"
      GOT_EXAMPLES=$((GOT_EXAMPLES + 1))
      printf -- '- **%s/%s**: %s\n  - 저자·출처: %s\n  - 원본: %s\n  - 라이선스: %s\n' "$dir" "$file" "$title" "$credit" "$url" "$license" >> "$CREDITS"
    else
      rm -f "$DEST/$dir/$file"
      say "  [안내] 받지 못했습니다: $file ($url)"
    fi
    case "$url" in *arxiv.org*) sleep 2 ;; esac
  done < "$manifest"
}
MANIFEST="$SRC/editions/$EDITION/examples/basic.tsv"
if [ -f "$MANIFEST" ]; then
  N="$(grep -c '^raw' "$MANIFEST" || true)"
  if [ "$EDITION" = "study" ]; then WHAT="MIT OpenCourseWare 인공지능 강의자료 ${N}개"; else WHAT="검색 증강 생성(RAG) 분야 공개 논문 ${N}편"; fi
  say ""
  say "예시 자료"
  if ask_yes "  바로 시험해 볼 수 있게 예시 자료(${WHAT}, 약 10MB)를 받아 둘까요?" "${LLM_WIKI_EXAMPLES:-}"; then
    fetch_manifest "$MANIFEST"
  fi
fi
BENCH="$SRC/editions/$EDITION/examples/benchmark.tsv"
if [ -f "$BENCH" ]; then
  N="$(grep -c '^raw' "$BENCH" || true)"
  say ""
  say "벤치마크 자료 (선택): RAG 대표 논문 ${N}편, 약 60MB, 2~3분"
  say "  한 채팅에 다 담기 어려운 양의 논문에서 위키가 얼마나 정확한지 직접 비교해 볼 때 씁니다."
  WANT_BENCH=""
  if [ -n "${LLM_WIKI_BENCHMARK:-}" ]; then
    case "$LLM_WIKI_BENCHMARK" in y|Y|yes|1|true) WANT_BENCH="yes" ;; esac
  elif [ -r /dev/tty ] && [ -z "${LLM_WIKI_NONINTERACTIVE:-}" ]; then
    case "$(ask "  벤치마크 논문도 받을까요? (나중에 Codex에서 \$wiki-examples 로도 받을 수 있습니다) [y/N]: " n)" in y|Y|yes|예|ㅇ) WANT_BENCH="yes" ;; esac
  fi
  [ -n "$WANT_BENCH" ] && fetch_manifest "$BENCH"
fi
[ "$GOT_EXAMPLES" -gt 0 ] && cp "$CREDITS" "$DEST/예시 자료 출처.md"

if [ "$EDITION" = "study" ]; then
  PUT="강의자료는 $DEST/raw/lectures/<과목>/ , 교재는 $DEST/raw/textbooks/"
  NEXT='$wiki-quiz      ← 퀴즈로 복습,   $wiki-exam ← 시험 대비 요약'
else
  PUT="논문 PDF는 $DEST/raw/papers/"
  NEXT='$wiki-compare   ← 선행연구 비교표,   $wiki-novelty ← 아이디어 중복 확인'
fi
[ "$GOT_EXAMPLES" -gt 0 ] && PUT="(예시 자료가 이미 들어 있으니 이 단계는 건너뛰어도 됩니다.) $PUT"

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
     (Codex가 "스킬을 찾을 수 없다"고 하면 작업 폴더가 이 위키 폴더인지 확인하고 Codex를 다시 시작하세요.)
  4. Obsidian 사용법: $DEST/Obsidian 사용법.md

MSG

if [ -n "$IS_MAC" ] && [ -z "${LLM_WIKI_NO_OPEN:-}" ]; then
  if [ -n "$VAULT_OK" ] && [ -n "$OBS_APP" ]; then
    open "obsidian://open?path=$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))' "$DEST/wiki/index.md")" 2>/dev/null || true
  else
    open "$DEST" 2>/dev/null || true
  fi
fi
exit 0
