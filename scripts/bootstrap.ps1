Param(
  [switch]$Install
)

$ErrorActionPreference = "Stop"

function Test-Command {
  Param([Parameter(Mandatory = $true)][string]$Name)

  return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Refresh-Path {
  $machine = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
  $user = [System.Environment]::GetEnvironmentVariable("Path", "User")
  $env:Path = "$machine;$user"
}

function To-Version {
  Param([Parameter(Mandatory = $true)][string]$Text)

  if ($Text -match '([0-9]+\.[0-9]+(\.[0-9]+)?)') {
    $value = $matches[1]
    if ($value -match '^[0-9]+\.[0-9]+$') {
      $value = "$value.0"
    }
    return [version]$value
  }

  return $null
}

function Test-GoVersion {
  Param([Parameter(Mandatory = $true)][string]$Text)

  $ver = To-Version $Text
  if ($null -eq $ver) {
    return $false
  }

  return ($ver.Major -gt 1) -or ($ver.Major -eq 1 -and $ver.Minor -ge 25)
}

function Test-NodeVersion {
  Param([Parameter(Mandatory = $true)][string]$Text)

  $ver = To-Version $Text
  if ($null -eq $ver) {
    return $false
  }

  if ($ver.Major -gt 22) {
    return $true
  }

  if ($ver.Major -eq 22 -and $ver.Minor -ge 12) {
    return $true
  }

  if ($ver.Major -eq 20 -and $ver.Minor -ge 19) {
    return $true
  }

  return $false
}

function Test-WailsVersion {
  Param([Parameter(Mandatory = $true)][string]$Text)

  $ver = To-Version $Text
  if ($null -eq $ver) {
    return $false
  }

  return $ver.Major -ge 2
}

$osName = if ($IsWindows) {
  "windows"
} elseif ($IsMacOS) {
  "macos"
} else {
  "linux"
}

Write-Host "Detected OS: $osName"

$missing = @()
$outdated = @()

if (Test-Command "go") {
  $goText = (go version)
  Write-Host "Go: $goText (required >= 1.25)"
  if (-not (Test-GoVersion $goText)) {
    $outdated += "go"
  }
} else {
  $missing += "go"
}

if (Test-Command "node") {
  $nodeText = (node -v)
  Write-Host "Node: $nodeText (required 20.19+ or 22.12+)"
  if (-not (Test-NodeVersion $nodeText)) {
    $outdated += "node"
  }
} else {
  $missing += "node"
}

if (Test-Command "pnpm") {
  Write-Host "pnpm: $(pnpm -v)"
} else {
  $missing += "pnpm"
}

if (Test-Command "wails") {
  $wailsText = (wails version)
  Write-Host "Wails: $wailsText (required >= 2.0)"
  if (-not (Test-WailsVersion $wailsText)) {
    $outdated += "wails"
  }
} else {
  $missing += "wails"
}

if ($missing.Count -eq 0 -and $outdated.Count -eq 0) {
  Write-Host "All required tools are installed."
  exit 0
}

if ($missing.Count -gt 0) {
  Write-Host "Missing tools: $($missing -join ', ')"
}
if ($outdated.Count -gt 0) {
  Write-Host "Outdated tools: $($outdated -join ', ')"
}

$commands = @()
$needs = @()
$needs += $missing
$needs += $outdated
$needs = $needs | Select-Object -Unique

if ($IsWindows) {
  $hasWinget = Test-Command "winget"
  if (-not $hasWinget) {
    Write-Host "winget not found. Install 'App Installer' from Microsoft Store or use manual installs."
  }

  if ($needs -contains "go") {
    if ($hasWinget) {
      if ($outdated -contains "go") {
        $commands += "winget upgrade -e --id GoLang.Go"
      } else {
        $commands += "winget install -e --id GoLang.Go"
      }
    } else {
      $commands += "# Install Go from https://go.dev/dl/"
    }
  }

  if ($needs -contains "node") {
    if ($hasWinget) {
      if ($outdated -contains "node") {
        $commands += "winget upgrade -e --id OpenJS.NodeJS.LTS"
      } else {
        $commands += "winget install -e --id OpenJS.NodeJS.LTS"
      }
    } else {
      $commands += "# Install Node.js LTS from https://nodejs.org/"
    }
  }

  if ($needs -contains "pnpm") {
    $commands += "corepack enable pnpm"
    $commands += "corepack prepare pnpm@latest --activate"
  }

  if ($needs -contains "wails") {
    $commands += "go install github.com/wailsapp/wails/v2/cmd/wails@latest"
  }
} else {
  Write-Host "This script is intended for Windows only. Use scripts/bootstrap.sh on macOS/WSL."
}

if ($commands.Count -eq 0) {
  Write-Host "No install commands were generated."
  exit 0
}

if (-not $Install) {
  Write-Host "Suggested install commands:"
  $commands | ForEach-Object { Write-Host "  $_" }
  Write-Host "Run with -Install to execute automatically."
  exit 0
}

foreach ($command in $commands) {
  Write-Host ">> $command"
  if ($command.StartsWith("#")) {
    continue
  }

  Invoke-Expression $command

  if ($command -match "winget install") {
    Refresh-Path
  }
}

if (Test-Command "go") {
  $gopath = (go env GOPATH)
  if ($gopath) {
    $gobin = Join-Path $gopath "bin"
    if (-not ($env:Path -split ';' | Where-Object { $_ -eq $gobin })) {
      $env:Path = "$env:Path;$gobin"
      Write-Host "Added GOPATH\\bin to PATH for this session. Open a new terminal for permanent PATH updates."
    }
  }
}
