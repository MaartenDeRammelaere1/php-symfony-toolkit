---
description: Run PHPUnit tests with optional filter, coverage reporting, and parallel execution
argument-hint: "[filter] [--coverage] [--parallel]"
disable-model-invocation: true
allowed-tools: Read, Bash, Glob, Grep
---

# Run Tests

Run the project's PHPUnit test suite with optional flags.

## Steps

1. **Detect test runner**:
   - Look for `phpunit.xml.dist` or `phpunit.xml`
   - Check if `vendor/bin/phpunit` exists
   - Check if `vendor/bin/paratest` exists (for parallel support)

2. **Parse arguments from `$ARGUMENTS`**:
   - `--coverage`: add `--coverage-text` to the command
   - `--parallel`: use `vendor/bin/paratest` instead of `vendor/bin/phpunit` (if available)
   - Any remaining text is used as a `--filter` value
   - Example: `run-tests OrderService --coverage` → filter by "OrderService" with coverage

3. **Build and run the command**:
   - Base: `vendor/bin/phpunit`
   - If parallel: `vendor/bin/paratest --processes=4`
   - If filter: add `--filter=<text>`
   - If coverage: add `--coverage-text`
   - Always add `--colors=always` for readable output

4. **Analyze results**:
   - Report: passed, failed, skipped, incomplete counts
   - If coverage was requested, show the coverage percentage
   - For failures:
     - Read the failing test file
     - Look at the assertion that failed
     - Suggest a possible fix or explain why it failed
   - For errors:
     - Show the exception message and stack trace
     - Suggest whether it's a test issue or an application issue

5. **Show summary**:
   - Total tests, assertions, time taken
   - List of failed tests with file:line references
   - If all pass, confirm success

6. If PHPUnit is not found, suggest:
   ```
   composer require --dev phpunit/phpunit
   ```
