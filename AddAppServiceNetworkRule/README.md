## AddAppServiceNetworkRule
- Adds the current IP as a named access restriction to each App Service listed in `resources.json`. Skips App Services that don't already have network restrictions enabled.

## RemoveAppServiceNetworkRule
- Removes any access restriction whose name matches `<YourName>*` (the pattern set at the top of the script) from each App Service listed in `resources.json`.

## Notes
- Copy `resources.template.json` to `resources.json` and fill in your own values. `resources.json` is gitignored, so your data stays local.
- See `resources.template.json` for the schema.

## Troubleshooting

```
 az logout
 az login
```
