# Enterprise Database Infrastructure Terraform Module (Option A)

A production-grade, highly resilient, and 100% YAML-driven Terraform module for Google Cloud Platform database infrastructure.

This unified module conditionally manages 6 database pillars:
1. **Cloud SQL**: PostgreSQL / MySQL / SQL Server with Regional High Availability (multi-zone failover), Private Service Access (PSA), automated backups with Point-in-Time Recovery (PITR), CMEK, IAM DB Auth, database flags, SSL mode (`ENCRYPTED_ONLY`), logical databases, and users.
2. **AlloyDB for PostgreSQL**: Enterprise-grade PostgreSQL clusters with automated continuous backups, 14-day PITR, Primary compute instances, and horizontally auto-scaled Read Pools.
3. **Memorystore for Redis**: In-memory caching and session state with `STANDARD_HA` (cross-zone replica with automatic failover), RDB persistence snapshots, Redis AUTH, and in-transit TLS encryption.
4. **Firestore / Datastore Mode**: Serverless, high-durability NoSQL document store with Point-in-Time Recovery (PITR), delete protection, CMEK encryption, and automated scheduled backups.
5. **Cloud Spanner**: Mission-critical globally distributed relational database with 99.999% SLA, processing units or node autoscaling, Point-in-Time Recovery (PITR), DDL schemas, and automated backup schedules.
6. **Cloud Bigtable**: High-throughput, low-latency NoSQL database with multi-cluster replication for cross-zone HA, SSD/HDD storage, tables, and column families.

> **Resilient & Dynamic Design**: If any database section (e.g. `alloydb`, `spanner`, or `bigtable`) is omitted or empty in your YAML configuration, Terraform automatically creates `0` resources for that section without errors.
>
> **Default VPC Fallback**: When no specific VPC network is declared, the module automatically defaults to the project's standard `"default"` VPC network (`projects/<project-id>/global/networks/default`).

---

## Architecture & Resilience Highlights

```
                                +-----------------------------------+
                                |      VPC Network (Default / PSA)  |
                                +-----------------+-----------------+
                                                  |
               +----------------------------------+----------------------------------+
               |                                  |                                  |
       +-------v-------+                  +-------v-------+                  +-------v-------+
       |   Cloud SQL   |                  |    AlloyDB    |                  |  Memorystore  |
       |  Regional HA  |                  |  Cluster HA   |                  |     Redis     |
       +-------+-------+                  +-------+-------+                  +-------+-------+
       | Zone A (Prim) |                  | Primary Inst. |                  | Primary Node  |
       | Zone B (Stby) |                  | Read Pool(s)  |                  | Standby Node  |
       | Auto-Failover |                  | 14-Day PITR   |                  | Auto-Failover |
       | 7-Day PITR    |                  | CMEK Support  |                  | RDB Snapshots |
       +---------------+                  +---------------+                  +---------------+

               +----------------------------------+----------------------------------+
               |                                  |                                  |
       +-------v-------+                  +-------v-------+                  +-------v-------+
       | Cloud Spanner |                  | Cloud Bigtable|                  |  Firestore    |
       | 99.999% SLA   |                  | Multi-Cluster |                  | Serverless    |
       +-------+-------+                  +-------+-------+                  +-------+-------+
       | Multi-Region  |                  | Zone A (Cl 1) |                  | Native/DS     |
       | Autoscaling PU|                  | Zone B (Cl 2) |                  | PITR Enabled  |
       | 7-Day PITR    |                  | Sub-10ms P99  |                  | Daily Backups |
       | Auto-Backups  |                  | ColumnFamilies|                  | Deletion Lock |
       +---------------+                  +---------------+                  +---------------+
```

---

## File Structure

```
database-infrastructure/
├── 0-locals.tf           # YAML parser, deep schema normalization & conditional defaults
├── 1-cloud-sql.tf        # Cloud SQL instances, databases, and users (ssl_mode & authorized networks)
├── 2-alloydb.tf          # AlloyDB clusters, primary instances, and read pools
├── 3-memorystore-redis.tf# Memorystore Redis HA instances & RDB persistence
├── 4-firestore.tf        # Firestore NoSQL databases & automated backup schedules
├── 5-spanner.tf          # Cloud Spanner instances, logical databases & backup schedules
├── 6-bigtable.tf         # Cloud Bigtable instances, multi-clusters, tables & column families
├── variables.tf          # Module inputs (config_file_path or yaml_content)
├── outputs.tf            # Connection strings, private IPs, IDs, and inventory summaries
├── versions.tf           # Required Terraform (>= 1.5.0) and Google Provider (>= 5.0.0)
└── README.md             # This documentation
```

