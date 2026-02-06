#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/bootstrap.sh [--install]

Options:
  --install   감지된 OS에 맞춰 설치 명령을 실행합니다.
USAGE
}

INSTALL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install)
      INSTALL=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "알 수 없는 인자: $1"
      usage
      exit 1
      ;;
  esac
done

has() {
  command -v "$1" >/dev/null 2>&1
}

version_ge() {
  local IFS=.
  local i
  local ver1=($1)
  local ver2=($2)

  for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
    ver1[i]=0
  done

  for ((i=0; i<${#ver1[@]}; i++)); do
    if [[ -z ${ver2[i]} ]]; then
      ver2[i]=0
    fi
    if ((10#${ver1[i]} > 10#${ver2[i]})); then
      return 0
    fi
    if ((10#${ver1[i]} < 10#${ver2[i]})); then
      return 1
    fi
  done

  return 0
}

node_version_ok() {
  local version=$1
  local major minor
  major=${version%%.*}
  minor=${version#*.}
  minor=${minor%%.*}

  if ((major > 22)); then
    return 0
  fi
  if ((major == 22 && minor >= 12)); then
    return 0
  fi
  if ((major == 20 && minor >= 19)); then
    return 0
  fi
  return 1
}

go_version() {
  local raw
  raw=$(go version 2>/dev/null | awk '{print $3}')
  echo "${raw#go}"
}

wails_version() {
  local raw
  raw=$(wails version 2>/dev/null | grep -Eo 'v[0-9]+(\\.[0-9]+){1,2}' | head -n1)
  echo "${raw#v}"
}

OS_NAME="$(uname -s)"
if [[ "$OS_NAME" == "Darwin" ]]; then
  PLATFORM="macos"
elif [[ "$OS_NAME" == "Linux" ]]; then
  PLATFORM="linux"
else
  PLATFORM="unknown"
fi

echo "Detected OS: ${PLATFORM}"

missing=()
outdated=()

if has go; then
  go_ver=$(go_version)
  echo "Go: ${go_ver} (required >= 1.25)"
  if ! version_ge "$go_ver" "1.25.0"; then
    outdated+=("go")
  fi
else
  missing+=("go")
fi

if has node; then
  node_ver=$(node -v)
  node_ver=${node_ver#v}
  echo "Node: v${node_ver} (required 20.19+ or 22.12+)"
  if ! node_version_ok "$node_ver"; then
    outdated+=("node")
  fi
else
  missing+=("node")
fi

if has pnpm; then
  echo "pnpm: $(pnpm -v)"
else
  missing+=("pnpm")
fi

if has wails; then
  wails_ver=$(wails_version)
  if [[ -n "$wails_ver" ]]; then
    echo "Wails: v${wails_ver} (required >= 2.0)"
    if ! version_ge "$wails_ver" "2.0.0"; then
      outdated+=("wails")
    fi
  else
    echo "Wails: detected (version unknown)"
  fi
else
  missing+=("wails")
fi

if [[ ${#missing[@]} -eq 0 && ${#outdated[@]} -eq 0 ]]; then
  echo "All required tools are installed."
  exit 0
fi

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "Missing tools: ${missing[*]}"
fi
if [[ ${#outdated[@]} -gt 0 ]]; then
  echo "Outdated tools: ${outdated[*]}"
fi

pm=""
if [[ "$PLATFORM" == "macos" ]]; then
  if has brew; then
    pm="brew"
  else
    echo "Homebrew가 필요합니다: https://brew.sh"
  fi
elif [[ "$PLATFORM" == "linux" ]]; then
  if has apt-get; then
    pm="apt"
  elif has dnf; then
    pm="dnf"
  elif has pacman; then
    pm="pacman"
  else
    echo "지원되는 패키지 매니저(apt, dnf, pacman)를 찾지 못했습니다."
  fi
else
  echo "이 스크립트는 macOS/WSL/Linux에서 사용하세요."
fi

if [[ "$pm" == "apt" || "$pm" == "dnf" || "$pm" == "pacman" ]]; then
  echo "주의: 배포판 패키지의 Node 버전이 요구사항(20.19+/22.12+)보다 낮을 수 있습니다."
fi

commands=()
needs=()
if [[ ${#missing[@]} -gt 0 ]]; then
  needs+=("${missing[@]}")
fi
if [[ ${#outdated[@]} -gt 0 ]]; then
  needs+=("${outdated[@]}")
fi

case "$pm" in
  brew)
    if [[ " ${needs[*]} " == *" go "* ]]; then
      commands+=("brew install go")
    fi
    if [[ " ${needs[*]} " == *" node "* ]]; then
      commands+=("brew install node")
    fi
    if [[ " ${needs[*]} " == *" pnpm "* ]]; then
      commands+=("corepack enable pnpm")
      commands+=("corepack prepare pnpm@latest --activate")
    fi
    if [[ " ${needs[*]} " == *" wails "* ]]; then
      commands+=("go install github.com/wailsapp/wails/v2/cmd/wails@latest")
    fi
    ;;
  apt)
    if [[ " ${needs[*]} " == *" go "* ]]; then
      commands+=("sudo apt-get update")
      commands+=("sudo apt-get install -y golang-go")
    fi
    if [[ " ${needs[*]} " == *" node "* ]]; then
      commands+=("sudo apt-get install -y nodejs npm")
    fi
    if [[ " ${needs[*]} " == *" pnpm "* ]]; then
      commands+=("corepack enable pnpm")
      commands+=("corepack prepare pnpm@latest --activate")
    fi
    if [[ " ${needs[*]} " == *" wails "* ]]; then
      commands+=("go install github.com/wailsapp/wails/v2/cmd/wails@latest")
    fi
    ;;
  dnf)
    if [[ " ${needs[*]} " == *" go "* ]]; then
      commands+=("sudo dnf install -y golang")
    fi
    if [[ " ${needs[*]} " == *" node "* ]]; then
      commands+=("sudo dnf install -y nodejs")
    fi
    if [[ " ${needs[*]} " == *" pnpm "* ]]; then
      commands+=("corepack enable pnpm")
      commands+=("corepack prepare pnpm@latest --activate")
    fi
    if [[ " ${needs[*]} " == *" wails "* ]]; then
      commands+=("go install github.com/wailsapp/wails/v2/cmd/wails@latest")
    fi
    ;;
  pacman)
    if [[ " ${needs[*]} " == *" go "* ]]; then
      commands+=("sudo pacman -Sy --noconfirm go")
    fi
    if [[ " ${needs[*]} " == *" node "* ]]; then
      commands+=("sudo pacman -Sy --noconfirm nodejs")
    fi
    if [[ " ${needs[*]} " == *" pnpm "* ]]; then
      commands+=("corepack enable pnpm")
      commands+=("corepack prepare pnpm@latest --activate")
    fi
    if [[ " ${needs[*]} " == *" wails "* ]]; then
      commands+=("go install github.com/wailsapp/wails/v2/cmd/wails@latest")
    fi
    ;;
  *)
    ;;
esac

if [[ ${#commands[@]} -eq 0 ]]; then
  echo "No install commands were generated."
  exit 0
fi

if [[ $INSTALL -eq 0 ]]; then
  echo "Suggested install commands:"
  for cmd in "${commands[@]}"; do
    echo "  $cmd"
  done
  echo "Run with --install to execute automatically."
  exit 0
fi

for cmd in "${commands[@]}"; do
  echo ">> $cmd"
  eval "$cmd"
done

echo "If 'wails' is still not found, open a new terminal and ensure GOPATH/bin is in PATH."
