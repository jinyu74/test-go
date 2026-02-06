package main

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

const (
	goVersion    = "1.25"
	templateApp  = "apps/desktop"
	sharedSuffix = "/shared"
)

type config struct {
	name       string
	appType    string
	moduleBase string
	product    string
	company    string
	skipWork   bool
	force      bool
}

func main() {
	cfg := parseFlags()
	if cfg.name == "" {
		fatal("--name is required")
	}

	appType, err := normalizeType(cfg.appType)
	if err != nil {
		fatal(err.Error())
	}

	repoRoot, err := findRepoRoot()
	if err != nil {
		fatal(err.Error())
	}

	moduleBase := strings.TrimSuffix(cfg.moduleBase, "/")
	if moduleBase == "" {
		moduleBase, err = inferModuleBase(repoRoot)
		if err != nil {
			fatal(err.Error())
		}
		if moduleBase == "" {
			fatal("could not infer module base; pass --module-base")
		}
	}

	product := cfg.product
	if appType == "wails" && product == "" {
		product = titleFromName(cfg.name)
	}

	targetRel := filepath.Join("apps", cfg.name)

	targetAbs := filepath.Join(repoRoot, targetRel)
	if exists(targetAbs) && !cfg.force {
		fatal(fmt.Sprintf("target already exists: %s (use --force to overwrite)", targetRel))
	}

	if appType == "service" {
		err = createService(targetAbs, moduleBase, cfg.name)
	} else {
		err = createWailsApp(repoRoot, targetAbs, moduleBase, cfg.name, product, cfg.company, cfg.force)
	}
	if err != nil {
		fatal(err.Error())
	}

	if !cfg.skipWork {
		err = goWorkUse(repoRoot, targetRel)
		if err != nil {
			fmt.Fprintf(os.Stderr, "warning: go work use failed: %v\n", err)
			fmt.Fprintf(os.Stderr, "run manually: go work use ./%s\n", filepath.ToSlash(targetRel))
		}
	}

	fmt.Printf("Created %s: %s\n", appType, filepath.ToSlash(targetRel))
}

func parseFlags() config {
	var cfg config
	flag.StringVar(&cfg.name, "name", "", "service/app name (kebab-case)")
	flag.StringVar(&cfg.appType, "type", "service", "service|headless|wails")
	flag.StringVar(&cfg.moduleBase, "module-base", "", "Go module base path (ex: github.com/your-org/my-app)")
	flag.StringVar(&cfg.product, "product", "", "Wails product name (default: titleized from name)")
	flag.StringVar(&cfg.company, "company", "Your Company", "Wails company name")
	flag.BoolVar(&cfg.skipWork, "skip-work", false, "skip go work use")
	flag.BoolVar(&cfg.force, "force", false, "overwrite existing target directory")
	flag.Parse()
	return cfg
}

func normalizeType(value string) (string, error) {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "service", "headless":
		return "service", nil
	case "wails", "app":
		return "wails", nil
	default:
		return "", fmt.Errorf("invalid --type: %s (use service|wails)", value)
	}
}

func findRepoRoot() (string, error) {
	cwd, err := os.Getwd()
	if err != nil {
		return "", err
	}

	current := cwd
	for {
		candidate := filepath.Join(current, "go.work")
		if exists(candidate) {
			return current, nil
		}
		parent := filepath.Dir(current)
		if parent == current {
			break
		}
		current = parent
	}

	return "", errors.New("go.work not found; run from repo root")
}

func inferModuleBase(repoRoot string) (string, error) {
	candidates := []string{
		filepath.Join(repoRoot, "apps", "desktop", "go.mod"),
		filepath.Join(repoRoot, "libs", "shared", "go.mod"),
		filepath.Join(repoRoot, "tools", "go.mod"),
	}

	for _, path := range candidates {
		mod, err := readModulePath(path)
		if err != nil || mod == "" {
			continue
		}
		base := deriveBase(mod)
		if base == "" {
			continue
		}
		if strings.Contains(base, "example.com/project-go") {
			fmt.Fprintln(os.Stderr, "warning: module base looks like a placeholder; pass --module-base to override")
		}
		return base, nil
	}

	return "", errors.New("module base not found; pass --module-base")
}

