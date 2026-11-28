# LLM Wiki Kit 설치 스크립트 (Windows PowerShell)
#
#   연구자용:  irm https://raw.githubusercontent.com/proton0902/llm-wiki-kit-ChatGPT-Edu/main/install.ps1 | iex
#   학습용:    irm https://raw.githubusercontent.com/proton0902/llm-wiki-kit-ChatGPT-Edu/main/install-study.ps1 | iex
#
# 환경 변수로 미리 정할 수 있음:  $env:LLM_WIKI_EDITION = "research" | "study"
#                                 $env:LLM_WIKI_DIR = "D:\MyWiki"
#                                 $env:LLM_WIKI_OBSIDIAN = "yes" | "no"       (Obsidian 설치·등록)
#                                 $env:LLM_WIKI_INSTALL_DEPS = "yes" | "no"   (Python·pypdf 자동 설치)
#                                 $env:LLM_WIKI_EXAMPLES = "yes" | "no"       (예시 자료 내려받기)
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
# 예/아니오 질문. 환경 변수로 정해 두었으면 묻지 않고, 물어볼 수 없는 환경이면 "아니오".
function AskYes($prompt, $envValue) {
  if ($envValue) { return ($envValue -match '^(y|yes|1|true)$') }
  if (-not $Interactive) { return $false }
  return ((Ask "$prompt [Y/n]" "y") -match '^(y|yes|예|ㅇ)')
}
# 외부 프로그램을 실행하되, 경고(stderr) 때문에 설치가 멈추지 않게 한다.
function Invoke-Quiet($exe, [string[]]$argv) {
  $old = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  try {
    $out = & $exe @argv 2>$null
    return [pscustomobject]@{ Ok = ($LASTEXITCODE -eq 0); Out = ($out | Out-String).Trim() }
  } catch { return [pscustomobject]@{ Ok = $false; Out = "" } }
  finally { $ErrorActionPreference = $old }
}
function Invoke-Loud($exe, [string[]]$argv) {
  $old = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  try { & $exe @argv | Out-Host; return ($LASTEXITCODE -eq 0) } catch { return $false }
  finally { $ErrorActionPreference = $old }
}
function Update-PathFromRegistry {
  $m = [Environment]::GetEnvironmentVariable("Path", "Machine"); $u = [Environment]::GetEnvironmentVariable("Path", "User")
  $env:Path = (@($m, $u) | Where-Object { $_ }) -join ";"
}
# 실제로 동작하는 Python 3를 찾는다.
# Windows의 python.exe는 Microsoft Store 바로가기(App execution alias)일 수 있는데,
# 이 가짜 python은 "Python was not found"만 출력하고 실패하므로 직접 실행해 보고 판단한다.
function Find-Python {
  $res = @{ Exe = $null; Pre = @(); StoreStub = $false }
  $cands = New-Object System.Collections.ArrayList
  foreach ($n in @("python", "python3")) {
    foreach ($g in @(Get-Command $n -CommandType Application -All -ErrorAction SilentlyContinue)) { [void]$cands.Add(@{ Exe = $g.Source; Pre = @() }) }
  }
  foreach ($g in @(Get-Command py -CommandType Application -ErrorAction SilentlyContinue)) { [void]$cands.Add(@{ Exe = $g.Source; Pre = @("-3") }) }
  foreach ($f in @(Get-ChildItem "$env:LOCALAPPDATA\Programs\Python\Python3*\python.exe", "$env:ProgramFiles\Python3*\python.exe" -ErrorAction SilentlyContinue)) {
    [void]$cands.Add(@{ Exe = $f.FullName; Pre = @() })
  }
  foreach ($c in $cands) {
    $exe = $c.Exe; $pre = [string[]]$c.Pre
    $r = Invoke-Quiet $exe ($pre + @("-c", "import sys; print(sys.version_info[0])"))
    if ($r.Ok -and $r.Out -match '3$') { $res.Exe = $exe; $res.Pre = $pre; return $res }
    if ($exe -like "*\WindowsApps\*") { $res.StoreStub = $true }
  }
  return $res
}
function Find-Obsidian {
  @("$env:LOCALAPPDATA\Programs\Obsidian\Obsidian.exe", "$env:LOCALAPPDATA\Obsidian\Obsidian.exe", "$env:ProgramFiles\Obsidian\Obsidian.exe") |
    Where-Object { Test-Path $_ } | Select-Object -First 1
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

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$ExampleRows = @(); $BenchRows = @()
function Read-Manifest($Path) {
  if (-not (Test-Path $Path)) { return @() }
  @([IO.File]::ReadAllLines($Path, [Text.Encoding]::UTF8) | Where-Object { $_ -and -not $_.StartsWith("#") } |
    ForEach-Object { $f = $_ -split "`t"; if ($f.Count -ge 6) { [pscustomobject]@{ Dir = $f[0]; File = $f[1]; Url = $f[2]; Title = $f[3]; Credit = $f[4]; License = $f[5] } } })
}
$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("llmwiki-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $Tmp | Out-Null
try {
  if ($env:LLM_WIKI_SRC) { $Src = $env:LLM_WIKI_SRC }
  else {
    $Zip = Join-Path $Tmp "kit.zip"
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
  $ExampleRows = @(Read-Manifest (Join-Path $EDir "examples\basic.tsv"))
  $BenchRows = @(Read-Manifest (Join-Path $EDir "examples\benchmark.tsv"))
} finally { Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue }

# ---------------------------------------------------------------- Obsidian (선택)
$ObsExe = Find-Obsidian
if (-not $Obsidian) {
  if ($ObsExe) { $q = "Obsidian 보관소로 등록하고 바로 열까요? [Y/n]" }
  else { $q = "위키를 그래프로 보는 Obsidian(무료)을 설치하고 보관소로 등록할까요? [Y/n]" }
  $Obsidian = if ((Ask $q "y") -match '^(y|yes|예|ㅇ)') { "yes" } else { "no" }
}
if ($Obsidian -eq "yes") {
  Write-Host "`nObsidian 설정"
  if (-not $ObsExe) {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
      Write-Host "  winget으로 Obsidian을 설치합니다 (1~2분)..."
      [void](Invoke-Loud "winget" @("install", "-e", "--id", "Obsidian.Obsidian", "--silent", "--accept-package-agreements", "--accept-source-agreements"))
      $ObsExe = Find-Obsidian
    }
    if (-not $ObsExe) {
      # winget이 없거나 실패하면 공식 배포처(GitHub)에서 설치 파일을 받아 조용히 설치한다.
      try {
        Write-Host "  공식 배포처에서 Obsidian 설치 파일을 받습니다..."
        $rel = Invoke-RestMethod -UseBasicParsing "https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest"
        $asset = $rel.assets | Where-Object { $_.name -match '^Obsidian-[\d.]+\.exe$' } | Select-Object -First 1
        if ($asset) {
          $Setup = Join-Path ([System.IO.Path]::GetTempPath()) $asset.name
          Invoke-WebRequest -UseBasicParsing $asset.browser_download_url -OutFile $Setup
          Start-Process -FilePath $Setup -ArgumentList "/S" -Wait
          Remove-Item $Setup -Force -ErrorAction SilentlyContinue
          $ObsExe = Find-Obsidian
        }
      } catch { }
    }
    if ($ObsExe) { Write-Host "  [OK] Obsidian을 설치했습니다." }
    else { Write-Host "  [안내] Obsidian 자동 설치에 실패했습니다. https://obsidian.md/download 에서 받아 설치해 주세요." }
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
    } catch { Write-Host "  [안내] 자동 등록에 실패했습니다. Obsidian에서 '폴더를 보관소로 열기'로 여세요." }
  }
}

# ---------------------------------------------------------------- Python·pypdf (선택)
# 위키는 Python 없이도 쓸 수 있다. PDF를 쪽 번호와 함께 정확히 읽을 때 쓰인다.
Write-Host "`nPDF 읽기 도구 (Python, pypdf)"
try {
  $P = Find-Python
  if (-not $P.Exe) {
    if ($P.StoreStub) { Write-Host "  지금 보이는 python은 Microsoft Store 바로가기라서 실제 Python이 아닙니다." }
    if (AskYes "  Python이 없습니다. PDF를 쪽 번호와 함께 읽도록 Python을 설치할까요? (약 30MB, 1~2분)" $env:LLM_WIKI_INSTALL_DEPS) {
      if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "  winget으로 Python을 설치합니다..."
        [void](Invoke-Loud "winget" @("install", "-e", "--id", "Python.Python.3.12", "--scope", "user", "--silent", "--accept-package-agreements", "--accept-source-agreements"))
        Update-PathFromRegistry
        $P = Find-Python
      }
      if (-not $P.Exe) { Write-Host "  [안내] Python 자동 설치에 실패했습니다. https://www.python.org/downloads/ 에서 받아 설치해 주세요. (위키는 Python 없이도 쓸 수 있습니다.)" }
      else { Write-Host "  [OK] Python을 설치했습니다." }
    } else { Write-Host "  [건너뜀] Python 없이도 위키는 쓸 수 있습니다. 나중에 설치하려면:  winget install Python.Python.3.12" }
  }
  if ($P.Exe) {
    $PyName = if ($P.Pre.Count -gt 0) { "py -3" } else { "python" }
    if ((Invoke-Quiet $P.Exe ($P.Pre + @("-c", "import pypdf"))).Ok) { Write-Host "  [OK] Python, PDF 읽기 도구" }
    elseif (AskYes "  PDF 읽기 도구(pypdf, 약 1MB)를 설치할까요?" $env:LLM_WIKI_INSTALL_DEPS) {
      [void](Invoke-Quiet $P.Exe ($P.Pre + @("-m", "pip", "install", "--user", "--quiet", "--disable-pip-version-check", "pypdf")))
      if ((Invoke-Quiet $P.Exe ($P.Pre + @("-c", "import pypdf"))).Ok) { Write-Host "  [OK] PDF 읽기 도구를 설치했습니다." }
      else { Write-Host "  [안내] 자동 설치에 실패했습니다. 나중에:  $PyName -m pip install --user pypdf" }
    } else { Write-Host "  [건너뜀] 나중에 설치하려면:  $PyName -m pip install --user pypdf" }
  }
} catch { Write-Host "  [안내] Python 확인을 건너뜁니다. (위키 사용에는 지장이 없습니다.)" }
if (Get-Command codex -ErrorAction SilentlyContinue) { Write-Host "  [OK] Codex CLI" }
else { Write-Host "  [안내] Codex CLI가 없습니다. ChatGPT 데스크톱 앱의 Codex나 VS Code 확장으로도 쓸 수 있습니다." }

