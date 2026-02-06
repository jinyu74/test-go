#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/create-app.sh --name "my-app" --module-base "github.com/your-org/my-app" --product "My App" --company "Your Company"

Options:
  --name         앱 이름 (필수, kebab-case 권장)
  --module-base  Go 모듈 기본 경로 (미지정 시 go.mod에서 추론)
  --product      Wails 앱 표시 이름
  --company      Wails 회사 이름 (기본값: Your Company)
  --skip-work    go work use 실행 생략
  --force        대상 디렉터리 덮어쓰기
USAGE
}

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

if ! command -v go >/dev/null 2>&1; then
  echo "go가 설치되어 있지 않습니다. 먼저 설치 후 다시 실행하세요."
  exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

cd "$REPO_ROOT"

go run ./tools/scaffold "$@" --type wails
