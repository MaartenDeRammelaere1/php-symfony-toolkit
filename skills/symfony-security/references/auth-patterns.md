# Authentication Patterns

## JWT Authentication

Using `lexik/jwt-authentication-bundle`:

### Installation

```bash
composer require lexik/jwt-authentication-bundle
# Generate SSL keys
php bin/console lexik:jwt:generate-keypair
```

### Configuration

```yaml
# config/packages/lexik_jwt_authentication.yaml
lexik_jwt_authentication:
    secret_key: '%env(resolve:JWT_SECRET_KEY)%'
    public_key: '%env(resolve:JWT_PUBLIC_KEY)%'
    pass_phrase: '%env(JWT_PASSPHRASE)%'
    token_ttl: 3600

# config/packages/security.yaml
security:
    firewalls:
        login:
            pattern: ^/api/login
            stateless: true
            json_login:
                check_path: /api/login
                success_handler: lexik_jwt_authentication.handler.authentication_success
                failure_handler: lexik_jwt_authentication.handler.authentication_failure
        api:
            pattern: ^/api
            stateless: true
            jwt: ~
```

### Login Endpoint

The bundle auto-handles `/api/login` when configured. Send:

```json
{
    "username": "user@example.com",
    "password": "secret"
}
```

Returns:

```json
{
    "token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9..."
}
```

### Custom JWT Claims

```php
use Lexik\Bundle\JWTAuthenticationBundle\Event\JWTCreatedEvent;
use Symfony\Component\EventDispatcher\Attribute\AsEventListener;

#[AsEventListener(event: 'lexik_jwt_authentication.on_jwt_created')]
final readonly class JwtCreatedListener
{
    public function __invoke(JWTCreatedEvent $event): void
    {
        $user = $event->getUser();
        $payload = $event->getData();
        $payload['id'] = $user->getId();
        $payload['roles'] = $user->getRoles();
        $event->setData($payload);
    }
}
```

## API Key Authentication

For service-to-service or simple API authentication:

```php
<?php

declare(strict_types=1);

namespace App\Security;

use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Security\Core\Authentication\Token\TokenInterface;
use Symfony\Component\Security\Core\Exception\AuthenticationException;
use Symfony\Component\Security\Http\Authenticator\AbstractAuthenticator;
use Symfony\Component\Security\Http\Authenticator\Passport\Badge\UserBadge;
use Symfony\Component\Security\Http\Authenticator\Passport\Passport;
use Symfony\Component\Security\Http\Authenticator\Passport\SelfValidatingPassport;

final class ApiKeyAuthenticator extends AbstractAuthenticator
{
    public function __construct(
        private readonly string $apiKey,
    ) {
    }

    public function supports(Request $request): ?bool
    {
        return $request->headers->has('X-API-Key');
    }

    public function authenticate(Request $request): Passport
    {
        $providedKey = $request->headers->get('X-API-Key', '');

        if (!hash_equals($this->apiKey, $providedKey)) {
            throw new AuthenticationException('Invalid API key.');
        }

        return new SelfValidatingPassport(
            new UserBadge('api-service', fn () => new ApiServiceUser()),
        );
    }

    public function onAuthenticationSuccess(Request $request, TokenInterface $token, string $firewallName): ?Response
    {
        return null;
    }

    public function onAuthenticationFailure(Request $request, AuthenticationException $exception): ?Response
    {
        return new JsonResponse(['error' => 'Invalid API key'], Response::HTTP_UNAUTHORIZED);
    }
}
```

## Rate Limiting

Using Symfony's RateLimiter component:

```yaml
# config/packages/rate_limiter.yaml
framework:
    rate_limiter:
        login_attempts:
            policy: 'sliding_window'
            limit: 5
            interval: '15 minutes'
        api_requests:
            policy: 'token_bucket'
            limit: 100
            rate: { interval: '1 minute', amount: 50 }
```

```php
use Symfony\Component\RateLimiter\RateLimiterFactory;

final readonly class LoginController extends AbstractController
{
    public function __construct(
        private RateLimiterFactory $loginAttemptLimiter,
    ) {
    }

    #[Route('/login', name: 'login', methods: ['POST'])]
    public function login(Request $request): JsonResponse
    {
        $limiter = $this->loginAttemptLimiter->create($request->getClientIp());

        if (!$limiter->consume()->isAccepted()) {
            return new JsonResponse(
                ['error' => 'Too many login attempts. Please try again later.'],
                Response::HTTP_TOO_MANY_REQUESTS,
            );
        }

        // ... authentication logic
    }
}
```

## CSRF Protection

### In Twig Forms (Automatic)

Symfony forms include CSRF tokens by default. No extra configuration needed.

### Manual CSRF for AJAX/API

```php
use Symfony\Component\Security\Csrf\CsrfTokenManagerInterface;
use Symfony\Component\Security\Csrf\CsrfToken;

final readonly class DeleteController extends AbstractController
{
    #[Route('/delete/{id}', name: 'delete', methods: ['DELETE'])]
    public function delete(
        Product $product,
        Request $request,
        CsrfTokenManagerInterface $csrfTokenManager,
    ): Response {
        $token = new CsrfToken('delete-product', $request->headers->get('X-CSRF-Token'));

        if (!$csrfTokenManager->isTokenValid($token)) {
            throw $this->createAccessDeniedException('Invalid CSRF token.');
        }

        // ... delete logic
    }
}
```

## Security Headers

Add security headers via an event listener:

```php
#[AsEventListener(event: KernelEvents::RESPONSE)]
final readonly class SecurityHeadersListener
{
    public function __invoke(ResponseEvent $event): void
    {
        $response = $event->getResponse();
        $response->headers->set('X-Content-Type-Options', 'nosniff');
        $response->headers->set('X-Frame-Options', 'DENY');
        $response->headers->set('X-XSS-Protection', '1; mode=block');
        $response->headers->set('Referrer-Policy', 'strict-origin-when-cross-origin');
    }
}
```

## Secrets Management

```bash
# Set a secret (for prod environment)
php bin/console secrets:set DATABASE_URL

# List secrets
php bin/console secrets:list

# Decrypt for local development
php bin/console secrets:decrypt-to-local
```

Secrets are encrypted and safe to commit. The decryption key (`config/secrets/prod/prod.decrypt.private.php`) must NEVER be committed.
