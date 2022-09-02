# Description
#   Utility Script to add Current IP to set of Azure SQL Servers

# Important Note: This script provided AS IS, please review the code before executing

$currentIpAddress = (Invoke-WebRequest myexternalip.com/raw).content
$firewallRuleName = "<YourFirewallRuleName>"

$json = Get-Content -Raw SqlServerList.json | ConvertFrom-Json

foreach ($item in $json) {
    $currentAzContext = Get-AzContext

    if (($currentAzContext.Tenant.Id -ne $item.tenantId) -or ($currentAzContext.Subscription.Id -ne $item.subscriptionId)) {
        Write-Host "INF | Switching AzContext: TenantId: '$($item.tenantId)', SubscriptionId: '$($item.subscriptionId)'."
        $currentAzContext = Set-AzContext -TenantId $item.tenantId -SubscriptionId $item.subscriptionId
    }

    if ($currentAzContext.Subscription.State -eq 'Disabled') {
        Write-Host "WARN | SubscriptionId: '$($item.subscriptionId)' is Disabled. Skippig adding Firewall Rule to SQL Server: '$($item.sqlServerName)'."
        continue
    }

    $allFirewallRules = Get-AzSqlServerFirewallRule -ResourceGroupName $item.resourceGroupName -ServerName $item.sqlServerName
    $matchingFirewallRules = $allFirewallRules.Where({ ($_.StartIpAddress -eq $currentIpAddress) -and ($_.EndIpAddress -eq $currentIpAddress) })
    if ($matchingFirewallRules.Count -gt 0) {
        Write-Host "INF | IP: '$($currentIpAddress)' already exists in SQL Server: '$($item.sqlServerName)'."
        continue
    }

    $matchingFirewallRules = $allFirewallRules.Where({ $_.FirewallRuleName -eq $firewallRuleName })
    if ($matchingFirewallRules.Count -gt 0) {
        Write-Host "INF | Firewall RuleName: '$($firewallRuleName)' already exists in SQL Server: '$($item.sqlServerName)'. Removing existing rule."
        Remove-AzSqlServerFirewallRule -ResourceGroupName $item.resourceGroupName `
            -ServerName $item.sqlServerName `
            -FirewallRuleName $firewallRuleName
    }
    
    Write-Host "INF | Adding IP: '$($currentIpAddress)' to SQL Server: '$($item.sqlServerName)'."
    New-AzSqlServerFirewallRule -ResourceGroupName $item.resourceGroupName `
        -ServerName $item.sqlServerName `
        -FirewallRuleName $firewallRuleName `
        -StartIpAddress $currentIpAddress `
        -EndIpAddress $currentIpAddress
}