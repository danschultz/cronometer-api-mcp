# cronometer-mcp

Container image for [rwestergren/cronometer-api-mcp](https://github.com/rwestergren/cronometer-api-mcp), built from a pinned upstream commit and served over MCP streamable HTTP.

Upstream ships a Dockerfile but doesn't publish an image. This wrapper builds one and adds:

- **Docker secret support for Cronometer credentials.** `CRONOMETER_USERNAME_FILE`, `CRONOMETER_PASSWORD_FILE` and `CRONOMETER_TOTP_SECRET_FILE` are read into the matching env vars by the entrypoint.
- **Non-root user.** Runs as `app` (uid/gid `10001`), with `HOME=/home/app`.
- **Pinned, reproducible builds.** The upstream commit is set by `CRONOMETER_MCP_REF` in the `Dockerfile`, and dependencies come from upstream's `uv.lock`.

```
ghcr.io/danschultz/cronometer-mcp:<version>
```

## Security

The server has **no authentication** and exposes diary-modifying tools (`add_food_entry`, `remove_food_entry`, `delete_recipe`, ...). Never expose it directly. Put an authenticating reverse proxy in front of it (the home-networking stack uses Traefik basic auth).

## Usage

```yaml
services:
  cronometer-mcp:
    image: ghcr.io/danschultz/cronometer-mcp:<version>
    secrets:
      - cronometer_username
      - cronometer_password
    environment:
      CRONOMETER_USERNAME_FILE: /run/secrets/cronometer_username
      CRONOMETER_PASSWORD_FILE: /run/secrets/cronometer_password
      # CRONOMETER_TOTP_SECRET_FILE: /run/secrets/cronometer_totp_secret
      # CRONOMETER_ACCOUNT_TZ: America/Los_Angeles
```

The MCP endpoint is `:8080/mcp` and the health check is `:8080/healthz`. Set `PORT` to change the port. Pass a different command to override the default supergateway command.

If both `FOO` and `FOO_FILE` are set, `FOO` wins. A `FOO_FILE` that points to a missing file stops the container on startup.

## Workflows

| Workflow | Trigger | What it does |
|---|---|---|
| `pr.yml` | Pull request | Builds the image, smoke-tests it, and pushes `pr-<number>` |
| `release.yml` | Manual (`version` input) | Tags `v<version>`, pushes `<version>`, `<major>.<minor>`, `<major>` and `latest`, and creates a GitHub release that records the upstream commit |
| `update-upstream.yml` | 1st of each month, or manual | Opens a PR bumping `CRONOMETER_MCP_REF` when upstream `main` moves |

Dependabot keeps GitHub Actions and the supergateway base image up to date.

### Upgrading upstream

1. Review the diff linked in the `update-upstream` PR and merge it.
2. Run **Release** with the next version.
3. Bump the image tag wherever it's deployed.

### Repository setup

- **Settings → Actions → General → Workflow permissions:** turn on *Allow GitHub Actions to create and approve pull requests*. Without it, `update-upstream.yml` can't open PRs.
- **Optional: `UPSTREAM_BUMP_TOKEN` secret.** PRs opened with the default `GITHUB_TOKEN` don't trigger `pr.yml`. Add a fine-grained PAT with *Contents* and *Pull requests* write access on this repo so upstream-bump PRs are built and tested automatically.
