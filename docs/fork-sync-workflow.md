# CRS Fork Sync Workflow

This workspace is set up for long-term CRS secondary development with upstream sync.

## Branch roles

- `main`: stays close to the upstream project
- `develop`: your integration branch for ongoing custom development
- `codex/<feature-name>`: feature branches for specific changes

## Current machine setup

1. Create your own GitHub fork in the browser:
   - `https://github.com/Wei-Shaw/claude-relay-service/fork`
2. Link this local repo to your fork:

```bash
bash scripts/git-link-origin.sh https://github.com/<your-account>/claude-relay-service.git
```

3. Push your local branches to your GitHub fork:

```bash
git push -u origin main
git push -u origin develop
```

After that:

- `origin` = your GitHub repo
- `upstream` = original CRS repo

## Daily development flow in Codex

Start from the integration branch:

```bash
git checkout develop
git pull origin develop
git checkout -b codex/<feature-name>
```

After Codex helps you finish a change:

```bash
git add .
git commit -m "feat: <change-summary>"
git push -u origin codex/<feature-name>
```

Then merge the feature branch into `develop` on GitHub or locally.

## Sync upstream changes

Run the sync script when you want the latest CRS updates:

```bash
bash scripts/git-sync-upstream.sh
```

What it does:

1. Fetches `upstream`
2. Updates local `main` from `upstream/main`
3. Pushes `main` to your GitHub fork if `origin` exists
4. Merges `main` into `develop`
5. Pushes `develop` to your GitHub fork if `origin` exists

## New machine workflow

On a new machine, pull your own fork instead of the original repo:

```bash
git clone https://github.com/<your-account>/claude-relay-service.git
cd claude-relay-service
git remote add upstream https://github.com/Wei-Shaw/claude-relay-service.git
git fetch upstream --prune
git checkout develop
```

Then restore environment and deploy:

```bash
cp .env.example .env
npm install
docker compose up -d
```

If you prefer local Node development instead of Docker:

```bash
npm install
npm run setup
npm run dev
```

## Optional: SS sidecar deployment (B strategy)

If your accounts need SS egress with low ops overhead:

```bash
bash scripts/ss-sidecar-setup.sh
bash scripts/docker-up-ss.sh
```

Then set account proxy in UI as:

- type `socks5`
- host `ss-sidecar`
- port `1080`

Quick latency test:

```bash
bash scripts/ss-sidecar-test.sh
```

Long-running auto-heal:

```bash
bash scripts/ss-sidecar-watchdog.sh
```

## Keep machine-specific data out of Git

Do not commit:

- `.env`
- local secrets
- server-specific runtime data
- logs and temp files

Commit:

- code changes
- deployment scripts
- safe config templates
- documentation for your workflow

## Recommended deployment rule

Deploy from your own GitHub fork only.

That gives you:

- one source of truth across machines
- full control over your custom changes
- clean separation between your work and upstream updates
