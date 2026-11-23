# Enterprise Compute Infrastructure Terraform Module (Option A)

A production-grade, highly resilient, and 100% YAML-driven Terraform module for Google Cloud Platform compute infrastructure.

This unified module conditionally manages 5 core compute pillars:
1. **Compute Resource Policies (`compute-policies`)**: Automated disk snapshot schedules (hourly, daily, weekly with retention and guest flush) and VM instance start/stop schedules (business-hours automation with IANA timezone support).
2. **Instance Templates (`instance-templates`)**: Reusable, hardened VM templates consuming golden images, custom machine types, Shielded VM security settings, service accounts, startup scripts, and snapshot resource policies.
3. **VM Instances (`vm-instances`)**: Standalone stateful instances (jump hosts, dedicated databases) created either **from an instance template** (`google_compute_instance_from_template`) or **custom configuration** (`google_compute_instance`), with automated start/stop and snapshot policy attachments.
4. **Autohealing Health Checks (`health-checks`)**: Regional and global health checks (HTTP, HTTPS, TCP, gRPC) powering Managed Instance Group autohealing and traffic routing.
5. **Managed Instance Groups & Autoscaling (`managed-instance-groups` & `autoscaling-policies`)**: Regional (multi-zone HA) and Zonal MIGs with automated rolling update policies, autohealing integration, and metric/CPU-driven autoscalers with business-hours scaling schedules.

> **Resilient & Dynamic Design**: If any compute pillar (e.g. `autoscaling_policies`, `managed_instance_groups`, `health_checks`, or `compute_policies`) is omitted or empty in your YAML configuration, Terraform automatically creates `0` resources for that pillar without errors.
>
> **Unified Template Reusability**: Instance Templates defined in this module can be directly consumed to spawn standalone VMs (`google_compute_instance_from_template`) and to scale Managed Instance Groups (`google_compute_region_instance_group_manager`).
>
> **Dual Policy Application**:
> - **Snapshot Schedules**: Apply to standalone VM boot disks directly via `google_compute_disk_resource_policy_attachment` AND to Managed Instance Groups via `disk.resource_policies` in the `instance_template`.
> - **Instance Start/Stop Schedules**: Apply to standalone VMs via `google_compute_instance_resource_policy_attachment` and to Managed Instance Groups via autoscaler `scaling_schedules`.

---

## Architecture & Integration Diagram

```
                                +-------------------------------------------+
                                |      YAML Configuration (declarative)     |
                                +---------------------+---------------------+
                                                      |
                    +---------------------------------+---------------------------------+
                    |                                                                   |
            +-------v-------+                                                   +-------v-------+
            | Compute Policy|                                                   | Health Checks |
            |  (Schedules)  |                                                   | (HTTP/TCP/etc)|
            +-------+-------+                                                   +-------+-------+
                    |                                                                   |
       +------------+------------+                                                      |
       |                         |                                                      |
+------v------+           +------v------+                                               |
|  Snapshot   |           |  Instance   |                                               |
|  Schedule   |           |  Start/Stop |                                               |
+------+------+           +------+------+                                               |
       |                         |                                                      |
       |                         |                                                      |
       |                         |                                                      |
       |           +-------------v---------------------+                                |
       |           |   Reusable Instance Templates     |                                |
       |           |   (Golden OS, Shielded VM, SAs)   |                                |
       |           +-------------+---------------------+                                |
       |                         |                                                      |
       |             +-----------+-----------+                                          |
       |             |                       |                                          |
       |     +-------v-------+       +-------v-------+                                  |
       +---->| Standalone VM |       | Managed Group |<---------------------------------+
             | (From Template|       |  (MIG - HA)   |
             |   or Custom)  |       +-------+-------+
             +---------------+               |
                                     +-------v-------+
                                     |  Autoscaler   |
                                     | (CPU & Cron)  |
                                     +---------------+
```

---

