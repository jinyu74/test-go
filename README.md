# project-go monorepo

Windows 환경에서 Go + Wails 데스크톱 앱을 빠르게 시작하기 위한 모노레포 보일러플레이트입니다.

워크스페이스 구성
요약: 모든 앱/서비스는 `apps/<name>` 아래에 배치하고, 공유 코드는 `libs/shared`를 사용합니다.
- `apps/desktop`: 기본 Wails 데스크톱 앱 (Go 백엔드 + 프론트엔드)
- `apps/<name>`: 추가 Wails 앱 또는 헤드리스 서비스
- `libs/shared`: 공유 Go 패키지
- `go.work`: Go 워크스페이스 구성 파일

개발환경 설정
요약: `scripts/bootstrap`으로 설치/버전 점검을 자동화하고, 필요 시 수동 설치 절차를 따릅니다.
요구사항
- Go 1.25+
- Node.js 20.19+ 또는 22.12+
- `pnpm`
- Wails CLI v2

환경 점검/설치 CLI
아래 스크립트는 OS를 감지해 Go/Node/pnpm/Wails 설치 여부와 버전(Go 1.25+, Node 20.19+/22.12+, Wails v2)을 확인하고, 설치/업데이트 명령을 안내하거나 실행합니다.

Windows (PowerShell)
```
pwsh -File scripts/bootstrap.ps1
pwsh -File scripts/bootstrap.ps1 -Install
```

macOS/WSL
```
./scripts/bootstrap.sh
./scripts/bootstrap.sh --install
```

메모
- `--install`은 Homebrew(macOS) 또는 apt/dnf/pacman(WSL/Linux)을 사용합니다.
- WSL/Linux는 배포판 패키지의 Node 버전이 낮을 수 있으니 요구사항(20.19+/22.12+)을 확인하세요.
- 설치 직후 `wails` 명령이 보이지 않으면 새 터미널을 열고 `GOPATH/bin`이 `PATH`에 포함됐는지 확인하세요.

macOS 수동 설치 (Homebrew)
1. Homebrew 설치: https://brew.sh
2. Go/Node 설치
```
brew install go node
```
3. pnpm 활성화
```
corepack enable pnpm
corepack prepare pnpm@latest --activate
```
4. Wails CLI 설치 및 점검
```
go install github.com/wailsapp/wails/v2/cmd/wails@latest
wails doctor
```

Windows 설치 가이드 (PowerShell)
1. Go 설치: `go.dev/dl`에서 Windows 인스톨러를 내려받아 설치 후 새 PowerShell을 열고 확인합니다.
```
go version
```
2. Node.js 설치: Node.js 20.19+ 또는 22.12+를 설치하고 확인합니다.
```
node -v
```
3. pnpm 설치: Windows에서는 Corepack 사용이 권장됩니다. Corepack을 활성화하고 pnpm을 준비합니다.
```
corepack enable pnpm
corepack prepare pnpm@latest --activate
```
4. Wails CLI 설치: Go로 Wails CLI를 설치하고 의존성 점검을 실행합니다. `wails` 명령이 없다고 나오면 `go/bin`이 `PATH`에 포함됐는지 확인하고 터미널을 다시 여세요.
```
go install github.com/wailsapp/wails/v2/cmd/wails@latest
wails doctor
```
5. WebView2 Runtime 확인: `wails doctor`가 안내하는 경우 Microsoft WebView2 Runtime을 설치합니다.

선택 사항 (Windows)
- UPX: 실행 파일 압축
- NSIS: Windows 설치 프로그램 생성

프로젝트 생성 (템플릿 기반)
1. 이 레포를 템플릿으로 복제하거나 클론합니다.
```
git clone <YOUR_REPO_URL> my-app
cd my-app
```
2. 초기화 CLI로 모듈 경로와 메타 정보를 설정합니다.

PowerShell (Windows)
```
pwsh -ExecutionPolicy Bypass -File scripts/init.ps1 -ModulePath "github.com/your-org/my-app" -ProductName "My App" -CompanyName "Your Company" -BinaryName "my-app"
```

WSL/macOS
```
chmod +x scripts/init.sh
./scripts/init.sh --module "github.com/your-org/my-app" --product "My App" --company "Your Company" --binary "my-app"
```
3. 필요하다면 `apps/desktop/wails.json`과 프론트엔드 텍스트를 추가로 수정합니다.

초기화 CLI 설명
- `-ModulePath`: Go 모듈 기본 경로 (예: `github.com/your-org/my-app`)
- `-ProductName`: Wails 앱 표시 이름과 창 제목
- `-CompanyName`: Wails 앱 회사 정보
- `-BinaryName`: 빌드 결과 파일 이름과 앱 식별자
- `--module`: Go 모듈 기본 경로 (WSL/macOS)
- `--product`: Wails 앱 표시 이름과 창 제목 (WSL/macOS)
- `--company`: Wails 앱 회사 정보 (WSL/macOS)
- `--binary`: 빌드 결과 파일 이름과 앱 식별자 (WSL/macOS)

메모 (PowerShell)
- `pwsh`가 없다면 `powershell`로 동일하게 실행 가능합니다.
- WSL/macOS 스크립트는 `python3`를 사용합니다.
- 초기화 스크립트는 `apps`/`libs` 하위 `go.mod`와 `.go` 파일의 기본 모듈 경로를 일괄 변경합니다.

