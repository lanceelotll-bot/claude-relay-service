const MainLayout = () => import('@/components/layout/MainLayout.vue')
const ProxyCenterView = () => import('@/custom/views/ProxyCenterView.vue')

export const getCustomRoutes = () => [
  {
    path: '/proxy-center',
    component: MainLayout,
    meta: { requiresAuth: true },
    children: [
      {
        path: '',
        name: 'ProxyCenter',
        component: ProxyCenterView
      }
    ]
  }
]

export const getCustomTabs = () => [
  {
    key: 'proxyCenter',
    name: '代理中心',
    shortName: '代理',
    icon: 'fas fa-network-wired',
    path: '/proxy-center'
  }
]
