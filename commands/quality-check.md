---
description: Run PHP code quality tools (PHPStan, PHP-CS-Fixer) on the project or a specific path
argument-hint: "[--fix] [path]"
disable-model-invocation: true
allowed-tools: Read, Bash, Glob, Grep
---

# Quality Check

Run PHP code quality analysis on the project.

## Steps

1. **Detect available tools** by checking for configuration files:
   - Look for `phpstan.neon` or `phpstan.neon.dist` (PHPStan)
   - Look for `.php-cs-fixer.php` or `.php-cs-fixer.dist.php` (PHP-CS-Fixer)
   - Check `vendor/bin/` for the binaries

2. **Parse arguments from `$ARGUMENTS`**:
   - If it contains `--fix`: run PHP-CS-Fixer in fix mode (not dry-run)
   - Any remaining text is treated as a path to scope the analysis
   - If no path specified, use the tool's default paths from config

3. **Run PHP-CS-Fixer**:
   - If `--fix` flag: `vendor/bin/php-cs-fixer fix [path] -v`
   - Otherwise: `vendor/bin/php-cs-fixer fix [path] --dry-run --diff`
   - Report files that would be changed (or were changed)

4. **Run PHPStan**:
   - `vendor/bin/phpstan analyse [path] --no-progress --error-format=table`
   - If a path was specified, pass it to PHPStan
   - If no path, let PHPStan use its config

5. **Present results**:
   - Group errors by file
   - For common PHPStan errors, suggest a fix:
     - Missing return type → add the return type
     - Parameter type mismatch → show correct type
     - Undefined method → check if method exists, suggest alternatives
     - Deprecated function → suggest the replacement
   - Show a summary: total errors, files affected, severity breakdown

6. If no tools are found, inform the user and suggest installing them:
   ```
   composer require --dev phpstan/phpstan friendsofphp/php-cs-fixer
   ```
