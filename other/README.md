# other

PowerShell utilities for non-Azure providers. Each folder is a self-contained utility; per-folder details are in each folder's `README.md`.

- `AddMongoDBAtlasNetworkRule/` — add/remove your current public IP on a MongoDB Atlas Project's IP Access List, tagged with a fixed comment so stale entries don't accumulate.

Requires the **MongoDB Atlas CLI** (`atlas`) — install: <https://www.mongodb.com/docs/atlas/cli/current/install-atlas-cli/>. Sign in with `atlas auth login`, or set the `MONGODB_ATLAS_PUBLIC_API_KEY` / `MONGODB_ATLAS_PRIVATE_API_KEY` environment variables.

## Setup

1. Copy `resources.template.json` → `resources.json` and fill in your Atlas project values (see the template for the schema). `resources.json` is gitignored.
2. Run the script from anywhere — paths are resolved against the script's own folder via `$PSScriptRoot`:
   ```pwsh
   .\other\AddMongoDBAtlasNetworkRule\AddMongoDBAtlasNetworkRule.ps1
   ```

## How "current IP" is tracked

- The Add script fetches your current public IP from `myexternalip.com/raw`.
- It tags the access list entry with the comment defined at the top of the script (`$accessListComment`, defaults to `<Your Name>`). On the next run that comment is used to locate the previous entry and replace it — no `.last-ip` file is needed.

See the repo-wide [`../README.md`](../README.md) for prerequisites.
