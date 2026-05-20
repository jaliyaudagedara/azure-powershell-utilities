# azure

PowerShell utilities for Azure resources. Each folder is a self-contained utility with an Add script and a Remove script; per-folder details are in each folder's `README.md`.

Requires **Azure CLI** (`az`) — install: <https://learn.microsoft.com/en-us/cli/azure/install-azure-cli>. Sign in with `az login`. **No `az` extensions are required.**

- `AddSqlServerFirewallRule/` — add/remove your current public IP as a named firewall rule on Azure SQL Server(s).
- `AddAppServiceNetworkRule/` — add/remove your current public IP as a named access restriction on Azure App Service(s).
- `AddCosmosDBAccountNetworkRule/` — add/remove your current public IP from the `ipRules` of Azure Cosmos DB account(s).
- `AddStorageAccountNetworkRule/` — add/remove your current public IP from the network rule set of Azure Storage Account(s).

## Setup

For each utility folder you want to use:

1. Copy `resources.template.json` → `resources.json` and fill in your `tenantId` / `subscriptionId` / `resourceGroupName` / resource names. `resources.json` is gitignored.
2. Run the script from anywhere — paths are resolved against the script's own folder via `$PSScriptRoot`:
   ```pwsh
   .\azure\AddAppServiceNetworkRule\AddAppServiceNetworkRule.ps1
   ```

## How "current IP" is tracked

- Each Add script fetches your current public IP from `myexternalip.com/raw`.
- The Storage Account and Cosmos DB scripts each maintain their own `.last-ip` inside their folder (e.g. `AddStorageAccountNetworkRule/.last-ip`). On the next run they use that value to remove the previous IP before adding the current one, so stale entries don't accumulate when your IP changes. `.last-ip` is gitignored and only persisted when every operation in that script succeeded.
- The SQL Server and App Service scripts don't need `.last-ip` — they look up the existing rule by a fixed name (set at the top of each script as `<YourName>`) and replace it.

See the repo-wide [`../README.md`](../README.md) for prerequisites.
