## AddStorageAccountNetworkRule
- Utility Script to add Current IP to set of Azure Storage Accounts maintained in `StorageAccountList.json`

## Notes
- Install [Azure PowerShell module](https://learn.microsoft.com/en-us/powershell/azure/install-azure-powershell).
 - Connect to Azure with your account
 ```
 Connect-AzAccount
 ```
 - List of Azure Storage Accounts are maintained inside `StorageAccountList.json` in following format
```
[
    {
        "tenantId": "<Tenant Id 1>",
        "subscriptionId": "<Subscription Id 1>",
        "resourceGroupName": "<Resource Group Name 1>",
        "storageAccountName": "<Storage Account Name 1>"
    },
    {
        "tenantId": "<Tenant Id 2>",
        "subscriptionId": "<Subscription Id 2>",
        "resourceGroupName": "<Resource Group Name 2>",
        "storageAccountName": "<Storage Account Name 2>"
    }
]
```
## Troubleshooting

`WARNING: Unable to acquire token for tenant '<TenantId>' with error 'SharedTokenCacheCredential authentication unavailable. Token acquisition failed for user <User>. Ensure that you have authenticated with a developer tool that supports Azure single sign on`

```
 Clear-AzContext
 Connect-AzAccount
```