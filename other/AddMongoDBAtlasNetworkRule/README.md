## AddMongoDBAtlasNetworkRule
- Adds the current IP to each MongoDB Atlas Project's IP Access List listed in `resources.json`, tagged with the comment defined at the top of the script (`$accessListComment`, defaults to `<Your Name>`). On the next run that comment is used to locate the previous entry and replace it, so stale entries don't accumulate when your IP changes. A per-project override is supported via the `comment` field in `resources.json`.
- Skips only when the single managed entry already matches the current IP. If extra stale entries share the comment, they're removed too.

## RemoveMongoDBAtlasNetworkRule
- Removes any access list entry whose comment matches `$accessListComment` (or the per-project override in `resources.json`) from each MongoDB Atlas Project.

## Notes
- For multiple Atlas organizations needing different credentials, create named profiles with `atlas config set --profile <name>` and reference the profile name per-org in `resources.json`.
- Copy `resources.template.json` to `resources.json` and fill in your own values. `resources.json` is gitignored, so your data stays local.
- See `resources.template.json` for the schema.

## Troubleshooting

```
 atlas auth logout
 atlas auth login
```
