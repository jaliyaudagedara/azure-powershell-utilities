## AddSqlServerFirewallRule
- Adds the current IP as a named firewall rule to each SQL Server listed in `resources.json`.
- Skips SQL Servers where `publicNetworkAccess` is `Disabled` or `SecuredByPerimeter` (firewall rules have no effect).

## RemoveSqlServerFirewallRule
- Removes any firewall rule whose name matches `<YourName>*` (the pattern set at the top of the script) from each SQL Server listed in `resources.json`.

## Notes
- Copy `resources.template.json` to `resources.json` and fill in your own values. `resources.json` is gitignored, so your data stays local.
- See `resources.template.json` for the schema.

## Troubleshooting

```
 az logout
 az login
```
