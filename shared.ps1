# Shared helpers for the azure-powershell-utilities scripts.
# Dot-source from each script:
#   . (Join-Path $PSScriptRoot ".." "shared.ps1")

function Get-CurrentPublicIp {
    <#
    .SYNOPSIS
    Returns the machine's current public IPv4 address.

    .DESCRIPTION
    Calls https://myexternalip.com/raw with a 10s timeout, trims whitespace, and
    validates the result is a dotted-quad IPv4. Throws if the response is unreachable
    or doesn't look like an IPv4 address.

    .OUTPUTS
    System.String - the current public IPv4 address.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $ip = (Invoke-WebRequest https://myexternalip.com/raw -UseBasicParsing -TimeoutSec 10).Content.Trim()
    if ($ip -notmatch '^\d{1,3}(\.\d{1,3}){3}$') {
        throw "Failed to determine current public IP (got: '$ip')."
    }
    return $ip
}

function Get-OrderPreservingGroups {
    <#
    .SYNOPSIS
    Like Group-Object but emits groups in first-seen key order rather than
    sorting alphabetically by group name. Keeps the iteration order matching
    the resources.json layout.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Items,
        [Parameter(Mandatory)]
        [scriptblock]$KeySelector
    )

    $keys = @($Items | ForEach-Object $KeySelector)
    $firstIndex = @{}
    for ($i = 0; $i -lt $keys.Count; $i++) {
        if ($null -ne $keys[$i] -and -not $firstIndex.ContainsKey($keys[$i])) {
            $firstIndex[$keys[$i]] = $i
        }
    }
    return $Items | Group-Object -Property $KeySelector | Sort-Object @{
        Expression = { $firstIndex[$_.Name] }
    }
}

function Get-ResourcesJson {
    <#
    .SYNOPSIS
    Loads and parses the per-folder resources.json, deduping across subscriptions,
    resource groups, and resource names (case-insensitive).

    .DESCRIPTION
    Reads <ScriptRoot>/resources.json and returns the parsed JSON. Throws with a
    user-friendly message pointing at the matching resources.template.json if the
    file is missing or malformed.

    If the same subscriptionId / resourceGroupName / resource name appears more
    than once, entries are merged (with a Write-Warning per merge) so subsequent
    iteration doesn't re-process the same target. Name dedupe is case-insensitive
    to match Azure resource-name semantics; the first-seen casing wins.

    .OUTPUTS
    System.Object[] - array of subscription entries with merged resource lists.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ScriptRoot
    )

    # Known per-RG resource-array properties. Extend when adding a new utility.
    $knownArrayProps = @('sqlServers', 'appServices', 'cosmosDbAccounts', 'storageAccounts')

    $path = Join-Path $ScriptRoot "resources.json"
    try {
        $raw = Get-Content -Raw $path -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Failed to load 'resources.json' from '$ScriptRoot'. Copy 'resources.template.json' and fill it in. ($_)"
    }

    $merged = @()
    $subGroups = Get-OrderPreservingGroups -Items @($raw) -KeySelector { $_.subscriptionId }
    foreach ($subGroup in $subGroups) {
        if ($subGroup.Count -gt 1) {
            $tenantIds = @($subGroup.Group | Select-Object -ExpandProperty tenantId -Unique)
            if ($tenantIds.Count -gt 1) {
                Write-Warning "subscriptionId '$($subGroup.Name)' has conflicting tenantIds: $($tenantIds -join ', '). Using '$($tenantIds[0])'."
            }
            Write-Warning "subscriptionId '$($subGroup.Name)' appears in $($subGroup.Count) entries; merging their resources."
        }

        # Concatenate `resources` arrays across duplicate sub entries.
        $allRgs = @()
        foreach ($entry in $subGroup.Group) {
            $allRgs += @($entry.resources)
        }

        # Group RGs by name; merge resource-name arrays from duplicates.
        $mergedRgs = @()
        $rgGroups = Get-OrderPreservingGroups -Items @($allRgs) -KeySelector { $_.resourceGroupName }
        foreach ($rgGroup in $rgGroups) {
            if ($rgGroup.Count -gt 1) {
                Write-Warning "ResourceGroup '$($rgGroup.Name)' appears $($rgGroup.Count) times under subscription '$($subGroup.Name)'; merging."
            }

            # Find the resource-array property from the allow-list (rather than
            # "first non-resourceGroupName property" which would break the moment
            # a new field is added to RG entries).
            $sample = $rgGroup.Group[0]
            $arrayProp = $sample.PSObject.Properties |
                Where-Object { $_.Name -in $knownArrayProps } |
                Select-Object -First 1 -ExpandProperty Name
            if (-not $arrayProp) {
                throw "ResourceGroup entry under subscription '$($subGroup.Name)' has no known resource array property (expected one of: $($knownArrayProps -join ', '))."
            }

            $allNames = @()
            foreach ($rgEntry in $rgGroup.Group) {
                $allNames += @($rgEntry.$arrayProp)
            }
            # Drop any null entries (malformed JSON, trailing commas) before grouping.
            $allNames = @($allNames | Where-Object { $_ })

            # Group case-insensitively (Azure resource names are case-insensitive);
            # preserve first-seen casing and JSON order on output.
            $nameGroups = Get-OrderPreservingGroups -Items @($allNames) -KeySelector { $_.ToLowerInvariant() }
            foreach ($ng in $nameGroups) {
                if ($ng.Count -gt 1) {
                    Write-Warning "Resource '$($ng.Group[0])' appears $($ng.Count) times in ResourceGroup '$($rgGroup.Name)' under subscription '$($subGroup.Name)'; deduping."
                }
            }
            $uniqueNames = @($nameGroups | ForEach-Object { $_.Group[0] })

            $rgDict = [ordered]@{ resourceGroupName = $rgGroup.Name }
            $rgDict[$arrayProp] = $uniqueNames
            $mergedRgs += [pscustomobject]$rgDict
        }

        $firstEntry = $subGroup.Group[0]
        $merged += [pscustomobject]@{
            tenantId       = $firstEntry.tenantId
            subscriptionId = $subGroup.Name
            resources      = $mergedRgs
        }
    }

    return $merged
}