---

## Complete YAML Configuration Schema

```yaml
project_id: "yuvaraj-internal-project"
region: "asia-south1"
network: "projects/yuvaraj-internal-project/global/networks/default"

# ------------------------------------------------------------------------------
# 1. Cloud SQL Instances (PostgreSQL, MySQL, SQL Server)
# ------------------------------------------------------------------------------
cloud_sql:
  instances:
    app-db-pg:
      database_version: "POSTGRES_15"
      tier: "db-custom-2-7680"
      availability_type: "REGIONAL" # High Availability with automatic cross-zone failover
      disk_type: "PD_SSD"
      disk_size_gb: 20
      disk_autoresize: true
      disk_autoresize_limit: 100
      deletion_protection: false
      private_network: "projects/yuvaraj-internal-project/global/networks/default"
      ipv4_enabled: true
      ssl_mode: "ENCRYPTED_ONLY" # Modern SSL enforcement
      enable_point_in_time_recovery: true
      backup_retention_days: 7
      backup_start_time: "02:00"
      transaction_log_retention_days: 7
      database_flags:
        max_connections: "200"
        log_checkpoints: "on"
      databases:
        - name: "app_production"
          charset: "UTF8"
          collation: "en_US.UTF8"
      users:
        - name: "app_user"
          password: "SuperSecretPassword123!"

# ------------------------------------------------------------------------------
# 2. AlloyDB for PostgreSQL Clusters & Read Pools
# ------------------------------------------------------------------------------
alloydb:
  clusters:
    analytics-cluster:
      network: "projects/yuvaraj-internal-project/global/networks/default"
      continuous_backup_retention_days: 14
      weekly_backup_days: ["SUNDAY", "WEDNESDAY"]
      weekly_backup_time: "03:00"
      deletion_protection: false
      primary_instance:
        instance_id: "analytics-primary"
        cpu_count: 2
      read_pools:
        - instance_id: "analytics-read-pool-1"
          cpu_count: 2
          node_count: 1
      users:
        - name: "app_user"
          password: "SuperSecretPassword123!"
          database_roles:
            - "alloydbsuperuser"

# ------------------------------------------------------------------------------
# 3. Memorystore Redis (In-Memory HA Cache)
# ------------------------------------------------------------------------------
memorystore_redis:
  instances:
    session-cache:
      tier: "STANDARD_HA" # Cross-zone failover
      memory_size_gb: 1
      redis_version: "REDIS_7_0"
      network: "projects/yuvaraj-internal-project/global/networks/default"
      auth_enabled: true
      transit_encryption_mode: "SERVER_AUTHENTICATION"
      rdb_snapshot_period: "TWELVE_HOURS"

# ------------------------------------------------------------------------------
# 4. Firestore (Serverless Resilient NoSQL)
# ------------------------------------------------------------------------------
firestore:
  databases:
    user-data-store:
      name: "app-nosql-db"
      type: "FIRESTORE_NATIVE"
      delete_protection_state: "DELETE_PROTECTION_ENABLED"
      point_in_time_recovery_enablement: "POINT_IN_TIME_RECOVERY_ENABLED"
      backup_schedules:
        - retention_days: 14
          recurrence: "daily"

# ------------------------------------------------------------------------------
# 5. Cloud Spanner (Global Multi-Region / Regional 99.999% SLA RDBMS)
# ------------------------------------------------------------------------------
spanner:
  instances:
    ecommerce-spanner:
      config: "regional-asia-south1"
      display_name: "Production Spanner Cluster"
      processing_units: 100 # Cost-effective dev/test sizing (100 PU = 0.1 node)
      deletion_protection: false
      databases:
        - name: "ecommerce-db"
          version_retention_period: "7d"
          ddl:
            - "CREATE TABLE Customers (CustomerId STRING(36) NOT NULL, Email STRING(255)) PRIMARY KEY (CustomerId)"
          backup_schedules:
            - name: "daily-spanner-backup"
              retention_duration: "604800s" # 7 days
              cron_spec: "0 2 * * *"

# ------------------------------------------------------------------------------
# 6. Cloud Bigtable (Low-Latency High-Throughput NoSQL)
# ------------------------------------------------------------------------------
bigtable:
  instances:
    analytics-bigtable:
      display_name: "Analytics Bigtable Cluster"
      deletion_protection: false
      clusters:
        - cluster_id: "cluster-1"
          zone: "asia-south1-a"
          num_nodes: 1
          storage_type: "SSD"
      tables:
        - name: "events"
          column_families:
            - family: "metadata"
            - family: "metrics"
```
