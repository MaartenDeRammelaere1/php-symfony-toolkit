#!/usr/bin/env bash
# Auto-format PHP files with PHP-CS-Fixer after Write/Edit
# Receives tool input as JSON on stdin

set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//;s/"$//')

# Only process PHP files
if [ -z "$FILE_PATH" ] || [[ "$FILE_PATH" != *.php ]]; then
    exit 0
fi

# Skip if file doesn't exist
if [ ! -f "$FILE_PATH" ]; then
    exit 0
fi

# Find project root by looking for composer.json
DIR=$(dirname "$FILE_PATH")
PROJECT_ROOT=""
while [ "$DIR" != "/" ]; do
    if [ -f "$DIR/composer.json" ]; then
        PROJECT_ROOT="$DIR"
        break
    fi
    DIR=$(dirname "$DIR")
done

if [ -z "$PROJECT_ROOT" ]; then
    exit 0
fi

# Find PHP-CS-Fixer binary
FIXER=""
if [ -x "$PROJECT_ROOT/vendor/bin/php-cs-fixer" ]; then
    FIXER="$PROJECT_ROOT/vendor/bin/php-cs-fixer"
elif [ -x "$PROJECT_ROOT/tools/php-cs-fixer/vendor/bin/php-cs-fixer" ]; then
    FIXER="$PROJECT_ROOT/tools/php-cs-fixer/vendor/bin/php-cs-fixer"
fi

if [ -z "$FIXER" ]; then
    exit 0
fi

# Find config file
CONFIG=""
if [ -f "$PROJECT_ROOT/.php-cs-fixer.php" ]; then
    CONFIG="$PROJECT_ROOT/.php-cs-fixer.php"
elif [ -f "$PROJECT_ROOT/.php-cs-fixer.dist.php" ]; then
    CONFIG="$PROJECT_ROOT/.php-cs-fixer.dist.php"
fi

if [ -z "$CONFIG" ]; then
    exit 0
fi

# Run PHP-CS-Fixer on the file (quiet mode)
"$FIXER" fix "$FILE_PATH" --config="$CONFIG" --quiet 2>/dev/null || true
