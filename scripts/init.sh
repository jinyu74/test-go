#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/init.sh --module "github.com/your-org/my-app" \
    --product "My App" \
    --company "Your Company" \
    --binary "my-app"

Options:
  --module   Go 모듈 기본 경로 (필수)
  --product  앱 표시 이름 (기본값: Project Go)
  --company  회사 이름 (기본값: Your Company)
  --binary   빌드 결과 파일 이름 (기본값: project-go)
USAGE
}

MODULE_PATH=""
PRODUCT_NAME="Project Go"
COMPANY_NAME="Your Company"
BINARY_NAME="project-go"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3가 필요합니다. python3를 설치한 뒤 다시 실행하세요."
  exit 1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --module)
      MODULE_PATH="$2"
      shift 2
      ;;
    --product)
      PRODUCT_NAME="$2"
      shift 2
      ;;
    --company)
      COMPANY_NAME="$2"
      shift 2
      ;;
    --binary)
      BINARY_NAME="$2"
      shift 2
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

if [[ -z "${MODULE_PATH}" ]]; then
  echo "--module 인자가 필요합니다."
  usage
  exit 1
fi

# Defaults are chosen for the current boilerplate; override them to match your project.

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DESKTOP_GO_MOD="$REPO_ROOT/apps/desktop/go.mod"
SHARED_GO_MOD="$REPO_ROOT/libs/shared/go.mod"
WAILS_JSON="$REPO_ROOT/apps/desktop/wails.json"
MAIN_GO="$REPO_ROOT/apps/desktop/main.go"
INDEX_HTML="$REPO_ROOT/apps/desktop/frontend/index.html"
MAIN_JS="$REPO_ROOT/apps/desktop/frontend/src/main.js"

if [[ ! -f "$DESKTOP_GO_MOD" ]]; then
  echo "apps/desktop/go.mod not found. Run this script from the repo root."
  exit 1
fi

export REPO_ROOT MODULE_PATH PRODUCT_NAME COMPANY_NAME BINARY_NAME

python3 - <<'PY'
import json
import os
import re
from pathlib import Path

repo_root = Path(os.environ["REPO_ROOT"])
module_base = os.environ["MODULE_PATH"].rstrip("/")
product_name = os.environ["PRODUCT_NAME"]
company_name = os.environ["COMPANY_NAME"]
binary_name = os.environ["BINARY_NAME"]

def replace_in_file(path: Path, pattern: str, replacement: str, regex: bool = False) -> None:
    if not path.exists():
        return
    data = path.read_text()
    if regex:
        updated = re.sub(pattern, replacement, data)
    else:
        updated = data.replace(pattern, replacement)
    if updated != data:
        path.write_text(updated)

def should_skip(path: Path) -> bool:
    skip_parts = {"frontend", "node_modules", "dist", "build", "wailsjs"}
    return any(part in skip_parts for part in path.parts)

def replace_module_base(root: Path) -> None:
    if not root.exists():
        return
    for path in root.rglob("go.mod"):
        if should_skip(path):
            continue
        replace_in_file(path, "example.com/project-go", module_base)
    for path in root.rglob("*.go"):
        if should_skip(path):
            continue
        replace_in_file(path, "example.com/project-go", module_base)

replace_module_base(repo_root / "apps")
replace_module_base(repo_root / "libs")
replace_in_file(repo_root / "tools/go.mod", "example.com/project-go", module_base)

wails_path = repo_root / "apps/desktop/wails.json"
if wails_path.exists():
    with wails_path.open() as handle:
        config = json.load(handle)
    config["name"] = binary_name
    config["outputfilename"] = binary_name
    info = config.get("info") or {}
    info["productName"] = product_name
    info["companyName"] = company_name
    config["info"] = info
    wails_path.write_text(json.dumps(config, indent=2, ensure_ascii=False) + "\n")

replace_in_file(repo_root / "apps/desktop/main.go", "Project Go", product_name)
replace_in_file(repo_root / "apps/desktop/frontend/index.html", "<title>Project Go</title>", f"<title>{product_name}</title>")
replace_in_file(repo_root / "apps/desktop/frontend/src/main.js", "Project Go", product_name)

print("Initialized project settings:")
print(f"- Module path: {module_base}")
print(f"- Product name: {product_name}")
print(f"- Company name: {company_name}")
print(f"- Binary name: {binary_name}")
PY
