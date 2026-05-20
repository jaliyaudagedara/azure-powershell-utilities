# Description
#   Utility Script to add Current IP to set of Azure App Services (uses az CLI)

# Important Note: This script provided AS IS, please review the code before executing

. (Join-Path $PSScriptRoot ".." ".." "shared.ps1")

# Replace with your own name/identifier; this is used as the access restriction rule name.
$accessRestrictionRuleName = "JaliyaUdagedara"

$currentIpAddress = Get-CurrentPublicIp
$json = Get-ResourcesJson -ScriptRoot $PSScriptRoot

foreach ($sub in $json) {
    $currentAzAccount = Switch-AzSubscriptionContext -TenantId $sub.tenantId -SubscriptionId $sub.subscriptionId
    if ($null -eq $currentAzAccount) { continue }

    foreach ($rg in $sub.resources) {
        Write-Host "ResourceGroup '$($rg.resourceGroupName)':"

        foreach ($appServiceName in $rg.appServices) {
            Write-Host "  App Service '$($appServiceName)':"

            $accessRestrictions = az webapp config access-restriction show --resource-group $rg.resourceGroupName --name $appServiceName --only-show-errors -o json | ConvertFrom-Json
            if ($null -eq $accessRestrictions) {
                Write-Host "    Could not query Access Restrictions, skipping."
                continue
            }

            $allRestrictionRules = @($accessRestrictions.ipSecurityRestrictions)
            # Filter out both implicit default rules ('Allow all' / 'Deny all' at the sentinel priority).
            $customRules = @($allRestrictionRules | Where-Object {
                    -not (($_.name -in 'Allow all', 'Deny all') -and $_.ipAddress -eq 'Any' -and $_.priority -eq 2147483647)
                })
            if ($customRules.Count -eq 0) {
                Write-Host "    No Network restrictions enabled, skipping."
                continue
            }

            # Azure stores a single IP as /32 CIDR.
            $currentIpCidr = "$currentIpAddress/32"
            if ($allRestrictionRules | Where-Object { $_.ipAddress -eq $currentIpCidr }) {
                Write-Host "    Current IP '$($currentIpAddress)' already present (name/comment '$($accessRestrictionRuleName)'); skipping."
                continue
            }

            if ($allRestrictionRules | Where-Object { $_.name -eq $accessRestrictionRuleName }) {
                Write-Host "    Rule '$($accessRestrictionRuleName)' already exists, removing."
                az webapp config access-restriction remove --resource-group $rg.resourceGroupName `
                    --name $appServiceName `
                    --rule-name $accessRestrictionRuleName `
                    --only-show-errors | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "    ERR | Failed to remove existing rule, skipping add."
                    continue
                }
            }

            Write-Host "    Adding IP '$($currentIpAddress)'."
            az webapp config access-restriction add --resource-group $rg.resourceGroupName `
                --name $appServiceName `
                --rule-name $accessRestrictionRuleName `
                --action Allow `
                --ip-address $currentIpCidr `
                --priority 300 `
                --only-show-errors | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "    ERR | Failed to add rule."
            }
        }
    }
}
