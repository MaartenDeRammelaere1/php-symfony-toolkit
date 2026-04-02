---
description: Generate Symfony components (entity, controller, command, message, voter, form, subscriber) following project conventions
argument-hint: "<type> <name>"
disable-model-invocation: true
allowed-tools: Read, Write, Bash, Glob, Grep
---

# Symfony Make

Generate Symfony components following the project's coding conventions.

## Steps

1. **Parse arguments**:
   - `$ARGUMENTS[0]` = component type (required)
   - `$ARGUMENTS[1]` = component name (required)
   - Supported types: `entity`, `controller`, `command`, `message`, `message-handler`, `voter`, `form`, `subscriber`

2. **Detect project conventions** before generating:
   - Read `composer.json` to determine Symfony version and autoload namespace
   - Look at existing files of the same type to detect patterns:
     - Find 1-2 existing examples using Glob/Grep
     - Note: namespace conventions, `declare(strict_types=1)`, `final readonly`, attribute usage
   - Check for PHP-CS-Fixer config to know the code style

3. **Generate the component** following detected conventions and these defaults:

   ### entity
   - Location: `src/Entity/{Name}.php`
   - Create with `#[ORM\Entity]`, `#[ORM\Table]`
   - Include `id`, `createdAt` properties
   - Use `Types::` constants for column types
   - Use `DateTimeImmutable` for timestamps
   - Also create matching repository at `src/Repository/{Name}Repository.php`
   - Suggest: "Run `/php-harmony:doctrine-migration diff` to generate the migration"

   ### controller
   - Location: `src/Controller/{Name}Controller.php`
   - Add `#[AsController]`, `#[Route]` attributes
   - Extend `AbstractController`
   - Include basic CRUD route stubs
   - Use `#[MapRequestPayload]` for POST/PUT endpoints

   ### command
   - Location: `src/Command/{Name}Command.php`
   - Add `#[AsCommand]` with name and description
   - Extend `Command`
   - Include `configure()` and `execute()` methods
   - Use `SymfonyStyle` for output

   ### message
   - Location: `src/Message/{Name}.php`
   - `final readonly class`
   - Constructor with typed parameters (primitives/IDs only)
   - Getters only

   ### message-handler
   - Location: `src/MessageHandler/{Name}Handler.php`
   - `final readonly class` with `#[AsMessageHandler]`
   - `__invoke()` method type-hinted with the message class
   - Inject `LoggerInterface`

   ### voter
   - Location: `src/Security/Voter/{Name}Voter.php`
   - `#[AsVoter]` attribute
   - Extend `Voter<string, {Entity}>`
   - Include `supports()` and `voteOnAttribute()` methods
   - Define permission constants

   ### form
   - Location: `src/Form/{Name}Type.php`
   - Extend `AbstractType`
   - Include `buildForm()` and `configureOptions()` methods

   ### subscriber
   - Location: `src/EventSubscriber/{Name}Subscriber.php` or use `#[AsEventListener]`
   - Implement `EventSubscriberInterface` or use attribute
   - `final readonly class`

4. **Post-generation**:
   - If PHP-CS-Fixer is available, run it on the new file: `vendor/bin/php-cs-fixer fix <file>`
   - Show the generated file content
   - Suggest next steps based on the type
