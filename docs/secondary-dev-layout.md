# CRS Secondary Development Layout

This repo now has a low-conflict structure for long-term customization.

## The rule of thumb

Prefer these folders first:

- `src/custom/` for backend custom logic
- `web/admin-spa/src/custom/` for frontend custom pages and navigation
- `docs/` for your deployment and operating notes

Avoid changing these unless necessary:

- `src/app.js`
- `src/routes/admin/index.js`
- `web/admin-spa/src/router/index.js`
- `web/admin-spa/src/components/layout/MainLayout.vue`
- `web/admin-spa/src/components/layout/TabBar.vue`

These are now your designated hook points.

## Backend strategy

Keep custom backend work inside:

- `src/custom/routes/`
- `src/custom/services/`
- `src/custom/index.js`

Use `src/custom/index.js` for:

- startup initialization
- custom route mounting
- thin integration with the core app

Recommended custom route prefixes:

- `/admin/custom/*`
- `/api/custom/*`

That keeps your new features isolated from upstream route files.

## Frontend strategy

Keep custom admin pages inside:

- `web/admin-spa/src/custom/views/`
- `web/admin-spa/src/custom/components/`
- `web/admin-spa/src/custom/index.js`

Use `getCustomRoutes()` to register new pages.
Use `getCustomTabs()` to add new tabs to the admin layout.

## Machine-local vs repo-tracked customization

This project already ignores `.local/`, and `src/utils/runtimeAddon.js` can load local extensions from there.

Use `.local/` only for:

- machine-specific debugging
- temporary experiments
- local-only scripts that should not go to GitHub

Use `src/custom/` and `web/admin-spa/src/custom/` for:

- business features
- shared custom logic
- anything that should follow you to a new machine through Git

## Recommended workflow

1. Sync upstream into `main`
2. Merge `main` into `develop`
3. Build features in `codex/<feature-name>`
4. Put new logic in `src/custom/` or `web/admin-spa/src/custom/`
5. Only add tiny generic hook changes to core files when needed

This keeps future upstream merges much easier to resolve.
