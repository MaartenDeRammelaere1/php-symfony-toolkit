# Advanced Entity Design

## Inheritance Mapping

### Single Table Inheritance

Best for few subclasses with shared columns:

```php
#[ORM\Entity]
#[ORM\InheritanceType('SINGLE_TABLE')]
#[ORM\DiscriminatorColumn(name: 'type', type: Types::STRING)]
#[ORM\DiscriminatorMap([
    'standard' => StandardProduct::class,
    'digital' => DigitalProduct::class,
])]
abstract class Product
{
    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column(type: Types::INTEGER)]
    private ?int $id = null;

    #[ORM\Column(type: Types::STRING)]
    private string $name;
}

#[ORM\Entity]
class StandardProduct extends Product
{
    #[ORM\Column(type: Types::FLOAT)]
    private float $weight;
}

#[ORM\Entity]
class DigitalProduct extends Product
{
    #[ORM\Column(type: Types::STRING)]
    private string $downloadUrl;
}
```

### Joined Table Inheritance

For subclasses with many different columns:

```php
#[ORM\Entity]
#[ORM\InheritanceType('JOINED')]
#[ORM\DiscriminatorColumn(name: 'type', type: Types::STRING)]
#[ORM\DiscriminatorMap([
    'email' => EmailNotification::class,
    'sms' => SmsNotification::class,
])]
abstract class Notification
{
    // shared columns in notification table
}
```

## Embeddable Value Objects

For groups of fields that belong together:

```php
#[ORM\Embeddable]
class Address
{
    public function __construct(
        #[ORM\Column(type: Types::STRING)]
        private readonly string $street,

        #[ORM\Column(type: Types::STRING)]
        private readonly string $city,

        #[ORM\Column(type: Types::STRING, length: 10)]
        private readonly string $postalCode,

        #[ORM\Column(type: Types::STRING, length: 2)]
        private readonly string $country,
    ) {
    }

    public function getStreet(): string { return $this->street; }
    public function getCity(): string { return $this->city; }
    public function getPostalCode(): string { return $this->postalCode; }
    public function getCountry(): string { return $this->country; }
}

// Usage in entity:
#[ORM\Entity]
class Customer
{
    #[ORM\Embedded(class: Address::class)]
    private Address $address;

    #[ORM\Embedded(class: Address::class, columnPrefix: 'shipping_')]
    private ?Address $shippingAddress = null;
}
```

## Lifecycle Callbacks

For automatic timestamp management:

```php
#[ORM\Entity]
#[ORM\HasLifecycleCallbacks]
class Article
{
    #[ORM\Column(type: Types::DATETIME_IMMUTABLE)]
    private \DateTimeImmutable $createdAt;

    #[ORM\Column(type: Types::DATETIME_IMMUTABLE, nullable: true)]
    private ?\DateTimeImmutable $updatedAt = null;

    public function __construct()
    {
        $this->createdAt = new \DateTimeImmutable();
    }

    #[ORM\PreUpdate]
    public function onPreUpdate(): void
    {
        $this->updatedAt = new \DateTimeImmutable();
    }
}
```

## Custom DBAL Types

For domain-specific types:

```php
<?php

declare(strict_types=1);

namespace App\Doctrine\Type;

use App\ValueObject\Money;
use Doctrine\DBAL\Platforms\AbstractPlatform;
use Doctrine\DBAL\Types\Type;

class MoneyType extends Type
{
    public const NAME = 'money';

    public function getSQLDeclaration(array $column, AbstractPlatform $platform): string
    {
        return $platform->getIntegerTypeDeclarationSQL($column);
    }

    public function convertToPHPValue(mixed $value, AbstractPlatform $platform): ?Money
    {
        return $value !== null ? Money::fromCents((int) $value) : null;
    }

    public function convertToDatabaseValue(mixed $value, AbstractPlatform $platform): ?int
    {
        return $value instanceof Money ? $value->getCents() : null;
    }

    public function getName(): string
    {
        return self::NAME;
    }
}
```

Register in `config/packages/doctrine.yaml`:

```yaml
doctrine:
    dbal:
        types:
            money: App\Doctrine\Type\MoneyType
```

## Indexing

```php
#[ORM\Entity]
#[ORM\Table(name: 'product')]
#[ORM\Index(columns: ['status', 'created_at'], name: 'idx_status_created')]
#[ORM\UniqueConstraint(columns: ['external_id'], name: 'uniq_external_id')]
class Product
{
}
```

## Soft Delete Pattern

Instead of deleting, mark as deleted:

```php
#[ORM\Entity]
class Product
{
    #[ORM\Column(type: Types::DATETIME_IMMUTABLE, nullable: true)]
    private ?\DateTimeImmutable $deletedAt = null;

    public function softDelete(): void
    {
        $this->deletedAt = new \DateTimeImmutable();
    }

    public function isDeleted(): bool
    {
        return $this->deletedAt !== null;
    }
}
```

Add a Doctrine filter to automatically exclude soft-deleted entities:

```php
class SoftDeleteFilter extends SQLFilter
{
    public function addFilterConstraint(ClassMetadata $targetEntity, string $targetTableAlias): string
    {
        if (!$targetEntity->reflClass->hasProperty('deletedAt')) {
            return '';
        }

        return sprintf('%s.deleted_at IS NULL', $targetTableAlias);
    }
}
```
