# Frontend Secondary Development

Put custom admin pages here to reduce merge conflicts with upstream updates.

Recommended structure:

- `web/admin-spa/src/custom/views/`: custom pages
- `web/admin-spa/src/custom/components/`: custom UI pieces
- `web/admin-spa/src/custom/stores/`: custom state modules
- `web/admin-spa/src/custom/api/`: custom request wrappers

Register custom routes and tabs in `web/admin-spa/src/custom/index.js`.

Example:

```js
const CustomOpsView = () => import('./views/CustomOpsView.vue')

export const getCustomRoutes = () => [
  {
    path: '/custom-ops',
    component: () => import('@/components/layout/MainLayout.vue'),
    meta: { requiresAuth: true },
    children: [
      {
        path: '',
        name: 'CustomOps',
        component: CustomOpsView
      }
    ]
  }
]

export const getCustomTabs = () => [
  {
    key: 'customOps',
    name: '自定义运营',
    shortName: '运营',
    icon: 'fas fa-compass',
    path: '/custom-ops'
  }
]
```
