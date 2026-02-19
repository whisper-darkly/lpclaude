---
description: Configure LSP plugins for a project — cross-references installed plugins with detected languages and user preferences
allowed-tools: Bash, AskUserQuestion
---

# /lsp:setup

Configure which LSP plugins are enabled at project scope. Cross-references installed plugins
against languages detected in this project, then asks for your preferences.

Run this once when starting work in a new project.

## Plugin–Language Mapping

| Plugin | Indicators |
|---|---|
| `pyright-lsp` | `*.py`, `pyproject.toml`, `requirements.txt`, `setup.py` |
| `typescript-lsp` | `*.ts`, `*.tsx`, `*.js`, `*.jsx`, `tsconfig.json`, `package.json` |
| `rust-analyzer-lsp` | `*.rs`, `Cargo.toml` |
| `gopls-lsp` | `*.go`, `go.mod` |
| `lua-lsp` | `*.lua` |
| `php-lsp` | `*.php`, `composer.json` |
| `kotlin-lsp` | `*.kt`, `*.kts`, `build.gradle.kts` |
| `clangd-lsp` | `*.c`, `*.cpp`, `*.h`, `*.hpp`, `CMakeLists.txt` |

## Steps

### 1. Run the detection script

```bash
~/.claude/utils/lsp-detect.sh
```

This reads `~/.claude/settings.json` and `.claude/settings.json` (if present), unions all
installed LSP plugin keys, then scans the project for language indicator files. Output is JSON:

```json
{
  "plugins": {
    "<plugin>@claude-plugins-official": {
      "global": true|false|null,
      "project": true|false|null,
      "detected": true|false,
      "sample_files": ["..."]
    }
  }
}
```

If `plugins` is empty, inform the user that no LSP plugins appear to be installed and exit.

### 2. Build the options list

For each plugin in the output, classify it as:
- **Detected** — `"detected": true` (indicator files found in this project)
- **Not detected** — `"detected": false` (no matching files found)

### 3. Ask the user

Use `AskUserQuestion` with `multiSelect: true`. Present **all installed plugins** as options,
detected ones first.

For each option:
- **label**: plugin name without `@claude-plugins-official`
- **description**: combine detection and current state, e.g.:
  - `Detected (utils/addjob.py) — currently disabled globally, not set at project scope`
  - `Not detected — currently disabled globally`

Note in the question which plugins were detected, e.g.:
_"Detected in this project: pyright-lsp. Select all you want enabled at project scope
(you can include others you plan to use)."_

### 4. Apply the selection

For each plugin the user selected:
```bash
claude plugin enable <plugin>@claude-plugins-official --scope project
```

For each installed plugin the user did NOT select:
```bash
claude plugin disable <plugin>@claude-plugins-official --scope project
```

### 5. Report results

List which plugins were enabled and which were disabled at project scope. Remind the user
that settings are stored in `.claude/settings.json` and `/lsp:setup` can be run again to
reconfigure.
