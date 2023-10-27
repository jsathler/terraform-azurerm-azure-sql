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

module "sql" {
  source              = "../../"
  resource_group_name = azurerm_resource_group.default.name

  sql_server = {
    name                         = local.prefix
    administrator_login_password = random_password.default.result
  }

  elastic_pools = [
    { name = "genpurpose" },
    { name = "basic", per_database_settings = { max_capacity = 5 }, sku = { name = "BasicPool", capacity = 50, tier = "Basic" }, },
    { name = "standard", per_database_settings = { max_capacity = 100 }, sku = { name = "StandardPool", capacity = 100, tier = "Standard" } },
    { name = "premium", per_database_settings = { max_capacity = 125 }, sku = { name = "PremiumPool", capacity = 125, tier = "Premium" } }
  ]

  sql_databases = [
    { name = "elasticpool", elastic_pool_name = "genpurpose" },
    { name = "basic1", elastic_pool_name = "basic", sku_name = "Basic" },
    { name = "basic2", elastic_pool_name = "basic", sku_name = "Basic" },
    { name = "standard", elastic_pool_name = "standard", sku_name = "S0" },
    { name = "premium", elastic_pool_name = "premium", sku_name = "P1" }
  ]
}

output "sql" {
  value = module.sql
}

output "password" {
  value     = random_password.default.result
  sensitive = true
}