func readModulePath(path string) (string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}
	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		trim := strings.TrimSpace(line)
		if strings.HasPrefix(trim, "module ") {
			return strings.TrimSpace(strings.TrimPrefix(trim, "module ")), nil
		}
	}
	return "", nil
}

func deriveBase(modulePath string) string {
	if idx := strings.LastIndex(modulePath, "/apps/"); idx != -1 {
		return modulePath[:idx]
	}
	if strings.HasSuffix(modulePath, sharedSuffix) {
		return strings.TrimSuffix(modulePath, sharedSuffix)
	}
	if strings.HasSuffix(modulePath, "/tools") {
		return strings.TrimSuffix(modulePath, "/tools")
	}
	return ""
}

func createService(targetAbs, moduleBase, name string) error {
	modulePath := fmt.Sprintf("%s/apps/%s", moduleBase, name)

	cmdDir := filepath.Join(targetAbs, "cmd", name)
	if err := os.MkdirAll(cmdDir, 0o755); err != nil {
		return err
	}

	goMod := fmt.Sprintf("module %s\n\ngo %s\n", modulePath, goVersion)
	if err := os.WriteFile(filepath.Join(targetAbs, "go.mod"), []byte(goMod), 0o644); err != nil {
		return err
	}

	mainGo := fmt.Sprintf("package main\n\nimport \"log\"\n\nfunc main() {\n\tlog.Println(\"%s starting...\")\n}\n", name)
	return os.WriteFile(filepath.Join(cmdDir, "main.go"), []byte(mainGo), 0o644)
}

func createWailsApp(repoRoot, targetAbs, moduleBase, name, product, company string, force bool) error {
	templateRoot := filepath.Join(repoRoot, templateApp)
	if !exists(templateRoot) {
		return fmt.Errorf("template app not found: %s", templateApp)
	}
	if exists(targetAbs) {
		if !force {
			return fmt.Errorf("target exists: %s", targetAbs)
		}
		if err := os.RemoveAll(targetAbs); err != nil {
			return err
		}
	}

	if err := copyDir(templateRoot, targetAbs); err != nil {
		return err
	}

	appGoMod := filepath.Join(targetAbs, "go.mod")
	oldModule, _ := readModulePath(appGoMod)
	oldBase := deriveBase(oldModule)
	newModule := fmt.Sprintf("%s/apps/%s", moduleBase, name)
	if err := updateGoMod(appGoMod, newModule, moduleBase); err != nil {
		return err
	}

	if err := updateWailsConfig(filepath.Join(targetAbs, "wails.json"), name, product, company); err != nil {
		return err
	}

	if err := updatePackageJSON(filepath.Join(targetAbs, "frontend", "package.json"), fmt.Sprintf("%s-frontend", name)); err != nil {
		return err
	}

	replacements := map[string]string{
		"Project Go": product,
		"project-go": name,
	}

	for _, rel := range []string{
		"main.go",
		filepath.Join("frontend", "index.html"),
		filepath.Join("frontend", "src", "main.js"),
	} {
		if err := replaceInFile(filepath.Join(targetAbs, rel), replacements); err != nil {
			return err
		}
	}

	if oldBase != "" && oldBase != moduleBase {
		if err := replaceModuleBaseInGoFiles(targetAbs, oldBase, moduleBase); err != nil {
			return err
		}
	}

	return nil
}

func updateGoMod(path, newModule, newBase string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}

	lines := strings.Split(string(data), "\n")
	oldModule := ""
	for i, line := range lines {
		trim := strings.TrimSpace(line)
		if strings.HasPrefix(trim, "module ") {
			oldModule = strings.TrimSpace(strings.TrimPrefix(trim, "module "))
			lines[i] = "module " + newModule
			break
		}
	}

	updated := strings.Join(lines, "\n")
	if oldModule != "" {
		oldBase := deriveBase(oldModule)
		if oldBase != "" && oldBase != newBase {
			updated = strings.ReplaceAll(updated, oldBase, newBase)
		}
	}

	return os.WriteFile(path, []byte(updated), 0o644)
}

