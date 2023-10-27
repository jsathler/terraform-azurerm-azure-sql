variable "location" {
  description = "The region where the Data Factory will be created. This parameter is required"
  type        = string
  default     = "northeurope"
  nullable    = false
}

variable "resource_group_name" {
  description = "The name of the resource group in which the resources will be created. This parameter is required"
  type        = string
  nullable    = false
}
variable "tags" {
  description = "Tags to be applied to resources."
  type        = map(string)
  default     = null
}

variable "name_sufix_append" {
  description = "Define if all resources names should be appended with sufixes according to https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations."
  type        = bool
  default     = true
  nullable    = false
}

variable "sql_server" {
  type = object({
    name                                         = string
    version                                      = optional(string, "12.0")
    administrator_login                          = optional(string, "localadmin")
    administrator_login_password                 = optional(string, null)
    connection_policy                            = optional(string, "Default")
    transparent_data_encryption_key_vault_key_id = optional(string, null)
    minimum_tls_version                          = optional(string, "1.2")
    allow_azure_services                         = optional(bool, false)
    public_network_access_enabled                = optional(bool, false)
    outbound_fqdns                               = optional(list(string), [])
    secondary_server_name                        = optional(string, null)
    secondary_server_resource_group_name         = optional(string, null)
    secondary_server_location                    = optional(string, "westeurope")
    primary_user_assigned_identity_id            = optional(string, null)

    identity = optional(object({
      type         = optional(string, "SystemAssigned")
      identity_ids = optional(list(string), null)
    }), {})

    entra_id = optional(object({
      login_username              = string
      object_id                   = string
      tenant_id                   = string
      azuread_authentication_only = optional(bool, true)
    }), null)

    firewall_rules = optional(list(object({
      name             = string
      start_ip_address = string
      end_ip_address   = string
    })), null)

    vnet_rules = optional(list(object({
      name                                 = string
      subnet_id                            = string
      ignore_missing_vnet_service_endpoint = optional(bool, false)
      secondary                            = optional(bool, false)
    })), null)

    auditing_policy = optional(object({
      storage_account_id                      = string
      storage_account_assign_role             = optional(bool, false)
      storage_account_access_key              = optional(string, null)
      storage_account_access_key_is_secondary = optional(bool, false)
      log_monitoring_enabled                  = optional(bool, true)
      storage_account_subscription_id         = optional(string, null)
      retention_in_days                       = optional(number, 31)
      #actions_and_groups                      = optional(list(string), ["BATCH_COMPLETED_GROUP", "SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP", "FAILED_DATABASE_AUTHENTICATION_GROUP", "APPLICATION_ROLE_CHANGE_PASSWORD_GROUP"])
      #predicate_expression                    = optional(string, "*")
    }), null)
  })

  validation {
    condition     = can(index(["2.0", "12.0"], var.sql_server.version) >= 0)
    error_message = "Valid values are: 2.0 and 12.0"
  }

  validation {
    condition     = can(index(["Default", "Proxy", "Redirect"], var.sql_server.connection_policy) >= 0)
    error_message = "Valid values are: Default, Proxy and Redirect"
  }

  validation {
    condition     = can(index(["1.0", "1.1", "1.2", "Disabled"], var.sql_server.minimum_tls_version) >= 0)
    error_message = "Valid values are: 1.0, 1.1, 1.2 and Disabled"
  }

  validation {
    condition     = var.sql_server.identity == null ? true : can(index(["SystemAssigned", "UserAssigned", "SystemAssigned, UserAssigned"], var.sql_server.identity.type) >= 0)
    error_message = "Valid values are: SystemAssigned, UserAssigned and SystemAssigned, UserAssigned"
  }
}

variable "elastic_pools" {
  type = list(object({
    name                           = string
    maintenance_configuration_name = optional(string, "SQL_Default")
    max_size_gb                    = optional(number, 50)
    zone_redundant                 = optional(bool, true)
    license_type                   = optional(string, "BasePrice")
    failover                       = optional(bool, false)

    sku = optional(object({
      name     = optional(string, "GP_Gen5")
      capacity = optional(number, 2)
      tier     = optional(string, "GeneralPurpose")
      family   = optional(string, "Gen5")
    }), {})

    per_database_settings = optional(object({
      min_capacity = optional(number, 0)
      max_capacity = optional(number, 2)
    }), {})
  }))

  default = null

  # validation {
  #   condition     = var.elastic_pools == null ? true : alltrue([for pool in var.elastic_pools : pool.zone_redundant ? can(index(["GeneralPurpose", "BusinessCritical", "Premium"], pool.sku.tier) >= 0) : true])
  #   error_message = "if zone_redundant is true, allowed values for sku.tier are GeneralPurpose, BusinessCritical and Premium"
  # }

  validation {
    condition     = var.elastic_pools == null ? true : alltrue([for pool in var.elastic_pools : can(index(["LicenseIncluded", "BasePrice"], pool.license_type) >= 0)])
    error_message = "Allowed values for license_type are LicenseIncluded and BasePrice"
  }

  validation {
    condition     = var.elastic_pools == null ? true : alltrue([for pool in var.elastic_pools : can(index(["Gen4", "Gen5", "Fsv2", "DC"], pool.sku.family) >= 0)])
    error_message = "Allowed values for sku.family are Gen4, Gen5, Fsv2 or DC"
  }

  validation {
    condition     = var.elastic_pools == null ? true : alltrue([for pool in var.elastic_pools : can(index(["GeneralPurpose", "BusinessCritical", "Basic", "Standard", "Premium", "HyperScale"], pool.sku.tier) >= 0)])
    error_message = "Allowed values for sku.tier are GeneralPurpose, BusinessCritical, Basic, Standard, Premium or HyperScale"
  }

  validation {
    condition     = var.elastic_pools == null ? true : alltrue([for pool in var.elastic_pools : can(index(["BasicPool", "StandardPool", "PremiumPool", "GP_Gen4", "GP_Gen5", "GP_Fsv2", "GP_DC", "BC_Gen4", "BC_Gen5", "BC_DC", "HS_Gen5"], pool.sku.name) >= 0)])
    error_message = "Allowed values for sku.name are BasicPool, StandardPool, PremiumPool, GP_Gen4, GP_Gen5, GP_Fsv2, GP_DC, BC_Gen4, BC_Gen5, BC_DC, or HS_Gen5"
  }
}

