#!/bin/sh
# Claude Code gets Matt Pocock's skills from the mattpocock-skills plugin.
# Earlier setmeup versions linked a standalone copy of his `pr` skill into
# ~/.claude/skills, which would now show up twice (pr and
# mattpocock-skills:pr). Remove that link; Codex keeps ~/.agents/skills/pr.
#
# Only the symlink the `skills` CLI created is removed, so a `pr` skill the
# user wrote themselves is left alone.
set -e

link="$HOME/.claude/skills/pr"

if [ -L "$link" ] && [ "$(readlink "$link")" = "../../.agents/skills/pr" ]; then
    rm "$link"
    echo "[setmeup] Removed standalone pr skill from Claude Code (now provided by the mattpocock-skills plugin)."
fi
