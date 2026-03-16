# Backend Secondary Development

Put your long-term custom backend code here instead of scattering changes across core folders.

Recommended structure:

- `src/custom/routes/`: custom Express routes
- `src/custom/services/`: your business services
- `src/custom/repositories/`: data access wrappers if needed
- `src/custom/constants/`: custom constants and enums

Two extension hooks are available from `src/custom/index.js`:

- `afterCoreInitialized(context)`
- `mountRoutes(app, context)`

Recommended rule:

- add new logic in `src/custom/*`
- only change core files when you need a new hook point
- if a core file must change, keep the change small and generic

Example route mount:

```js
const express = require('express')

module.exports.mountRoutes = async (app) => {
  const router = express.Router()

  router.get('/health', (req, res) => {
    res.json({ ok: true, source: 'custom' })
  })

  app.use('/admin/custom', router)
}
```
