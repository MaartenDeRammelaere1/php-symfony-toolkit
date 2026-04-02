# Messenger Transport Configuration

## RabbitMQ Configuration

### Basic Setup

```yaml
# config/packages/messenger.yaml
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

```dotenv
MESSENGER_TRANSPORT_DSN=amqp://guest:guest@localhost:5672/%2f/messages
```

### Advanced RabbitMQ with Exchanges and Queues

```yaml
framework:
    messenger:
        transports:
            orders:
                dsn: '%env(MESSENGER_TRANSPORT_DSN)%'
                options:
                    exchange:
                        name: orders_exchange
                        type: direct
                    queues:
                        orders_queue:
                            binding_keys: ['order']
                retry_strategy:
                    max_retries: 5
                    delay: 2000
                    multiplier: 3
                    max_delay: 300000

            notifications:
                dsn: '%env(MESSENGER_TRANSPORT_DSN)%'
                options:
                    exchange:
                        name: notifications_exchange
                        type: fanout
                    queues:
                        notifications_queue: ~

            failed:
                dsn: 'doctrine://default?queue_name=failed'

        routing:
            App\Message\ProcessOrder: orders
            App\Message\SendNotification: notifications
```

### Topic Exchange (Pattern-Based Routing)

```yaml
framework:
    messenger:
        transports:
            events:
                dsn: '%env(MESSENGER_TRANSPORT_DSN)%'
                options:
                    exchange:
                        name: events_exchange
                        type: topic
                    queues:
                        order_events:
                            binding_keys: ['order.*']
                        payment_events:
                            binding_keys: ['payment.*']
                        all_events:
                            binding_keys: ['#']
```

## Retry Strategies

### Configuration Options

```yaml
retry_strategy:
    max_retries: 3         # Number of retry attempts
    delay: 1000            # Initial delay in milliseconds
    multiplier: 2          # Multiply delay by this factor each retry
    max_delay: 60000       # Maximum delay cap in milliseconds
    # service: App\Messenger\CustomRetryStrategy  # Custom strategy
```

### Retry Behavior Example

With `delay: 1000`, `multiplier: 2`, `max_retries: 3`:
1. First retry: 1000ms (1 second)
2. Second retry: 2000ms (2 seconds)
3. Third retry: 4000ms (4 seconds)
4. After 3rd failure → sent to failed transport

### Per-Exception Retry

```php
use Symfony\Component\Messenger\Exception\RecoverableExceptionInterface;
use Symfony\Component\Messenger\Exception\UnrecoverableExceptionInterface;

// Implement RecoverableExceptionInterface to always retry
class TemporaryApiException extends \RuntimeException implements RecoverableExceptionInterface
{
}

// Implement UnrecoverableExceptionInterface to never retry
class InvalidPayloadException extends \RuntimeException implements UnrecoverableExceptionInterface
{
}
```

## Doctrine Transport

Simpler alternative when RabbitMQ is not available:

```yaml
framework:
    messenger:
        transports:
            async:
                dsn: 'doctrine://default?auto_setup=true'
                retry_strategy:
                    max_retries: 3
                    delay: 1000
                    multiplier: 2
```

Doctrine transport uses a database table for the queue. Good for development and low-throughput applications.

## Multiple Buses

```yaml
framework:
    messenger:
        default_bus: command.bus
        buses:
            command.bus:
                middleware:
                    - doctrine_transaction
            query.bus:
                middleware: []
            event.bus:
                default_middleware:
                    allow_no_handlers: true
```

## Worker Configuration

### Supervisor Config (Production)

```ini
[program:messenger-consume]
command=php /path/to/project/bin/console messenger:consume async --time-limit=3600 --memory-limit=128M -vv
user=www-data
numprocs=2
startsecs=0
autostart=true
autorestart=true
startretries=10
process_name=%(program_name)s_%(process_num)02d
stderr_logfile=/var/log/messenger_err.log
stdout_logfile=/var/log/messenger_out.log
```

### Systemd Config (Alternative)

```ini
[Unit]
Description=Symfony Messenger Consumer
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/path/to/project
ExecStart=/usr/bin/php bin/console messenger:consume async --time-limit=3600 --memory-limit=128M
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

## FrankenPHP Worker Mode

When using FrankenPHP runtime, the Messenger worker runs in the same process:

```yaml
# config/packages/messenger.yaml
framework:
    messenger:
        transports:
            async:
                dsn: '%env(MESSENGER_TRANSPORT_DSN)%'
```

FrankenPHP handles worker lifecycle, so time/memory limits are managed by the runtime, not Supervisor.

## Monitoring Failed Messages

```bash
# View failed messages
php bin/console messenger:failed:show

# View count by message class
php bin/console messenger:failed:show --stats

# Retry specific messages
php bin/console messenger:failed:retry 20 30 --force

# Remove without retrying
php bin/console messenger:failed:remove 20

# Remove all
php bin/console messenger:failed:remove --all
```
