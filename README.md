# php-harmony

A Claude Code plugin for PHP and Symfony development. Provides code quality enforcement, Doctrine patterns, Messenger guidance, testing best practices, security conventions, and automated quality hooks.

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed and authenticated
- PHP project with Composer
- Recommended: [php-lsp plugin](https://claude.ai/settings/plugins) for PHP language intelligence

## Installation

### From marketplace

```bash
claude plugin install php-harmony
```

### Local development

```bash
claude --plugin-dir /path/to/php-harmony
```

## What's included

### Skills (auto-invoked)

Claude automatically uses these when working on relevant PHP/Symfony code:

| Skill | Description |
|-------|-------------|
| `symfony-conventions` | PHP/Symfony coding standards, service design, PHP 8 attributes |
| `doctrine-patterns` | Entity design, repositories, migrations, query patterns |
| `messenger-patterns` | Messages, handlers, middleware, RabbitMQ transport config |
| `testing-patterns` | PHPUnit structure, unit/integration/functional testing |
| `symfony-security` | Authentication, authorization, voters, firewalls |

### Commands (user-invoked)

| Command | Description |
|---------|-------------|
| `/php-harmony:quality-check [--fix] [path]` | Run PHPStan and PHP-CS-Fixer |
| `/php-harmony:run-tests [filter] [--coverage] [--parallel]` | Run PHPUnit or Paratest |
| `/php-harmony:check-debug [path]` | Scan for leftover debug statements |
| `/php-harmony:doctrine-migration [action]` | Generate, run, or review Doctrine migrations |
| `/php-harmony:symfony-make <type> <name>` | Generate Symfony components |

### Agents

| Agent | Description |
|-------|-------------|
| `php-code-reviewer` | Reviews PHP code for bugs, anti-patterns, and convention violations |
| `symfony-architect` | Analyzes project architecture and module structure |
| `security-auditor` | Audits code for OWASP vulnerabilities |

### Hooks

Automated quality enforcement after every PHP file write/edit:

- **Debug statement check**: Warns when `dd()`, `dump()`, `var_dump()`, `die()`, `ray()` etc. are detected
- **PHP-CS-Fixer**: Auto-formats PHP files using your project's `.php-cs-fixer.dist.php` config

## Supported frameworks

- Symfony 6.x, 7.x
- Any PHP project using Composer

## License

MIT
