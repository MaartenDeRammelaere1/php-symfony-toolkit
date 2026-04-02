---
description: Generate, review, and manage Doctrine database migrations
argument-hint: "[diff|migrate|status|rollback]"
disable-model-invocation: true
allowed-tools: Read, Bash, Glob
---

# Doctrine Migration

Manage Doctrine migrations for the project.

## Steps

1. **Parse action from `$ARGUMENTS`** (default: `status`):
   - `status` — show current migration status
   - `diff` — generate a new migration from entity changes
   - `migrate` — run pending migrations
   - `rollback` — rollback the last migration

2. **Detect Doctrine setup**:
   - Check for `bin/console` (Symfony) or `vendor/bin/doctrine-migrations` (standalone)
   - Check for `config/packages/doctrine_migrations.yaml` or `migrations.php`

3. **Execute based on action**:

   ### status
   ```bash
   php bin/console doctrine:migrations:status
   ```
   Present the output in a readable format: current version, available migrations, pending count.

   ### diff
   ```bash
   php bin/console doctrine:migrations:diff
   ```
   After generation:
   - Read the generated migration file
   - Review the SQL for destructive operations:
     - **DROP TABLE** — warn prominently
     - **DROP COLUMN** — warn prominently
     - **ALTER TABLE ... DROP** — warn prominently
     - **TRUNCATE** — warn prominently
   - Explain what the migration does in plain language
   - If destructive operations found, explicitly ask if this is intentional

   ### migrate
   ```bash
   php bin/console doctrine:migrations:migrate --no-interaction
   ```
   Show the executed migration versions and any output.

   ### rollback
   ```bash
   php bin/console doctrine:migrations:migrate prev --no-interaction
   ```
   Show which migration was rolled back.

4. **After diff**: suggest next steps:
   - "Review the migration SQL, then run `/php-harmony:doctrine-migration migrate`"
   - "Or rollback with `/php-harmony:doctrine-migration rollback`"
