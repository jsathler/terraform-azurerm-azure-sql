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

resource "azurerm_application_security_group" "default" {
  name                = "${local.prefix}-asg"
  resource_group_name = azurerm_resource_group.default.name
  location            = azurerm_resource_group.default.location
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

module "private-zone" {
  source              = "jsathler/dns-zone/azurerm"
  version             = "0.0.1"
  resource_group_name = azurerm_resource_group.default.name
  zones = {
    "privatelink.database.windows.net" = {
      private = true
      vnets = {
        "${basename(path.cwd)}-vnet" = { id = module.vnet.vnet_id }
      }
    }
  }
}

module "sql" {
  source              = "../../"
  resource_group_name = azurerm_resource_group.default.name
  location            = azurerm_resource_group.default.location

  sql_server = {
    name                         = local.prefix
    administrator_login_password = random_password.default.result
  }

  private_endpoint = {
    name                           = "${local.prefix}-sqlserver"
    subnet_id                      = module.vnet.subnet_ids.default-snet
    application_security_group_ids = [azurerm_application_security_group.default.id]
    private_dns_zone_id            = module.private-zone.private_zone_ids["privatelink.database.windows.net"]
  }
}

output "sql" {
  value = module.sql
}

output "vnet" {
  value = module.vnet
}
