# Advanced Testing Strategies

## Mocking Patterns

### Mock vs Stub

```php
// Stub: only cares about return values (no expectations)
$repository = $this->createStub(ProductRepository::class);
$repository->method('find')->willReturn(new Product('Test', 100));

// Mock: verifies interactions (has expectations)
$mailer = $this->createMock(MailerInterface::class);
$mailer->expects(self::once())
    ->method('send')
    ->with(self::isInstanceOf(Email::class));
```

### Consecutive Returns

```php
$repository = $this->createStub(ProductRepository::class);
$repository->method('find')
    ->willReturnOnConsecutiveCalls(
        new Product('First', 100),
        new Product('Second', 200),
        null,
    );
```

### Callback-Based Returns

```php
$repository = $this->createStub(ProductRepository::class);
$repository->method('find')
    ->willReturnCallback(function (int $id): ?Product {
        return match ($id) {
            1 => new Product('Widget', 999),
            2 => new Product('Gadget', 1999),
            default => null,
        };
    });
```

### Argument Matching

```php
$service = $this->createMock(NotificationService::class);
$service->expects(self::once())
    ->method('send')
    ->with(
        self::equalTo('user@example.com'),
        self::stringContains('Order confirmed'),
        self::isType('array'),
    );
```

## Database Testing

### Transaction Rollback Per Test

```php
use Doctrine\ORM\EntityManagerInterface;

abstract class DatabaseTestCase extends KernelTestCase
{
    protected EntityManagerInterface $em;

    protected function setUp(): void
    {
        self::bootKernel();
        $this->em = self::getContainer()->get(EntityManagerInterface::class);
        $this->em->beginTransaction();
    }

    protected function tearDown(): void
    {
        $this->em->rollback();
        parent::tearDown();
    }
}
```

### Loading Fixtures

With `doctrine/doctrine-fixtures-bundle`:

```php
use Doctrine\Common\DataFixtures\Purger\ORMPurger;
use Liip\TestFixturesBundle\Services\DatabaseToolCollection;

final class ProductControllerTest extends WebTestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        $this->databaseTool = static::getContainer()->get(DatabaseToolCollection::class)->get();
        $this->databaseTool->loadFixtures([ProductFixtures::class]);
    }
}
```

### Fixture Class

```php
<?php

declare(strict_types=1);

namespace App\DataFixtures;

use App\Entity\Product;
use Doctrine\Bundle\FixturesBundle\Fixture;
use Doctrine\Persistence\ObjectManager;

class ProductFixtures extends Fixture
{
    public function load(ObjectManager $manager): void
    {
        for ($i = 1; $i <= 10; $i++) {
            $product = new Product(
                name: sprintf('Product %d', $i),
                price: $i * 1000,
            );
            $manager->persist($product);
            $this->addReference(sprintf('product-%d', $i), $product);
        }

        $manager->flush();
    }
}
```

## Testing Messenger

### Testing Message Dispatch

```php
use Symfony\Component\Messenger\Transport\InMemoryTransport;

final class OrderServiceTest extends KernelTestCase
{
    public function testOrderCreationDispatchesMessage(): void
    {
        self::bootKernel();
        $container = self::getContainer();

        $service = $container->get(OrderService::class);
        $service->createOrder($dto);

        /** @var InMemoryTransport $transport */
        $transport = $container->get('messenger.transport.async');
        $messages = $transport->getSent();

        self::assertCount(1, $messages);
        self::assertInstanceOf(ProcessOrder::class, $messages[0]->getMessage());
    }
}
```

Configure test transport in `config/packages/test/messenger.yaml`:

```yaml
framework:
    messenger:
        transports:
            async: 'in-memory://'
```

## Testing Console Commands

```php
use Symfony\Bundle\FrameworkBundle\Console\Application;
use Symfony\Component\Console\Tester\CommandTester;

final class ImportProductsCommandTest extends KernelTestCase
{
    public function testExecuteImportsProducts(): void
    {
        self::bootKernel();
        $application = new Application(self::$kernel);

        $command = $application->find('app:import-products');
        $commandTester = new CommandTester($command);
        $commandTester->execute([
            'source' => 'test-data.csv',
            '--dry-run' => true,
        ]);

        $commandTester->assertCommandIsSuccessful();
        self::assertStringContainsString('Imported', $commandTester->getDisplay());
    }
}
```

## Parallel Testing with Paratest

Install: `composer require --dev brianium/paratest`

```bash
# Run with 4 processes
vendor/bin/paratest --processes=4

# With specific configuration
vendor/bin/paratest --configuration=phpunit.xml.dist --processes=4
```

For database isolation in parallel tests, use a separate database per process:

```yaml
# config/packages/test/doctrine.yaml
doctrine:
    dbal:
        url: '%env(resolve:DATABASE_URL)%_test%env(default::TEST_TOKEN)%'
```

## Clock Mocking

For testing time-dependent code, use Symfony's `ClockInterface`:

```php
use Symfony\Component\Clock\ClockInterface;
use Symfony\Component\Clock\MockClock;

final class SubscriptionServiceTest extends TestCase
{
    public function testSubscriptionExpiresAfter30Days(): void
    {
        $clock = new MockClock('2024-01-01 00:00:00');
        $service = new SubscriptionService($clock);

        $subscription = $service->create();
        self::assertFalse($subscription->isExpired());

        $clock->modify('+31 days');
        self::assertTrue($subscription->isExpired());
    }
}
```

## HTTP Client Testing

```php
use Symfony\Component\HttpClient\MockHttpClient;
use Symfony\Component\HttpClient\Response\MockResponse;

$mockClient = new MockHttpClient([
    new MockResponse(json_encode(['status' => 'ok']), [
        'http_code' => 200,
        'response_headers' => ['content-type' => 'application/json'],
    ]),
]);

$service = new ApiClient($mockClient);
$result = $service->fetchStatus();
self::assertSame('ok', $result);
```

## Assertion Tips

- Prefer `self::assertSame()` over `self::assertEquals()` (strict type checking)
- Use `self::assertCount()` over `self::assertSame(3, count($arr))`
- Use `$this->expectException()` before the triggering call, not after
- Use `self::assertStringContainsString()` for partial string matching
- Use `self::assertMatchesRegularExpression()` for pattern matching
