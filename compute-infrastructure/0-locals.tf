/**
 * Copyright 2026 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

locals {
  # ----------------------------------------------------------------------------
  # 1. Configuration Parsing & Context
  # ----------------------------------------------------------------------------
  raw_config = (
    var.yaml_content != null ? yamldecode(var.yaml_content) : (
      var.config_file_path != null ? yamldecode(file(var.config_file_path)) : {}
    )
  )

  cfg                = try(local.raw_config.compute_infrastructure, try(local.raw_config.compute, local.raw_config))
  default_project_id = try(local.cfg.project_id, null)
  default_region     = try(local.cfg.region, "asia-south1")
  default_zone       = try(local.cfg.zone, "${local.default_region}-a")
  default_network    = try(local.cfg.network, "default")
  default_subnetwork = try(local.cfg.subnetwork, null)

  # ----------------------------------------------------------------------------
  # 2. Compute Resource Policies (Snapshot & Instance Start/Stop Schedules)
  # ----------------------------------------------------------------------------
  raw_policies           = try(local.cfg.compute_policies, try(local.cfg.resource_policies, {}))
  raw_snapshot_schedules = try(local.raw_policies.snapshot_schedules, {})
  raw_instance_schedules = try(local.raw_policies.instance_schedules, {})

  snapshot_schedules_map = {
    for k, v in local.raw_snapshot_schedules : try(v.name, tostring(k)) => {
      name        = try(v.name, tostring(k))
      project_id  = try(v.project_id, local.default_project_id)
      region      = try(v.region, local.default_region)
      description = try(v.description, "Managed automated disk snapshot schedule")

      # Schedule definition (hourly, daily, or weekly)
      schedule_type  = lower(try(v.schedule.type, try(v.recurrence, "daily")))
      start_time     = try(v.schedule.start_time, try(v.start_time, "02:00")) # UTC e.g. "02:00"
      hours_in_cycle = try(v.schedule.hours_in_cycle, try(v.hours_in_cycle, 24))
      day_of_week    = upper(try(v.schedule.day_of_week, try(v.day_of_week, "SUNDAY")))

      # Retention & source disk deletion behavior
      max_retention_days    = try(v.retention_days, try(v.retention_policy.max_retention_days, 14))
      on_source_disk_delete = upper(try(v.on_source_disk_delete, try(v.retention_policy.on_source_disk_delete, "KEEP_AUTO_SNAPSHOTS")))

      # Snapshot properties
      guest_flush       = try(v.guest_flush, false)
      labels            = try(v.labels, {})
      storage_locations = try(v.storage_locations, [try(v.region, local.default_region)])
    }
  }

  instance_schedules_map = {
    for k, v in local.raw_instance_schedules : try(v.name, tostring(k)) => {
      name              = try(v.name, tostring(k))
      project_id        = try(v.project_id, local.default_project_id)
      region            = try(v.region, local.default_region)
      description       = try(v.description, "Managed automated VM start/stop schedule")
      time_zone         = try(v.time_zone, try(v.timezone, "Asia/Kolkata"))          # IANA time zone
      vm_start_schedule = try(v.vm_start_schedule, try(v.start_cron, "0 8 * * 1-5")) # Mon-Fri 8:00 AM
      vm_stop_schedule  = try(v.vm_stop_schedule, try(v.stop_cron, "0 19 * * 1-5"))  # Mon-Fri 7:00 PM
      init_time         = try(v.init_time, null)
      end_time          = try(v.end_time, null)
    }
  }

  # ----------------------------------------------------------------------------
  # 3. Instance Templates (Golden Image Family, SAs, Shielded VM, Metadata)
  # ----------------------------------------------------------------------------
  raw_templates = try(local.cfg.instance_templates, {})

  instance_templates_map = {
    for k, v in local.raw_templates : try(v.name, tostring(k)) => {
      name_prefix    = try(v.name_prefix, "${try(v.name, tostring(k))}-")
      project_id     = try(v.project_id, local.default_project_id)
      region         = try(v.region, local.default_region)
      description    = try(v.description, "Managed instance template for ${try(v.name, tostring(k))}")
      machine_type   = try(v.machine_type, "e2-medium")
      can_ip_forward = try(v.can_ip_forward, false)
      tags           = try(v.tags, ["allow-iap-ssh", "allow-health-check"])
      labels         = try(v.labels, {})

      # Boot Disk Configuration (Consumes Packer golden images or image families)
      boot_disk = {
        source_image = (
          try(v.boot_disk.image_family, try(v.image_family, null)) != null ?
          "projects/${try(v.boot_disk.image_project, try(v.image_project, try(v.project_id, local.default_project_id)))}/global/images/family/${try(v.boot_disk.image_family, v.image_family)}" :
          try(
            v.boot_disk.source_image,
            try(v.source_image, "projects/debian-cloud/global/images/family/debian-12")
          )
        )
        disk_type    = try(v.boot_disk.disk_type, try(v.disk_type, "pd-balanced"))
        disk_size_gb = try(v.boot_disk.disk_size_gb, try(v.disk_size_gb, 20))
        auto_delete  = try(v.boot_disk.auto_delete, true)
        kms_key_name = try(v.boot_disk.kms_key_name, try(v.kms_key_name, null))
        # Resource policy attached to template disk (e.g. snapshot schedule)
        resource_policies = try(v.boot_disk.resource_policies, try(v.resource_policies, []))
      }

      # Optional attached secondary persistent disks
      additional_disks = [
        for d in try(v.additional_disks, try(v.attached_disks, [])) : {
          disk_name         = try(d.name, null)
          device_name       = try(d.device_name, try(d.name, "data-disk"))
          disk_type         = try(d.disk_type, "pd-balanced")
          disk_size_gb      = try(d.disk_size_gb, 50)
          auto_delete       = try(d.auto_delete, false)
          mode              = try(d.mode, "READ_WRITE")
          resource_policies = try(d.resource_policies, [])
        }
      ]

      # Network Interfaces
      network_interfaces = [
        for idx, nic in try(v.network_interfaces, [try(v.network_interface, {})]) : {
          network = (
            try(nic.network, local.default_network) != null && try(nic.network, local.default_network) != "" ? (
              startswith(try(nic.network, local.default_network), "projects/") ?
              try(nic.network, local.default_network) :
              "projects/${try(v.project_id, local.default_project_id)}/global/networks/${try(nic.network, local.default_network)}"
            ) : null
          )
          subnetwork = (
            try(nic.subnetwork, try(v.subnetwork, local.default_subnetwork)) != null && try(nic.subnetwork, try(v.subnetwork, local.default_subnetwork)) != "" ? (
              startswith(try(nic.subnetwork, try(v.subnetwork, local.default_subnetwork)), "projects/") ?
              try(nic.subnetwork, try(v.subnetwork, local.default_subnetwork)) :
              "projects/${try(v.project_id, local.default_project_id)}/regions/${try(v.region, local.default_region)}/subnetworks/${try(nic.subnetwork, try(v.subnetwork, local.default_subnetwork))}"
            ) : null
          )
          enable_public_ip = try(nic.enable_public_ip, try(v.enable_public_ip, false))
          network_tier     = try(nic.network_tier, "PREMIUM")
        }
      ]

      # Shielded VM Configuration
      shielded_instance_config = {
        enable_secure_boot          = try(v.shielded_instance_config.enable_secure_boot, true)
        enable_vtpm                 = try(v.shielded_instance_config.enable_vtpm, true)
        enable_integrity_monitoring = try(v.shielded_instance_config.enable_integrity_monitoring, true)
      }

      # Service Account
      service_account = {
        email  = try(v.service_account.email, try(v.service_account_email, null))
        scopes = try(v.service_account.scopes, ["https://www.googleapis.com/auth/cloud-platform"])
      }

      # Metadata, Cloud-Init Bootstrap & Startup Scripts
      metadata = merge(
        try(v.metadata, {}),
        # 1. Cloud-Init Bootstrap Script (String, structured YAML object, or file path)
        try(v.cloud_init, try(v.user_data, null)) != null ? {
          "user-data" = can(tostring(try(v.cloud_init, try(v.user_data, null)))) ? (
            tostring(try(v.cloud_init, try(v.user_data, null)))
          ) : "#cloud-config\n${yamlencode(try(v.cloud_init, try(v.user_data, null)))}"
          } : (
          try(v.cloud_init_path, try(v.user_data_path, null)) != null ? {
            "user-data" = file(try(v.cloud_init_path, v.user_data_path))
          } : {}
        ),
        # 2. Traditional Startup Script (inline or path)
        try(v.startup_script, null) != null ? { "startup-script" = v.startup_script } : (
          try(v.startup_script_path, null) != null ? { "startup-script" = file(v.startup_script_path) } : {}
        ),
        # 3. Cloud Storage Startup Script URL
        try(v.startup_script_url, null) != null ? { "startup-script-url" = v.startup_script_url } : {}
      )
    }
  }

  # ----------------------------------------------------------------------------
  # 4. Standalone VM Instances (Jump Hosts, Stateful DBs, Template-derived or Custom)
  # ----------------------------------------------------------------------------
  raw_vms = try(local.cfg.vm_instances, try(local.cfg.instances, {}))

  vm_instances_map = {
    for k, v in local.raw_vms : try(v.name, tostring(k)) => {
      name        = try(v.name, tostring(k))
      project_id  = try(v.project_id, local.default_project_id)
      zone        = try(v.zone, "${try(v.region, local.default_region)}-a")
      description = try(v.description, "Managed VM Instance ${try(v.name, tostring(k))}")

      # Optional: Instance Template inheritance
      instance_template = try(v.instance_template, try(v.source_instance_template, null))

      # Machine sizing (optional override when template is specified, default e2-medium otherwise)
      machine_type        = try(v.machine_type, try(v.instance_template, null) == null ? "e2-medium" : null)
      can_ip_forward      = try(v.can_ip_forward, false)
      tags                = try(v.tags, ["allow-iap-ssh", "allow-health-check"])
      labels              = try(v.labels, {})
      deletion_protection = try(v.deletion_protection, false)

      # Boot disk definition (used when NOT deriving from template)
      boot_disk = {
        source_image = (
          try(v.boot_disk.image_family, try(v.image_family, null)) != null ?
          "projects/${try(v.boot_disk.image_project, try(v.image_project, try(v.project_id, local.default_project_id)))}/global/images/family/${try(v.boot_disk.image_family, v.image_family)}" :
          try(
            v.boot_disk.source_image,
            try(v.source_image, "projects/debian-cloud/global/images/family/debian-12")
          )
        )
        disk_type    = try(v.boot_disk.disk_type, try(v.disk_type, "pd-balanced"))
        disk_size_gb = try(v.boot_disk.disk_size_gb, try(v.disk_size_gb, 20))
        auto_delete  = try(v.boot_disk.auto_delete, true)
        kms_key_name = try(v.boot_disk.kms_key_name, try(v.kms_key_name, null))
      }

      # Attached Disks
      attached_disks = [
        for d in try(v.attached_disks, []) : {
          source      = d.source
          device_name = try(d.device_name, null)
          mode        = try(d.mode, "READ_WRITE")
        }
      ]

      # Network Interfaces
      network_interfaces = [
        for idx, nic in try(v.network_interfaces, [try(v.network_interface, {})]) : {
          network = (
            try(nic.network, local.default_network) != null && try(nic.network, local.default_network) != "" ? (
              startswith(try(nic.network, local.default_network), "projects/") ?
              try(nic.network, local.default_network) :
              "projects/${try(v.project_id, local.default_project_id)}/global/networks/${try(nic.network, local.default_network)}"
            ) : null
          )
          subnetwork = (
            try(nic.subnetwork, try(v.subnetwork, local.default_subnetwork)) != null && try(nic.subnetwork, try(v.subnetwork, local.default_subnetwork)) != "" ? (
              startswith(try(nic.subnetwork, try(v.subnetwork, local.default_subnetwork)), "projects/") ?
              try(nic.subnetwork, try(v.subnetwork, local.default_subnetwork)) :
              "projects/${try(v.project_id, local.default_project_id)}/regions/${try(v.region, local.default_region)}/subnetworks/${try(nic.subnetwork, try(v.subnetwork, local.default_subnetwork))}"
            ) : null
          )
          network_ip       = try(nic.network_ip, try(v.static_internal_ip, null))
          enable_public_ip = try(nic.enable_public_ip, try(v.enable_public_ip, false))
          network_tier     = try(nic.network_tier, "PREMIUM")
        }
      ]

      # Shielded VM Configuration
      shielded_instance_config = {
        enable_secure_boot          = try(v.shielded_instance_config.enable_secure_boot, true)
        enable_vtpm                 = try(v.shielded_instance_config.enable_vtpm, true)
        enable_integrity_monitoring = try(v.shielded_instance_config.enable_integrity_monitoring, true)
      }

      # Service Account
      service_account = {
        email  = try(v.service_account.email, try(v.service_account_email, null))
        scopes = try(v.service_account.scopes, ["https://www.googleapis.com/auth/cloud-platform"])
      }

      # Metadata, Cloud-Init Bootstrap & Startup Scripts
      metadata = merge(
        try(v.metadata, {}),
        # 1. Cloud-Init Bootstrap Script (String, structured YAML object, or file path)
        try(v.cloud_init, try(v.user_data, null)) != null ? {
          "user-data" = can(tostring(try(v.cloud_init, try(v.user_data, null)))) ? (
            tostring(try(v.cloud_init, try(v.user_data, null)))
          ) : "#cloud-config\n${yamlencode(try(v.cloud_init, try(v.user_data, null)))}"
          } : (
          try(v.cloud_init_path, try(v.user_data_path, null)) != null ? {
            "user-data" = file(try(v.cloud_init_path, v.user_data_path))
          } : {}
        ),
        # 2. Traditional Startup Script (inline or path)
        try(v.startup_script, null) != null ? { "startup-script" = v.startup_script } : (
          try(v.startup_script_path, null) != null ? { "startup-script" = file(v.startup_script_path) } : {}
        ),
        # 3. Cloud Storage Startup Script URL
        try(v.startup_script_url, null) != null ? { "startup-script-url" = v.startup_script_url } : {}
      )

      # Resource Policies for Standalone VMs
      # 1. Instance schedule (start/stop)
      instance_schedule = try(v.instance_schedule, try(v.policies.instance_schedule, null))
      # 2. Disk snapshot schedule for boot disk
      snapshot_schedule = try(v.snapshot_schedule, try(v.policies.snapshot_schedule, null))
    }
  }

  # Partition VMs into template-derived vs custom standalone
  vm_instances_from_template = {
    for k, v in local.vm_instances_map : k => v if v.instance_template != null && v.instance_template != ""
  }

  vm_instances_custom = {
    for k, v in local.vm_instances_map : k => v if v.instance_template == null || v.instance_template == ""
  }

  # Map for VM instance start/stop schedule policy attachment
  vm_instance_schedule_attachments = {
    for k, v in local.vm_instances_map : k => {
      vm_name           = v.name
      zone              = v.zone
      project_id        = v.project_id
      instance_schedule = v.instance_schedule
    } if v.instance_schedule != null && v.instance_schedule != ""
  }

  # Map for VM boot disk snapshot schedule policy attachment
  vm_disk_snapshot_attachments = {
    for k, v in local.vm_instances_map : k => {
      disk_name         = v.name # Default boot disk name matches VM name
      zone              = v.zone
      project_id        = v.project_id
      snapshot_schedule = v.snapshot_schedule
    } if v.snapshot_schedule != null && v.snapshot_schedule != ""
  }

  # ----------------------------------------------------------------------------
  # 5. Autohealing Health Checks (TCP / HTTP / HTTPS / gRPC)
  # ----------------------------------------------------------------------------
  raw_health_checks = try(local.cfg.health_checks, {})

  health_checks_map = {
    for k, v in local.raw_health_checks : try(v.name, tostring(k)) => {
      name                = try(v.name, tostring(k))
      project_id          = try(v.project_id, local.default_project_id)
      description         = try(v.description, "Autohealing health check for ${try(v.name, tostring(k))}")
      type                = upper(try(v.type, "HTTP")) # HTTP, HTTPS, TCP, GRPC
      port                = try(v.port, 80)
      request_path        = try(v.request_path, "/")
      proxy_header        = try(v.proxy_header, "NONE")
      response            = try(v.response, null)
      check_interval_sec  = try(v.check_interval_sec, 10)
      timeout_sec         = try(v.timeout_sec, 5)
      healthy_threshold   = try(v.healthy_threshold, 2)
      unhealthy_threshold = try(v.unhealthy_threshold, 3)
      enable_logging      = try(v.enable_logging, false)
    }
  }

  # ----------------------------------------------------------------------------
  # 6. Managed Instance Groups (Regional & Zonal MIGs with Autohealing)
  # ----------------------------------------------------------------------------
  raw_migs = try(local.cfg.managed_instance_groups, try(local.cfg.migs, {}))

  managed_instance_groups_map = {
    for k, v in local.raw_migs : try(v.name, tostring(k)) => {
      name               = try(v.name, tostring(k))
      project_id         = try(v.project_id, local.default_project_id)
      type               = upper(try(v.type, "REGIONAL")) # REGIONAL or ZONAL
      region             = try(v.region, local.default_region)
      zone               = try(v.zone, "${try(v.region, local.default_region)}-a")
      description        = try(v.description, "Managed Instance Group ${try(v.name, tostring(k))}")
      base_instance_name = try(v.base_instance_name, try(v.name, tostring(k)))
      instance_template  = try(v.instance_template, try(v.template, null))
      target_size        = try(v.target_size, 2)
      target_pools       = try(v.target_pools, [])
      wait_for_instances = try(v.wait_for_instances, false)

      # Distribution policy for regional MIGs (defaults to 3 zones)
      distribution_policy_zones = try(v.distribution_policy_zones, [
        "${try(v.region, local.default_region)}-a",
        "${try(v.region, local.default_region)}-b",
        "${try(v.region, local.default_region)}-c"
      ])

      # Autohealing policies
      auto_healing_policies = {
        health_check      = try(v.auto_healing_policies.health_check, try(v.health_check, null))
        initial_delay_sec = try(v.auto_healing_policies.initial_delay_sec, try(v.initial_delay_sec, 300))
      }

      # Rolling Update Policies
      update_policy = {
        type                  = upper(try(v.update_policy.type, "PROACTIVE"))         # PROACTIVE or OPPORTUNISTIC
        minimal_action        = upper(try(v.update_policy.minimal_action, "REPLACE")) # REPLACE, RESTART, REFRESH
        max_surge_fixed       = try(v.update_policy.max_surge_fixed, 1)
        max_unavailable_fixed = try(v.update_policy.max_unavailable_fixed, 0)
        min_ready_sec         = try(v.update_policy.min_ready_sec, 30)
        replacement_method    = upper(try(v.update_policy.replacement_method, "SUBSTITUTE")) # SUBSTITUTE or RECREATE
      }

      # Compute Policies (Instance start/stop schedules for instances in MIG)
      instance_schedule = try(v.instance_schedule, try(v.policies.instance_schedule, null))
    }
  }

  regional_migs_map = {
    for k, v in local.managed_instance_groups_map : k => v if v.type == "REGIONAL"
  }

  zonal_migs_map = {
    for k, v in local.managed_instance_groups_map : k => v if v.type == "ZONAL"
  }

  # ----------------------------------------------------------------------------
  # 7. Autoscaling Policies (CPU, Load Balancer & Metric-Driven Autoscalers)
  # ----------------------------------------------------------------------------
  raw_autoscalers = try(local.cfg.autoscaling_policies, try(local.cfg.autoscalers, {}))

  autoscaling_policies_map = {
    for k, v in local.raw_autoscalers : try(v.name, tostring(k)) => {
      name            = try(v.name, tostring(k))
      project_id      = try(v.project_id, local.default_project_id)
      mig_name        = try(v.mig_name, try(v.target, try(v.name, tostring(k))))
      min_replicas    = try(v.min_replicas, 1)
      max_replicas    = try(v.max_replicas, 5)
      cooldown_period = try(v.cooldown_period, 60)
      description     = try(v.description, "Autoscaling policy for ${try(v.mig_name, tostring(k))}")

      # CPU Target Utilization
      cpu_target = try(v.cpu_utilization.target, try(v.cpu_target, 0.65))

      # Optional Load Balancing Target Utilization
      load_balancing_target = try(v.load_balancing_utilization.target, try(v.load_balancing_target, null))

      # Optional Scaling Schedules (Time-based scaling e.g. Business Hours spike)
      scaling_schedules = [
        for s_idx, s in try(v.scaling_schedules, []) : {
          name                  = try(s.name, "schedule-${s_idx}")
          min_required_replicas = try(s.min_required_replicas, 2)
          schedule              = s.schedule # Cron expression e.g. "0 9 * * 1-5"
          time_zone             = try(s.time_zone, "Asia/Kolkata")
          duration_sec          = try(s.duration_sec, 32400) # 9 hours
          disabled              = try(s.disabled, false)
        }
      ]
    }
  }

  # Split autoscalers into regional vs zonal based on target MIG type
  regional_autoscalers_map = {
    for k, v in local.autoscaling_policies_map : k => v
    if can(local.regional_migs_map[v.mig_name])
  }

  zonal_autoscalers_map = {
    for k, v in local.autoscaling_policies_map : k => v
    if can(local.zonal_migs_map[v.mig_name])
  }

  # List of MIG names that have active autoscalers attached
  migs_with_autoscalers = [
    for k, v in local.autoscaling_policies_map : v.mig_name
  ]
}
