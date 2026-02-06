Param(
  [Parameter(Mandatory = $true)]
  [string]$ModulePath,
  [string]$ProductName = "Project Go",
  [string]$CompanyName = "Your Company",
  [string]$BinaryName = "project-go"
)

$ErrorActionPreference = "Stop"

# Defaults are chosen for the current boilerplate; override them to match your project.

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$desktopGoMod = Join-Path $repoRoot "apps/desktop/go.mod"
$sharedGoMod = Join-Path $repoRoot "libs/shared/go.mod"
$toolsGoMod = Join-Path $repoRoot "tools/go.mod"
$wailsJsonPath = Join-Path $repoRoot "apps/desktop/wails.json"
$mainGoPath = Join-Path $repoRoot "apps/desktop/main.go"
$indexHtmlPath = Join-Path $repoRoot "apps/desktop/frontend/index.html"
$mainJsPath = Join-Path $repoRoot "apps/desktop/frontend/src/main.js"

if (-not (Test-Path $desktopGoMod)) {
  throw "apps/desktop/go.mod not found. Run this script from the repo root."
}

function Replace-InFile {
  Param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Pattern,
    [Parameter(Mandatory = $true)][string]$Replacement
  )

  if (-not (Test-Path $Path)) {
    return
  }

  $content = Get-Content -Raw -LiteralPath $Path
  $safeReplacement = $Replacement -replace '\$', '$$'
  $updated = [regex]::Replace($content, $Pattern, $safeReplacement)

  if ($updated -ne $content) {
    Set-Content -NoNewline -LiteralPath $Path -Value $updated
  }
}

$moduleBase = $ModulePath.TrimEnd('/')

$skipPattern = "\\\\frontend\\\\|\\\\node_modules\\\\|\\\\dist\\\\|\\\\build\\\\|\\\\wailsjs\\\\"
$appsRoot = Join-Path $repoRoot "apps"
$libsRoot = Join-Path $repoRoot "libs"

foreach ($root in @($appsRoot, $libsRoot)) {
  if (-not (Test-Path $root)) {
    continue
  }

  Get-ChildItem -Path $root -Filter "go.mod" -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch $skipPattern } |
    ForEach-Object { Replace-InFile -Path $_.FullName -Pattern "example\.com/project-go" -Replacement $moduleBase }

  Get-ChildItem -Path $root -Filter "*.go" -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch $skipPattern } |
    ForEach-Object { Replace-InFile -Path $_.FullName -Pattern "example\.com/project-go" -Replacement $moduleBase }
}

Replace-InFile -Path $toolsGoMod -Pattern "example\.com/project-go" -Replacement $moduleBase

if (Test-Path $wailsJsonPath) {
  $wailsConfig = Get-Content -Raw -LiteralPath $wailsJsonPath | ConvertFrom-Json
  $wailsConfig.name = $BinaryName
  $wailsConfig.outputfilename = $BinaryName

  if ($null -eq $wailsConfig.info) {
    $wailsConfig | Add-Member -MemberType NoteProperty -Name info -Value @{}
  }

  $wailsConfig.info.productName = $ProductName
  $wailsConfig.info.companyName = $CompanyName

  $wailsConfig | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $wailsJsonPath
}

Replace-InFile -Path $mainGoPath -Pattern "Title:\s+\"Project Go\"" -Replacement "Title:  \"$ProductName\""
Replace-InFile -Path $indexHtmlPath -Pattern "<title>Project Go</title>" -Replacement "<title>$ProductName</title>"
Replace-InFile -Path $mainJsPath -Pattern "Project Go" -Replacement $ProductName

Write-Host "Initialized project settings:"
Write-Host "- Module path: $moduleBase"
Write-Host "- Product name: $ProductName"
Write-Host "- Company name: $CompanyName"
Write-Host "- Binary name: $BinaryName"
