Param(
  [Parameter(Mandatory = $true)]
  [string]$Name,
  [switch]$Force,
  [switch]$SkipWork
)

$ErrorActionPreference = "Stop"

if ($Name -match "[\\/]") {
  Write-Host "잘못된 이름입니다: $Name"
  exit 1
}

if ($Name -eq ".." -or $Name -eq ".") {
  Write-Host "잘못된 이름입니다: $Name"
  exit 1
}

if ($Name -notmatch '^[a-zA-Z0-9][a-zA-Z0-9._-]*$') {
  Write-Host "이름은 영문/숫자/.-_만 사용할 수 있습니다: $Name"
  exit 1
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$target = Join-Path $repoRoot (Join-Path "apps" $Name)

if (-not (Test-Path $target)) {
  Write-Host "존재하지 않는 경로입니다: apps/$Name"
  exit 1
}

if (-not $Force) {
  $answer = Read-Host "apps/$Name 을(를) 삭제할까요? (y/N)"
  if ($answer -notmatch '^(y|Y|yes|YES)$') {
    Write-Host "취소했습니다."
    exit 0
  }
}

Remove-Item -Path $target -Recurse -Force

if (-not $SkipWork) {
  if (Get-Command go -ErrorAction SilentlyContinue) {
    $workFile = Join-Path $repoRoot "go.work"
    if (Test-Path $workFile) {
      Push-Location $repoRoot
      try {
        & go work edit -dropuse=./apps/$Name | Out-Null
      } catch {
        Write-Host "경고: go work edit -dropuse 실패. 수동으로 go.work를 확인하세요." 1>&2
      } finally {
        Pop-Location
      }
    }
  }
}

Write-Host "삭제 완료: apps/$Name"
