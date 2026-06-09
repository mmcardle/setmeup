#!/usr/bin/env bash
# Install Claude Code plugins from a plugins list, registering each plugin's
# marketplace first.
#
# Usage: setmeup-install-claude-plugins.sh <plugins-list-file>
#
# The list format (one plugin per line, blanks and #-comments ignored):
#   <plugin>@<marketplace>  <marketplace_source>
#
# Idempotent and safe to re-run. Crucially, plugins that are ALREADY installed
# are skipped: `claude plugin install` re-enables a disabled plugin, so a plain
# re-install pass (setmeup-update, or the chezmoi onchange installer) would
# silently undo a user's decision to disable a plugin. By only installing
# genuinely-missing plugins, this preserves enabled/disabled state across runs.
set -euo pipefail

PLUGINS_LIST="${1:?usage: setmeup-install-claude-plugins.sh <plugins-list-file>}"

export PATH="$HOME/.local/bin:$PATH"

if [[ ! -f "$PLUGINS_LIST" ]]; then
    echo "[setmeup] ERROR: plugins list not found at $PLUGINS_LIST" >&2
    exit 1
fi

# Claude Code is installed as an npm tool by mise; chain node@lts so npm is on
# PATH, then claude itself comes from the npm package.
CLAUDE_EXEC=(mise exec node@lts 'npm:@anthropic-ai/claude-code' --)

# Strip comments/blank lines to a normalized stream of: <plugin>@<marketplace> <source>
plugin_lines=$(grep -vE '^\s*(#|$)' "$PLUGINS_LIST" || true)

# Register marketplaces (deduped). `claude plugin marketplace add` is
# idempotent — it reports the marketplace is already on disk and exits 0.
declare -A seen_sources=()
while read -r _plugin source; do
    [ -z "${source:-}" ] && continue
    [ -n "${seen_sources[$source]:-}" ] && continue
    seen_sources["$source"]=1
    echo "[setmeup]   marketplace add: $source"
    "${CLAUDE_EXEC[@]}" claude plugin marketplace add "$source" </dev/null
done <<< "$plugin_lines"

# Collect the ids of already-installed plugins (enabled OR disabled). These are
# skipped below so we never re-enable a plugin the user disabled.
declare -A installed=()
while read -r id; do
    [ -z "$id" ] && continue
    installed["$id"]=1
done < <("${CLAUDE_EXEC[@]}" claude plugin list --json </dev/null 2>/dev/null \
    | mise exec node@lts -- node -e \
        'let a=[];try{a=JSON.parse(require("fs").readFileSync(0,"utf8"))}catch(e){};for(const p of a)if(p&&p.id)console.log(p.id)')

# Install only the plugins that are not already on disk. `claude plugin install`
# is idempotent for missing plugins; we additionally skip installed ones so
# their enabled/disabled state is left untouched.
while read -r plugin _source; do
    [ -z "${plugin:-}" ] && continue
    if [ -n "${installed[$plugin]:-}" ]; then
        echo "[setmeup]   already installed, leaving as-is: $plugin"
        continue
    fi
    echo "[setmeup]   plugin install: $plugin"
    "${CLAUDE_EXEC[@]}" claude plugin install "$plugin" -s user </dev/null
done <<< "$plugin_lines"
