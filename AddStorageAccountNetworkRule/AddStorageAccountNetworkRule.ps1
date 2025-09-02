# Description
#   Utility Script to add Current IP to set of Azure Storage Accounts

# Important Note: This script provided AS IS, please review the code before executing

$currentIpAddress = (Invoke-WebRequest myexternalip.com/raw).content

$json = Get-Content -Raw StorageAccountList.json | ConvertFrom-Json

foreach ($item in $json) {
    $currentAzContext = Get-AzContext

    if (($currentAzContext.Tenant.Id -ne $item.tenantId) -or ($currentAzContext.Subscription.Id -ne $item.subscriptionId)) {
        Write-Host "INF | Switching AzContext: TenantId: '$($item.tenantId)', SubscriptionId: '$($item.subscriptionId)'."
        $currentAzContext = Set-AzContext -TenantId $item.tenantId -SubscriptionId $item.subscriptionId
    }

    if ($currentAzContext.Subscription.State -eq 'Disabled') {
        Write-Host "WARN | SubscriptionId: '$($item.subscriptionId)' is Disabled. Skippig adding Firewall Rule to Storage Account: '$($item.storageAccountName)'."
        continue
    }
    
    Write-Host "INF | Adding IP: '$($currentIpAddress)' to Storage Account: '$($item.storageAccountName)'."
    Add-AzStorageAccountNetworkRule -ResourceGroupName $item.resourceGroupName `
        -Name $item.storageAccountName `
        -IPAddress $currentIpAddress
}