func updateWailsConfig(path, name, product, company string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}

	var config map[string]interface{}
	if err := json.Unmarshal(data, &config); err != nil {
		return err
	}

	config["name"] = name
	config["outputfilename"] = name

	info, ok := config["info"].(map[string]interface{})
	if !ok || info == nil {
		info = map[string]interface{}{}
	}
	info["productName"] = product
	info["companyName"] = company
	config["info"] = info

	updated, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return err
	}

	updated = append(updated, '\n')
	return os.WriteFile(path, updated, 0o644)
}

func updatePackageJSON(path, newName string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}

	var config map[string]interface{}
	if err := json.Unmarshal(data, &config); err != nil {
		return err
	}

	config["name"] = newName
	updated, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return err
	}

	updated = append(updated, '\n')
	return os.WriteFile(path, updated, 0o644)
}

func replaceInFile(path string, replacements map[string]string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}

	content := string(data)
	for oldValue, newValue := range replacements {
		content = strings.ReplaceAll(content, oldValue, newValue)
	}

	return os.WriteFile(path, []byte(content), 0o644)
}

func replaceModuleBaseInGoFiles(root, oldBase, newBase string) error {
	return filepath.WalkDir(root, func(path string, entry fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, err := filepath.Rel(root, path)
		if err != nil {
			return err
		}
		if rel == "." {
			return nil
		}
		if shouldSkipForReplace(rel, entry) {
			if entry.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}
		if entry.IsDir() {
			return nil
		}
		if filepath.Ext(entry.Name()) != ".go" {
			return nil
		}
		data, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		updated := strings.ReplaceAll(string(data), oldBase, newBase)
		if updated == string(data) {
			return nil
		}
		return os.WriteFile(path, []byte(updated), 0o644)
	})
}

func copyDir(src, dst string) error {
	return filepath.WalkDir(src, func(path string, entry fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, err := filepath.Rel(src, path)
		if err != nil {
			return err
		}
		if rel == "." {
			return nil
		}
		if shouldSkip(rel, entry) {
			if entry.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}

		target := filepath.Join(dst, rel)
		if entry.IsDir() {
			return os.MkdirAll(target, 0o755)
		}
		return copyFile(path, target)
	})
}

func shouldSkip(rel string, entry fs.DirEntry) bool {
	clean := filepath.ToSlash(rel)
	if strings.HasPrefix(clean, "frontend/node_modules") ||
		strings.HasPrefix(clean, "frontend/dist") ||
		strings.HasPrefix(clean, "frontend/wailsjs") ||
		strings.HasPrefix(clean, "wailsjs") ||
		strings.HasPrefix(clean, "build") {
		return true
	}
	return false
}

func shouldSkipForReplace(rel string, entry fs.DirEntry) bool {
	clean := filepath.ToSlash(rel)
	skipPrefixes := []string{
		"frontend",
		"node_modules",
		"dist",
		"wailsjs",
		"build",
	}
	for _, prefix := range skipPrefixes {
		if clean == prefix || strings.HasPrefix(clean, prefix+"/") {
			return true
		}
	}
	return false
}

func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()

	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}

	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer out.Close()

	if _, err := io.Copy(out, in); err != nil {
		return err
	}

	info, err := in.Stat()
	if err == nil {
		_ = os.Chmod(dst, info.Mode())
	}

	return nil
}

func goWorkUse(repoRoot, targetRel string) error {
	if _, err := exec.LookPath("go"); err != nil {
		return err
	}

	cmd := exec.Command("go", "work", "use", "./"+filepath.ToSlash(targetRel))
	cmd.Dir = repoRoot
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func titleFromName(name string) string {
	parts := strings.FieldsFunc(name, func(r rune) bool {
		return r == '-' || r == '_' || r == ' '
	})
	for i, part := range parts {
		if part == "" {
			continue
		}
		lower := strings.ToLower(part)
		parts[i] = strings.ToUpper(lower[:1]) + lower[1:]
	}
	return strings.Join(parts, " ")
}

func exists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func fatal(message string) {
	fmt.Fprintln(os.Stderr, message)
	os.Exit(1)
}
