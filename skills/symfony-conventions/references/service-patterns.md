# Service Design Patterns

## Standard Service Pattern

Services should be `final readonly` with constructor injection:

```php
<?php

declare(strict_types=1);

namespace App\Service;

use App\Repository\ProductRepository;
use Psr\Log\LoggerInterface;

final readonly class ProductService
{
    public function __construct(
        private ProductRepository $productRepository,
        private LoggerInterface $logger,
    ) {
    }

    public function findActiveProducts(string $category): array
    {
        $this->logger->info('Fetching active products', ['category' => $category]);

        return $this->productRepository->findActiveByCategory($category);
    }
}
```

## DataHandler Pattern

For processing incoming data from external sources (webhooks, APIs, imports), use a DataHandler that coordinates validation, transformation, and persistence:

```php
<?php

declare(strict_types=1);

namespace App\DataHandler;

use App\Dto\WebhookDto;
use App\Entity\Webhook;
use App\Repository\WebhookRepository;
use Psr\Log\LoggerInterface;

final readonly class WebhookDataHandler
{
    public function __construct(
        private WebhookRepository $webhookRepository,
        private WebhookValidator $validator,
        private LoggerInterface $logger,
    ) {
    }

    public function handle(WebhookDto $dto): Webhook
    {
        $this->validator->validate($dto);

        $webhook = new Webhook(
            gatewayDeviceId: $dto->gatewayDeviceId,
            eventType: $dto->eventType,
            data: $dto->data,
        );

        $this->webhookRepository->save($webhook);

        $this->logger->info('Webhook processed', [
            'id' => $webhook->getId(),
            'eventType' => $dto->eventType,
        ]);

        return $webhook;
    }
}
```

## DTO Patterns

### Request DTO with MapRequestPayload

```php
<?php

declare(strict_types=1);

namespace App\Dto;

use Symfony\Component\Validator\Constraints as Assert;

final readonly class CreateProductDto
{
    public function __construct(
        #[Assert\NotBlank]
        #[Assert\Length(max: 255)]
        public string $name,

        #[Assert\Positive]
        public int $price,

        #[Assert\NotBlank]
        public string $category,

        public ?string $description = null,
    ) {
    }
}
```

Use in controller with `#[MapRequestPayload]`:

```php
#[Route('', name: 'create', methods: ['POST'])]
public function create(#[MapRequestPayload] CreateProductDto $dto): JsonResponse
{
    $product = $this->productService->create($dto);
    return $this->json($product, Response::HTTP_CREATED);
}
```

### Response DTO

```php
<?php

declare(strict_types=1);

namespace App\Dto;

final readonly class ProductResponse
{
    public function __construct(
        public int $id,
        public string $name,
        public int $price,
        public string $status,
        public string $createdAt,
    ) {
    }

    public static function fromEntity(Product $product): self
    {
        return new self(
            id: $product->getId(),
            name: $product->getName(),
            price: $product->getPrice(),
            status: $product->getStatus()->value,
            createdAt: $product->getCreatedAt()->format(\DateTimeInterface::ATOM),
        );
    }
}
```

## Event Subscriber Pattern

```php
<?php

declare(strict_types=1);

namespace App\EventSubscriber;

use App\Event\OrderCreatedEvent;
use Psr\Log\LoggerInterface;
use Symfony\Component\EventDispatcher\EventSubscriberInterface;

final readonly class OrderNotificationSubscriber implements EventSubscriberInterface
{
    public function __construct(
        private NotificationService $notificationService,
        private LoggerInterface $logger,
    ) {
    }

    public static function getSubscribedEvents(): array
    {
        return [
            OrderCreatedEvent::class => 'onOrderCreated',
        ];
    }

    public function onOrderCreated(OrderCreatedEvent $event): void
    {
        $this->logger->info('Sending order notification', ['orderId' => $event->getOrderId()]);

        $this->notificationService->sendOrderConfirmation($event->getOrderId());
    }
}
```

Or using the attribute-based approach (Symfony 6.2+):

```php
<?php

declare(strict_types=1);

namespace App\EventListener;

use Symfony\Component\EventDispatcher\Attribute\AsEventListener;
use Symfony\Component\HttpKernel\Event\ExceptionEvent;
use Symfony\Component\HttpKernel\KernelEvents;

#[AsEventListener(event: KernelEvents::EXCEPTION, priority: 10)]
final readonly class ExceptionListener
{
    public function __invoke(ExceptionEvent $event): void
    {
        // Handle exception
    }
}
```

## Console Command Pattern

```php
<?php

declare(strict_types=1);

namespace App\Command;

use Symfony\Component\Console\Attribute\AsCommand;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputArgument;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Input\InputOption;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\Console\Style\SymfonyStyle;

#[AsCommand(
    name: 'app:import-products',
    description: 'Import products from an external source',
)]
final class ImportProductsCommand extends Command
{
    public function __construct(
        private readonly ProductImporter $importer,
    ) {
        parent::__construct();
    }

    protected function configure(): void
    {
        $this
            ->addArgument('source', InputArgument::REQUIRED, 'The data source URL or file path')
            ->addOption('dry-run', null, InputOption::VALUE_NONE, 'Preview changes without persisting');
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        $io = new SymfonyStyle($input, $output);
        $source = $input->getArgument('source');
        $dryRun = $input->getOption('dry-run');

        $io->title('Importing products');

        $result = $this->importer->import($source, $dryRun);

        $io->success(sprintf('Imported %d products.', $result->getCount()));

        return Command::SUCCESS;
    }
}
```

## Symfony Workflow Integration

For entities with state machines:

```php
use Symfony\Component\Workflow\WorkflowInterface;

final readonly class OrderService
{
    public function __construct(
        private WorkflowInterface $orderStateMachine,
        private OrderRepository $orderRepository,
    ) {
    }

    public function ship(int $orderId): void
    {
        $order = $this->orderRepository->find($orderId);

        if ($this->orderStateMachine->can($order, 'ship')) {
            $this->orderStateMachine->apply($order, 'ship');
            $this->orderRepository->save($order);
        }
    }
}
```
