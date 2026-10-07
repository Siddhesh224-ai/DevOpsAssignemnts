# S3 — Object Storage

Amazon S3 stores objects in globally named regional buckets. Objects are addressed by keys and contain data plus metadata. Storage classes range from Standard and Intelligent-Tiering to infrequent-access and archival tiers.

Versioning preserves object generations; lifecycle rules transition or expire data. Use default encryption (SSE-S3 or KMS), Block Public Access, tightly scoped bucket/IAM policies, TLS, logging, and retention where needed. Common uses include backups, static assets, data lakes, logs, artifacts, and disaster recovery.
