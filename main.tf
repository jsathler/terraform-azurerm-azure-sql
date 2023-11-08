locals {
  tags = merge(var.tags, { ManagedByTerraform = "True" })
}

###########
# SQL Server
###########

locals {
  /*
  Create a local var with values for both primary and secondary servers
  This was created to avoid duplicating code for both primary ande secondary servers
  */
  sql_servers = var.sql_server.secondary_server_name == null ? {
    primary = var.sql_server
    } : {
    primary   = var.sql_server
    secondary = var.sql_server
  }
}

resource "azurerm_mssql_server" "default" {
  for_each                                     = { for key, value in local.sql_servers : key => value }
  name                                         = each.key == "primary" ? var.name_sufix_append ? "${each.value.name}-sql" : each.value.name : var.name_sufix_append ? "${each.value.secondary_server_name}-sql" : each.value.secondary_server_name
  resource_group_name                          = each.key == "primary" ? var.resource_group_name : each.value.secondary_server_resource_group_name
  location                                     = each.key == "primary" ? var.location : each.value.secondary_server_location
  version                                      = each.value.version
  administrator_login                          = try(each.value.entra_id.azuread_authentication_only, false) ? null : each.value.administrator_login
  administrator_login_password                 = try(each.value.entra_id.azuread_authentication_only, false) ? null : each.value.administrator_login_password
  connection_policy                            = each.value.connection_policy
  transparent_data_encryption_key_vault_key_id = each.value.transparent_data_encryption_key_vault_key_id
  minimum_tls_version                          = each.value.minimum_tls_version
  public_network_access_enabled                = each.value.public_network_access_enabled
  outbound_network_restriction_enabled         = each.value.outbound_fqdns == null ? false : true
  primary_user_assigned_identity_id            = each.value.primary_user_assigned_identity_id
  tags                                         = local.tags

  dynamic "azuread_administrator" {
    for_each = var.sql_server.entra_id == null ? [] : [each.value.entra_id]
    content {
      login_username              = azuread_administrator.value.login_username
      object_id                   = azuread_administrator.value.object_id
      tenant_id                   = azuread_administrator.value.tenant_id
      azuread_authentication_only = azuread_administrator.value.azuread_authentication_only
    }
  }

  dynamic "identity" {
    for_each = var.sql_server.identity == null ? [] : [each.value.identity]
    content {
      type         = identity.value.type
      identity_ids = identity.value.identity_ids
    }
  }
}

locals {
  #If allow_azure_services is true, we merge an 'special' rule to var.sql_server.firewall_rules
  firewall_rules = var.sql_server.allow_azure_services && var.sql_server.public_network_access_enabled ? concat(var.sql_server.firewall_rules,
  [{ name = "AllowAllWindowsAzureIps", start_ip_address = "0.0.0.0", end_ip_address = "0.0.0.0" }]) : var.sql_server.firewall_rules

  full_firewall_rules = local.firewall_rules == null ? [] : flatten([for key, value in local.sql_servers : [
    for rule in local.firewall_rules : {
      server = key
      name   = rule.name
      params = rule
    }
  ]])

  full_outbound_rules = var.sql_server.outbound_fqdns == null ? [] : flatten([for key, value in local.sql_servers : [
    for fqdn in var.sql_server.outbound_fqdns : {
      server = key
      fqdn   = fqdn
    }
  ]])
}

resource "azurerm_mssql_firewall_rule" "default" {
  for_each         = local.full_firewall_rules != null && var.sql_server.public_network_access_enabled ? { for key, value in local.full_firewall_rules : "${value.server}-${value.name}" => value } : {}
  name             = each.value.name == "AllowAllWindowsAzureIps" ? each.value.name : var.name_sufix_append ? "${each.value.name}-sqlfw" : each.value.name
  server_id        = azurerm_mssql_server.default[each.value.server].id
  start_ip_address = each.value.params.start_ip_address
  end_ip_address   = each.value.params.end_ip_address
}

resource "azurerm_mssql_outbound_firewall_rule" "default" {
  for_each  = { for key, value in local.full_outbound_rules : "${value.server}-${value.fqdn}" => value }
  name      = each.value.fqdn
  server_id = azurerm_mssql_server.default[each.value.server].id
}

resource "azurerm_mssql_virtual_network_rule" "default" {
  for_each                             = var.sql_server.vnet_rules != null && var.sql_server.public_network_access_enabled ? { for rules in var.sql_server.vnet_rules : "${rules.secondary ? "secondary" : "primary"}-${rules.name}" => rules } : {}
  name                                 = var.name_sufix_append ? "${each.key}-sqlfw" : each.key
  server_id                            = azurerm_mssql_server.default[each.value.secondary ? "secondary" : "primary"].id
  subnet_id                            = each.value.subnet_id
  ignore_missing_vnet_service_endpoint = each.value.ignore_missing_vnet_service_endpoint
}

