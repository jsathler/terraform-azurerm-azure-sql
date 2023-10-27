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
