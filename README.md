## 🚀 High-Level Architecture

This project implements a real-time fraud detection pipeline on AWS using a streaming-first architecture.
Kinesis Data Streams act as the central event bus, allowing multiple consumers to process the same transaction events independently.

### Architecture Flow

1. **Ingestion Layer**
   - External systems send JSON transactions to a public `POST /transactions` endpoint.
   - API Gateway forwards requests to the Ingest Lambda.
   - The Ingest Lambda validates the payload and publishes valid events to Kinesis.
   - `card_last4` is used as the partition key to preserve ordering per card.

2. **Streaming Layer**
   - Kinesis Data Streams provide high-throughput, low-latency ingestion.
   - Multiple consumers read from the same stream without coupling.

3. **RAW Storage Layer**
   - A Firehose delivery stream writes unmodified events to the RAW S3 bucket.
   - Data is immutable and partitioned by `year/month/day/hour`.
   - This layer acts as the source of truth for replay and auditing.

4. **Transform & CLEAN Layer**
   - A second Firehose stream invokes a Transform Lambda.
   - The Lambda enriches events with `ingest_ts` and `is_high_risk`.
   - Enriched data is stored in the CLEAN S3 bucket using the same partitioning scheme.
   - This layer is optimized for analytics and downstream ML use cases.

5. **Alerts Layer**
   - An Alerts Lambda is subscribed directly to the Kinesis stream.
   - It applies simple fraud rules in real time.
   - Suspicious transactions trigger notifications via SNS email alerts.

6. **Analytics Layer**
   - Athena external tables are defined over both RAW and CLEAN buckets.
   - Partition projection is used to avoid manual partition management.
   - Enables fast querying for investigations and reporting.