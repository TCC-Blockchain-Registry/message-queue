# RabbitMQ Message Queue

Message queue infrastructure for the Property Tokenization Platform.

## Purpose

Provides asynchronous job processing for blockchain operations:
- Decouples Orchestrator from slow blockchain calls
- Ensures reliable message delivery
- Enables retry logic for failed transactions
- Allows horizontal scaling of workers

## Architecture

```
Orchestrator (Producer)
    ↓ Publishes
blockchain-exchange (Topic Exchange)
    ↓ Routes by pattern
blockchain-jobs (Main Queue)
    ↓ Consumes
Queue Worker (Consumer)

If job fails after max retries:
    ↓
blockchain-jobs-dlq (Dead Letter Queue)
```

## Quick Start

### Start RabbitMQ

```bash
cd message-queue
docker-compose up -d
```

### Verify Running

```bash
docker-compose ps
```

Expected output:
```
NAME                  STATUS              PORTS
rabbitmq-property     Up (healthy)        0.0.0.0:5672->5672/tcp, 0.0.0.0:15672->15672/tcp
```

### Access Management UI

Open in browser: **http://localhost:15672**

- Username: `admin`
- Password: `admin123`

## Configuration

### Queues

1. **blockchain-jobs** (Main Queue)
   - Durable: Yes (survives broker restart)
   - Auto-delete: No
   - Dead letter: blockchain-jobs-dlq
   - Purpose: All blockchain operations

2. **blockchain-jobs-dlq** (Dead Letter Queue)
   - Durable: Yes
   - Purpose: Failed jobs after max retries

### Exchange

- **blockchain-exchange** (Topic Exchange)
  - Routing pattern: `blockchain.*`
  - Binds to: blockchain-jobs

### User

- **Username**: admin
- **Password**: admin123
- **Permissions**: Full (configure, write, read)

## Usage

### Publishing Messages (Orchestrator)

```java
// Spring Boot example
@Autowired
private RabbitTemplate rabbitTemplate;

public void publishJob(String jobType, Object payload) {
    BlockchainJob job = new BlockchainJob(
        UUID.randomUUID().toString(),
        jobType,
        payload,
        LocalDateTime.now()
    );

    rabbitTemplate.convertAndSend(
        "blockchain-exchange",
        "blockchain.property.register",
        job
    );
}
```

### Consuming Messages (Worker)

```typescript
// Queue Worker example
const connection = await amqp.connect('amqp://admin:admin123@localhost:5672');
const channel = await connection.createChannel();

await channel.consume('blockchain-jobs', async (msg) => {
    const job = JSON.parse(msg.content.toString());

    try {
        await processJob(job);
        channel.ack(msg); // Success
    } catch (error) {
        channel.nack(msg, false, false); // Fail → DLQ
    }
});
```

## Monitoring

### Management UI

**http://localhost:15672**

Features:
- Queue statistics (messages, consumers, rates)
- Browse messages
- Purge queues
- Monitor connections and channels
- View exchange bindings

### Health Check

```bash
docker exec rabbitmq-property rabbitmq-diagnostics ping
```

Expected: `Ping succeeded`

### Queue Stats

```bash
docker exec rabbitmq-property rabbitmqctl list_queues name messages consumers
```

## Maintenance

### View Logs

```bash
docker-compose logs -f rabbitmq
```

### Restart

```bash
docker-compose restart rabbitmq
```

### Stop

```bash
docker-compose down
```

### Stop and Remove Data

```bash
docker-compose down -v
```

**⚠️ Warning**: This deletes all messages and configuration!

## Dead Letter Queue Management

### Inspect Failed Jobs

1. Open Management UI: http://localhost:15672
2. Go to **Queues** tab
3. Click **blockchain-jobs-dlq**
4. Click **Get messages**

### Reprocess Failed Jobs

Option 1: Manual (via UI)
1. Get message from DLQ
2. Fix the issue (e.g., update payload)
3. Publish to main queue

Option 2: Automated Script
```bash
# Move all DLQ messages back to main queue
docker exec rabbitmq-property rabbitmqadmin \
  shovel blockchain-jobs-dlq blockchain-jobs
```

## Troubleshooting

### "Connection refused"

Check if RabbitMQ is running:
```bash
docker-compose ps
```

If not running, start it:
```bash
docker-compose up -d
```

### "Authentication failed"

Verify credentials in `.env` files match:
- Username: `admin`
- Password: `admin123`

### Messages stuck in queue

Possible causes:
1. No consumers running → Start Queue Worker
2. Worker crashed → Check worker logs
3. Messages failing → Check DLQ

### High memory usage

RabbitMQ is configured to use up to 60% of available RAM. To adjust:

Edit `rabbitmq.conf`:
```
vm_memory_high_watermark.relative = 0.4
```

Restart:
```bash
docker-compose restart rabbitmq
```

## Configuration Files

### docker-compose.yml
Main Docker Compose configuration

### rabbitmq.conf
RabbitMQ server configuration:
- Networking
- Memory limits
- Logging
- Performance tuning

### definitions.json
Pre-configured resources:
- Users
- Vhosts
- Queues
- Exchanges
- Bindings
- Policies

## Ports

| Port | Service |
|------|---------|
| 5672 | AMQP Protocol (client connections) |
| 15672 | Management UI (web interface) |

## Data Persistence

RabbitMQ data is stored in Docker volumes:
- `rabbitmq_data`: Queue messages and metadata
- `rabbitmq_logs`: Application logs

To backup:
```bash
docker run --rm -v message-queue_rabbitmq_data:/data -v $(pwd):/backup \
  alpine tar czf /backup/rabbitmq-backup.tar.gz /data
```

To restore:
```bash
docker run --rm -v message-queue_rabbitmq_data:/data -v $(pwd):/backup \
  alpine tar xzf /backup/rabbitmq-backup.tar.gz -C /
```

## Production Considerations

For production deployment:

1. **Use strong credentials**
   - Change default password
   - Use environment variables

2. **Enable TLS/SSL**
   - Encrypt AMQP connections
   - Secure Management UI

3. **Set up clustering**
   - Run multiple RabbitMQ nodes
   - High availability

4. **Monitor metrics**
   - Integrate with Prometheus
   - Set up alerts

5. **Backup regularly**
   - Automated backup scripts
   - Test restore procedures

6. **Resource limits**
   - Set memory and disk limits
   - Configure alarms

## Environment Variables

For docker-compose:

```yaml
environment:
  RABBITMQ_DEFAULT_USER: ${RABBITMQ_USER:-admin}
  RABBITMQ_DEFAULT_PASS: ${RABBITMQ_PASS:-admin123}
```

Create `.env` file:
```
RABBITMQ_USER=admin
RABBITMQ_PASS=your-secure-password
```

## References

- RabbitMQ Documentation: https://www.rabbitmq.com/documentation.html
- Management Plugin: https://www.rabbitmq.com/management.html
- Production Checklist: https://www.rabbitmq.com/production-checklist.html
