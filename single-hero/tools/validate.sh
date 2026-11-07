#!/usr/bin/env bash
# Runs the checks of the CI job "Validate Code" (.github/workflows/github.yml) locally,
# on exactly what would be committed now (tracked + new files, as `git add -A` would stage them).
#
# Needs: git, python3 with jstyleson (pip install jstyleson), Node.js (for markdownlint-cli2).
# Usage (Git Bash on Windows, or Linux/macOS):  bash single-hero/tools/validate.sh
# Set NODE_DIR to a folder with node/npx if Node.js is not on PATH.
set -u

ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT"

if [ -n "${NODE_DIR:-}" ]; then
	command -v cygpath > /dev/null && NODE_DIR=$(cygpath -u "$NODE_DIR")
	export PATH="$NODE_DIR:$PATH"
fi
PYTHON=$(command -v python3 || command -v python)
export PYTHONUTF8=1   # the JSON check prints emoji and must read files as UTF-8, also on Windows

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# 1. export the would-be commit with a temporary index (the real index is not touched), line endings as stored in git
export GIT_INDEX_FILE="$WORK/index"
git read-tree HEAD
git -c core.safecrlf=false add -A 2> /dev/null
git -c core.autocrlf=false checkout-index -a --prefix="$WORK/tree/"
unset GIT_INDEX_FILE
cd "$WORK/tree"

failed=0
step() { printf '\n=== %s\n' "$1"; }

step "Ensure LF line endings"
crlf=$(find . -path ./.git -prune -o -path ./AI/FuzzyLite -prune -o -path ./test/googletest \
	-o -path ./osx -prune -o -type f \
	-not -name '*.png' -and -not -name '*.ttf' -and -not -name '*.wav' -and -not -name '*.webm' -and -not -name '*.ico' -and -not -name '*.bat' -and -not -name '*.cmd' -and -not -name '*.iss' -and -not -name '*.isl' -print0 |
	xargs -0 grep -l -z -P '\r\n')
if [ -n "$crlf" ]; then echo "CRLF found in:"; echo "$crlf"; failed=1; else echo "OK"; fi

step "Validate JSON"
if "$PYTHON" "$ROOT/CI/validate_json.py" > "$WORK/json.log" 2>&1; then
	echo "OK ($(grep -c . "$WORK/json.log") files)"
else
	grep -v '^✅' "$WORK/json.log"; failed=1
fi

step "Validate Markdown"
if command -v npx > /dev/null; then
	npx --yes markdownlint-cli2@0.20.0 --config CI/example.markdownlint-cli2.jsonc '**/*.md' || failed=1
else
	echo "Node.js not found - set NODE_DIR"; failed=1
fi

echo
if [ $failed = 0 ]; then echo "ALL CHECKS PASSED"; else echo "SOME CHECKS FAILED"; fi
exit $failed
