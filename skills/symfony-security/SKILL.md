---
name: symfony-security
description: Symfony security patterns for authentication and authorization. Use when adding authentication, creating voters, configuring security firewalls, implementing API tokens or JWT, writing access control rules, or asking about Symfony security, user authorization, or protecting routes.
paths: "*.php"
---

# Symfony Security Patterns

## Security Configuration

`config/packages/security.yaml`:

```yaml
security:
    password_hashers:
        Symfony\Component\Security\Core\User\PasswordAuthenticatedUserInterface: 'auto'

    providers:
        app_user_provider:
            entity:
                class: App\Entity\User
                property: email

    firewalls:
        dev:
            pattern: ^/(_(profiler|wdt)|css|images|js)/
            security: false
        api:
            pattern: ^/api
            stateless: true
            # Choose your authenticator:
            # jwt: ~                          # For lexik/jwt-authentication-bundle
            # custom_authenticators:
            #     - App\Security\ApiTokenAuthenticator
        main:
            lazy: true
            provider: app_user_provider
            form_login:
                login_path: app_login
                check_path: app_login
            logout:
                path: app_logout

    access_control:
        - { path: ^/api/login, roles: PUBLIC_ACCESS }
        - { path: ^/api, roles: ROLE_API }
        - { path: ^/admin, roles: ROLE_ADMIN }

    role_hierarchy:
        ROLE_ADMIN: ROLE_USER
        ROLE_SUPER_ADMIN: [ROLE_ADMIN, ROLE_API]
```

## User Entity

Implement `UserInterface` and `PasswordAuthenticatedUserInterface`:

```php
<?php

declare(strict_types=1);

namespace App\Entity;

use App\Repository\UserRepository;
use Doctrine\DBAL\Types\Types;
use Doctrine\ORM\Mapping as ORM;
use Symfony\Component\Security\Core\User\PasswordAuthenticatedUserInterface;
use Symfony\Component\Security\Core\User\UserInterface;

#[ORM\Entity(repositoryClass: UserRepository::class)]
#[ORM\Table(name: '`user`')]
class User implements UserInterface, PasswordAuthenticatedUserInterface
{
    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column(type: Types::INTEGER)]
    private ?int $id = null;

    #[ORM\Column(type: Types::STRING, length: 180, unique: true)]
    private string $email;

    /** @var list<string> */
    #[ORM\Column(type: Types::JSON)]
    private array $roles = [];

    #[ORM\Column(type: Types::STRING)]
    private string $password;

    public function getUserIdentifier(): string
    {
        return $this->email;
    }

    /** @return list<string> */
    public function getRoles(): array
    {
        $roles = $this->roles;
        $roles[] = 'ROLE_USER';

        return array_unique($roles);
    }

    public function getPassword(): string
    {
        return $this->password;
    }

    public function eraseCredentials(): void
    {
    }
}
```

## Voters

Voters are the preferred way to handle authorization logic. Use `#[AsVoter]`:

```php
<?php

declare(strict_types=1);

namespace App\Security\Voter;

use App\Entity\Product;
use App\Entity\User;
use Symfony\Component\Security\Core\Authentication\Token\TokenInterface;
use Symfony\Component\Security\Core\Authorization\Voter\Voter;

/** @extends Voter<string, Product> */
#[AsVoter]
final class ProductVoter extends Voter
{
    public const EDIT = 'PRODUCT_EDIT';
    public const DELETE = 'PRODUCT_DELETE';

    protected function supports(string $attribute, mixed $subject): bool
    {
        return in_array($attribute, [self::EDIT, self::DELETE], true)
            && $subject instanceof Product;
    }

    protected function voteOnAttribute(string $attribute, mixed $subject, TokenInterface $token): bool
    {
        $user = $token->getUser();

        if (!$user instanceof User) {
            return false;
        }

        return match ($attribute) {
            self::EDIT => $this->canEdit($subject, $user),
            self::DELETE => $this->canDelete($subject, $user),
            default => false,
        };
    }

    private function canEdit(Product $product, User $user): bool
    {
        return $product->getOwner() === $user;
    }

    private function canDelete(Product $product, User $user): bool
    {
        return in_array('ROLE_ADMIN', $user->getRoles(), true)
            || $product->getOwner() === $user;
    }
}
```

## Using Authorization in Controllers

Use `#[IsGranted]` attribute or `$this->denyAccessUnlessGranted()`:

```php
use Symfony\Component\Security\Http\Attribute\IsGranted;

#[Route('/{id}/edit', name: 'edit', methods: ['PUT'])]
#[IsGranted(ProductVoter::EDIT, subject: 'product')]
public function edit(Product $product, #[MapRequestPayload] ProductDto $dto): JsonResponse
{
    // User is authorized — proceed
}

// Or programmatically:
public function delete(Product $product): JsonResponse
{
    $this->denyAccessUnlessGranted(ProductVoter::DELETE, $product);

    // ...
}
```

## API Token Authentication

Custom authenticator for API tokens:

```php
<?php

declare(strict_types=1);

namespace App\Security;

use App\Repository\ApiTokenRepository;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Security\Core\Authentication\Token\TokenInterface;
use Symfony\Component\Security\Core\Exception\AuthenticationException;
use Symfony\Component\Security\Core\Exception\CustomUserMessageAuthenticationException;
use Symfony\Component\Security\Http\Authenticator\AbstractAuthenticator;
use Symfony\Component\Security\Http\Authenticator\Passport\Badge\UserBadge;
use Symfony\Component\Security\Http\Authenticator\Passport\Passport;
use Symfony\Component\Security\Http\Authenticator\Passport\SelfValidatingPassport;

final class ApiTokenAuthenticator extends AbstractAuthenticator
{
    public function __construct(
        private readonly ApiTokenRepository $tokenRepository,
    ) {
    }

    public function supports(Request $request): ?bool
    {
        return $request->headers->has('Authorization');
    }

    public function authenticate(Request $request): Passport
    {
        $token = str_replace('Bearer ', '', $request->headers->get('Authorization', ''));

        if ('' === $token) {
            throw new CustomUserMessageAuthenticationException('No API token provided.');
        }

        return new SelfValidatingPassport(
            new UserBadge($token, fn (string $token) => $this->tokenRepository->findUserByToken($token)),
        );
    }

    public function onAuthenticationSuccess(Request $request, TokenInterface $token, string $firewallName): ?Response
    {
        return null; // Continue to controller
    }

    public function onAuthenticationFailure(Request $request, AuthenticationException $exception): ?Response
    {
        return new JsonResponse(
            ['error' => strtr($exception->getMessageKey(), $exception->getMessageData())],
            Response::HTTP_UNAUTHORIZED,
        );
    }
}
```

## Security Best Practices

1. **Never trust user input**: Always validate and sanitize at controller boundaries
2. **Use CSRF protection** in all forms (enabled by default with Symfony forms)
3. **Rate limiting**: Use Symfony's `#[RateLimiter]` attribute on sensitive endpoints
4. **Secrets management**: Use `php bin/console secrets:set` for production secrets — never commit `.env.local`
5. **Password hashing**: Always use `'auto'` hasher — Symfony picks the best algorithm
6. **Escape output**: Twig auto-escapes by default. Never use `|raw` on user-provided data
7. **HTTPS only**: Set `framework.session.cookie_secure: auto` and use HTTPS in production
8. **Dependency audit**: Run `composer audit` regularly to check for known vulnerabilities

## Additional Resources

- For JWT, OAuth2, and advanced authentication patterns, see [auth-patterns.md](references/auth-patterns.md)
