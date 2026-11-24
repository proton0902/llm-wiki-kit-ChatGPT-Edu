# LLM Wiki Kit 설치 스크립트 (Windows PowerShell)
# 사용법:  irm https://raw.githubusercontent.com/proton0902/llm-wiki-kit-ChatGPT-Edu/main/install.ps1 | iex
# 다른 폴더에 설치:  $env:LLM_WIKI_DIR="D:\MyWiki"; irm .../install.ps1 | iex
$ErrorActionPreference = "Stop"
$Owner = "proton0902"; $Repo = "llm-wiki-kit-ChatGPT-Edu"; $Branch = "main"
$Dest = if ($env:LLM_WIKI_DIR) { $env:LLM_WIKI_DIR } else { Join-Path $HOME "LLM-Wiki" }

function Fail($msg) { Write-Host "`n[설치 중단] $msg" -ForegroundColor Red; return }

Write-Host "`nLLM Wiki Kit 설치를 시작합니다."
Write-Host "설치 위치: $Dest"

if ((Test-Path $Dest) -and (Get-ChildItem -Force $Dest | Select-Object -First 1)) {
  Fail "'$Dest' 폴더가 이미 있고 비어 있지 않습니다. `$env:LLM_WIKI_DIR 로 다른 위치를 지정하세요."
  return
}

$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("llmwiki-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $Tmp | Out-Null
try {
  if ($env:LLM_WIKI_SRC) {
    $Src = $env:LLM_WIKI_SRC
  } else {
    $Zip = Join-Path $Tmp "kit.zip"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -UseBasicParsing "https://codeload.github.com/$Owner/$Repo/zip/refs/heads/$Branch" -OutFile $Zip
    Expand-Archive -Path $Zip -DestinationPath $Tmp
    $Src = (Get-ChildItem -Directory $Tmp | Select-Object -First 1).FullName
  }
  if (-not (Test-Path (Join-Path $Src "AGENTS.md"))) { Fail "템플릿 파일(AGENTS.md)을 찾지 못했습니다."; return }

  New-Item -ItemType Directory -Force -Path $Dest | Out-Null
  $Exclude = @("install.sh", "install.ps1", "docs", ".git", ".github", "tests")
  Get-ChildItem -Force $Src | Where-Object { $Exclude -notcontains $_.Name } |
    Copy-Item -Destination $Dest -Recurse -Force

  $Log = Join-Path $Dest "wiki\log.md"
  if (Test-Path $Log) {
    $Today = Get-Date -Format "yyyy-MM-dd"
    $Text = [IO.File]::ReadAllText($Log, [Text.Encoding]::UTF8) -replace "(?m)^- 설치 \| install \|", "- $Today | install |"
    [IO.File]::WriteAllText($Log, $Text, (New-Object Text.UTF8Encoding $false))
  }
} finally {
  Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
}

Write-Host "`n환경 점검"
$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) { $py = Get-Command py -ErrorAction SilentlyContinue }
if ($py) {
  & $py.Source -c "import pypdf" 2>$null
  if ($LASTEXITCODE -eq 0) { Write-Host "  [OK] PDF 읽기 도구" }
  else { Write-Host "  [권장] PDF 읽기 도구가 없습니다:  python -m pip install --user pypdf" }
} else { Write-Host "  [권장] Python이 없습니다:  winget install Python.Python.3.12" }
if (Get-Command codex -ErrorAction SilentlyContinue) { Write-Host "  [OK] Codex CLI" }
else { Write-Host "  [안내] Codex CLI가 없습니다. ChatGPT 데스크톱 앱의 Codex나 VS Code 확장으로도 쓸 수 있습니다." }

Write-Host @"

설치 완료: $Dest

다음 단계 (3분)
  1. 논문 PDF를 넣습니다:   $Dest\raw\papers\
  2. Codex에서 이 폴더를 엽니다 (ChatGPT 데스크톱 앱 Codex 또는 VS Code 확장).
     학교 계정(ChatGPT Edu)으로 로그인하세요.
  3. Codex에 입력합니다:
       `$wiki-setup     <- 내 연구 분야에 맞게 설정 (처음 한 번)
       `$wiki-ingest    <- raw에 넣은 논문 소화
     그다음엔 그냥 질문하면 됩니다.
  4. (선택) Obsidian > "폴더를 보관소로 열기" > $Dest

"@
if (-not $env:LLM_WIKI_NO_OPEN) { Start-Process explorer.exe $Dest }
