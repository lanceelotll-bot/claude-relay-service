# Local Development Runbook

This repo is configured for the workflow:

1. run locally
2. do secondary development
3. commit and push to your GitHub fork

## One-time setup on a development machine

From the repo root:

```bash
bash scripts/dev-start.sh
bash scripts/dev-ui-start.sh
```

What it does:

- creates `config/config.js` if missing
- generates `.env` and admin credentials if missing
- installs and builds the admin frontend
- downloads and builds a local Redis under `.local/`
- starts Redis
- starts the CRS backend

For local development, the frontend is better run as a separate Vite dev server.

## Daily commands

Start:

```bash
bash scripts/dev-start.sh
bash scripts/dev-ui-start.sh
```

During `dev-start.sh`, the repo now checks `upstream/main` automatically.
If upstream is ahead, it prints a warning and suggests creating a sync branch.
In interactive terminals, it will also ask whether to run:

```bash
bash scripts/git-create-sync-branch.sh
```

Optional env toggles:

- `DEV_UPSTREAM_CHECK=false` to skip startup upstream check
- `DEV_UPSTREAM_PROMPT_CREATE=false` to skip interactive prompt

Double-click launchers in repo root:

- `Start CRS.command`
- `Start CRS UI.command`
- `Open CRS.command`
- `CRS Status.command`
- `Stop CRS.command`

Stop:

```bash
bash scripts/dev-stop.sh
```

Status:

```bash
bash scripts/dev-status.sh
```

## Useful files

- app log: `logs/dev-app.log`
- redis log: `logs/dev-redis.log`
- admin credentials: `data/init.json`
- local Redis binary: `.local/bin/redis-server`

## URLs

- health: `http://127.0.0.1:3000/health`
- admin dev UI: `http://127.0.0.1:3001/admin/`
- backend API: `http://127.0.0.1:3000`

## Deployment on another machine

Deployment machines should pull from your own fork, not from upstream:

```bash
git clone https://github.com/lanceelotll-bot/claude-relay-service.git
cd claude-relay-service
git remote add upstream https://github.com/Wei-Shaw/claude-relay-service.git
git checkout develop
```

If the target machine is also a development machine, use:

```bash
bash scripts/dev-start.sh
bash scripts/dev-ui-start.sh
```

If the target machine is a production/deployment machine, prefer Docker or system Redis instead of the local `.local/` Redis build.
