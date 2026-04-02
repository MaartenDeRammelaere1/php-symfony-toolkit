---
name: testing-patterns
description: PHP and Symfony testing patterns with PHPUnit. Use when writing unit tests, integration tests, functional tests, creating test cases, mocking services, testing controllers, testing Doctrine entities or repositories, configuring PHPUnit, or asking about PHP testing strategies.
paths: "*.php"
---

# PHP & Symfony Testing Patterns

## Test Organization

Mirror the `src/` directory structure under `tests/` with clear separation:

```
tests/
├── Unit/              # Fast, isolated tests — no framework or database
│   ├── Service/
│   ├── Dto/
│   └── Entity/
├── Integration/       # Tests with framework container and real services
│   ├── Repository/
│   └── Service/
└── Functional/        # HTTP-level tests through controllers
    └── Controller/
```

Test class naming: `{ClassName}Test` in the matching namespace.

## PHPUnit Configuration

`phpunit.xml.dist` (committed to VCS, never `phpunit.xml`):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<phpunit xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:noNamespaceSchemaLocation="vendor/phpunit/phpunit/phpunit.xsd"
         bootstrap="tests/bootstrap.php"
         colors="true"
         executionOrder="depends,defects"
>
    <php>
        <ini name="display_errors" value="1"/>
        <ini name="error_reporting" value="-1"/>
        <server name="APP_ENV" value="test" force="true"/>
        <server name="SHELL_VERBOSITY" value="-1"/>
    </php>

    <testsuites>
        <testsuite name="Unit">
            <directory>tests/Unit</directory>
        </testsuite>
        <testsuite name="Integration">
            <directory>tests/Integration</directory>
        </testsuite>
        <testsuite name="Functional">
            <directory>tests/Functional</directory>
        </testsuite>
    </testsuites>
</phpunit>
```

## Unit Tests

Extend `TestCase`. No framework, no database. Test a single behavior per method:

```php
<?php

declare(strict_types=1);

namespace App\Tests\Unit\Service;

use App\Dto\WebhookDto;
use App\Service\WebhookValidator;
use PHPUnit\Framework\TestCase;

final class WebhookValidatorTest extends TestCase
{
    private WebhookValidator $validator;

    protected function setUp(): void
    {
        $this->validator = new WebhookValidator();
    }

    public function testValidateAcceptsValidPayload(): void
    {
        $dto = new WebhookDto(
            gatewayDeviceId: 'device-123',
            eventType: 'temperature',
            data: ['value' => '22.5'],
        );

        $result = $this->validator->validate($dto);

        self::assertTrue($result->isValid());
    }

    public function testValidateRejectsEmptyDeviceId(): void
    {
        $dto = new WebhookDto(
            gatewayDeviceId: '',
            eventType: 'temperature',
            data: [],
        );

        $result = $this->validator->validate($dto);

        self::assertFalse($result->isValid());
        self::assertContains('gatewayDeviceId', $result->getErrors());
    }
}
```

### Test naming convention

`test{Behavior}When{Condition}` or `test{ExpectedResult}`:
- `testValidateAcceptsValidPayload`
- `testCalculateTotalReturnsZeroForEmptyCart`
- `testThrowsExceptionWhenProductNotFound`

### Mocking

Use `createMock()` for dependencies, `createStub()` when you only need return values:

```php
public function testProcessDelegatesToService(): void
{
    $orderService = $this->createMock(OrderService::class);
    $orderService->expects(self::once())
        ->method('process')
        ->with(42, 'ship');

    $handler = new ProcessOrderHandler($orderService, new NullLogger());
    $handler(new ProcessOrder(orderId: 42, action: 'ship'));
}
```

### Data Providers

Use data providers for parameterized tests:

```php
/** @dataProvider statusTransitionProvider */
public function testStatusTransition(OrderStatus $from, OrderStatus $to, bool $allowed): void
{
    $order = new Order(status: $from);

    if (!$allowed) {
        $this->expectException(InvalidStatusTransitionException::class);
    }

    $order->transitionTo($to);

    if ($allowed) {
        self::assertSame($to, $order->getStatus());
    }
}

/** @return iterable<string, array{OrderStatus, OrderStatus, bool}> */
public static function statusTransitionProvider(): iterable
{
    yield 'pending to processing' => [OrderStatus::Pending, OrderStatus::Processing, true];
    yield 'pending to completed' => [OrderStatus::Pending, OrderStatus::Completed, false];
    yield 'processing to completed' => [OrderStatus::Processing, OrderStatus::Completed, true];
}
```

## Integration Tests

Extend `KernelTestCase`. Use the real Symfony container and database:

```php
<?php

declare(strict_types=1);

namespace App\Tests\Integration\Repository;

use App\Entity\Product;
use App\Repository\ProductRepository;
use Symfony\Bundle\FrameworkBundle\Test\KernelTestCase;

final class ProductRepositoryTest extends KernelTestCase
{
    private ProductRepository $repository;

    protected function setUp(): void
    {
        self::bootKernel();
        $this->repository = self::getContainer()->get(ProductRepository::class);
    }

    public function testFindActiveByCategory(): void
    {
        // ... test with real database
        $products = $this->repository->findActiveByCategory('electronics');

        self::assertCount(2, $products);
    }
}
```

## Functional / Controller Tests

Extend `WebTestCase`. Test HTTP request/response cycle:

```php
<?php

declare(strict_types=1);

namespace App\Tests\Functional\Controller;

use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\Response;

final class ProductControllerTest extends WebTestCase
{
    public function testListProducts(): void
    {
        $client = static::createClient();
        $client->request('GET', '/api/products');

        self::assertResponseIsSuccessful();
        self::assertResponseHeaderSame('content-type', 'application/json');
    }

    public function testCreateProductRequiresAuthentication(): void
    {
        $client = static::createClient();
        $client->request('POST', '/api/products', [], [], [
            'CONTENT_TYPE' => 'application/json',
        ], json_encode(['name' => 'Test']));

        self::assertResponseStatusCodeSame(Response::HTTP_UNAUTHORIZED);
    }

    public function testCreateProduct(): void
    {
        $client = static::createClient();
        // Authenticate if needed
        $client->request('POST', '/api/products', [], [], [
            'CONTENT_TYPE' => 'application/json',
        ], json_encode([
            'name' => 'Test Product',
            'price' => 1999,
        ]));

        self::assertResponseStatusCodeSame(Response::HTTP_CREATED);

        $response = json_decode($client->getResponse()->getContent(), true);
        self::assertSame('Test Product', $response['name']);
    }
}
```

## Running Tests

```bash
# Run all tests
vendor/bin/phpunit

# Run specific suite
vendor/bin/phpunit --testsuite=Unit

# Run with filter
vendor/bin/phpunit --filter=ProductRepository

# Run with coverage
vendor/bin/phpunit --coverage-text

# Parallel execution (if Paratest available)
vendor/bin/paratest --processes=4
```

## Key Assertions

- `self::assertSame()` for strict equality (preferred over `assertEquals`)
- `self::assertTrue()` / `self::assertFalse()` for booleans
- `self::assertNull()` / `self::assertNotNull()`
- `self::assertCount()` for collections
- `self::assertInstanceOf()` for type checks
- `$this->expectException(ExceptionClass::class)` before the triggering call

Always use `self::` for static assertion methods, not `$this->assert*()`.

## Additional Resources

- For advanced testing strategies (mocking, fixtures, factories, database isolation), see [testing-strategies.md](references/testing-strategies.md)
