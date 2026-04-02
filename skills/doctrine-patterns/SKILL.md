---
name: doctrine-patterns
description: Doctrine ORM patterns and best practices for Symfony. Use when creating entities, writing repositories, defining entity relations, mapping database columns, writing DQL or QueryBuilder queries, creating migrations, or asking about Doctrine ORM, database schema, or query optimization in Symfony.
paths: "*.php"
---

# Doctrine ORM Patterns

## Entity Design

Entities use PHP 8 attributes for mapping. Always import `Doctrine\DBAL\Types\Types` for type constants:

```php
<?php

declare(strict_types=1);

namespace App\Entity;

use App\Repository\ProductRepository;
use Doctrine\DBAL\Types\Types;
use Doctrine\ORM\Mapping as ORM;

#[ORM\Entity(repositoryClass: ProductRepository::class)]
#[ORM\Table(name: 'product')]
class Product
{
    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column(type: Types::INTEGER)]
    private ?int $id = null;

    #[ORM\Column(type: Types::STRING, length: 255)]
    private string $name;

    #[ORM\Column(type: Types::TEXT, nullable: true)]
    private ?string $description = null;

    #[ORM\Column(type: Types::INTEGER)]
    private int $price;

    #[ORM\Column(type: Types::STRING, enumType: ProductStatus::class)]
    private ProductStatus $status;

    #[ORM\Column(type: Types::DATETIME_IMMUTABLE)]
    private \DateTimeImmutable $createdAt;

    public function __construct(
        string $name,
        int $price,
        ProductStatus $status = ProductStatus::Draft,
    ) {
        $this->name = $name;
        $this->price = $price;
        $this->status = $status;
        $this->createdAt = new \DateTimeImmutable();
    }
}
```

### Key rules

1. **ID pattern**: `?int $id = null` with `#[ORM\Id]`, `#[ORM\GeneratedValue]`, `#[ORM\Column(type: Types::INTEGER)]`
2. **Use `Types::` constants**: `Types::STRING`, `Types::INTEGER`, `Types::TEXT`, `Types::DATETIME_IMMUTABLE`, etc. Never use string literals for types
3. **Prefer `DateTimeImmutable`**: Use `Types::DATETIME_IMMUTABLE` over `Types::DATETIME_MUTABLE` for all date/time columns
4. **BackedEnum support**: Use `enumType` parameter on `#[ORM\Column]` for PHP 8.1+ enums
5. **Constructor**: Required fields as parameters, set `createdAt` in constructor
6. **Nullable**: Only mark properties `nullable: true` when the business logic genuinely allows null values

### Getters and Setters

- Return types on all getters
- `void` return type on setters
- Add business logic methods on the entity where appropriate:

```php
public function getId(): ?int
{
    return $this->id;
}

public function getName(): string
{
    return $this->name;
}

public function setName(string $name): void
{
    $this->name = $name;
}

public function isPublished(): bool
{
    return $this->status === ProductStatus::Published;
}
```

## Relationships

### OneToMany / ManyToOne

```php
use Doctrine\Common\Collections\ArrayCollection;
use Doctrine\Common\Collections\Collection;

class Order
{
    /** @var Collection<int, OrderLine> */
    #[ORM\OneToMany(targetEntity: OrderLine::class, mappedBy: 'order', cascade: ['persist', 'remove'], orphanRemoval: true)]
    private Collection $orderLines;

    public function __construct()
    {
        $this->orderLines = new ArrayCollection();
    }

    /** @return Collection<int, OrderLine> */
    public function getOrderLines(): Collection
    {
        return $this->orderLines;
    }

    public function addOrderLine(OrderLine $orderLine): void
    {
        if (!$this->orderLines->contains($orderLine)) {
            $this->orderLines->add($orderLine);
            $orderLine->setOrder($this);
        }
    }

    public function removeOrderLine(OrderLine $orderLine): void
    {
        if ($this->orderLines->removeElement($orderLine)) {
            $orderLine->setOrder(null);
        }
    }
}
```

### ManyToMany

```php
/** @var Collection<int, Tag> */
#[ORM\ManyToMany(targetEntity: Tag::class, inversedBy: 'products')]
#[ORM\JoinTable(name: 'product_tag')]
private Collection $tags;
```

### Key relationship rules
- Always initialize collections in the constructor: `$this->items = new ArrayCollection()`
- Use PHPDoc generics: `Collection<int, Entity>`
- Set `orphanRemoval: true` on owning OneToMany when child entities have no meaning without the parent
- Use `cascade: ['persist']` sparingly — only when the child is always created with the parent

## Repository Pattern

Extend `ServiceEntityRepository` with typed methods:

```php
<?php

declare(strict_types=1);

namespace App\Repository;

use App\Entity\Product;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

/** @extends ServiceEntityRepository<Product> */
class ProductRepository extends ServiceEntityRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, Product::class);
    }

    /** @return Product[] */
    public function findActiveByCategory(string $category): array
    {
        return $this->createQueryBuilder('p')
            ->andWhere('p.status = :status')
            ->andWhere('p.category = :category')
            ->setParameter('status', ProductStatus::Active)
            ->setParameter('category', $category)
            ->orderBy('p.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }

    public function findLatestByExternalId(string $externalId): ?Product
    {
        return $this->createQueryBuilder('p')
            ->andWhere('p.externalId = :externalId')
            ->setParameter('externalId', $externalId)
            ->orderBy('p.createdAt', 'DESC')
            ->setMaxResults(1)
            ->getQuery()
            ->getOneOrNullResult();
    }
}
```

### Query guidelines
- Use `andWhere()` consistently (it works the same as `where()` for the first call)
- Use named parameters with `setParameter()`
- Return typed results (`?Entity`, `Entity[]`)
- Use `getOneOrNullResult()` for single-result queries
- Use `getResult()` for collections

## Migrations

### Workflow

```bash
# Generate migration from entity changes
php bin/console doctrine:migrations:diff

# Review the generated migration SQL before running
php bin/console doctrine:migrations:status

# Execute migrations
php bin/console doctrine:migrations:migrate

# Rollback last migration
php bin/console doctrine:migrations:migrate prev
```

### Migration best practices
- Always review generated SQL before running
- Watch for destructive operations (DROP TABLE, DROP COLUMN) and confirm intent
- Separate schema migrations from data migrations
- Never modify an already-executed migration — create a new one instead
- Version format: `VersionYYYYMMDDHHMMSS`

## Additional Resources

- For advanced entity design (inheritance, embeddables, lifecycle callbacks), see [entity-design.md](references/entity-design.md)
- For QueryBuilder patterns, pagination, and batch processing, see [repository-patterns.md](references/repository-patterns.md)