# ###########
# # Elastic Pool
# ###########

locals {
  full_elastic_pool = var.elastic_pools == null ? null : flatten([for key, value in local.sql_servers : [
    for ep_value in var.elastic_pools : {
      server = key
      name   = ep_value.name
      params = key == "secondary" && ep_value.failover == false ? null : ep_value
    }
  ]])
}

resource "azurerm_mssql_elasticpool" "default" {
  for_each                       = local.full_elastic_pool == null ? {} : { for key, value in local.full_elastic_pool : "${value.server}-${value.name}" => value if value.params != null }
  name                           = var.name_sufix_append ? "${each.value.name}-sqlep" : each.value.name
  resource_group_name            = azurerm_mssql_server.default[each.value.server].resource_group_name
  location                       = azurerm_mssql_server.default[each.value.server].location
  server_name                    = azurerm_mssql_server.default[each.value.server].name
  maintenance_configuration_name = each.value.params.maintenance_configuration_name
  max_size_gb                    = each.value.params.sku.tier == "Basic" ? 4.8828125 : each.value.params.max_size_gb
  zone_redundant                 = each.value.params.sku.tier == "Basic" || each.value.params.sku.tier == "Standard" ? false : each.value.params.zone_redundant
  license_type                   = strcontains(each.value.params.sku.name, "Pool") ? "LicenseIncluded" : each.value.params.license_type
  tags                           = local.tags

  sku {
    name     = each.value.params.sku.name
    capacity = each.value.params.sku.capacity
    tier     = each.value.params.sku.tier
    family   = strcontains(each.value.params.sku.name, "Pool") ? null : each.value.params.sku.family
  }

  per_database_settings {
    min_capacity = each.value.params.per_database_settings.min_capacity
    max_capacity = each.value.params.per_database_settings.max_capacity
  }
}

# ###########
# # SQL DB
# ###########

resource "azurerm_mssql_database" "default" {
  for_each                       = var.sql_databases == null ? {} : { for key, value in var.sql_databases : value.name => value }
  name                           = var.name_sufix_append ? "${each.key}-sqldb" : each.key
  server_id                      = azurerm_mssql_server.default["primary"].id
  collation                      = each.value.collation
  license_type                   = strcontains(each.value.sku_name, "_S_") ? null : each.value.license_type
  max_size_gb                    = each.value.sku_name == "Basic" ? 2 : each.value.max_size_gb
  sku_name                       = each.value.elastic_pool_name == null ? each.value.sku_name : "ElasticPool"
  elastic_pool_id                = each.value.elastic_pool_name == null ? null : azurerm_mssql_elasticpool.default["primary-${each.value.elastic_pool_name}"].id
  zone_redundant                 = each.value.sku_name == "Basic" || startswith(each.value.sku_name, "S") ? false : each.value.zone_redundant
  geo_backup_enabled             = each.value.geo_backup_enabled
  maintenance_configuration_name = each.value.elastic_pool_name != null ? null : each.value.maintenance_configuration_name
  create_mode                    = each.value.create_mode
  storage_account_type           = each.value.storage_account_type
  tags                           = local.tags

  #Serverless
  auto_pause_delay_in_minutes = strcontains(each.value.sku_name, "_S_") ? each.value.auto_pause_delay_in_minutes : null
  min_capacity                = strcontains(each.value.sku_name, "_S_") ? each.value.min_capacity : null

  transparent_data_encryption_enabled = each.value.transparent_data_encryption_enabled
  ledger_enabled                      = each.value.ledger_enabled
  creation_source_database_id         = each.value.creation_source_database_id

  read_scale                  = each.value.read_scale                  # Premium and Business Critical
  read_replica_count          = each.value.read_replica_count          # Hyperscale
  restore_point_in_time       = each.value.restore_point_in_time       # create_mode is PointInTimeRestore
  recover_database_id         = each.value.recover_database_id         # create_mode is Recovery
  restore_dropped_database_id = each.value.restore_dropped_database_id # create_mode is Restore

  dynamic "threat_detection_policy" {
    for_each = each.value.threat_detection_policy == null ? [] : [each.value.threat_detection_policy]
    content {
      state                      = threat_detection_policy.value.state
      disabled_alerts            = threat_detection_policy.value.disabled_alerts
      email_account_admins       = threat_detection_policy.value.email_account_admins
      email_addresses            = threat_detection_policy.value.email_addresses
      retention_days             = threat_detection_policy.value.retention_days
      storage_account_access_key = threat_detection_policy.value.storage_account_access_key
      storage_endpoint           = threat_detection_policy.value.storage_endpoint
    }
  }

  dynamic "short_term_retention_policy" {
    for_each = each.value.short_term_retention_policy == null ? [] : [each.value.short_term_retention_policy]
    content {
      retention_days           = short_term_retention_policy.value.retention_days
      backup_interval_in_hours = short_term_retention_policy.value.backup_interval_in_hours
    }
  }

  dynamic "long_term_retention_policy" {
    for_each = each.value.long_term_retention_policy == null ? [] : [each.value.long_term_retention_policy]
    content {
      weekly_retention  = long_term_retention_policy.value.weekly_retention
      monthly_retention = long_term_retention_policy.value.monthly_retention
      yearly_retention  = long_term_retention_policy.value.yearly_retention
      week_of_year      = long_term_retention_policy.value.week_of_year
    }
  }

  dynamic "import" {
    for_each = each.value.import == null ? [] : [each.value.import]
    content {
      storage_uri                  = import.value.storage_uri
      storage_key                  = import.value.storage_key
      storage_key_type             = import.value.storage_key_type
      administrator_login          = import.value.administrator_login
      administrator_login_password = import.value.administrator_login_password
      authentication_type          = import.value.authentication_type
      storage_account_id           = import.value.storage_account_id
    }
  }
}

