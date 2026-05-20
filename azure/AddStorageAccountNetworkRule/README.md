## AddStorageAccountNetworkRule
- Adds the current IP to each Storage Account listed in `resources.json`. If `.last-ip` (in this folder) exists, that previous IP is removed first so stale entries don't accumulate when your IP changes. Writes the current IP back to `.last-ip`.
- Skips Storage Accounts where `publicNetworkAccess` is `Disabled` or `networkRuleSet.defaultAction` is `Allow` (no IP restrictions enabled). Best-effort removes the previous IP from skipped accounts to avoid stale entries.

## RemoveStorageAccountNetworkRule
- Removes the IP recorded in `.last-ip` (in this folder) from each Storage Account listed in `resources.json`. Skips accounts where the IP isn't currently in `networkRuleSet.ipRules`.

## Notes
- Copy `resources.template.json` to `resources.json` and fill in your own values. `resources.json` is gitignored, so your data stays local.
- See `resources.template.json` for the schema.

## Troubleshooting

```
 az logout
 az login
```
