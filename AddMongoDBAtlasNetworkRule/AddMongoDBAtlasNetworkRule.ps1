# Description
#   Utility Script to add Current IP to set of MongoDB Atlas Projects' IP Access Lists (uses atlas CLI)

# Important Note: This script provided AS IS, please review the code before executing

. (Join-Path $PSScriptRoot ".." "shared.ps1")

# Replace '<Your Name>' with your name or identifier; defaults to "Jaliya Udagedara".
# Set as the access list entry's comment - the script uses this comment to find
# and replace its own previous entry when your IP changes. Per-project override is
# supported via the `comment` field in resources.json.
$accessListComment = "JaliyaUdagedara"

$currentIpAddress = Get-CurrentPublicIp
$json = Get-AtlasResourcesJson -ScriptRoot $PSScriptRoot

foreach ($org in $json) {
    $profileArgs = @()
    if ($org.profile) {
        $profileArgs = @('--profile', $org.profile)
        Write-Host "Atlas Organization '$($org.orgId)' (profile '$($org.profile)'):"
    } else {
        Write-Host "Atlas Organization '$($org.orgId)':"
    }

    foreach ($project in $org.projects) {
        Write-Host "  Project '$($project.projectId)':"

        $comment = $accessListComment
        if ($project.comment) {
            $comment = $project.comment
        }

        # TODO: `atlas accessLists list` defaults to 100 entries; pass --itemsPerPage / page through if you ever cross that.
        $listOutput = atlas accessLists list --projectId $project.projectId @profileArgs -o json
        if ($LASTEXITCODE -ne 0 -or -not $listOutput) {
            Write-Host "    ERR | Could not list access list."
            continue
        }

        $listJson = $listOutput | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($null -eq $listJson) {
            Write-Host "    ERR | Could not parse access list response."
            continue
        }

        # Any existing entries tagged with our comment are ours to manage.
        # Normalize each entry's IP (prefer `ipAddress`, fall back to `cidrBlock` stripped of /32)
        # so portal-created cidrBlock-only entries are also matched.
        $managed = @($listJson.results | Where-Object { $_.comment -eq $comment })
        $alreadyHasCurrent = [bool]($managed | Where-Object {
                $entryIp = if ($_.ipAddress) { $_.ipAddress } else { $_.cidrBlock -replace '/32$', '' }
                $entryIp -eq $currentIpAddress
            })

        if ($managed.Count -eq 1 -and $alreadyHasCurrent) {
            Write-Host "    Current IP '$($currentIpAddress)' already present (name/comment '$($comment)'); skipping."
            continue
        }

        # Remove any managed entries that aren't the current IP.
        foreach ($entry in $managed) {
            $entryIp = if ($entry.ipAddress) { $entry.ipAddress } else { $entry.cidrBlock -replace '/32$', '' }
            if ($entryIp -eq $currentIpAddress) { continue }
            $entryValue = if ($entry.ipAddress) { $entry.ipAddress } else { $entry.cidrBlock }
            Write-Host "    Removing previous entry '$($entryValue)' (comment '$($comment)')."
            atlas accessLists delete $entryValue --projectId $project.projectId @profileArgs --force | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "    ERR | Failed to remove previous entry."
            }
        }

        if (-not $alreadyHasCurrent) {
            Write-Host "    Adding IP '$($currentIpAddress)' (comment '$($comment)')."
            atlas accessLists create $currentIpAddress --type ipAddress --projectId $project.projectId --comment $comment @profileArgs | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "    ERR | Failed to add IP."
            }
        }
    }
}
