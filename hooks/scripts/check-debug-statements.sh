#!/usr/bin/env bash
# Check for debug statements in PHP files after Write/Edit
# Receives tool input as JSON on stdin

set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//;s/"$//')

# Only check PHP files
if [ -z "$FILE_PATH" ] || [[ "$FILE_PATH" != *.php ]]; then
    exit 0
fi

# Skip if file doesn't exist
if [ ! -f "$FILE_PATH" ]; then
    exit 0
fi

# Search for debug statements (excluding comments)
PATTERNS='(\bdie\s*\(|\bdd\s*\(|\bdump\s*\(|\bvar_dump\s*\(|\bprint_r\s*\(|\bdebug_backtrace\s*\(|\bray\s*\()'

MATCHES=$(grep -nE "$PATTERNS" "$FILE_PATH" 2>/dev/null | grep -vE '^\s*(//|/?\*)' || true)

if [ -n "$MATCHES" ]; then
    echo '{"additionalContext": "WARNING: Debug statements found in '"$FILE_PATH"'. Remove these before committing:\n'"$(echo "$MATCHES" | head -5 | sed 's/"/\\"/g' | tr '\n' '|' | sed 's/|/\\n/g')"'"}'
fi
