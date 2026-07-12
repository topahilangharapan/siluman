#!/usr/bin/env bash
# Installs the siluman harness into ~/.claude (override with CLAUDE_DIR).
set -euo pipefail

CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
repo="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$CLAUDE_DIR/hooks" "$CLAUDE_DIR/writing" "$CLAUDE_DIR/skills"

install -m 755 "$repo/hooks/writing-preset-inject" "$CLAUDE_DIR/hooks/writing-preset-inject"
install -m 755 "$repo/hooks/writing-preset-lint" "$CLAUDE_DIR/hooks/writing-preset-lint"

cp "$repo/writing/human-writing-preset.md" "$CLAUDE_DIR/writing/"
cp "$repo/writing/human-writing-preset-compact.md" "$CLAUDE_DIR/writing/"
cp "$repo/writing/lint-rules.json" "$CLAUDE_DIR/writing/"

# personal rules survive reinstalls and preset refreshes
if [ ! -f "$CLAUDE_DIR/writing/user-overrides.md" ]; then
  cp "$repo/writing/user-overrides.md" "$CLAUDE_DIR/writing/"
else
  echo "kept existing $CLAUDE_DIR/writing/user-overrides.md"
fi

rm -rf "$CLAUDE_DIR/skills/human-writing-preset-refresh"
cp -R "$repo/skills/human-writing-preset-refresh" "$CLAUDE_DIR/skills/"

cat <<EOF

Installed into $CLAUDE_DIR.

Last step: register the hooks in $CLAUDE_DIR/settings.json
(merge into the existing "hooks" object if you already have one):

{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "~/.claude/hooks/writing-preset-inject", "timeout": 5 }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "~/.claude/hooks/writing-preset-lint", "timeout": 60 }] }
    ]
  }
}

Then start a fresh claude session and try: write a short blog post about coffee
EOF
