# Description
#   Utility Script to remove the IP recorded in .last-ip (in this folder) from set of Azure Storage Accounts (uses az CLI)

# Important Note: This script provided AS IS, please review the code before executing

. (Join-Path $PSScriptRoot ".." ".." "shared.ps1")

$ipAddressToRemove = Get-LastIp -ScriptRoot $PSScriptRoot
if (-not $ipAddressToRemove) {
    Write-Warning "'.last-ip' not found or empty. Nothing to remove."
    return
}

$json = Get-ResourcesJson -ScriptRoot $PSScriptRoot

foreach ($sub in $json) {
    $currentAzAccount = Switch-AzSubscriptionContext -TenantId $sub.tenantId -SubscriptionId $sub.subscriptionId
    if ($null -eq $currentAzAccount) { continue }

    foreach ($rg in $sub.resources) {
        Write-Host "ResourceGroup '$($rg.resourceGroupName)':"

        foreach ($storageAccountName in $rg.storageAccounts) {
            Write-Host "  Storage Account '$($storageAccountName)':"

            $storageAccount = az storage account show --resource-group $rg.resourceGroupName --name $storageAccountName --only-show-errors -o json | ConvertFrom-Json
            if ($null -eq $storageAccount) {
                Write-Host "    Could not query Storage Account, skipping."
                continue
            }

            $existingIps = @($storageAccount.networkRuleSet.ipRules | ForEach-Object { $_.ipAddressOrRange })
            if ($existingIps -notcontains $ipAddressToRemove) {
                Write-Host "    IP '$($ipAddressToRemove)' not present, skipping."
                continue
            }

            Write-Host "    Removing IP '$($ipAddressToRemove)'."
            az storage account network-rule remove --resource-group $rg.resourceGroupName `
                --account-name $storageAccountName `
                --ip-address $ipAddressToRemove `
                --only-show-errors | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "    ERR | Failed to remove IP."
            }
        }
    }
}
