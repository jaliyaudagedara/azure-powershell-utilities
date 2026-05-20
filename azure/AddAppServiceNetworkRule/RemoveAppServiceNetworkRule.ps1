# Description
#   Utility Script to remove a given Access Restriction Rule from set of Azure App Services (uses az CLI)

# Important Note: This script provided AS IS, please review the code before executing

. (Join-Path $PSScriptRoot ".." ".." "shared.ps1")

# Replace with your own name/identifier (wildcard pattern matched against the rule name).
$accessRestrictionRuleNamePattern = "JaliyaUdagedara*"

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

            $matchingRules = @($accessRestrictions.ipSecurityRestrictions | Where-Object { $_.name -like $accessRestrictionRuleNamePattern })
            if ($matchingRules.Count -eq 0) {
                Write-Host "    No rules matching '$($accessRestrictionRuleNamePattern)', skipping."
                continue
            }

            foreach ($rule in $matchingRules) {
                Write-Host "    Removing rule '$($rule.name)'."
                az webapp config access-restriction remove --resource-group $rg.resourceGroupName `
                    --name $appServiceName `
                    --rule-name $rule.name `
                    --only-show-errors | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "    ERR | Failed to remove rule '$($rule.name)'."
                }
            }
        }
    }
}
