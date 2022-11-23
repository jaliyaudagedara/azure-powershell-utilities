## AddSqlServerFirewallRule
- Utility Script to add Current IP to set of Azure SQL Servers maintained in `SqlServerList.json`


## RemoveSqlServerFirewallRule
- Utility Script to remove a given FirewallRuleName from set of Azure SQL Servers maintained in `SqlServerList.json`

## Notes
- Install [Azure PowerShell module](https://docs.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-8.2.0).
 - Connect to Azure with your account
 ```
 Connect-AzAccount
 ```
 - List of Azure SQL Servers are maintained inside `SqlServerList.json` in following format
```
[
    {
        "tenantId": "<Tenant Id 1>",
        "subscriptionId": "<Subscription Id 1>",
        "resourceGroupName": "<Resource Group Name 1>",
        "sqlServerName": "<SQL Server Name 1>"
    },
    {
        "tenantId": "<Tenant Id 2>",
        "subscriptionId": "<Subscription Id 2>",
        "resourceGroupName": "<Resource Group Name 2>",
        "sqlServerName": "<SQL Server Name 2>"
    }
]
```
## Troubleshooting

`WARNING: Unable to acquire token for tenant '<TenantId>' with error 'SharedTokenCacheCredential authentication unavailable. Token acquisition failed for user <User>. Ensure that you have authenticated with a developer tool that supports Azure single sign on`

```
 Clear-AzContext
 Connect-AzAccount
```