# ###########
# # Failover Group
# ###########

resource "azurerm_mssql_failover_group" "default" {
  for_each                                  = var.failover_groups == null ? {} : { for key, value in var.failover_groups : value.name => value }
  name                                      = var.name_sufix_append ? "${each.key}-sqlfg" : each.key
  server_id                                 = azurerm_mssql_server.default["primary"].id
  databases                                 = [for db in each.value.database_names : azurerm_mssql_database.default[db].id]
  readonly_endpoint_failover_policy_enabled = each.value.readonly_endpoint_failover_policy_enabled
  tags                                      = local.tags

  partner_server {
    id = azurerm_mssql_server.default["secondary"].id
  }

  read_write_endpoint_failover_policy {
    mode          = each.value.read_write_endpoint_failover_policy.mode
    grace_minutes = each.value.read_write_endpoint_failover_policy.mode == "Automatic" ? each.value.read_write_endpoint_failover_policy.grace_minutes : null
  }
}

###########
# Auditing
###########

resource "azurerm_mssql_server_extended_auditing_policy" "default" {
  depends_on                              = [azurerm_mssql_outbound_firewall_rule.default]
  for_each                                = var.sql_server.auditing_policy == null ? {} : { for key, value in local.sql_servers : key => value }
  enabled                                 = true
  server_id                               = azurerm_mssql_server.default[each.key].id
  storage_endpoint                        = "https://${split("/", each.value.auditing_policy.storage_account_id)[8]}.blob.core.windows.net/"
  storage_account_access_key              = each.value.auditing_policy.storage_account_access_key
  storage_account_access_key_is_secondary = each.value.auditing_policy.storage_account_access_key_is_secondary
  log_monitoring_enabled                  = each.value.auditing_policy.log_monitoring_enabled
  storage_account_subscription_id         = each.value.auditing_policy.storage_account_subscription_id
  retention_in_days                       = each.value.auditing_policy.retention_in_days
}

resource "azurerm_role_assignment" "default" {
  for_each             = try(var.sql_server.auditing_policy.storage_account_assign_role, false) ? { for key, value in local.sql_servers : key => value } : {}
  scope                = var.sql_server.auditing_policy.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_mssql_server.default[each.key].identity[0].principal_id
}

#######
# Create private endpoint
#######

module "private-endpoint" {
  for_each            = { for key, value in local.sql_servers : key => value if var.private_endpoint != null }
  source              = "jsathler/private-endpoint/azurerm"
  version             = "0.0.2"
  resource_group_name = each.key == "primary" ? var.resource_group_name : each.value.secondary_server_resource_group_name
  location            = each.key == "primary" ? var.location : each.value.secondary_server_location
  name_sufix_append   = var.name_sufix_append
  tags                = local.tags

  private_endpoint = {
    name                           = each.key == "primary" ? var.private_endpoint.name : var.private_endpoint.secondary_server_name
    subnet_id                      = each.key == "primary" ? var.private_endpoint.subnet_id : var.private_endpoint.secondary_server_subnet_id
    private_connection_resource_id = azurerm_mssql_server.default[each.key].id
    subresource_name               = "sqlServer"
    application_security_group_ids = var.private_endpoint.application_security_group_ids
    private_dns_zone_id            = var.private_endpoint.private_dns_zone_id
  }
}
