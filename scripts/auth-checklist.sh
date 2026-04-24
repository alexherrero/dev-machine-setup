#!/usr/bin/env bash
# auth-checklist.sh — printed at the end of setup.sh. Enumerates the
# manual auth / first-run steps that preceding stages cannot automate.
# Always exits 0; this is informational output, not a gate.

set -euo pipefail

cat <<'EOF'
==> first-run auth checklist

Installed tooling is in place. Complete each step below in any order —
this is the minimum set that can't be scripted (oauth, interactive login,
or signing into the GUI apps).

  1. claude login
     Sign in to the Claude Code CLI. Opens a browser for Anthropic oauth.

  2. gh auth login
     Sign in to GitHub. Pick "GitHub.com" → "HTTPS" → "Login with a web
     browser". Required for `gh pr create`, `gh release create`, etc.

  3. gemini
     First invocation of the Gemini CLI triggers Google oauth. Just run
     `gemini` in any terminal and follow the browser prompt.

  4. open -a Antigravity
     Launch Antigravity and sign in with the Google account you want it
     tied to. First launch finalizes workspace + agent config.

  5. open -a Claude
     Launch Claude Desktop and sign in with your Anthropic account. MCP
     extensions and preferences persist across restarts.

See docs/first-run.md for the same list with extra context.
EOF
