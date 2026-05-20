# Description
#   Utility Script to add Current IP to set of Azure SQL Servers (uses az CLI)

# Important Note: This script provided AS IS, please review the code before executing

. (Join-Path $PSScriptRoot ".." ".." "shared.ps1")

# Replace with your own name/identifier; this is used as the firewall rule name.
$firewallRuleName = "JaliyaUdagedara"

$currentIpAddress = Get-CurrentPublicIp
$json = Get-ResourcesJson -ScriptRoot $PSScriptRoot

foreach ($sub in $json) {
    $currentAzAccount = Switch-AzSubscriptionContext -TenantId $sub.tenantId -SubscriptionId $sub.subscriptionId
    if ($null -eq $currentAzAccount) { continue }

    foreach ($rg in $sub.resources) {
        Write-Host "ResourceGroup '$($rg.resourceGroupName)':"

        foreach ($sqlServerName in $rg.sqlServers) {
            Write-Host "  SQL Server '$($sqlServerName)':"

            $sqlServer = az sql server show --resource-group $rg.resourceGroupName --name $sqlServerName --only-show-errors -o json | ConvertFrom-Json
            if ($null -eq $sqlServer) {
                Write-Host "    Could not query SQL Server, skipping."
                continue
            }
            if ($sqlServer.publicNetworkAccess -in 'Disabled', 'SecuredByPerimeter') {
                Write-Host "    Public network access is '$($sqlServer.publicNetworkAccess)' (firewall rules have no effect), skipping."
                continue
            }

            $allFirewallRules = az sql server firewall-rule list --resource-group $rg.resourceGroupName --server $sqlServerName --only-show-errors -o json | ConvertFrom-Json
            if ($null -eq $allFirewallRules) {
                Write-Host "    Could not list Firewall Rules, skipping."
                continue
            }

            $allFirewallRules = @($allFirewallRules)
            if ($allFirewallRules | Where-Object { ($_.startIpAddress -eq $currentIpAddress) -and ($_.endIpAddress -eq $currentIpAddress) }) {
                Write-Host "    Current IP '$($currentIpAddress)' already present (name/comment '$($firewallRuleName)'); skipping."
                continue
            }

            if ($allFirewallRules | Where-Object { $_.name -eq $firewallRuleName }) {
                Write-Host "    Rule '$($firewallRuleName)' already exists, removing."
                az sql server firewall-rule delete --resource-group $rg.resourceGroupName `
                    --server $sqlServerName `
                    --name $firewallRuleName `
                    --only-show-errors | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "    ERR | Failed to remove existing rule, skipping add."
                    continue
                }
            }

            Write-Host "    Adding IP '$($currentIpAddress)'."
            az sql server firewall-rule create --resource-group $rg.resourceGroupName `
                --server $sqlServerName `
                --name $firewallRuleName `
                --start-ip-address $currentIpAddress `
                --end-ip-address $currentIpAddress `
                --only-show-errors | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "    ERR | Failed to add rule."
            }
        }
    }
}
