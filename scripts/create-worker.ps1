Param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

$ErrorActionPreference = "Stop"

if ($Args.Count -eq 0) {
  Write-Host "Usage:"
  Write-Host "  pwsh -File scripts/create-worker.ps1 --name \"sftp-monitor\" --module-base \"github.com/your-org/my-app\""
  exit 1
}

if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
  Write-Host "go가 설치되어 있지 않습니다. 먼저 설치 후 다시 실행하세요."
  exit 1
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Push-Location $repoRoot
try {
  & go run ./tools/scaffold @Args --type service
} finally {
  Pop-Location
}