function Get-AtlasResourcesJson {
    <#
    .SYNOPSIS
    Loads and parses the per-folder resources.json for MongoDB Atlas, deduping
    across organizations and projects.

    .DESCRIPTION
    Reads <ScriptRoot>/resources.json and returns the parsed JSON. Throws with a
    user-friendly message pointing at the matching resources.template.json if the
    file is missing or malformed.

    If the same orgId / projectId appears more than once, entries are merged
    (with a Write-Warning per merge). The first occurrence's `comment` (and
    `profile` at the org level) is retained.

    .OUTPUTS
    System.Object[] - array of organization entries with merged project lists.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ScriptRoot
    )

    $path = Join-Path $ScriptRoot "resources.json"
    try {
        $raw = Get-Content -Raw $path -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Failed to load 'resources.json' from '$ScriptRoot'. Copy 'resources.template.json' and fill it in. ($_)"
    }

    $merged = @()
    $orgGroups = Get-OrderPreservingGroups -Items @($raw) -KeySelector { $_.orgId }
    foreach ($orgGroup in $orgGroups) {
        if ($orgGroup.Count -gt 1) {
            $profiles = @()
            foreach ($entry in $orgGroup.Group) {
                if ($entry.profile) { $profiles += $entry.profile }
            }
            $profiles = @($profiles | Select-Object -Unique)
            if ($profiles.Count -gt 1) {
                Write-Warning "orgId '$($orgGroup.Name)' has conflicting profiles: $($profiles -join ', '). Using '$($profiles[0])'."
            }
            Write-Warning "orgId '$($orgGroup.Name)' appears in $($orgGroup.Count) entries; merging their projects."
        }

        # Concatenate `projects` arrays across duplicate org entries.
        $allProjects = @()
        foreach ($entry in $orgGroup.Group) {
            $allProjects += @($entry.projects)
        }

        # Group by projectId; warn on duplicates and keep the first entry's comment.
        $mergedProjects = @()
        $projectGroups = Get-OrderPreservingGroups -Items @($allProjects) -KeySelector { $_.projectId }
        foreach ($pg in $projectGroups) {
            if ($pg.Count -gt 1) {
                Write-Warning "projectId '$($pg.Name)' appears $($pg.Count) times under orgId '$($orgGroup.Name)'; deduping."
            }
            $mergedProjects += $pg.Group[0]
        }

        # Resolve profile: first non-empty value across duplicate org entries.
        $resolvedProfile = $null
        foreach ($entry in $orgGroup.Group) {
            if ($entry.profile) {
                $resolvedProfile = $entry.profile
                break
            }
        }

        $orgDict = [ordered]@{ orgId = $orgGroup.Name }
        if ($resolvedProfile) { $orgDict.profile = $resolvedProfile }
        $orgDict.projects = $mergedProjects
        $merged += [pscustomobject]$orgDict
    }

    return $merged
}

