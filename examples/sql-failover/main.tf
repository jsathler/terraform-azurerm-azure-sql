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

resource "random_password" "default" {
  length = 21
}

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

module "pri-vnet" {
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

module "sec-vnet" {
  source              = "jsathler/network/azurerm"
  version             = "0.0.2"
  name                = "${local.prefix}-sec"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.default.name
  address_space       = ["10.1.0.0/16"]

  subnets = {
    default = {
      address_prefixes   = ["10.1.0.0/24"]
      nsg_create_default = false
      service_endpoints  = ["Microsoft.Sql"]
    }
  }
}

module "sql" {
  source              = "../../"
  resource_group_name = azurerm_resource_group.default.name

  sql_server = {
    name                          = local.prefix
    administrator_login_password  = random_password.default.result
    public_network_access_enabled = true
    #We can't use "azurerm_storage_account.default.primary_blob_host" because its value is unknown until apply
    outbound_fqdns                       = ["${azurerm_storage_account.default.name}.blob.core.windows.net"]
    secondary_server_name                = "${local.prefix}-sec"
    secondary_server_resource_group_name = azurerm_resource_group.default.name

    vnet_rules = [
      { name = "default-snet", subnet_id = module.pri-vnet.subnet_ids["default-snet"] },
      { name = "default-snet", subnet_id = module.sec-vnet.subnet_ids["default-snet"], secondary = true }
    ]

    firewall_rules = [{ name = "my-ip", start_ip_address = chomp(data.http.myip.response_body), end_ip_address = chomp(data.http.myip.response_body) }]

    auditing_policy = {
      storage_account_id          = azurerm_storage_account.default.id
      storage_account_assign_role = true
    }
  }

  /*
  To create a failover for a DB in elastic pool, you need a elastic pool with same name on secondary server
  'failover = true' defines if the elastic pool should be created on both servers
  */
  elastic_pools = [
    { name     = "basic", per_database_settings = { max_capacity = 5 }
      sku      = { name = "BasicPool", capacity = 50, tier = "Basic" }
      failover = true
    },
    { name     = "standard", per_database_settings = { max_capacity = 100 }
      sku      = { name = "StandardPool", capacity = 100, tier = "Standard" }
      failover = true
    }
  ]

  sql_databases = [
    { name = "basic1", elastic_pool_name = "basic", sku_name = "Basic" },
    { name = "basic2", sku_name = "Basic" },
    { name = "standard1", elastic_pool_name = "standard", sku_name = "S0" },
    { name = "standard2", sku_name = "S0" },
    { name = "standard3", sku_name = "S0" }
  ]

  failover_groups = [
    { name = "${local.prefix}-failover-1", database_names = ["basic1", "basic2"] },
    { name = "${local.prefix}-failover-2", database_names = ["standard1", "standard3"]
      read_write_endpoint_failover_policy = {
        mode          = "Manual"
        grace_minutes = 120
      }
    }
  ]
}

output "sql" {
  value = module.sql
}

output "pri-vnet" {
  value = module.pri-vnet
}

output "sec-vnet" {
  value = module.sec-vnet
}

output "password" {
  value     = random_password.default.result
  sensitive = true
}
