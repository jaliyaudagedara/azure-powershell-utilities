# Description
#   Utility Script to remove a given FirewallRuleName from set of Azure SQL Servers (uses az CLI)

# Important Note: This script provided AS IS, please review the code before executing

. (Join-Path $PSScriptRoot ".." ".." "shared.ps1")

# Replace with your own name/identifier (wildcard pattern matched against the rule name).
$firewallRuleNamePattern = "JaliyaUdagedara*"

$json = Get-ResourcesJson -ScriptRoot $PSScriptRoot

foreach ($sub in $json) {
    $currentAzAccount = Switch-AzSubscriptionContext -TenantId $sub.tenantId -SubscriptionId $sub.subscriptionId
    if ($null -eq $currentAzAccount) { continue }

    foreach ($rg in $sub.resources) {
        Write-Host "ResourceGroup '$($rg.resourceGroupName)':"

        foreach ($sqlServerName in $rg.sqlServers) {
            Write-Host "  SQL Server '$($sqlServerName)':"

            $allFirewallRules = az sql server firewall-rule list --resource-group $rg.resourceGroupName --server $sqlServerName --only-show-errors -o json | ConvertFrom-Json
            if ($null -eq $allFirewallRules) {
                Write-Host "    Could not list Firewall Rules, skipping."
                continue
            }

            $matchingFirewallRules = @($allFirewallRules | Where-Object { $_.name -like $firewallRuleNamePattern })
            if ($matchingFirewallRules.Count -eq 0) {
                Write-Host "    No rules matching '$($firewallRuleNamePattern)', skipping."
                continue
            }

            foreach ($rule in $matchingFirewallRules) {
                Write-Host "    Removing rule '$($rule.name)'."
                az sql server firewall-rule delete --resource-group $rg.resourceGroupName `
                    --server $sqlServerName `
                    --name $rule.name `
                    --only-show-errors | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "    ERR | Failed to remove rule '$($rule.name)'."
                }
            }
        }
    }
}
