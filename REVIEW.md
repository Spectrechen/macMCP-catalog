# Reviewing catalog changes

Each change to `catalog.json` changes what macMCP sends to organisations' servers with their
credentials. Before merging:

1. **Sources.** Every endpoint, parameter and auth method is backed by a vendor documentation link
   in the connector's `documentation` list (or the PR description).
2. **Read vs write.** A tool is `readOnly: true` only if it uses `GET` and changes nothing.
   Anything else is a write tool; admins must enable write tools per connector. Mark
   deletions and irreversible actions `destructive: true`.
3. **Least data.** Use `response.pick` so tools return what a model needs, not whole objects
   (inventory records, page bodies). Set `maxBytes` for large responses.
4. **No secrets, no hosts.** Paths are relative to the admin's base URL. Never add absolute URLs,
   `Authorization`/`Cookie` headers, tokens or example credentials.
5. **Credentials.** `perUser: true` only where users really have their own credentials
   (personal access tokens). Service accounts (API clients) are `perUser: false`.
6. **Stable names.** Tool names are part of admins' profiles (`EnabledTools`/`DisabledTools`):
   never rename or remove a tool without a deprecation note in `notes` first.
7. **Status.** New connectors and clients start as `experimental` (or `planned`). Promote to
   `supported` only after testing against a real server.
8. `lastReviewed` is updated for every connector the PR touches.
9. CI (`validate`) must pass.

Then run `scripts/release.sh` locally. It is the only step that uses the signing key.