macOS 개발 흐름 (로컬 개발)
1. 환경 점검: `./scripts/bootstrap.sh`
2. 필요 시 설치: `./scripts/bootstrap.sh --install`
3. 의존성 설치: `pnpm -C apps/desktop/frontend install`
4. 개발 실행: `cd apps/desktop` 후 `wails dev`
5. 문제가 있으면 `wails doctor`로 점검하세요.

빠른 시작 (Windows PowerShell)
1. `cd apps/desktop`
2. `pnpm -C frontend install`
3. `wails dev`

팀 온보딩 체크리스트
- [ ] 레포 클론 및 이동: `git clone ...` / `cd ...`
- [ ] 초기화 실행: `scripts/init.ps1` 또는 `scripts/init.sh`
- [ ] 환경 점검/설치: `scripts/bootstrap.ps1` 또는 `scripts/bootstrap.sh`
- [ ] 프론트 의존성 설치: `pnpm -C apps/desktop/frontend install`
- [ ] 기본 앱 실행: `cd apps/desktop` 후 `wails dev`
- [ ] 필요 시 앱/워커 생성: `create-app` 또는 `create-worker`
- [ ] 원격 푸시 후 CI 결과 확인

서비스/워커 생성
요약: 헤드리스 서비스는 `create-worker`, Wails 앱은 `create-app`을 사용합니다.
macOS/WSL
```
./scripts/create-worker.sh --name "sftp-monitor" --module-base "github.com/your-org/my-app"
./scripts/create-app.sh --name "link-server" --module-base "github.com/your-org/my-app" --product "Link Server" --company "Your Company"
```

Windows (PowerShell)
```
pwsh -File scripts/create-worker.ps1 --name "sftp-monitor" --module-base "github.com/your-org/my-app"
pwsh -File scripts/create-app.ps1 --name "link-server" --module-base "github.com/your-org/my-app" --product "Link Server" --company "Your Company"
```

Go 기반 직접 실행 (모든 OS)
```
go run ./tools/scaffold --name "sftp-monitor" --type service --module-base "github.com/your-org/my-app"
```

옵션 요약
- `--name`: 생성할 서비스/앱 이름 (필수)
- `--type`: `service` 또는 `wails` (Go CLI 직접 실행 시)
- `--module-base`: 모듈 기본 경로 (미지정 시 `apps/desktop/go.mod` 또는 `libs/shared/go.mod`에서 추론)
- `--product`, `--company`: Wails 앱 메타 정보
- `--skip-work`: `go work use` 실행 생략
- `--force`: 대상 디렉터리가 있어도 덮어쓰기

서비스/워커 삭제
요약: `apps/<name>` 경로를 안전하게 삭제하고 `go.work`에서도 제거합니다.

macOS/WSL
```
./scripts/delete-worker.sh --name "sftp-monitor"
./scripts/delete-app.sh --name "link-server" --force
```

Windows (PowerShell)
```
pwsh -File scripts/delete-worker.ps1 -Name "sftp-monitor"
pwsh -File scripts/delete-app.ps1 -Name "link-server" -Force
```

옵션 요약
- `--force` / `-Force`: 확인 없이 삭제
- `--skip-work` / `-SkipWork`: `go work edit -dropuse` 실행 생략

생성 경로
- `service`: `apps/<name>`
- `wails`: `apps/<name>`

메모
- `go work use`가 실패하면 `go work use ./apps/<name>`을 수동으로 실행하세요.
- 다른 Go 모듈을 추가하려면 모듈을 만든 뒤, 레포 루트에서 `go work use ./path/to/module`을 실행하세요.

테스트/빌드
요약: 로컬은 `wails build`로 빌드하고, Windows 빌드는 GitHub Actions를 사용합니다.
빌드 (PowerShell)
1. `cd apps/desktop`
2. `pnpm -C frontend build`
3. `wails build`

GitHub Actions (Windows 빌드/릴리스)
1. CI 빌드: `main` 브랜치에 push/PR 시 `.github/workflows/windows-ci.yml`이 실행되며 빌드 산출물을 Actions Artifact로 업로드합니다.
2. 릴리스: `v*` 태그를 push 하면 `.github/workflows/windows-release.yml`이 실행되어 GitHub Release에 zip 파일을 업로드합니다.
3. 릴리스 태그 예시 (macOS/WSL)
```
git tag v0.1.0
git push origin v0.1.0
```
4. 브랜치 이름이나 Node/Go 버전은 워크플로 파일에서 변경하세요.
5. CI 아티팩트 확인: GitHub > Actions > Windows Build (CI) > 해당 실행 > Artifacts 에서 다운로드합니다.
6. 릴리스 파일 확인: GitHub > Releases에서 zip 파일을 내려받습니다.

릴리스 아티팩트 이름 규칙
- `apps/desktop/wails.json`의 `outputfilename`을 기준으로 `<binary>-<tag>-windows-amd64.zip` 형식으로 생성됩니다.

CI/릴리스 메모
- WebView2 Runtime을 자동으로 포함하고 싶다면 `wails build`에 `-webview2` 옵션을 추가하세요.
- 릴리스 zip에는 `apps/desktop/build/bin`의 결과물을 포함합니다. 필요하면 `windows-release.yml`의 `Compress-Archive` 경로를 조정하세요.

개발/빌드 메모
- `frontend:dev:watcher`는 `vite build --watch`를 사용하여 `frontend/dist`에 빌드 산출물을 만들고, Wails는 그 자산을 로딩합니다.
- 실제 레포 경로가 정해지면 `scripts/init.ps1`를 사용하거나 `apps/desktop/go.mod`와 `libs/shared/go.mod`의 모듈 경로를 교체하세요.
