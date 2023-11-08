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

module "private-zone" {
  source              = "jsathler/dns-zone/azurerm"
  version             = "0.0.1"
  resource_group_name = azurerm_resource_group.default.name
  zones = {
    "privatelink.database.windows.net" = {
      private = true
      vnets = {
        "${local.prefix}"     = { id = module.pri-vnet.vnet_id }
        "${local.prefix}-sec" = { id = module.sec-vnet.vnet_id }
      }
    }
  }
}

module "sql" {
  source              = "../../"
  resource_group_name = azurerm_resource_group.default.name

  sql_server = {
    name                                 = local.prefix
    administrator_login_password         = random_password.default.result
    secondary_server_name                = "${local.prefix}-sec"
    secondary_server_resource_group_name = azurerm_resource_group.default.name
  }

  private_endpoint = {
    name                       = "${local.prefix}-sqlserver"
    subnet_id                  = module.pri-vnet.subnet_ids["default-snet"]
    secondary_server_name      = "${local.prefix}-sec-sqlserver"
    secondary_server_subnet_id = module.sec-vnet.subnet_ids["default-snet"]
    private_dns_zone_id        = module.private-zone.private_zone_ids["privatelink.database.windows.net"]
  }
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
