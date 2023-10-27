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