## File Structure

```
compute-infrastructure/
├── 0-locals.tf               # YAML parser, normalization, policy resolution & conditional defaults
├── 1-instance-templates.tf   # Reusable Google Compute Instance Templates
├── 2-vm-instances.tf         # Standalone VMs (from template & custom) + Policy attachments
├── 3-health-checks.tf        # Autohealing & Load Balancer Health Checks (HTTP, HTTPS, TCP, gRPC)
├── 4-managed-instance-groups.tf # Regional & Zonal MIGs with autohealing & rolling updates
├── 5-autoscaling-policies.tf # Regional & Zonal autoscalers with CPU targets & scaling schedules
├── 6-compute-policies.tf     # Disk snapshot schedules & VM start/stop resource policies
├── variables.tf              # Input variables (config_file_path or yaml_content)
├── outputs.tf                # Comprehensive IDs, self-links, IPs, and summary inventory
├── versions.tf               # Terraform (>= 1.5.0) and Google Provider (>= 5.0.0, < 7.0.0)
└── README.md                 # Documentation and complete YAML schema
```

---

## Complete YAML Configuration Schema

```yaml
compute_infrastructure:
  project_id: "yuvaraj-internal-project"
  region: "asia-south1"
  zone: "asia-south1-a"
  network: "projects/yuvaraj-internal-project/global/networks/default"
  subnetwork: "projects/yuvaraj-internal-project/regions/asia-south1/subnetworks/default"

  # ----------------------------------------------------------------------------
  # 1. Compute Resource Policies (Snapshot & Start/Stop Schedules)
  # ----------------------------------------------------------------------------
  compute_policies:
    snapshot_schedules:
      daily-backup-schedule:
        description: "Daily automated disk snapshot schedule with 14-day retention"
        schedule:
          type: "daily"
          start_time: "02:00" # UTC e.g. 02:00
        retention_days: 14
        on_source_disk_delete: "KEEP_AUTO_SNAPSHOTS"
        guest_flush: false
        labels:
          environment: "production"
          backup_tier: "gold"

    instance_schedules:
      dev-business-hours-schedule:
        description: "Business hours schedule: Mon-Fri 8:00 AM to 7:00 PM IST"
        time_zone: "Asia/Kolkata"
        vm_start_schedule: "0 8 * * 1-5" # Start at 8:00 AM IST
        vm_stop_schedule: "0 19 * * 1-5"  # Stop at 7:00 PM IST

  # ----------------------------------------------------------------------------
  # 2. Instance Templates (Golden Image Family, Shielded VM, SAs)
  # ----------------------------------------------------------------------------
  instance_templates:
    app-web-template:
      machine_type: "e2-medium"
      tags: ["allow-iap-ssh", "allow-health-check", "http-server"]
      labels:
        environment: "production"
        role: "web-server"
      boot_disk:
        source_image: "projects/debian-cloud/global/images/family/debian-12"
        disk_type: "pd-balanced"
        disk_size_gb: 20
        auto_delete: true
        # Attach snapshot policy to template boot disk (applies to all MIG instances)
        resource_policies: ["daily-backup-schedule"]
      shielded_instance_config:
        enable_secure_boot: true
        enable_vtpm: true
        enable_integrity_monitoring: true
      service_account:
        scopes: ["https://www.googleapis.com/auth/cloud-platform"]
      # Cloud-init bootstrap script (YAML string or file path)
      cloud_init: |
        #cloud-config
        package_upgrade: true
        packages:
          - nginx
          - curl
          - jq
        write_files:
          - path: /var/www/html/index.html
            content: "<h1>Welcome to GCP Autohealing MIG with Cloud-Init - $(hostname)</h1>"
            permissions: "0644"
        runcmd:
          - [ systemctl, restart, nginx ]
      # Optional: Startup script executed on every boot
      startup_script: |
        #!/bin/bash
        echo "Instance booted at $(date)" >> /var/log/boot-tracker.log

  # ----------------------------------------------------------------------------
  # 3. Autohealing Health Checks
  # ----------------------------------------------------------------------------
  health_checks:
    app-http-health-check:
      type: "HTTP"
      port: 80
      request_path: "/"
      check_interval_sec: 10
      timeout_sec: 5
      healthy_threshold: 2
      unhealthy_threshold: 3

  # ----------------------------------------------------------------------------
  # 4. Standalone VM Instances (Jump Host, Custom DB, or Template-Derived)
  # ----------------------------------------------------------------------------
  vm_instances:
    # Example A: Standalone VM derived from an Instance Template
    bastion-jump-host:
      instance_template: "app-web-template"
      zone: "asia-south1-a"
      tags: ["allow-iap-ssh"]
      # Attach start/stop instance schedule
      instance_schedule: "dev-business-hours-schedule"
      # Attach disk snapshot schedule
      snapshot_schedule: "daily-backup-schedule"

    # Example B: Standalone custom VM (Custom disk, OS, machine type, and cloud-init)
    standalone-test-vm:
      machine_type: "e2-micro"
      zone: "asia-south1-a"
      tags: ["allow-iap-ssh"]
      boot_disk:
        source_image: "projects/debian-cloud/global/images/family/debian-12"
        disk_type: "pd-standard"
        disk_size_gb: 15
      # Cloud-Init bootstrap configuration
      cloud_init: |
        #cloud-config
        users:
          - name: devops
            groups: sudo
            shell: /bin/bash
            sudo: ['ALL=(ALL) NOPASSWD:ALL']
        packages:
          - curl
          - htop
      instance_schedule: "dev-business-hours-schedule"
      snapshot_schedule: "daily-backup-schedule"

  # ----------------------------------------------------------------------------
  # 5. Managed Instance Groups (Regional HA or Zonal)
  # ----------------------------------------------------------------------------
  managed_instance_groups:
    app-regional-mig:
      type: "REGIONAL"
      region: "asia-south1"
      base_instance_name: "app-mig"
      instance_template: "app-web-template"
      target_size: 2
      auto_healing_policies:
        health_check: "app-http-health-check"
        initial_delay_sec: 300
      update_policy:
        type: "PROACTIVE"
        minimal_action: "REPLACE"
        max_surge_fixed: 1
        max_unavailable_fixed: 0
        min_ready_sec: 30

  # ----------------------------------------------------------------------------
  # 6. Autoscaling Policies (Targeting Regional/Zonal MIGs)
  # ----------------------------------------------------------------------------
  autoscaling_policies:
    app-mig-autoscaler:
      mig_name: "app-regional-mig"
      min_replicas: 1
      max_replicas: 5
      cooldown_period: 60
      cpu_target: 0.70
      scaling_schedules:
        - name: "business-hours-spike"
          min_required_replicas: 3
          schedule: "0 9 * * 1-5"
          time_zone: "Asia/Kolkata"
          duration_sec: 32400 # 9 hours
```

---

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `config_file_path` | Absolute or relative path to the YAML configuration file | `string` | `null` | no |
| `yaml_content` | Direct YAML string containing the configuration | `string` | `null` | no |

---

## Outputs

| Name | Description |
|------|-------------|
| `instance_templates` | Map of all created instance templates with IDs, names, self links, and tags |
| `vm_instances` | Map of all created standalone VMs (both `FROM_TEMPLATE` and `CUSTOM`) with private/public IPs |
| `managed_instance_groups` | Map of all Regional and Zonal MIGs with IDs, names, target pools, and target sizes |
| `health_checks` | Map of all created health checks with IDs, types, and self links |
| `autoscalers` | Map of all created autoscalers attached to MIGs |
| `compute_policies` | Map of created snapshot schedules and instance start/stop schedules |
| `compute_summary` | Summary count of all deployed compute components |
