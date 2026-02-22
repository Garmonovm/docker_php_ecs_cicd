<?php

declare(strict_types=1);

use Slim\Factory\AppFactory;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

require __DIR__ . '/../vendor/autoload.php';

// Create Slim app
$app = AppFactory::create();

// Add error middleware — logs to stderr
$app->addErrorMiddleware(
    displayErrorDetails: (bool) ($_ENV['APP_DEBUG'] ?? false),
    logErrors: true,
    logErrorDetails: true
);

// Health check endpoint — used by ALB/ECS health checks
$app->get('/health', function (Request $request, Response $response) {
    $payload = json_encode([
        'status'    => 'healthy',
        'timestamp' => gmdate('Y-m-d\TH:i:s\Z'),
        'service'   => $_ENV['APP_NAME'] ?? 'php-app',
        'version'   => $_ENV['APP_VERSION'] ?? '1.0.0',
    ], JSON_THROW_ON_ERROR);

    $response->getBody()->write($payload);

    return $response
        ->withHeader('Content-Type', 'application/json')
        ->withStatus(200);
});

// Root endpoint
$app->get('/', function (Request $request, Response $response) {
    $payload = json_encode([
        'message' => 'PHP Application is running',
        'service' => $_ENV['APP_NAME'] ?? 'php-app',
    ], JSON_THROW_ON_ERROR);

    $response->getBody()->write($payload);

    return $response
        ->withHeader('Content-Type', 'application/json')
        ->withStatus(200);
});

// Run the application
$app->run();
