#!/usr/bin/env bash
#
# lsp-detect.sh — Detect installed LSP plugins and project language indicators.
#
# Reads ~/.claude/settings.json and .claude/settings.json (if present), unions
# all installed LSP plugin keys, then scans the current directory for language
# indicator files.
#
# Output: JSON to stdout
# {
#   "plugins": {
#     "<plugin-name>": {
#       "global": true|false|null,    // null = not present in global settings
#       "project": true|false|null,   // null = not present in project settings
#       "detected": true|false,       // indicator files found in project
#       "sample_files": ["a.py", ...]  // up to 3 example files found
#     },
#     ...
#   }
# }
#
# Requires: jq

set -euo pipefail

if ! command -v jq &>/dev/null; then
  echo '{"error":"jq is required but not installed. Install it with: brew install jq  OR  sudo apt install jq  OR  https://jqlang.org/download/"}' >&2
  exit 1
fi

GLOBAL_SETTINGS="$HOME/.claude/settings.json"
PROJECT_SETTINGS=".claude/settings.json"

# ---------------------------------------------------------------------------
# Read enabledPlugins from a settings file; output key=value lines
# ---------------------------------------------------------------------------
read_plugins() {
  local file="$1"
  if [[ -f "$file" ]]; then
    jq -r '
      .enabledPlugins // {} |
      to_entries[] |
      select(.key | test("-lsp@claude-plugins-official$")) |
      "\(.key)=\(.value)"
    ' "$file" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# Collect all plugin names and their global/project states
# ---------------------------------------------------------------------------
declare -A GLOBAL_STATE
declare -A PROJECT_STATE

while IFS='=' read -r key val; do
  GLOBAL_STATE["$key"]="$val"
done < <(read_plugins "$GLOBAL_SETTINGS")

while IFS='=' read -r key val; do
  PROJECT_STATE["$key"]="$val"
done < <(read_plugins "$PROJECT_SETTINGS")

# Union of all plugin keys
declare -A ALL_PLUGINS
for k in "${!GLOBAL_STATE[@]}"; do ALL_PLUGINS["$k"]=1; done
for k in "${!PROJECT_STATE[@]}"; do ALL_PLUGINS["$k"]=1; done

if [[ ${#ALL_PLUGINS[@]} -eq 0 ]]; then
  echo '{"plugins":{}}'
  exit 0
fi

# ---------------------------------------------------------------------------
# Language indicator patterns keyed by plugin base name
# ---------------------------------------------------------------------------
declare -A INDICATORS
INDICATORS["pyright-lsp"]="*.py pyproject.toml requirements.txt setup.py"
INDICATORS["typescript-lsp"]="*.ts *.tsx *.js *.jsx tsconfig.json package.json"
INDICATORS["rust-analyzer-lsp"]="*.rs Cargo.toml"
INDICATORS["gopls-lsp"]="*.go go.mod"
INDICATORS["lua-lsp"]="*.lua"
INDICATORS["php-lsp"]="*.php composer.json"
INDICATORS["kotlin-lsp"]="*.kt *.kts build.gradle.kts"
INDICATORS["clangd-lsp"]="*.c *.cpp *.h *.hpp CMakeLists.txt"

# ---------------------------------------------------------------------------
# Detect indicator files for each plugin (limit depth to keep it fast)
# ---------------------------------------------------------------------------
declare -A DETECTED
declare -A SAMPLE_FILES

for full_key in "${!ALL_PLUGINS[@]}"; do
  base="${full_key%@*}"  # strip @claude-plugins-official
  patterns="${INDICATORS[$base]:-}"
  DETECTED["$full_key"]="false"
  SAMPLE_FILES["$full_key"]=""

  if [[ -z "$patterns" ]]; then
    continue
  fi

  found=()
  for pattern in $patterns; do
    while IFS= read -r f; do
      found+=("$f")
      [[ ${#found[@]} -ge 3 ]] && break 2
    done < <(find . -maxdepth 5 \
        -not \( -path '*/node_modules/*' -o -path '*/.git/*' \
               -o -path '*/vendor/*'     -o -path '*/dist/*' \
               -o -path '*/build/*'      -o -path '*/.venv/*' \) \
        -name "$pattern" 2>/dev/null | head -3)
  done

  if [[ ${#found[@]} -gt 0 ]]; then
    DETECTED["$full_key"]="true"
    # Build a JSON array of sample file paths (strip leading ./)
    samples=$(printf '%s\n' "${found[@]}" | sed 's|^\./||' \
              | jq -Rn '[inputs]')
    SAMPLE_FILES["$full_key"]="$samples"
  fi
done

# ---------------------------------------------------------------------------
# Emit JSON
# ---------------------------------------------------------------------------
first=1
echo '{"plugins":{'
for full_key in "${!ALL_PLUGINS[@]}"; do
  g="${GLOBAL_STATE[$full_key]:-null}"
  p="${PROJECT_STATE[$full_key]:-null}"
  # Convert string "true"/"false" to JSON booleans; keep null as null
  [[ "$g" == "true" ]]  && g="true"
  [[ "$g" == "false" ]] && g="false"
  [[ "$p" == "true" ]]  && p="true"
  [[ "$p" == "false" ]] && p="false"

  det="${DETECTED[$full_key]}"
  samples="${SAMPLE_FILES[$full_key]:-[]}"
  [[ -z "$samples" ]] && samples="[]"

  [[ $first -eq 0 ]] && echo ','
  first=0
  printf '  %s: {"global":%s,"project":%s,"detected":%s,"sample_files":%s}' \
    "$(echo "$full_key" | jq -R .)" "$g" "$p" "$det" "$samples"
done
echo
echo '}}'
