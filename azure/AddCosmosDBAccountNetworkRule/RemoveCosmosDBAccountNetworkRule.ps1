# Description
#   Utility Script to remove the IP recorded in .last-ip (in this folder) from set of Azure Cosmos DB Accounts (uses az CLI)

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

        foreach ($cosmosDbAccountName in $rg.cosmosDbAccounts) {
            Write-Host "  Cosmos DB Account '$($cosmosDbAccountName)':"

            $account = az cosmosdb show --resource-group $rg.resourceGroupName --name $cosmosDbAccountName --only-show-errors -o json | ConvertFrom-Json
            if ($null -eq $account) {
                Write-Host "    Could not query account, skipping."
                continue
            }

            # Normalize single-IP /32 entries to bare IPs for comparison against .last-ip.
            $existingIps = @($account.ipRules | ForEach-Object {
                    if ($_.ipAddressOrRange) { $_.ipAddressOrRange -replace '/32$', '' }
                })
            if ($existingIps -notcontains $ipAddressToRemove) {
                Write-Host "    IP '$($ipAddressToRemove)' not present, skipping."
                continue
            }

            $desiredIps = @($existingIps | Where-Object { $_ -ne $ipAddressToRemove })
            # Refuse to clear the last IP rule. An empty --ip-range-filter wipes all
            # IP restrictions, which materially changes the account's exposure.
            if ($desiredIps.Count -eq 0) {
                Write-Host "    Removing this IP would clear all ipRules (would broaden access), skipping. Remove manually if intentional."
                continue
            }

            $ipRangeFilter = ($desiredIps -join ',')

            Write-Host "    Removing IP '$($ipAddressToRemove)'."
            az cosmosdb update --resource-group $rg.resourceGroupName `
                --name $cosmosDbAccountName `
                --ip-range-filter $ipRangeFilter `
                --only-show-errors | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "    ERR | Failed to update ipRules."
            }
        }
    }
}
