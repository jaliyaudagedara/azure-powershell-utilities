# Description
#   Utility Script to add Current IP to set of Azure Storage Accounts (uses az CLI)

# Important Note: This script provided AS IS, please review the code before executing

. (Join-Path $PSScriptRoot ".." ".." "shared.ps1")

$currentIpAddress = Get-CurrentPublicIp
$previousIpAddress = Get-LastIp -ScriptRoot $PSScriptRoot
$json = Get-ResourcesJson -ScriptRoot $PSScriptRoot

# $hadFailure tracks real query/op failures only. Applicability skips (account
# in a state where IP rules don't apply) do NOT set it - we still want .last-ip
# to advance in that case so subsequent runs don't keep trying to clean up the
# same previous IP on resources that ignore IP rules.
$hadFailure = $false

# Helper: best-effort cleanup of $previousIpAddress on a skipped resource.
# Returns $true on success/no-op, $false on a real failure - callers must set
# $hadFailure on $false so .last-ip doesn't advance past an un-cleaned entry.
function Remove-StalePreviousIpFromStorage {
    param($ResourceGroupName, $StorageAccountName, $PreviousIp, $IpRules)
    if (-not $PreviousIp) { return $true }
    if (-not ($IpRules | Where-Object { $_.ipAddressOrRange -eq $PreviousIp })) { return $true }
    Write-Host "    Cleaning up stale previous IP '$($PreviousIp)'."
    az storage account network-rule remove --resource-group $ResourceGroupName `
        --account-name $StorageAccountName `
        --ip-address $PreviousIp `
        --only-show-errors | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    ERR | Failed to clean up stale IP."
        return $false
    }
    return $true
}

foreach ($sub in $json) {
    $currentAzAccount = Switch-AzSubscriptionContext -TenantId $sub.tenantId -SubscriptionId $sub.subscriptionId
    if ($null -eq $currentAzAccount) {
        # Real failure - block .last-ip update so we retry next run.
        $hadFailure = $true
        continue
    }

    foreach ($rg in $sub.resources) {
        Write-Host "ResourceGroup '$($rg.resourceGroupName)':"

        foreach ($storageAccountName in $rg.storageAccounts) {
            Write-Host "  Storage Account '$($storageAccountName)':"

            $storageAccount = az storage account show --resource-group $rg.resourceGroupName --name $storageAccountName --only-show-errors -o json | ConvertFrom-Json
            if ($null -eq $storageAccount) {
                Write-Host "    Could not query Storage Account, skipping."
                # Real failure - block .last-ip update so we retry next run.
                $hadFailure = $true
                continue
            }

            if ($storageAccount.publicNetworkAccess -eq 'Disabled') {
                Write-Host "    Public network access is Disabled (IP rules have no effect)."
                if ($previousIpAddress -and $previousIpAddress -ne $currentIpAddress) {
                    $cleanupOk = Remove-StalePreviousIpFromStorage `
                        -ResourceGroupName $rg.resourceGroupName `
                        -StorageAccountName $storageAccountName `
                        -PreviousIp $previousIpAddress `
                        -IpRules $storageAccount.networkRuleSet.ipRules
                    if (-not $cleanupOk) { $hadFailure = $true }
                }
                continue
            }

            $defaultAction = $storageAccount.networkRuleSet.defaultAction
            if (-not $defaultAction -or $defaultAction -eq 'Allow') {
                Write-Host "    Network defaultAction is Allow / not configured (no IP restrictions enabled)."
                if ($previousIpAddress -and $previousIpAddress -ne $currentIpAddress) {
                    $cleanupOk = Remove-StalePreviousIpFromStorage `
                        -ResourceGroupName $rg.resourceGroupName `
                        -StorageAccountName $storageAccountName `
                        -PreviousIp $previousIpAddress `
                        -IpRules $storageAccount.networkRuleSet.ipRules
                    if (-not $cleanupOk) { $hadFailure = $true }
                }
                continue
            }

            $existingIps = @($storageAccount.networkRuleSet.ipRules | ForEach-Object { $_.ipAddressOrRange })

            if ($previousIpAddress -and $previousIpAddress -ne $currentIpAddress -and $existingIps -contains $previousIpAddress) {
                Write-Host "    Removing previous IP '$($previousIpAddress)'."
                az storage account network-rule remove --resource-group $rg.resourceGroupName `
                    --account-name $storageAccountName `
                    --ip-address $previousIpAddress `
                    --only-show-errors | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "    ERR | Failed to remove previous IP."
                    $hadFailure = $true
                }
            }

            if ($existingIps -contains $currentIpAddress) {
                Write-Host "    Current IP '$($currentIpAddress)' already present (name/comment 'NOT APPLICABLE'); skipping."
                continue
            }

            Write-Host "    Adding IP '$($currentIpAddress)'."
            az storage account network-rule add --resource-group $rg.resourceGroupName `
                --account-name $storageAccountName `
                --ip-address $currentIpAddress `
                --only-show-errors | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "    ERR | Failed to add IP."
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