variable "sql_databases" {
  type = list(object({
    name                                = string
    collation                           = optional(string, "SQL_Latin1_General_CP1_CI_AS")
    license_type                        = optional(string, "BasePrice")
    max_size_gb                         = optional(number, 50)
    sku_name                            = optional(string, "GP_Gen5_2") #https://learn.microsoft.com/en-us/azure/azure-sql/database/resource-limits-vcore-single-databases?view=azuresql
    zone_redundant                      = optional(bool, true)
    elastic_pool_name                   = optional(string, null)
    maintenance_configuration_name      = optional(string, "SQL_Default")
    create_mode                         = optional(string, null)
    geo_backup_enabled                  = optional(bool, true)
    storage_account_type                = optional(string, "Geo")
    auto_pause_delay_in_minutes         = optional(number, 60)
    min_capacity                        = optional(number, 0.5)
    transparent_data_encryption_enabled = optional(bool, true)
    ledger_enabled                      = optional(bool, false)
    creation_source_database_id         = optional(string, null)
    job_agent_name                      = optional(string, null)

    read_scale                  = optional(bool, false)
    read_replica_count          = optional(number, null)
    restore_point_in_time       = optional(string, null)
    recover_database_id         = optional(string, null)
    restore_dropped_database_id = optional(string, null)

    threat_detection_policy = optional(object({
      state                      = optional(string, null)
      disabled_alerts            = optional(string, null)
      email_account_admins       = optional(string, null)
      email_addresses            = optional(string, null)
      retention_days             = optional(number, 31)
      storage_account_access_key = optional(string, null)
      storage_endpoint           = optional(string, null)
    }), null)

    short_term_retention_policy = optional(object({
      retention_days           = optional(number, 7)  #between 7 - 35
      backup_interval_in_hours = optional(number, 24) #12 or 24
    }), {})

    long_term_retention_policy = optional(object({
      weekly_retention  = optional(string, "P4W")
      monthly_retention = optional(string, "P12M")
      yearly_retention  = optional(string, "P5Y")
      week_of_year      = optional(number, 1)
    }), null)

    import = optional(object({
      storage_uri                  = string
      storage_key                  = string
      storage_key_type             = optional(string, "StorageAccessKey")
      administrator_login          = string
      administrator_login_password = string
      authentication_type          = optional(string, "SQL")
      storage_account_id           = optional(string, null)
    }), null)
  }))

  default = null

  validation {
    condition     = var.sql_databases == null ? true : alltrue([for db in var.sql_databases : db.create_mode != null ? can(index(["Copy", "Default", "OnlineSecondary", "PointInTimeRestore", "Recovery", "Restore", "RestoreExternalBackup", "RestoreExternalBackupSecondary", "RestoreLongTermRetentionBackup", "Secondary"], db.storage_account_type) >= 0) : true])
    error_message = "Allowed values for create_mode are Copy, Default, OnlineSecondary, PointInTimeRestore, Recovery, Restore, RestoreExternalBackup, RestoreExternalBackupSecondary, RestoreLongTermRetentionBackup and Secondary"
  }

  validation {
    condition     = var.sql_databases == null ? true : alltrue([for db in var.sql_databases : db.geo_backup_enabled ? can(index(["Geo", "Local", "Zone"], db.storage_account_type) >= 0) : true])
    error_message = "if geo_backup_enabled is true, allowed values for storage_account_type are Geo, Local and Zone"
  }

  validation {
    condition     = var.sql_databases == null ? true : alltrue([for db in var.sql_databases : db.short_term_retention_policy == null ? true : db.short_term_retention_policy.retention_days >= 7 && db.short_term_retention_policy.retention_days <= 35])
    error_message = "short_term_retention_policy.retention_days should be between 7 and 35"
  }

  validation {
    condition     = var.sql_databases == null ? true : alltrue([for db in var.sql_databases : db.auto_pause_delay_in_minutes == null ? true : db.auto_pause_delay_in_minutes >= 60])
    error_message = "short_term_retention_policy.retention_days should be between 7 and 35"
  }

  validation {
    condition     = var.sql_databases == null ? true : alltrue([for db in var.sql_databases : db.short_term_retention_policy == null ? true : db.short_term_retention_policy.backup_interval_in_hours == 12 || db.short_term_retention_policy.backup_interval_in_hours == 24])
    error_message = "short_term_retention_policy.backup_interval_in_hours should be 12 or 24"
  }
}

variable "failover_groups" {
  type = list(object({
    name                                      = string
    database_names                            = list(string)
    readonly_endpoint_failover_policy_enabled = optional(bool, false)

    read_write_endpoint_failover_policy = optional(object({
      mode          = optional(string, "Automatic")
      grace_minutes = optional(number, 60)
    }), {})
  }))

  default = null

  validation {
    condition     = var.failover_groups == null ? true : alltrue([for group in var.failover_groups : length(group.database_names) <= 5])
    error_message = "Azure SQL Failover supports up to 5 DBs per group. database_names list has more than 5 DBs"
  }
}
