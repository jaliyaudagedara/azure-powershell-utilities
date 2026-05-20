## AddCosmosDBAccountNetworkRule
- Adds the current IP to each Cosmos DB Account listed in `resources.json`. If `.last-ip` (in this folder) exists, that previous IP is removed from `ipRules` first so stale entries don't accumulate when your IP changes. Writes the current IP back to `.last-ip`.
- Skips Cosmos DB Accounts where `publicNetworkAccess` is `Disabled` (with best-effort stale-IP cleanup), or where the account has no `ipRules` and no `virtualNetworkRules` (account is on "All networks" — adding our IP would flip it to "Selected" and lock everyone else out).

## RemoveCosmosDBAccountNetworkRule
- Removes the IP recorded in `.last-ip` (in this folder) from each Cosmos DB Account listed in `resources.json`.

## Notes
- Copy `resources.template.json` to `resources.json` and fill in your own values. `resources.json` is gitignored, so your data stays local.
- See `resources.template.json` for the schema.

## Troubleshooting

```
 az logout
 az login
```
