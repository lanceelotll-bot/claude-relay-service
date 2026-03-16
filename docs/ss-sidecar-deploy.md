# SS Sidecar Deployment (Low-Ops)

This is the recommended `B` path:

1. deploy an SS sidecar once
2. keep CRS account proxy config as standard `socks5/http`

No code change is required on each account for SS protocol internals.

## One-time setup

From repo root:

```bash
bash scripts/ss-sidecar-setup.sh
```

The script asks for:

- SS server host
- SS server port
- SS method
- SS password

It writes local secret config to:

- `config/sing-box/config.json` (git-ignored)

## Start stack

```bash
bash scripts/docker-up-ss.sh
```

This starts:

- CRS (`docker-compose.yml`)
- Redis
- SS sidecar (`docker-compose.ss.yml`)

## Account proxy config in CRS UI

For accounts that should go through SS:

- proxy type: `socks5`
- host: `ss-sidecar`
- port: `1080`
- username/password: leave empty unless your local sidecar inbound requires auth

This keeps account-level logic unchanged and stable.

## One-click connectivity + latency test

```bash
bash scripts/ss-sidecar-test.sh
```

Default test target:

- `https://api.anthropic.com/v1/messages`

Output includes:

- HTTP status code
- latency in milliseconds

Notes:

- `401/403` is acceptable for connectivity testing (reachable but unauthorized).
- If you need another target:

```bash
bash scripts/ss-sidecar-test.sh https://api.openai.com/v1/models
```

## Long-running stability (recommended)

For 24x7 running, use the watchdog script in cron/systemd timer:

```bash
bash scripts/ss-sidecar-watchdog.sh
```

What it does:

1. checks `ss-sidecar` container running state
2. runs proxy connectivity + latency test
3. auto-restarts `ss-sidecar` on failure and re-tests once

Useful env overrides:

- `AUTO_RESTART_SS_SIDECAR=false` to disable auto restart
- `SS_WATCHDOG_TEST_URL=https://api.openai.com/v1/models` custom test target
- `SS_SIDECAR_SOCKS_PORT=11080` host-side socks port override

Cron example (every 5 minutes):

```bash
*/5 * * * * cd /path/to/claude-relay-service && bash scripts/ss-sidecar-watchdog.sh >> logs/ss-watchdog.log 2>&1
```

## Stop stack

```bash
bash scripts/docker-down-ss.sh
```
