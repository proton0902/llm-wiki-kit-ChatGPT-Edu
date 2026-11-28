# LLM Wiki Kit 설치 스크립트 (Windows PowerShell)
#
#   연구자용:  irm https://raw.githubusercontent.com/proton0902/llm-wiki-kit-ChatGPT-Edu/main/install.ps1 | iex
#   학습용:    irm https://raw.githubusercontent.com/proton0902/llm-wiki-kit-ChatGPT-Edu/main/install-study.ps1 | iex
#
# 환경 변수로 미리 정할 수 있음:  $env:LLM_WIKI_EDITION = "research" | "study"
#                                 $env:LLM_WIKI_DIR = "D:\MyWiki"
#                                 $env:LLM_WIKI_OBSIDIAN = "yes" | "no"
& {
$ErrorActionPreference = "Stop"
$Owner = "proton0902"; $Repo = "llm-wiki-kit-ChatGPT-Edu"; $Branch = "main"
$Edition = $env:LLM_WIKI_EDITION
$Obsidian = $env:LLM_WIKI_OBSIDIAN
$Interactive = -not $env:LLM_WIKI_NONINTERACTIVE

function Fail($msg) { Write-Host "`n[설치 중단] $msg" -ForegroundColor Red }
function Ask($prompt, $default) {
  if (-not $Interactive) { return $default }
  try { $a = Read-Host $prompt } catch { $a = "" }
  if ([string]::IsNullOrWhiteSpace($a)) { return $default } else { return $a.Trim() }
}

Write-Host "`nLLM Wiki Kit 설치를 시작합니다."
if (-not $Edition) {
  Write-Host ""
  Write-Host "  1) 연구자용 - 논문 정리, 선행연구 비교, 연구 동향"
  Write-Host "  2) 학습용   - 강의자료·교재 정리, 개념 카드, 퀴즈, 시험 대비"
  $Edition = if ((Ask "어떤 판을 설치할까요? [1/2, 기본 1]" "1") -match '^(2|s|study|학습)') { "study" } else { "research" }
}
if ($Edition -notin @("research", "study")) { Fail "판 이름은 research 또는 study 입니다."; return }
if ($Edition -eq "study") { $Label = "학습용"; $DefaultDest = Join-Path $HOME "Study-Wiki" }
else { $Label = "연구자용"; $DefaultDest = Join-Path $HOME "LLM-Wiki" }
$Dest = if ($env:LLM_WIKI_DIR) { $env:LLM_WIKI_DIR } else { $DefaultDest }
Write-Host "판: $Label"
Write-Host "설치 위치: $Dest"

if ((Test-Path $Dest) -and (Get-ChildItem -Force $Dest | Select-Object -First 1)) {
  Fail "'$Dest' 폴더가 이미 있고 비어 있지 않습니다. `$env:LLM_WIKI_DIR 로 다른 위치를 지정하세요."; return
}

$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("llmwiki-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $Tmp | Out-Null
try {
  if ($env:LLM_WIKI_SRC) { $Src = $env:LLM_WIKI_SRC }
  else {
    $Zip = Join-Path $Tmp "kit.zip"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -UseBasicParsing "https://codeload.github.com/$Owner/$Repo/zip/refs/heads/$Branch" -OutFile $Zip
    Expand-Archive -Path $Zip -DestinationPath $Tmp
    $Src = (Get-ChildItem -Directory $Tmp | Select-Object -First 1).FullName
  }
  $EDir = Join-Path $Src "editions\$Edition"
  if (-not (Test-Path (Join-Path $EDir "AGENTS.md"))) { Fail "템플릿 파일($Edition\AGENTS.md)을 찾지 못했습니다."; return }
  New-Item -ItemType Directory -Force -Path $Dest | Out-Null
  Get-ChildItem -Force $EDir | Copy-Item -Destination $Dest -Recurse -Force
  $Log = Join-Path $Dest "wiki\log.md"
  if (Test-Path $Log) {
    $Today = Get-Date -Format "yyyy-MM-dd"
    $Text = [IO.File]::ReadAllText($Log, [Text.Encoding]::UTF8) -replace "(?m)^- 설치 \| install \|", "- $Today | install |"
    [IO.File]::WriteAllText($Log, $Text, (New-Object Text.UTF8Encoding $false))
  }
} finally { Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue }

# Obsidian (선택)
$ObsExe = @("$env:LOCALAPPDATA\Programs\Obsidian\Obsidian.exe", "$env:LOCALAPPDATA\Obsidian\Obsidian.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $Obsidian) {
  if ($ObsExe) { $q = "Obsidian 보관소로 등록하고 바로 열까요? [Y/n]"; $def = "y" }
  else { $q = "위키를 그래프로 보는 Obsidian(무료)을 설치할까요? [y/N]"; $def = "n" }
  $Obsidian = if ((Ask $q $def) -match '^(y|yes|예|ㅇ)') { "yes" } else { "no" }
}
if ($Obsidian -eq "yes") {
  Write-Host "`nObsidian 설정"
  if (-not $ObsExe) {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
      Write-Host "  winget으로 Obsidian을 설치합니다..."
      try { $ErrorActionPreference = "Continue"; winget install -e --id Obsidian.Obsidian } catch { } finally { $ErrorActionPreference = "Stop" }
      $ObsExe = @("$env:LOCALAPPDATA\Programs\Obsidian\Obsidian.exe", "$env:LOCALAPPDATA\Obsidian\Obsidian.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
    }
    if (-not $ObsExe) { Write-Host "  [안내] https://obsidian.md/download 에서 Obsidian을 받아 설치해 주세요." }
  }
  if (Get-Process Obsidian -ErrorAction SilentlyContinue) {
    Write-Host "  [안내] Obsidian이 실행 중이라 자동 등록을 건너뜁니다. Obsidian에서 '폴더를 보관소로 열기'로 여세요."
  } else {
    try {
      $Cfg = Join-Path $env:APPDATA "obsidian\obsidian.json"
      if (Test-Path $Cfg) { $Data = Get-Content $Cfg -Raw -Encoding UTF8 | ConvertFrom-Json; Copy-Item $Cfg "$Cfg.bak" -Force }
      else { New-Item -ItemType Directory -Force -Path (Split-Path $Cfg) | Out-Null; $Data = [pscustomobject]@{} }
      if (-not $Data.vaults) { $Data | Add-Member -NotePropertyName vaults -NotePropertyValue ([pscustomobject]@{}) -Force }
      $Full = (Resolve-Path $Dest).Path
      $Exists = $Data.vaults.PSObject.Properties | Where-Object { $_.Value.path -eq $Full }
      if (-not $Exists) {
        foreach ($p in $Data.vaults.PSObject.Properties) { $p.Value.PSObject.Properties.Remove("open") }
        $Id = -join ((1..16) | ForEach-Object { "{0:x}" -f (Get-Random -Maximum 16) })
        $Data.vaults | Add-Member -NotePropertyName $Id -NotePropertyValue ([pscustomobject]@{ path = $Full; ts = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds(); open = $true })
      }
      [IO.File]::WriteAllText($Cfg, ($Data | ConvertTo-Json -Depth 10 -Compress), (New-Object Text.UTF8Encoding $false))
      Write-Host "  [OK] Obsidian 보관소로 등록했습니다."
      if ($ObsExe -and -not $env:LLM_WIKI_NO_OPEN) {
        Start-Process ("obsidian://open?path=" + [uri]::EscapeDataString((Join-Path $Full "wiki\index.md")))
      }
    } catch { Write-Host "  [안내] 자동 등록에 실패했습니다. Obsidian에서 '폴더를 보관소로 열기'로 여세요." }
  }
}

# 환경 점검: 안내만 하고, 어떤 경우에도 설치를 멈추지 않는다.
# Windows의 python.exe는 Microsoft Store 바로가기(App execution alias)일 수 있다.
# 이 가짜 python은 "Python was not found"를 stderr로 출력하고 실패하므로, 실제로 실행해 보고 판단한다.
function Invoke-Quiet($exe, [string[]]$argv) {
  $old = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  try {
    $out = & $exe @argv 2>$null
    return [pscustomobject]@{ Ok = ($LASTEXITCODE -eq 0); Out = ($out | Out-String).Trim() }
  } catch { return [pscustomobject]@{ Ok = $false; Out = "" } }
  finally { $ErrorActionPreference = $old }
}
Write-Host "`n환경 점검"
try {
  $Py = $null; $PyArgs = @(); $StoreStub = $false
  $cands = New-Object System.Collections.ArrayList
  foreach ($n in @("python", "python3")) {
    foreach ($g in @(Get-Command $n -CommandType Application -All -ErrorAction SilentlyContinue)) { [void]$cands.Add(@{ Exe = $g.Source; Pre = @() }) }
  }
  foreach ($g in @(Get-Command py -CommandType Application -ErrorAction SilentlyContinue)) { [void]$cands.Add(@{ Exe = $g.Source; Pre = @("-3") }) }
  foreach ($c in $cands) {
    $exe = $c.Exe; $pre = [string[]]$c.Pre
    $r = Invoke-Quiet $exe ($pre + @("-c", "import sys; print(sys.version_info[0])"))
    if ($r.Ok -and $r.Out -match '3$') { $Py = $exe; $PyArgs = $pre; break }
    if ($exe -like "*\WindowsApps\*") { $StoreStub = $true }
  }
  if ($Py) {
    $PyName = if ($PyArgs.Count -gt 0) { "py -3" } else { "python" }
    if ((Invoke-Quiet $Py ($PyArgs + @("-c", "import pypdf"))).Ok) { Write-Host "  [OK] Python, PDF 읽기 도구" }
    else { Write-Host "  [선택] PDF를 쪽 번호와 함께 읽으려면:  $PyName -m pip install --user pypdf" }
  } else {
    Write-Host "  [선택] Python이 없습니다. 위키는 Python 없이도 쓸 수 있습니다."
    Write-Host "         PDF·PPT를 쪽/슬라이드 번호와 함께 읽고 싶을 때만 설치하세요:  winget install Python.Python.3.12"
    if ($StoreStub) { Write-Host "         (지금 보이는 python은 Microsoft Store 바로가기라서 실제 Python이 아닙니다.)" }
  }
} catch { Write-Host "  [안내] Python 확인을 건너뜁니다. (위키 사용에는 지장이 없습니다.)" }
if (Get-Command codex -ErrorAction SilentlyContinue) { Write-Host "  [OK] Codex CLI" }
else { Write-Host "  [안내] Codex CLI가 없습니다. ChatGPT 데스크톱 앱의 Codex나 VS Code 확장으로도 쓸 수 있습니다." }

if ($Edition -eq "study") {
  $Put = "강의자료는 $Dest\raw\lectures\<과목>\ , 교재는 $Dest\raw\textbooks\"
  $Next = "`$wiki-quiz      <- 퀴즈로 복습,   `$wiki-exam <- 시험 대비 요약"
} else {
  $Put = "논문 PDF는 $Dest\raw\papers\"
  $Next = "`$wiki-compare   <- 선행연구 비교표,   `$wiki-novelty <- 아이디어 중복 확인"
}
Write-Host @"

설치 완료 ($Label): $Dest

다음 단계 (3분)
  1. 자료를 넣습니다: $Put
  2. Codex에서 이 폴더를 엽니다 (ChatGPT 데스크톱 앱 Codex 또는 VS Code 확장). 학교 ChatGPT Edu 계정으로 로그인.
  3. Codex에 입력합니다:
       `$wiki-setup     <- 처음 한 번 맞춤 설정
       `$wiki-ingest    <- 넣은 자료 소화
       $Next
     그다음엔 그냥 질문하면 됩니다.
  4. Obsidian 사용법: $Dest\Obsidian 사용법.md

"@
if (-not $env:LLM_WIKI_NO_OPEN -and $Obsidian -ne "yes") { Start-Process explorer.exe $Dest }
}
