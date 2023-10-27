locals {
  prefix = "${basename(path.cwd)}-example"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "default" {
  name     = "${local.prefix}-rg"
  location = "northeurope"
}

data "azurerm_client_config" "default" {}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

resource "azurerm_storage_account" "default" {
  name                     = "${lower(replace(local.prefix, "/[^A-Za-z0-9]/", ""))}st"
  location                 = azurerm_resource_group.default.location
  resource_group_name      = azurerm_resource_group.default.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

module "vnet" {
  source              = "jsathler/network/azurerm"
  version             = "0.0.2"
  name                = local.prefix
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  address_space       = ["10.0.0.0/16"]

  subnets = {
    default = {
      address_prefixes   = ["10.0.0.0/24"]
      nsg_create_default = false
      service_endpoints  = ["Microsoft.Sql"]
    }
  }
}

module "sql" {
  source              = "../../"
  resource_group_name = azurerm_resource_group.default.name
  location            = azurerm_resource_group.default.location

  sql_server = {
    name                          = local.prefix
    public_network_access_enabled = true
    allow_azure_services          = true
    #We can't use "azurerm_storage_account.default.primary_blob_host" because its value is unknown until apply
    outbound_fqdns = ["hostname1.fqdn.com", "hostname2.fqdn.com", "${azurerm_storage_account.default.name}.blob.core.windows.net"]

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

output "sql" {
  value = module.sql
}

output "vnet" {
  value = module.vnet
}
