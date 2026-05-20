# Description
#   Utility Script to remove access list entries matching $accessListComment from set of MongoDB Atlas Projects (uses atlas CLI)

# Important Note: This script provided AS IS, please review the code before executing

. (Join-Path $PSScriptRoot ".." ".." "shared.ps1")

# Must match the comment used by AddMongoDBAtlasNetworkRule.ps1 (or the per-project
# override in resources.json) - the script removes any entry tagged with this comment.
$accessListComment = "JaliyaUdagedara"

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

        $listOutput = atlas accessLists list --projectId $project.projectId @profileArgs -o json
        if ($LASTEXITCODE -ne 0 -or -not $listOutput) {
            Write-Host "    Could not list access list, skipping."
            continue
        }

        $listJson = $listOutput | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($null -eq $listJson) {
            Write-Host "    Could not parse access list response, skipping."
            continue
        }

        $managed = @($listJson.results | Where-Object { $_.comment -eq $comment })
        if ($managed.Count -eq 0) {
            Write-Host "    No entries with comment '$($comment)'; skipping."
            continue
        }

        foreach ($entry in $managed) {
            $entryValue = if ($entry.ipAddress) { $entry.ipAddress } else { $entry.cidrBlock }
            Write-Host "    Removing entry '$($entryValue)' (comment '$($comment)')."
            atlas accessLists delete $entryValue --projectId $project.projectId @profileArgs --force | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "    ERR | Failed to remove entry."
            }
        }
    }
}
