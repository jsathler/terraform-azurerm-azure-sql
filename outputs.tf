output "servers" {
  value = { for key, value in azurerm_mssql_server.default : key => {
    name                                 = value.name
    id                                   = value.id
    fqdn                                 = value.fully_qualified_domain_name
    public_network_access_enabled        = value.public_network_access_enabled
    outbound_network_restriction_enabled = value.outbound_network_restriction_enabled
    }
  }
}

output "databases" {
  value = { for key, value in azurerm_mssql_database.default : value.name => value.id }
}

output "elastic_pools" {
  value = { for key, value in azurerm_mssql_elasticpool.default : value.server_name => {
    name = value.name
    id   = value.id
    }...
  }
}

output "failover_groups" {
  value = { for key, value in azurerm_mssql_failover_group.default : value.name => value.id }
}
