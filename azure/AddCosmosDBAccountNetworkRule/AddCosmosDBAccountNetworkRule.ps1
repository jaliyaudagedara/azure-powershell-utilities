# Description
#   Utility Script to add Current IP to set of Azure Cosmos DB Accounts (uses az CLI)

# Important Note: This script provided AS IS, please review the code before executing

. (Join-Path $PSScriptRoot ".." ".." "shared.ps1")

$currentIpAddress = Get-CurrentPublicIp
$previousIpAddress = Get-LastIp -ScriptRoot $PSScriptRoot
$json = Get-ResourcesJson -ScriptRoot $PSScriptRoot

# $hadFailure tracks real query/op failures only. Applicability skips (account
# in a state where IP rules don't apply) do NOT set it — we still want .last-ip
# to advance in that case so subsequent runs don't keep trying to clean up the
# same previous IP on resources that ignore IP rules.
$hadFailure = $false

foreach ($sub in $json) {
    $currentAzAccount = Switch-AzSubscriptionContext -TenantId $sub.tenantId -SubscriptionId $sub.subscriptionId
    if ($null -eq $currentAzAccount) {
        # Real failure — block .last-ip update so we retry next run.
        $hadFailure = $true
        continue
    }

    foreach ($rg in $sub.resources) {
        Write-Host "ResourceGroup '$($rg.resourceGroupName)':"

        foreach ($cosmosDbAccountName in $rg.cosmosDbAccounts) {
            Write-Host "  Cosmos DB Account '$($cosmosDbAccountName)':"

            $account = az cosmosdb show --resource-group $rg.resourceGroupName --name $cosmosDbAccountName --only-show-errors -o json | ConvertFrom-Json
            if ($null -eq $account) {
                Write-Host "    Could not query account, skipping."
                # Real failure — block .last-ip update so we retry next run.
                $hadFailure = $true
                continue
            }

            # ipRules may contain bare IPs or CIDR ranges; normalize single-IP /32 entries
            # to bare IPs so comparisons match what we write back.
            $existingIps = @($account.ipRules | ForEach-Object {
                    if ($_.ipAddressOrRange) { $_.ipAddressOrRange -replace '/32$', '' }
                })

            if ($account.publicNetworkAccess -eq 'Disabled') {
                Write-Host "    Public network access is Disabled (ipRules have no effect)."
                # Best-effort cleanup of a stale previous IP entry that won't ever be acted on
                # again once .last-ip advances past it.
                if ($previousIpAddress -and $previousIpAddress -ne $currentIpAddress -and $existingIps -contains $previousIpAddress) {
                    $desiredIps = @($existingIps | Where-Object { $_ -ne $previousIpAddress })
                    if ($desiredIps.Count -gt 0) {
                        Write-Host "    Cleaning up stale previous IP '$($previousIpAddress)'."
                        az cosmosdb update --resource-group $rg.resourceGroupName `
                            --name $cosmosDbAccountName `
                            --ip-range-filter ($desiredIps -join ',') `
                            --only-show-errors | Out-Null
                        if ($LASTEXITCODE -ne 0) {
                            Write-Host "    ERR | Failed to clean up stale IP (continuing)."
                            $hadFailure = $true
                        }
                    } else {
                        Write-Host "    Stale previous IP '$($previousIpAddress)' is the only ipRule; leaving it (won't clear all ipRules)."
                    }
                }
                continue
            }

            # An account with no IP and no VNet rules is fully open. Adding our IP would
            # switch it from open to restricted and lock everyone else out. Skip.
            $hasVnetRules = @($account.virtualNetworkRules).Count -gt 0
            if ($existingIps.Count -eq 0 -and -not $hasVnetRules) {
                Write-Host "    No ipRules or virtualNetworkRules configured (account is open); skipping to avoid switching from open to restricted."
                continue
            }

            $desiredIps = $existingIps
            if ($previousIpAddress -and $previousIpAddress -ne $currentIpAddress) {
                $desiredIps = @($desiredIps | Where-Object { $_ -ne $previousIpAddress })
            }
            if ($desiredIps -notcontains $currentIpAddress) {
                $desiredIps = @($desiredIps) + $currentIpAddress
            }

            $existingSorted = (@($existingIps) | Sort-Object) -join ','
            $desiredSorted = (@($desiredIps) | Sort-Object) -join ','
            if ($existingSorted -eq $desiredSorted) {
                Write-Host "    Current IP '$($currentIpAddress)' already present (name/comment 'NOT APPLICABLE'); skipping."
                continue
            }

            $ipRangeFilter = ($desiredIps -join ',')

            Write-Host "    Updating IP rules (current IP '$($currentIpAddress)')."
            az cosmosdb update --resource-group $rg.resourceGroupName `
                --name $cosmosDbAccountName `
                --ip-range-filter $ipRangeFilter `
                --only-show-errors | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "    ERR | Failed to update ipRules."
                $hadFailure = $true
            }
        }
    }
}

# Only persist current IP if every operation succeeded. Otherwise the .last-ip
# pointer would lose track of stale entries still on at least one account.
if ($hadFailure) {
    Write-Warning "Some operations failed. '.last-ip' was NOT updated; re-run after fixing the cause."
} else {
    Set-LastIp -ScriptRoot $PSScriptRoot -IpAddress $currentIpAddress
}