function Switch-AzSubscriptionContext {
    <#
    .SYNOPSIS
    Switches az CLI to the target subscription and verifies the switch landed.

    .DESCRIPTION
    Reads the current az account context. If the active sub doesn't match the target,
    runs `az account set --subscription <id>` then re-reads to confirm both tenant
    and subscription match. Also checks the subscription is not disabled.

    On any skip reason (not logged in, failed switch, wrong tenant after switch,
    disabled sub) the function writes a warning and returns $null so the caller
    can `continue` to the next entry without halting the loop. Callers iterating
    over multiple subs should check for $null and skip that entry (and optionally
    flag a failure).

    .OUTPUTS
    PSCustomObject - the az account object on success; $null on any skip reason.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$TenantId,
        [Parameter(Mandatory)]
        [string]$SubscriptionId
    )

    $currentAzAccount = az account show --only-show-errors -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($LASTEXITCODE -ne 0 -or $null -eq $currentAzAccount) {
        Write-Warning "Could not read az account context (try 'az login'), skipping."
        return $null
    }

    if (($currentAzAccount.tenantId -ne $TenantId) -or ($currentAzAccount.id -ne $SubscriptionId)) {
        Write-Host "Switching az account: TenantId '$TenantId', SubscriptionId '$SubscriptionId'."
        az account set --subscription $SubscriptionId --only-show-errors | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to switch to SubscriptionId '$SubscriptionId' (try 'az login --tenant $TenantId'), skipping."
            return $null
        }
        $currentAzAccount = az account show --only-show-errors -o json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($LASTEXITCODE -ne 0 -or $null -eq $currentAzAccount) {
            Write-Warning "Could not re-read az account context after switching SubscriptionId '$SubscriptionId', skipping."
            return $null
        }
        if (($currentAzAccount.tenantId -ne $TenantId) -or ($currentAzAccount.id -ne $SubscriptionId)) {
            Write-Warning "Subscription context did not switch (expected TenantId '$TenantId', SubscriptionId '$SubscriptionId'), skipping."
            return $null
        }
    }

    if ($currentAzAccount.state -eq 'Disabled') {
        Write-Warning "SubscriptionId '$SubscriptionId' is disabled, skipping."
        return $null
    }

    return $currentAzAccount
}

function Get-LastIp {
    <#
    .SYNOPSIS
    Reads the previously-recorded IP from <ScriptRoot>/.last-ip.

    .OUTPUTS
    System.String - the trimmed IP value; $null if the file is missing or empty.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$ScriptRoot
    )

    $path = Join-Path $ScriptRoot ".last-ip"
    if (-not (Test-Path $path)) {
        return $null
    }
    $value = (Get-Content -Raw $path).Trim()
    if (-not $value) {
        return $null
    }
    return $value
}

function Set-LastIp {
    <#
    .SYNOPSIS
    Writes the given IP to <ScriptRoot>/.last-ip (no trailing newline).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ScriptRoot,
        [Parameter(Mandatory)]
        [string]$IpAddress
    )

    $path = Join-Path $ScriptRoot ".last-ip"
    Set-Content -Path $path -Value $IpAddress -NoNewline
}
