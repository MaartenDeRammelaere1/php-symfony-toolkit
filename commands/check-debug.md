---
description: Scan the codebase for leftover debug statements (dd, dump, var_dump, die, ray, etc.)
argument-hint: "[path]"
disable-model-invocation: true
allowed-tools: Read, Grep, Glob
---

# Check Debug Statements

Scan PHP files for debug statements that should not be committed.

## Steps

1. **Determine scan scope**:
   - If `$ARGUMENTS` specifies a path, scan that path only
   - Otherwise, scan `src/` by default

2. **Search for blacklisted functions** using Grep:

   Search for these patterns in `.php` files:
   - `die(`
   - `dd(`
   - `dump(`
   - `var_dump(`
   - `print_r(`
   - `debug_backtrace(`
   - `file_put_contents(`
   - `ray(`
   - `dpm(`
   - `dsm(`
   - `kpr(`
   - `kint(`

   Exclude these directories: `vendor/`, `var/`, `node_modules/`, `.git/`

3. **Filter out false positives**:
   - Ignore lines that are comments (starting with `//` or `*`)
   - Ignore lines in test files that legitimately test these functions
   - Ignore lines in configuration files that reference these as strings

4. **Report findings**:
   - For each match, show:
     - File path and line number
     - The matching line with context (1 line before and after)
     - The specific debug function found
   - Suggest replacement: use `LoggerInterface` instead

5. **Summary**:
   - Total debug statements found
   - Grouped by function type
   - If none found: "No debug statements found. Code is clean."
