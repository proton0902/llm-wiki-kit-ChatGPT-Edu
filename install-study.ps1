# 학습용 LLM Wiki 설치 (Windows):  irm https://raw.githubusercontent.com/proton0902/llm-wiki-kit-ChatGPT-Edu/main/install-study.ps1 | iex
$env:LLM_WIKI_EDITION = "study"
irm https://raw.githubusercontent.com/proton0902/llm-wiki-kit-ChatGPT-Edu/main/install.ps1 | iex
Remove-Item Env:LLM_WIKI_EDITION -ErrorAction SilentlyContinue
