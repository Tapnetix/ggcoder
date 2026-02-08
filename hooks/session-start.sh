#!/usr/bin/env bash
# SessionStart hook for ggcoder plugin

set -euo pipefail

# Determine plugin root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Check if legacy skills directory exists and build warning
warning_message=""
legacy_skills_dir="${HOME}/.config/superpowers/skills"
if [ -d "$legacy_skills_dir" ]; then
    warning_message="\n\n<important-reminder>IN YOUR FIRST REPLY AFTER SEEING THIS MESSAGE YOU MUST TELL THE USER:⚠️ **WARNING:** Legacy skills directory found. Custom skills in ~/.config/superpowers/skills will not be read. Move custom skills to ~/.claude/skills instead.</important-reminder>"
fi

# Check if original superpowers plugin is also installed (conflict detection)
superpowers_conflict=""
plugins_cache="${HOME}/.claude/plugins/cache"
if [ -d "$plugins_cache" ]; then
    # Look for superpowers plugin (but not ggcoder)
    if find "$plugins_cache" -maxdepth 2 -type d -name "superpowers" 2>/dev/null | grep -v ggcoder | grep -q .; then
        superpowers_conflict="\n\n<important-reminder>IN YOUR FIRST REPLY AFTER SEEING THIS MESSAGE YOU MUST TELL THE USER:⚠️ **CONFLICT DETECTED:** Both 'superpowers' and 'ggcoder' plugins are installed. GGCoder is a superset of Superpowers with GridGain-specific reviewers. Having both causes duplicate skills and confusion.\n\nPlease uninstall one:\n\`\`\`\n/plugin uninstall superpowers@superpowers-marketplace\n\`\`\`\n\nKeep only ggcoder for GridGain/Ignite development.</important-reminder>"
    fi
fi

# Combine warnings
if [ -n "$superpowers_conflict" ]; then
    warning_message="${warning_message}${superpowers_conflict}"
fi

# Read using-superpowers content
using_superpowers_content=$(cat "${PLUGIN_ROOT}/skills/using-superpowers/SKILL.md" 2>&1 || echo "Error reading using-superpowers skill")

# Escape string for JSON embedding using bash parameter substitution.
# Each ${s//old/new} is a single C-level pass - orders of magnitude
# faster than the character-by-character loop this replaces.
escape_for_json() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

using_superpowers_escaped=$(escape_for_json "$using_superpowers_content")
warning_escaped=$(escape_for_json "$warning_message")

# Output context injection as JSON
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "<EXTREMELY_IMPORTANT>\nYou have ggcoder superpowers.\n\n**Below is the full content of your 'ggcoder:using-superpowers' skill - your introduction to using skills. For all other skills, use the 'Skill' tool:**\n\n${using_superpowers_escaped}\n\n${warning_escaped}\n</EXTREMELY_IMPORTANT>"
  }
}
EOF

exit 0
