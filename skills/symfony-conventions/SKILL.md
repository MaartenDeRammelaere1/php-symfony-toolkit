---
name: symfony-conventions
description: PHP and Symfony coding conventions and best practices. Use when creating controllers, services, DTOs, console commands, event subscribers, form types, or any PHP class in a Symfony project. Also use when asking about PHP coding standards, dependency injection, service configuration, or PHP-CS-Fixer rules.
paths: "*.php"
---

# PHP & Symfony Coding Conventions

## File-Level Requirements

Every PHP file MUST start with `declare(strict_types=1)` immediately after the opening `<?php` tag, with one blank line before the namespace declaration:

```php
<?php

declare(strict_types=1);

namespace App\Service;
```

One class per file. File name matches class name exactly (PSR-4).

## Class Design Defaults

Use `final readonly class` as the default for:
- Services
- Messages and message handlers
- DTOs (Data Transfer Objects)
- Console commands
- Event subscribers

```php
final readonly class OrderProcessor
{
    public function __construct(
        private OrderRepository $orderRepository,
        private LoggerInterface $logger,
    ) {
    }
}
```

Only omit `final` when inheritance is intentionally needed (e.g., abstract base classes). Only omit `readonly` when the class has mutable state that is genuinely required.

## Constructor Property Promotion

Always use constructor property promotion with visibility modifiers. Prefer `private readonly` for service dependencies:

```php
// Correct
public function __construct(
    private readonly EntityManagerInterface $entityManager,
    private readonly LoggerInterface $logger,
) {
}

// Wrong - don't assign manually when promotion works
public function __construct(EntityManagerInterface $entityManager)
{
    $this->entityManager = $entityManager;
}
```

Always include trailing commas in multi-line parameter lists.

## PHP 8 Attributes Over Annotations

Always use PHP 8 attributes, never `@` annotations:

```php
// Controllers
#[AsController]
#[Route('/api/products', name: 'api_products_')]
final class ProductController extends AbstractController
{
    #[Route('/{id}', name: 'show', methods: ['GET'])]
    public function show(Product $product): JsonResponse
    {
    }
}

// Console commands
#[AsCommand(name: 'app:import-products', description: 'Import products from external source')]
final class ImportProductsCommand extends Command
{
}

// Event subscribers
#[AsEventListener(event: KernelEvents::EXCEPTION)]
final readonly class ExceptionListener
{
}

// Message handlers
#[AsMessageHandler]
final readonly class ProcessOrderHandler
{
}
```

## Type Strictness

- All parameters MUST be typed
- All return types MUST be declared (including `void`)
- Use union types where appropriate: `string|int`
- Use intersection types for combined interfaces: `Countable&Iterator`
- Use `BackedEnum` for status/type fields:

```php
enum OrderStatus: string
{
    case Pending = 'pending';
    case Processing = 'processing';
    case Completed = 'completed';
    case Cancelled = 'cancelled';
}
```

## Service Design

- One responsibility per service
- Constructor injection only (no setter injection, no property injection)
- Type-hint interfaces where polymorphism is needed (`LoggerInterface`, `EntityManagerInterface`)
- Inject `LoggerInterface` for services that need logging
- Services are autowired by default in Symfony — avoid manual service definitions unless necessary

## Controller Patterns

Controllers MUST be thin — delegate business logic to services:

```php
#[AsController]
#[Route('/api/webhooks', name: 'api_webhooks_')]
final class WebhookController extends AbstractController
{
    public function __construct(
        private readonly WebhookService $webhookService,
    ) {
    }

    #[Route('', name: 'create', methods: ['POST'])]
    public function create(#[MapRequestPayload] WebhookDto $dto): JsonResponse
    {
        $webhook = $this->webhookService->process($dto);

        return $this->json($webhook, Response::HTTP_CREATED);
    }
}
```

Key patterns:
- Use `#[MapRequestPayload]` for request body deserialization (Symfony 6.3+)
- Use `#[MapQueryString]` for query parameter mapping
- Return typed Response objects
- Named routes for URL generation

## DTO Design

DTOs should be `final readonly class` with public properties and optional static factory methods:

```php
final readonly class WebhookDto
{
    public function __construct(
        public string $gatewayDeviceId,
        public string $eventType,
        public array $data,
    ) {
    }

    public static function createFromArray(array $data): self
    {
        return new self(
            gatewayDeviceId: $data['gatewayDeviceId'],
            eventType: $data['eventType'] ?? '',
            data: $data['data'] ?? [],
        );
    }
}
```

## PHP-CS-Fixer Rules

Projects use `@Symfony` as the base ruleset with these customizations:

```php
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
    ]);
```

Key rules:
- No Yoda conditions (`$status === 'active'`, not `'active' === $status`)
- Spaces around concatenation (`$a . $b`, not `$a.$b`)
- Trailing commas everywhere in multiline constructs
- Left-aligned PHPDoc

## PHPStan

Use the highest practical level (aim for `max`). Configure in `phpstan.neon`:

```neon
parameters:
    level: max
    paths:
        - src/
        - tests/
```

Use phpstan-symfony and phpstan-doctrine extensions for framework-aware analysis. Use baseline files (`phpstan-baseline.neon`) for legacy code.

## Debug Statements

NEVER commit debug statements. The following are blacklisted:
`die()`, `dd()`, `dump()`, `var_dump()`, `print_r()`, `debug_backtrace()`, `file_put_contents()`, `ray()`

Use `LoggerInterface` instead for any debugging that needs to persist.

## Additional Resources

- For detailed PHP-CS-Fixer configuration and PHPStan setup, see [coding-standards.md](references/coding-standards.md)
- For service design patterns and DTO examples, see [service-patterns.md](references/service-patterns.md)
