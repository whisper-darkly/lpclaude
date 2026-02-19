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

```bash
for lang in \
  "pyright-lsp:*.py pyproject.toml requirements.txt setup.py" \
  "typescript-lsp:*.ts *.tsx *.js *.jsx tsconfig.json package.json" \
  "rust-analyzer-lsp:*.rs Cargo.toml" \
  "gopls-lsp:*.go go.mod" \
  "lua-lsp:*.lua" \
  "php-lsp:*.php composer.json" \
  "kotlin-lsp:*.kt *.kts build.gradle.kts" \
  "clangd-lsp:*.c *.cpp *.h *.hpp CMakeLists.txt"
do
  plugin="${lang%%:*}"
  patterns="${lang#*:}"
  count=0
  for pat in $patterns; do
    count=$((count + $(find . -maxdepth 5 -name "$pat" -not \( -path '*/node_modules/*' -o -path '*/.git/*' -o -path '*/vendor/*' -o -path '*/dist/*' -o -path '*/build/*' -o -path '*/.venv/*' \) 2>/dev/null | wc -l)))
  done
  echo "$plugin: $count files"
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
