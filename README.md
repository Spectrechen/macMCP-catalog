# macMCP-catalog

The catalog for [macMCP](https://github.com/Spectrechen/macMCP), a local MCP server for macOS
that is configured entirely by MDM. Share here how applications are exposed as MCP tools and how
MCP clients are connected to macMCP.

`catalog.json` contains:

- **connectors**: per application (Jira Data Center, Confluence Data Center, Jamf Pro …)
  - **auth**: the accepted authentication methods (`bearer`, `basic`, `header`,
    `oauth2ClientCredentials`) and whether users may bring their own credentials (`perUser`);
  - **tools**: each one a JSON Schema for its arguments plus a templated REST request
    (`method`, `path`, `query`, `headers`, `body`) and optional response trimming (`pick`, `maxBytes`);
  - **connectionCheck**, **status** (`supported`, `experimental`, `planned`), **documentation**, **lastReviewed**;
- **clients**: how MCP clients (Claude Desktop, Claude Code, VS Code, Cursor) are wired up:
  config file, server map key, entry template, and the Mimir harness ID for central deployment.

It is data only. Admins decide in their MDM profile which connectors and tools run, with which
base URL and credentials; tools that change data only run when the admin allows write tools.
macMCP additionally keeps every request on the configured base URL and never lets the catalog
set authentication headers, whoever signed it.

## Connectors

| id | Application | Auth | Tools (R = read, W = write) | Status |
|---|---|---|---|---|
| `jira-dc` | Jira Data Center | PAT, basic (per user) | 4 R, 3 W | experimental |
| `confluence-dc` | Confluence Data Center | PAT, basic (per user) | 4 R, 1 W | experimental |
| `jamf-pro` | Jamf Pro | API client (service account) | 7 R, 1 W | experimental |

## Clients

`claude-desktop` (stdio), `claude-code`, `vscode`, `cursor` (HTTP).

## Trust

Releases carry `catalog.json` and `catalog.json.sig`, a detached Ed25519 signature. macMCP
accepts a catalog only with a valid signature from a key compiled into macMCP (or one the admin
adds by MDM for an organisation's own catalog), and never one older than the catalog it already
has, unless an admin pins a version.

Public key (base64, raw Ed25519): `muvNXXcLx2e53jHSvuuDqiWfIOhJIiSGiEzaJxnJyc8=`

The private key is kept offline and never used in CI.

## Contributing

Pull requests welcome; see [REVIEW.md](REVIEW.md) for the rules every change must meet.
`swift scripts/validate.swift catalog.json` runs the same checks as CI.

## Releasing (maintainer)

```sh
scripts/release.sh            # bumps catalogVersion, validates, signs, tags, creates the GitHub release
```
