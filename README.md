<!-- BEGIN_TF_DOCS -->
# Azure SQL Terraform module

Terraform module which creates Azure SQL resources on Azure.

Supported Azure services:

* [Azure SQL](https://learn.microsoft.com/en-us/azure/azure-sql/azure-sql-iaas-vs-paas-what-is-overview?view=azuresql)
* [Azure SQL Logic Server](https://learn.microsoft.com/en-us/azure/azure-sql/database/logical-servers?view=azuresql&tabs=portal)
* [Azure SQL Database](https://learn.microsoft.com/en-us/azure/azure-sql/database/sql-database-paas-overview?view=azuresql)
* [Azure SQL elastic pools](https://learn.microsoft.com/en-us/azure/azure-sql/database/elastic-pool-overview?view=azuresql)
* [Azure SQL Failover](https://learn.microsoft.com/en-us/azure/azure-sql/database/auto-failover-group-sql-db)
* [Azure SQL Automated Backup](https://learn.microsoft.com/en-us/azure/azure-sql/database/automated-backups-overview?view=azuresql)
* [Azure SQL Server Auditing](https://learn.microsoft.com/en-us/azure/azure-sql/database/auditing-setup?view=azuresql#configure-auditing-for-your-server)

## SQL SKUs
* [DB vCore Model](https://learn.microsoft.com/en-us/azure/azure-sql/database/resource-limits-vcore-single-databases?view=azuresql)
* [DB DTU model](https://learn.microsoft.com/en-us/azure/azure-sql/database/resource-limits-dtu-single-databases?view=azuresql)
* [Elastic Pool vCore Model](https://learn.microsoft.com/en-us/azure/azure-sql/database/resource-limits-vcore-elastic-pools?view=azuresql)
* [Elastic Pool DTU model](https://learn.microsoft.com/en-us/azure/azure-sql/database/resource-limits-dtu-elastic-pools?view=azuresql)

## Notes

This module supports creating an Azure SQL Failover, but:
 - If your DB is allocated inside an Elastic Pool on primary server, you need an "identical" Elastic Pool on secondary server. This can be achieved setting the "failover = true" on your Elastic Pool
 - DBs are created ONLY on primary servers and then replicated to secondary (if defined in var.failover_groups.database_names)
 - When you run terraform destroy, DBs on secondary servers are not destroyed (this is by Azure design). You will need to delete these DBs manually

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.6 |
| <a name="requirement_azapi"></a> [azapi](#requirement\_azapi) | >= 1.9.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 3.70.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | >= 3.70.0 |

## Resources

| Name | Type |
|------|------|
| [azurerm_mssql_database.default](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/mssql_database) | resource |
| [azurerm_mssql_elasticpool.default](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/mssql_elasticpool) | resource |
| [azurerm_mssql_failover_group.default](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/mssql_failover_group) | resource |
| [azurerm_mssql_firewall_rule.default](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/mssql_firewall_rule) | resource |
| [azurerm_mssql_outbound_firewall_rule.default](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/mssql_outbound_firewall_rule) | resource |
| [azurerm_mssql_server.default](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/mssql_server) | resource |
| [azurerm_mssql_server_extended_auditing_policy.default](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/mssql_server_extended_auditing_policy) | resource |
| [azurerm_mssql_virtual_network_rule.default](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/mssql_virtual_network_rule) | resource |
| [azurerm_role_assignment.default](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_elastic_pools"></a> [elastic\_pools](#input\_elastic\_pools) | n/a | <pre>list(object({<br>    name                           = string<br>    maintenance_configuration_name = optional(string, "SQL_Default")<br>    max_size_gb                    = optional(number, 50)<br>    zone_redundant                 = optional(bool, true)<br>    license_type                   = optional(string, "BasePrice")<br>    failover                       = optional(bool, false)<br><br>    sku = optional(object({<br>      name     = optional(string, "GP_Gen5")<br>      capacity = optional(number, 2)<br>      tier     = optional(string, "GeneralPurpose")<br>      family   = optional(string, "Gen5")<br>    }), {})<br><br>    per_database_settings = optional(object({<br>      min_capacity = optional(number, 0)<br>      max_capacity = optional(number, 2)<br>    }), {})<br>  }))</pre> | `null` | no |
| <a name="input_failover_groups"></a> [failover\_groups](#input\_failover\_groups) | n/a | <pre>list(object({<br>    name                                      = string<br>    database_names                            = list(string)<br>    readonly_endpoint_failover_policy_enabled = optional(bool, false)<br><br>    read_write_endpoint_failover_policy = optional(object({<br>      mode          = optional(string, "Automatic")<br>      grace_minutes = optional(number, 60)<br>    }), {})<br>  }))</pre> | `null` | no |
| <a name="input_location"></a> [location](#input\_location) | The region where the Data Factory will be created. This parameter is required | `string` | `"northeurope"` | no |
| <a name="input_name_sufix_append"></a> [name\_sufix\_append](#input\_name\_sufix\_append) | Define if all resources names should be appended with sufixes according to https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations. | `bool` | `true` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | The name of the resource group in which the resources will be created. This parameter is required | `string` | n/a | yes |
| <a name="input_sql_databases"></a> [sql\_databases](#input\_sql\_databases) | n/a | <pre>list(object({<br>    name                                = string<br>    collation                           = optional(string, "SQL_Latin1_General_CP1_CI_AS")<br>    license_type                        = optional(string, "BasePrice")<br>    max_size_gb                         = optional(number, 50)<br>    sku_name                            = optional(string, "GP_Gen5_2") #https://learn.microsoft.com/en-us/azure/azure-sql/database/resource-limits-vcore-single-databases?view=azuresql<br>    zone_redundant                      = optional(bool, true)<br>    elastic_pool_name                   = optional(string, null)<br>    maintenance_configuration_name      = optional(string, "SQL_Default")<br>    create_mode                         = optional(string, null)<br>    geo_backup_enabled                  = optional(bool, true)<br>    storage_account_type                = optional(string, "Geo")<br>    auto_pause_delay_in_minutes         = optional(number, 60)<br>    min_capacity                        = optional(number, 0.5)<br>    transparent_data_encryption_enabled = optional(bool, true)<br>    ledger_enabled                      = optional(bool, false)<br>    creation_source_database_id         = optional(string, null)<br>    job_agent_name                      = optional(string, null)<br><br>    read_scale                  = optional(bool, false)<br>    read_replica_count          = optional(number, null)<br>    restore_point_in_time       = optional(string, null)<br>    recover_database_id         = optional(string, null)<br>    restore_dropped_database_id = optional(string, null)<br><br>    threat_detection_policy = optional(object({<br>      state                      = optional(string, null)<br>      disabled_alerts            = optional(string, null)<br>      email_account_admins       = optional(string, null)<br>      email_addresses            = optional(string, null)<br>      retention_days             = optional(number, 31)<br>      storage_account_access_key = optional(string, null)<br>      storage_endpoint           = optional(string, null)<br>    }), null)<br><br>    short_term_retention_policy = optional(object({<br>      retention_days           = optional(number, 7)  #between 7 - 35<br>      backup_interval_in_hours = optional(number, 24) #12 or 24<br>    }), {})<br><br>    long_term_retention_policy = optional(object({<br>      weekly_retention  = optional(string, "P4W")<br>      monthly_retention = optional(string, "P12M")<br>      yearly_retention  = optional(string, "P5Y")<br>      week_of_year      = optional(number, 1)<br>    }), null)<br><br>    import = optional(object({<br>      storage_uri                  = string<br>      storage_key                  = string<br>      storage_key_type             = optional(string, "StorageAccessKey")<br>      administrator_login          = string<br>      administrator_login_password = string<br>      authentication_type          = optional(string, "SQL")<br>      storage_account_id           = optional(string, null)<br>    }), null)<br>  }))</pre> | `null` | no |
| <a name="input_sql_server"></a> [sql\_server](#input\_sql\_server) | n/a | <pre>object({<br>    name                                         = string<br>    version                                      = optional(string, "12.0")<br>    administrator_login                          = optional(string, "localadmin")<br>    administrator_login_password                 = optional(string, null)<br>    connection_policy                            = optional(string, "Default")<br>    transparent_data_encryption_key_vault_key_id = optional(string, null)<br>    minimum_tls_version                          = optional(string, "1.2")<br>    allow_azure_services                         = optional(bool, false)<br>    public_network_access_enabled                = optional(bool, false)<br>    outbound_fqdns                               = optional(list(string), [])<br>    secondary_server_name                        = optional(string, null)<br>    secondary_server_resource_group_name         = optional(string, null)<br>    secondary_server_location                    = optional(string, "westeurope")<br>    primary_user_assigned_identity_id            = optional(string, null)<br><br>    identity = optional(object({<br>      type         = optional(string, "SystemAssigned")<br>      identity_ids = optional(list(string), null)<br>    }), {})<br><br>    entra_id = optional(object({<br>      login_username              = string<br>      object_id                   = string<br>      tenant_id                   = string<br>      azuread_authentication_only = optional(bool, true)<br>    }), null)<br><br>    firewall_rules = optional(list(object({<br>      name             = string<br>      start_ip_address = string<br>      end_ip_address   = string<br>    })), null)<br><br>    vnet_rules = optional(list(object({<br>      name                                 = string<br>      subnet_id                            = string<br>      ignore_missing_vnet_service_endpoint = optional(bool, false)<br>      secondary                            = optional(bool, false)<br>    })), null)<br><br>    auditing_policy = optional(object({<br>      storage_account_id                      = string<br>      storage_account_assign_role             = optional(bool, false)<br>      storage_account_access_key              = optional(string, null)<br>      storage_account_access_key_is_secondary = optional(bool, false)<br>      log_monitoring_enabled                  = optional(bool, true)<br>      storage_account_subscription_id         = optional(string, null)<br>      retention_in_days                       = optional(number, 31)<br>      #actions_and_groups                      = optional(list(string), ["BATCH_COMPLETED_GROUP", "SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP", "FAILED_DATABASE_AUTHENTICATION_GROUP", "APPLICATION_ROLE_CHANGE_PASSWORD_GROUP"])<br>      #predicate_expression                    = optional(string, "*")<br>    }), null)<br>  })</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to be applied to resources. | `map(string)` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_databases"></a> [databases](#output\_databases) | n/a |
| <a name="output_elastic_pools"></a> [elastic\_pools](#output\_elastic\_pools) | n/a |
| <a name="output_failover_groups"></a> [failover\_groups](#output\_failover\_groups) | n/a |
| <a name="output_servers"></a> [servers](#output\_servers) | n/a |

## Examples
```hcl
module "sql" {
  source              = "jsathler/azure-sql/azurerm"
  resource_group_name = azurerm_resource_group.default.name
  location            = azurerm_resource_group.default.location

  sql_server = {
    name                          = local.prefix
    public_network_access_enabled = true
    allow_azure_services          = true

    firewall_rules = [{ name = "my-ip", start_ip_address = chomp(data.http.myip.response_body), end_ip_address = chomp(data.http.myip.response_body) }]

    vnet_rules = [{ name = "default-snet", subnet_id = module.vnet.subnet_ids["default-snet"] }]

    entra_id = {
      login_username = "SQL Admin"
      object_id      = data.azurerm_client_config.default.object_id
      tenant_id      = data.azurerm_client_config.default.tenant_id
    }

    auditing_policy = {
      storage_account_id          = azurerm_storage_account.default.id
      storage_account_assign_role = true
    }
  }

  sql_databases = [
    { name = "genpurpose", short_term_retention_policy = { retention_days = 35 }, long_term_retention_policy = {} },
    { name = "serverless", sku_name = "GP_S_Gen5_2" },
    { name = "basic", sku_name = "Basic" },
    { name = "standard", sku_name = "S0" },
    { name = "premium", sku_name = "P1" }
  ]
}
```
More examples in ./examples folder
<!-- END_TF_DOCS -->