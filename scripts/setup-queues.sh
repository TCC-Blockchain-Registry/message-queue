#!/bin/bash

# Setup RabbitMQ Queues Script
# This script creates queues and exchanges if they don't exist

set -e

RABBITMQ_HOST=${RABBITMQ_HOST:-localhost}
RABBITMQ_PORT=${RABBITMQ_PORT:-15672}
RABBITMQ_USER=${RABBITMQ_USER:-admin}
RABBITMQ_PASS=${RABBITMQ_PASS:-admin123}

echo "==================================="
echo "RabbitMQ Queue Setup"
echo "==================================="
echo "Host: $RABBITMQ_HOST:$RABBITMQ_PORT"
echo "User: $RABBITMQ_USER"
echo "==================================="

# Wait for RabbitMQ to be ready
echo "Waiting for RabbitMQ to be ready..."
until curl -s -u "$RABBITMQ_USER:$RABBITMQ_PASS" "http://$RABBITMQ_HOST:$RABBITMQ_PORT/api/overview" > /dev/null; do
    echo "RabbitMQ is unavailable - sleeping"
    sleep 2
done

echo "✓ RabbitMQ is ready!"

# Create exchange
echo "Creating blockchain-exchange..."
curl -u "$RABBITMQ_USER:$RABBITMQ_PASS" \
    -X PUT \
    -H "content-type:application/json" \
    -d '{"type":"topic","durable":true}' \
    "http://$RABBITMQ_HOST:$RABBITMQ_PORT/api/exchanges/%2F/blockchain-exchange"

echo "✓ Exchange created"

# Create main queue
echo "Creating blockchain-jobs queue..."
curl -u "$RABBITMQ_USER:$RABBITMQ_PASS" \
    -X PUT \
    -H "content-type:application/json" \
    -d '{"durable":true,"arguments":{"x-dead-letter-exchange":"","x-dead-letter-routing-key":"blockchain-jobs-dlq"}}' \
    "http://$RABBITMQ_HOST:$RABBITMQ_PORT/api/queues/%2F/blockchain-jobs"

echo "✓ Main queue created"

# Create dead letter queue
echo "Creating blockchain-jobs-dlq queue..."
curl -u "$RABBITMQ_USER:$RABBITMQ_PASS" \
    -X PUT \
    -H "content-type:application/json" \
    -d '{"durable":true}' \
    "http://$RABBITMQ_HOST:$RABBITMQ_PORT/api/queues/%2F/blockchain-jobs-dlq"

echo "✓ Dead letter queue created"

# Create binding
echo "Creating binding..."
curl -u "$RABBITMQ_USER:$RABBITMQ_PASS" \
    -X POST \
    -H "content-type:application/json" \
    -d '{"routing_key":"blockchain.*"}' \
    "http://$RABBITMQ_HOST:$RABBITMQ_PORT/api/bindings/%2F/e/blockchain-exchange/q/blockchain-jobs"

echo "✓ Binding created"

echo "==================================="
echo "✅ Setup completed successfully!"
echo "==================================="
echo ""
echo "Management UI: http://$RABBITMQ_HOST:$RABBITMQ_PORT"
echo "Username: $RABBITMQ_USER"
echo "Password: $RABBITMQ_PASS"
echo ""