# ---------------------------------------------------------------- 예시 자료 (선택)
# 파일은 이 키트에 들어 있지 않고, 원 출처(arXiv, MIT OpenCourseWare)에서 사용자 PC로 직접 받는다.
$GotExamples = 0
$Lines = @("# 예시 자료 출처", "", "아래 원 출처에서 이 PC로 직접 내려받은 자료입니다. 개인 학습·연구 체험용으로만 쓰고, 다시 배포할 때는 각 라이선스를 따르세요.", "")
function Get-ExampleRows($Rows) {
  foreach ($r in $Rows) {
    try {
      $Dir = Join-Path $Dest ($r.Dir -replace '/', '\')
      New-Item -ItemType Directory -Force -Path $Dir | Out-Null
      $Out = Join-Path $Dir $r.File
      Invoke-WebRequest -UseBasicParsing -UserAgent "llm-wiki-kit-installer" $r.Url -OutFile $Out
      if ((Get-Item $Out).Length -gt 10000) { Write-Host "  [OK] $($r.Dir)/$($r.File)" }
      else { Remove-Item $Out -Force; throw "too small" }
      Write-Output "- **$($r.Dir)/$($r.File)**: $($r.Title)"; Write-Output "  - 저자·출처: $($r.Credit)"; Write-Output "  - 원본: $($r.Url)"; Write-Output "  - 라이선스: $($r.License)"
    } catch { Write-Host "  [안내] 받지 못했습니다: $($r.File) ($($r.Url))" }
    if ($r.Url -match 'arxiv\.org') { Start-Sleep -Seconds 2 }
  }
}
if ($ExampleRows.Count -gt 0) {
  $What = if ($Edition -eq "study") { "MIT OpenCourseWare 인공지능 강의자료 $($ExampleRows.Count)개" } else { "검색 증강 생성(RAG) 분야 공개 논문 $($ExampleRows.Count)편" }
  Write-Host "`n예시 자료"
  if (AskYes "  바로 시험해 볼 수 있게 예시 자료($What, 약 10MB)를 받아 둘까요?" $env:LLM_WIKI_EXAMPLES) { $Lines += @(Get-ExampleRows $ExampleRows) }
}
if ($BenchRows.Count -gt 0) {
  Write-Host "`n벤치마크 자료 (선택): RAG 대표 논문 $($BenchRows.Count)편, 약 60MB, 2~3분"
  Write-Host "  한 채팅에 다 담기 어려운 양의 논문에서 위키가 얼마나 정확한지 직접 비교해 볼 때 씁니다."
  $WantBench = $false
  if ($env:LLM_WIKI_BENCHMARK) { $WantBench = $env:LLM_WIKI_BENCHMARK -match '^(y|yes|1|true)$' }
  elseif ($Interactive) { $WantBench = (Ask "  벤치마크 논문도 받을까요? (나중에 Codex에서 `$wiki-examples 로도 받을 수 있습니다) [y/N]" "n") -match '^(y|yes|예|ㅇ)' }
  if ($WantBench) { $Lines += @(Get-ExampleRows $BenchRows) }
}
$GotExamples = @($Lines | Where-Object { $_.StartsWith("- **") }).Count
if ($GotExamples -gt 0) { [IO.File]::WriteAllLines((Join-Path $Dest "예시 자료 출처.md"), $Lines, (New-Object Text.UTF8Encoding $false)) }

if ($Edition -eq "study") {
  $Put = "강의자료는 $Dest\raw\lectures\<과목>\ , 교재는 $Dest\raw\textbooks\"
  $Next = "`$wiki-quiz      <- 퀴즈로 복습,   `$wiki-exam <- 시험 대비 요약"
} else {
  $Put = "논문 PDF는 $Dest\raw\papers\"
  $Next = "`$wiki-compare   <- 선행연구 비교표,   `$wiki-novelty <- 아이디어 중복 확인"
}
if ($GotExamples -gt 0) { $Put = "(예시 자료가 이미 들어 있으니 이 단계는 건너뛰어도 됩니다.) $Put" }
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
if (-not $env:LLM_WIKI_NO_OPEN) {
  if ($Obsidian -eq "yes" -and $ObsExe -and $Full) {
    Start-Process ("obsidian://open?path=" + [uri]::EscapeDataString((Join-Path $Full "wiki\index.md")))
  } else { Start-Process explorer.exe $Dest }
}
}
