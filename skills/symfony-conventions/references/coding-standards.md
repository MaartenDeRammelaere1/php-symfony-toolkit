# PHP Coding Standards Reference

## PHP-CS-Fixer Configuration

### Recommended `.php-cs-fixer.dist.php`

```php
<?php

$finder = (new PhpCsFixer\Finder())
    ->in(__DIR__)
    ->exclude('var')
    ->exclude('vendor')
    ->exclude('node_modules')
;

return (new PhpCsFixer\Config())
    ->setRules([
        '@Symfony' => true,
        'yoda_style' => false,
        'blank_line_after_opening_tag' => false,
        'concat_space' => ['spacing' => 'one'],
        'phpdoc_align' => ['align' => 'left'],
        'operator_linebreak' => ['position' => 'end', 'only_booleans' => true],
        'trailing_comma_in_multiline' => [
            'after_heredoc' => true,
            'elements' => ['arguments', 'arrays', 'match', 'parameters'],
        ],
    ])
    ->setFinder($finder);
```

### Rule Explanations

| Rule | Setting | Effect |
|------|---------|--------|
| `@Symfony` | `true` | Base ruleset following Symfony conventions |
| `yoda_style` | `false` | `$var === 'value'` instead of `'value' === $var` |
| `blank_line_after_opening_tag` | `false` | No blank line between `<?php` and `declare(strict_types=1)` |
| `concat_space` | `one` | `$a . $b` with spaces around the dot |
| `phpdoc_align` | `left` | PHPDoc tags aligned to the left, not padded with spaces |
| `operator_linebreak` | `end`, booleans only | `&&` and `||` at end of line in multiline conditions |
| `trailing_comma_in_multiline` | all elements | Trailing commas in function arguments, arrays, match, and parameters |

### Running PHP-CS-Fixer

```bash
# Dry run to see what would change
vendor/bin/php-cs-fixer fix --dry-run --diff

# Fix all files
vendor/bin/php-cs-fixer fix

# Fix a specific file
vendor/bin/php-cs-fixer fix src/Service/MyService.php

# Fix with verbose output
vendor/bin/php-cs-fixer fix -v
```

## PHPStan Configuration

### Recommended `phpstan.neon`

```neon
parameters:
    level: max
    paths:
        - bin/
        - config/
        - public/
        - src/
        - tests/
    tmpDir: var/cache/phpstan
```

### PHPStan Levels

| Level | What it checks |
|-------|----------------|
| 0 | Basic checks: unknown classes, functions, methods |
| 1 | Possibly undefined variables, unknown magic methods |
| 2 | Unknown methods on all expressions (not just `$this`) |
| 3 | Return types, types of arguments passed to functions |
| 4 | Basic dead code checking |
| 5 | Type checks of arguments passed to methods and functions |
| 6 | Missing typehints reported |
| 7 | Union types checked partially |
| 8 | Strict union types, no mixed type allowed |
| 9 (max) | Mixed type is treated as strict |

### Recommended Extensions

```neon
includes:
    - vendor/phpstan/phpstan-symfony/extension.neon
    - vendor/phpstan/phpstan-doctrine/extension.neon
    - vendor/phpstan/phpstan-phpunit/extension.neon
    - vendor/phpstan/phpstan-strict-rules/rules.neon
```

Install with:
```bash
composer require --dev phpstan/phpstan-symfony phpstan/phpstan-doctrine phpstan/phpstan-phpunit phpstan/phpstan-strict-rules
```

### Type Aliases

For complex array shapes used across the codebase:

```neon
parameters:
    typeAliases:
        WebhookPayload: 'array{eventType?: string, gatewayDeviceId: string, data: array{name?: string, value?: string}}'
```

### Baseline Management

When introducing PHPStan to a legacy project:

```bash
# Generate baseline with all current errors
vendor/bin/phpstan analyse --generate-baseline

# Include baseline in phpstan.neon
includes:
    - phpstan-baseline.neon
```

Gradually reduce the baseline by fixing errors and re-generating it.

## GrumPHP Configuration

### Recommended `grumphp.yml`

```yaml
grumphp:
    ascii:
        failed: ~
        succeeded: ~
    tasks:
        composer:
            file: ./composer.json
        git_blacklist:
            keywords:
                - " die("
                - " var_dump("
                - " print_r("
                - " print("
                - " dump("
                - " debug_backtrace("
                - " file_put_contents("
                - " ray("
            triggered_by:
                - php
        phpcsfixer:
            config: ./.php-cs-fixer.dist.php
            diff: true
        phpstan:
            autoload_file: ./vendor/autoload.php
            configuration: ./phpstan.neon
            use_grumphp_paths: false
        phpunit: ~
        yamllint:
            parse_custom_tags: true
        jsonlint:
            detect_key_conflicts: true
        xmllint: ~
        securitychecker_roave:
            run_always: true
```

### Task Descriptions

| Task | Purpose |
|------|---------|
| `composer` | Validates `composer.json` and `composer.lock` are in sync |
| `git_blacklist` | Prevents committing debug statements |
| `phpcsfixer` | Enforces coding standards with diff output |
| `phpstan` | Static analysis at configured level |
| `phpunit` | Runs test suite |
| `yamllint` | Validates YAML config files |
| `jsonlint` | Validates JSON files, detects duplicate keys |
| `xmllint` | Validates XML files |
| `securitychecker_roave` | Checks dependencies for known vulnerabilities |

### Installation

```bash
composer require --dev phpro/grumphp
# GrumPHP auto-installs its git hooks via a Composer plugin
```
