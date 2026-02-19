---
description: Configure LSP plugins for a project — cross-references installed plugins with detected languages and user preferences
allowed-tools: Bash, AskUserQuestion
---

# /lsp:setup

Configure which LSP plugins are enabled at project scope.

## Steps

### 1. Read current plugin state

```bash
for f in ~/.claude/settings.json .claude/settings.json; do
  echo "=== $f ==="
  if [ ! -f "$f" ]; then echo "(not found)"; continue; fi
  if command -v jq &>/dev/null; then
    jq -r '.enabledPlugins // {} | to_entries[] | select(.key | test("-lsp@")) | "\(.key) \(.value)"' "$f"
  else
    cat "$f"
  fi
done
```

The `~/.claude/settings.json` section = global scope; `.claude/settings.json` = project scope. If no LSP plugins appear anywhere, inform the user and exit.

### 2. Detect project languages

Run this exact script verbatim — do not modify or simplify it:

```bash
_git=$(command -v git &>/dev/null && git rev-parse --git-dir &>/dev/null 2>&1 && echo 1)
for lang in "pyright-lsp:*.py pyproject.toml requirements.txt setup.py" "typescript-lsp:*.ts *.tsx *.js *.jsx tsconfig.json package.json" "rust-analyzer-lsp:*.rs Cargo.toml" "gopls-lsp:*.go go.mod" "lua-lsp:*.lua" "php-lsp:*.php composer.json" "kotlin-lsp:*.kt *.kts build.gradle.kts" "clangd-lsp:*.c *.cpp *.h *.hpp CMakeLists.txt"; do
  IFS=' ' read -rA pats <<< "${lang#*:}" 2>/dev/null || read -ra pats <<< "${lang#*:}"
  if [ -n "$_git" ]; then
    count=$(git ls-files --cached --others --exclude-standard -- "${pats[@]}" 2>/dev/null | wc -l)
  else
    args=(); f=1; for pat in "${pats[@]}"; do [ $f -eq 0 ] && args+=("-o"); args+=("-name" "$pat"); f=0; done
    count=$(find . -maxdepth 5 \( "${args[@]}" \) -not \( -path '*/node_modules/*' -o -path '*/.git/*' -o -path '*/vendor/*' -o -path '*/dist/*' -o -path '*/build/*' -o -path '*/.venv/*' \) 2>/dev/null | wc -l)
  fi
  echo "${lang%%:*}: $count files"
done
```

### 3. Ask the user

Use `AskUserQuestion` with `multiSelect: true`. Include all installed plugins as options, detected ones first. Show each plugin's file count and current project-scope state in the description. If current project state already matches what the user would naturally select (e.g., detected plugin already enabled, others already disabled), include a "No changes needed" option — and if selected, exit immediately.

### 4. Apply only necessary changes

All changes are **project scope only**. Before running any command, compare the user's selection against the current project state from step 1. **Skip any plugin that is already in the desired state.**

For each selected plugin not yet enabled at project scope:
```bash
claude plugin install <plugin>@claude-plugins-official --scope project  # only if not installed at project scope
claude plugin enable <plugin>@claude-plugins-official --scope project
```

For each unselected plugin currently enabled at project scope (`true` in `.claude/settings.json`):
```bash
claude plugin disable <plugin>@claude-plugins-official --scope project
```

### 5. Report

State what changed (or confirm nothing needed to change).
