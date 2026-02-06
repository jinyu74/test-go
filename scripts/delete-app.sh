#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/delete-app.sh --name "my-app" [--force] [--skip-work]

Options:
  --name       삭제할 앱/서비스 이름 (필수, apps/<name>)
  --force      확인 없이 삭제
  --skip-work  go work edit -dropuse 실행 생략
USAGE
}

NAME=""
FORCE=0
SKIP_WORK=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      NAME="$2"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --skip-work)
      SKIP_WORK=1
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

if [[ -z "$NAME" ]]; then
  echo "--name 인자가 필요합니다."
  usage
  exit 1
fi

if [[ "$NAME" == *"/"* || "$NAME" == *"\\"* || "$NAME" == ".." ]]; then
  echo "잘못된 이름입니다: $NAME"
  exit 1
fi

if [[ ! "$NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]]; then
  echo "이름은 영문/숫자/.-_만 사용할 수 있습니다: $NAME"
  exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
TARGET="$REPO_ROOT/apps/$NAME"

if [[ ! -d "$TARGET" ]]; then
  echo "존재하지 않는 경로입니다: apps/$NAME"
  exit 1
fi

if [[ $FORCE -eq 0 ]]; then
  read -r -p "apps/$NAME 을(를) 삭제할까요? (y/N) " answer
  case "$answer" in
    y|Y|yes|YES)
      ;;
    *)
      echo "취소했습니다."
      exit 0
      ;;
  esac
fi

rm -rf "$TARGET"

if [[ $SKIP_WORK -eq 0 ]]; then
  if command -v go >/dev/null 2>&1 && [[ -f "$REPO_ROOT/go.work" ]]; then
    (cd "$REPO_ROOT" && go work edit -dropuse=./apps/$NAME) || {
      echo "경고: go work edit -dropuse 실패. 수동으로 go.work를 확인하세요." >&2
    }
  fi
fi

echo "삭제 완료: apps/$NAME"
