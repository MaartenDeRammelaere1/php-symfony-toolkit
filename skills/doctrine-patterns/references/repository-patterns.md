# Repository Patterns

## QueryBuilder Best Practices

### Composable Query Methods

```php
/** @extends ServiceEntityRepository<Product> */
class ProductRepository extends ServiceEntityRepository
{
    public function createBaseQuery(): QueryBuilder
    {
        return $this->createQueryBuilder('p')
            ->andWhere('p.deletedAt IS NULL');
    }

    /** @return Product[] */
    public function findActiveByCategory(string $category, int $limit = 50): array
    {
        return $this->createBaseQuery()
            ->andWhere('p.status = :status')
            ->andWhere('p.category = :category')
            ->setParameter('status', ProductStatus::Active)
            ->setParameter('category', $category)
            ->orderBy('p.createdAt', 'DESC')
            ->setMaxResults($limit)
            ->getQuery()
            ->getResult();
    }

    public function findOneByExternalId(string $externalId): ?Product
    {
        return $this->createBaseQuery()
            ->andWhere('p.externalId = :externalId')
            ->setParameter('externalId', $externalId)
            ->getQuery()
            ->getOneOrNullResult();
    }
}
```

### Joins and Eager Loading

```php
/** @return Product[] */
public function findWithCategoryAndTags(): array
{
    return $this->createQueryBuilder('p')
        ->leftJoin('p.category', 'c')
        ->addSelect('c')
        ->leftJoin('p.tags', 't')
        ->addSelect('t')
        ->orderBy('p.name', 'ASC')
        ->getQuery()
        ->getResult();
}
```

Always `addSelect()` joined entities to avoid N+1 queries.

### Aggregate Queries

```php
public function countByStatus(): array
{
    return $this->createQueryBuilder('p')
        ->select('p.status, COUNT(p.id) as total')
        ->groupBy('p.status')
        ->getQuery()
        ->getResult();
}

public function getTotalRevenue(): int
{
    return (int) $this->createQueryBuilder('p')
        ->select('SUM(p.price)')
        ->andWhere('p.status = :status')
        ->setParameter('status', ProductStatus::Sold)
        ->getQuery()
        ->getSingleScalarResult();
}
```

## Pagination

### With Doctrine Paginator

```php
use Doctrine\ORM\Tools\Pagination\Paginator;

/** @return Paginator<Product> */
public function findPaginated(int $page, int $limit = 20): Paginator
{
    $query = $this->createQueryBuilder('p')
        ->orderBy('p.createdAt', 'DESC')
        ->setFirstResult(($page - 1) * $limit)
        ->setMaxResults($limit)
        ->getQuery();

    return new Paginator($query);
}

// Usage:
$paginator = $repository->findPaginated(page: 2, limit: 20);
$totalItems = count($paginator); // Total count (uses COUNT query)
foreach ($paginator as $product) {
    // ...
}
```

### With Pagerfanta

```php
use Pagerfanta\Doctrine\ORM\QueryAdapter;
use Pagerfanta\Pagerfanta;

public function findPaginated(int $page, int $limit = 20): Pagerfanta
{
    $qb = $this->createQueryBuilder('p')
        ->orderBy('p.createdAt', 'DESC');

    $pagerfanta = new Pagerfanta(new QueryAdapter($qb));
    $pagerfanta->setMaxPerPage($limit);
    $pagerfanta->setCurrentPage($page);

    return $pagerfanta;
}
```

## Batch Processing

### With iterate() for Memory Efficiency

```php
public function processAllProducts(callable $callback): void
{
    $query = $this->createQueryBuilder('p')
        ->getQuery();

    foreach ($query->toIterable() as $product) {
        $callback($product);
        $this->getEntityManager()->detach($product);
    }
}
```

### Batch Updates

```php
public function deactivateOlderThan(\DateTimeImmutable $date): int
{
    return $this->createQueryBuilder('p')
        ->update()
        ->set('p.status', ':status')
        ->andWhere('p.createdAt < :date')
        ->setParameter('status', ProductStatus::Inactive->value)
        ->setParameter('date', $date)
        ->getQuery()
        ->execute();
}
```

## Native SQL Queries

For complex queries that are difficult with QueryBuilder:

```php
public function findWithComplexJoins(): array
{
    $conn = $this->getEntityManager()->getConnection();

    $sql = <<<'SQL'
        SELECT p.id, p.name, COUNT(ol.id) as order_count
        FROM product p
        LEFT JOIN order_line ol ON ol.product_id = p.id
        LEFT JOIN "order" o ON o.id = ol.order_id
        WHERE o.status = :status
        GROUP BY p.id, p.name
        HAVING COUNT(ol.id) > :minOrders
        ORDER BY order_count DESC
        SQL;

    return $conn->executeQuery($sql, [
        'status' => OrderStatus::Completed->value,
        'minOrders' => 5,
    ])->fetchAllAssociative();
}
```

## Repository as a Service

Repositories are autowired as services. Inject them directly:

```php
final readonly class ProductService
{
    public function __construct(
        private ProductRepository $productRepository,
    ) {
    }
}
```

Never use `$entityManager->getRepository(Product::class)` in services — inject the repository directly.
