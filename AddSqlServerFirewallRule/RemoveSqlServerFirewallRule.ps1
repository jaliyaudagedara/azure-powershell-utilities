$firewallRuleName = "<YourFirewallRuleName>"

$json = Get-Content -Raw SqlServerList.JSON | ConvertFrom-Json

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

    $matchingFirewallRules = Get-AzSqlServerFirewallRule -ResourceGroupName $item.resourceGroupName -ServerName $item.sqlServerName -FirewallRuleName $firewallRuleName

    foreach ($rule in $matchingFirewallRules){
		Write-Host "INF | Removing Firewall RuleName: '$($rule.FirewallRuleName)'."
        Remove-AzSqlServerFirewallRule -ResourceGroupName $item.resourceGroupName `
            -ServerName $item.sqlServerName `
            -FirewallRuleName $rule.FirewallRuleName
    }
}