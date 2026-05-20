# azure-powershell-utilities

Small PowerShell utilities for managing your current public IP across Azure network rules / firewalls (with one MongoDB Atlas helper that follows the same pattern).

Each folder is a self-contained utility with an Add script and a Remove script. Per-folder details, JSON schema and run instructions are in each folder's `README.md`.

| Folder | Resource |
| --- | --- |
| `AddSqlServerFirewallRule/` | Azure SQL Server firewall rules |
| `AddAppServiceNetworkRule/` | Azure App Service access restrictions |
| `AddCosmosDBAccountNetworkRule/` | Azure Cosmos DB account `ipRules` |
| `AddStorageAccountNetworkRule/` | Azure Storage Account network rules |
| `AddMongoDBAtlasNetworkRule/` | MongoDB Atlas Project IP Access List |

## Prerequisites

- **PowerShell 7+** (`pwsh`). The scripts use PS 7-only features such as the 3-argument form of `Join-Path`. Windows PowerShell 5.1 is not supported.
- **Azure CLI** (`az`) — required for the four Azure folders. Install: <https://learn.microsoft.com/en-us/cli/azure/install-azure-cli>. Sign in with `az login`. **No `az` extensions are required.**
- **MongoDB Atlas CLI** (`atlas`) — required only for `AddMongoDBAtlasNetworkRule/`. Install: <https://www.mongodb.com/docs/atlas/cli/current/install-atlas-cli/>. Sign in with `atlas auth login`, or set the `MONGODB_ATLAS_PUBLIC_API_KEY` / `MONGODB_ATLAS_PRIVATE_API_KEY` environment variables.

## Setup

For each utility folder you want to use:

1. Copy `resources.template.json` → `resources.json` and fill in your `tenantId` / `subscriptionId` / `resourceGroupName` / resource names. `resources.json` is gitignored.
2. Run the script from anywhere — paths are resolved against the script's own folder via `$PSScriptRoot`:
   ```pwsh
   .\AddAppServiceNetworkRule\AddAppServiceNetworkRule.ps1
   ```

## How "current IP" is tracked

- The five Add scripts fetch your current public IP from `myexternalip.com/raw`.
- The Storage Account and Cosmos DB scripts each maintain their own `.last-ip` inside their folder (e.g. `AddStorageAccountNetworkRule/.last-ip`). On the next run they use that value to remove the previous IP before adding the current one, so stale entries don't accumulate when your IP changes. `.last-ip` is gitignored and only persisted when every operation in that script succeeded.
- The SQL Server, App Service, and MongoDB Atlas scripts don't need `.last-ip` — they look up the existing entry by a fixed identifier (rule name for SQL/App Service, entry comment for Atlas, all set at the top of each script as `<YourName>`) and replace it.
