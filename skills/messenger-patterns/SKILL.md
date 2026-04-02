---
name: messenger-patterns
description: Symfony Messenger component patterns for async processing. Use when creating messages, message handlers, configuring message buses, adding middleware, setting up RabbitMQ or AMQP transports, or asking about async processing, message queues, or background jobs in Symfony.
paths: "*.php"
---

# Symfony Messenger Patterns

## Message Design

Messages are simple data carriers. They MUST be `final readonly class` and carry only primitive types or IDs — never entities:

```php
<?php

declare(strict_types=1);

namespace App\Message;

final readonly class ProcessOrder
{
    public function __construct(
        private int $orderId,
        private string $action,
    ) {
    }

    public function getOrderId(): int
    {
        return $this->orderId;
    }

    public function getAction(): string
    {
        return $this->action;
    }
}
```

### Key rules
- **Never pass entities** in messages — they may be stale or detached when processed. Pass IDs and re-fetch in the handler
- Use primitive types only: `int`, `string`, `float`, `bool`, `array` (of primitives)
- Getters only, no setters — messages are immutable
- One message per use case (don't reuse messages for different purposes)
- For messages that need routing, add a routing key method:

```php
public function getRoutingKey(): string
{
    return sprintf('order.%s', $this->action);
}
```

## Message Handler Design

Handlers are `final readonly class` with `#[AsMessageHandler]` and a single `__invoke` method:

```php
<?php

declare(strict_types=1);

namespace App\MessageHandler;

use App\Message\ProcessOrder;
use App\Service\OrderService;
use Psr\Log\LoggerInterface;
use Symfony\Component\Messenger\Attribute\AsMessageHandler;

#[AsMessageHandler]
final readonly class ProcessOrderHandler
{
    public function __construct(
        private OrderService $orderService,
        private LoggerInterface $logger,
    ) {
    }

    public function __invoke(ProcessOrder $message): void
    {
        $this->logger->info('Processing order', [
            'orderId' => $message->getOrderId(),
            'action' => $message->getAction(),
        ]);

        $this->orderService->process(
            $message->getOrderId(),
            $message->getAction(),
        );
    }
}
```

### Handler guidelines
- One `__invoke` method, type-hinted with the message class
- Keep handlers thin — delegate business logic to a service
- Always inject `LoggerInterface` for observability
- Re-fetch entities from the repository using the ID from the message
- Handle exceptions gracefully — unhandled exceptions trigger the retry mechanism

## Transport Configuration

### messenger.yaml

```yaml
framework:
    messenger:
        transports:
            async:
                dsn: '%env(MESSENGER_TRANSPORT_DSN)%'
                retry_strategy:
                    max_retries: 3
                    delay: 1000
                    multiplier: 2
                    max_delay: 60000
            failed:
                dsn: 'doctrine://default?queue_name=failed'

        routing:
            App\Message\ProcessOrder: async
            App\Message\SendNotification: async
```

### Environment variable

```dotenv
# RabbitMQ
MESSENGER_TRANSPORT_DSN=amqp://guest:guest@localhost:5672/%2f/messages

# Doctrine (simpler alternative)
MESSENGER_TRANSPORT_DSN=doctrine://default?auto_setup=true
```

### RabbitMQ-specific options

```yaml
framework:
    messenger:
        transports:
            async:
                dsn: '%env(MESSENGER_TRANSPORT_DSN)%'
                options:
                    exchange:
                        name: app_exchange
                        type: direct
                    queues:
                        app_queue:
                            binding_keys: ['app']
```

## Middleware

Custom middleware wraps the message handling pipeline:

```php
<?php

declare(strict_types=1);

namespace App\Middleware;

use Symfony\Component\Messenger\Envelope;
use Symfony\Component\Messenger\Middleware\MiddlewareInterface;
use Symfony\Component\Messenger\Middleware\StackInterface;

final readonly class LoggingMiddleware implements MiddlewareInterface
{
    public function __construct(
        private LoggerInterface $logger,
    ) {
    }

    public function handle(Envelope $envelope, StackInterface $stack): Envelope
    {
        $this->logger->info('Handling message', [
            'class' => $envelope->getMessage()::class,
        ]);

        return $stack->next()->handle($envelope, $stack);
    }
}
```

Register middleware in `messenger.yaml`:

```yaml
framework:
    messenger:
        buses:
            messenger.bus.default:
                middleware:
                    - App\Middleware\LoggingMiddleware
```

## Failed Message Management

```bash
# View failed messages
php bin/console messenger:failed:show

# Retry specific failed messages
php bin/console messenger:failed:retry 20 30 --force

# Remove a message without retrying
php bin/console messenger:failed:remove 20

# Retry all interactively
php bin/console messenger:failed:retry -vv
```

## Consuming Messages

```bash
# Start a worker
php bin/console messenger:consume async -vv

# Consume with limits (recommended for production)
php bin/console messenger:consume async --time-limit=3600 --memory-limit=128M

# Consume from multiple transports
php bin/console messenger:consume async priority_high
```

In production, use a process manager (Supervisor, systemd) to keep workers running and restart them after the time/memory limits.

## Additional Resources

- For RabbitMQ exchange/queue configuration and retry strategies, see [transport-config.md](references/transport-config.md)
