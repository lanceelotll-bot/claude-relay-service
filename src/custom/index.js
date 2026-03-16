const express = require('express')
const axios = require('axios')
const { authenticateAdmin } = require('../middleware/auth')
const logger = require('../utils/logger')
const ProxyHelper = require('../utils/proxyHelper')

const claudeAccountService = require('../services/account/claudeAccountService')
const claudeConsoleAccountService = require('../services/account/claudeConsoleAccountService')
const bedrockAccountService = require('../services/account/bedrockAccountService')
const geminiAccountService = require('../services/account/geminiAccountService')
const geminiApiAccountService = require('../services/account/geminiApiAccountService')
const openaiAccountService = require('../services/account/openaiAccountService')
const openaiResponsesAccountService = require('../services/account/openaiResponsesAccountService')
const azureOpenaiAccountService = require('../services/account/azureOpenaiAccountService')
const droidAccountService = require('../services/account/droidAccountService')
const ccrAccountService = require('../services/account/ccrAccountService')

const noop = async () => {}
const proxyCenterRouter = express.Router()

const PROXY_TEST_TARGETS = {
  anthropic: 'https://api.anthropic.com/v1/messages',
  openai: 'https://api.openai.com/v1/models',
  gemini: 'https://generativelanguage.googleapis.com/v1beta/models'
}

const PLATFORM_LOADERS = [
  { platform: 'claude', fetch: () => claudeAccountService.getAllAccounts() },
  { platform: 'claude-console', fetch: () => claudeConsoleAccountService.getAllAccounts() },
  { platform: 'bedrock', fetch: () => bedrockAccountService.getAllAccounts() },
  { platform: 'gemini', fetch: () => geminiAccountService.getAllAccounts() },
  { platform: 'gemini-api', fetch: () => geminiApiAccountService.getAllAccounts(true) },
  { platform: 'openai', fetch: () => openaiAccountService.getAllAccounts() },
  { platform: 'openai-responses', fetch: () => openaiResponsesAccountService.getAllAccounts(true) },
  { platform: 'azure-openai', fetch: () => azureOpenaiAccountService.getAllAccounts() },
  { platform: 'droid', fetch: () => droidAccountService.getAllAccounts() },
  { platform: 'ccr', fetch: () => ccrAccountService.getAllAccounts() }
]

function toBoolean(value, fallback = false) {
  if (typeof value === 'boolean') {
    return value
  }
  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase()
    if (['true', '1', 'yes', 'on'].includes(normalized)) {
      return true
    }
    if (['false', '0', 'no', 'off'].includes(normalized)) {
      return false
    }
  }
  return fallback
}

function normalizeProxyConfig(rawProxy) {
  if (!rawProxy) {
    return null
  }

  let proxyObject = rawProxy
  if (typeof rawProxy === 'string') {
    try {
      proxyObject = JSON.parse(rawProxy)
    } catch (error) {
      return null
    }
  }

  if (
    proxyObject &&
    typeof proxyObject === 'object' &&
    proxyObject.proxy &&
    typeof proxyObject.proxy === 'object'
  ) {
    proxyObject = proxyObject.proxy
  }

  if (!proxyObject || typeof proxyObject !== 'object') {
    return null
  }

  const host =
    typeof proxyObject.host === 'string'
      ? proxyObject.host.trim()
      : proxyObject.host !== undefined && proxyObject.host !== null
        ? String(proxyObject.host).trim()
        : ''
  const port =
    proxyObject.port !== undefined && proxyObject.port !== null
      ? String(proxyObject.port).trim()
      : ''

  if (!host || !port) {
    return null
  }

  return {
    type:
      typeof proxyObject.type === 'string' && proxyObject.type.trim()
        ? proxyObject.type.trim().toLowerCase()
        : 'socks5',
    host,
    port: Number.parseInt(port, 10),
    username:
      typeof proxyObject.username === 'string'
        ? proxyObject.username
        : proxyObject.username !== undefined && proxyObject.username !== null
          ? String(proxyObject.username)
          : '',
    password:
      typeof proxyObject.password === 'string'
        ? proxyObject.password
        : proxyObject.password !== undefined && proxyObject.password !== null
          ? String(proxyObject.password)
          : ''
  }
}

function maskUsername(username) {
  if (!username) {
    return ''
  }
  if (username.length <= 2) {
    return username
  }
  return `${username[0]}***${username[username.length - 1]}`
}

function buildProxyKey(proxy) {
  const username = proxy.username || ''
  return `${proxy.type}://${username}@${proxy.host}:${proxy.port}`
}

function resolveAccountStatus(account) {
  const status = account.status || 'unknown'
  const isActive = toBoolean(account.isActive, true)
  const rateLimited = Boolean(
    account.rateLimitInfo?.isRateLimited || account.rateLimitStatus === 'limited'
  )
  const hasError =
    ['error', 'blocked', 'unauthorized', 'disabled', 'invalid'].includes(status) ||
    Boolean(account.errorMessage)

  return {
    status,
    isActive,
    rateLimited,
    hasError
  }
}

function computeProxyStatus(stats) {
  if (stats.errorAccounts > 0) {
    return 'error'
  }
  if (stats.inactiveAccounts > 0 || stats.rateLimitedAccounts > 0) {
    return 'warning'
  }
  return 'healthy'
}

async function collectAccounts() {
  const allAccounts = []
  const errors = []

  for (const loader of PLATFORM_LOADERS) {
    try {
      const accounts = await loader.fetch()
      for (const account of accounts || []) {
        allAccounts.push({
          platform: loader.platform,
          id: account.id,
          name: account.name || account.email || account.accountName || account.id,
          status: account.status || '',
          isActive: account.isActive,
          schedulable: account.schedulable,
          rateLimitInfo: account.rateLimitInfo || null,
          rateLimitStatus: account.rateLimitStatus || '',
          errorMessage: account.errorMessage || '',
          proxy: account.proxy || null
        })
      }
    } catch (error) {
      errors.push({ platform: loader.platform, message: error.message })
      logger.warn(`[proxy-center] failed to load accounts for ${loader.platform}: ${error.message}`)
    }
  }

  return { allAccounts, errors }
}

async function buildProxyOverview() {
  const { allAccounts, errors } = await collectAccounts()
  const proxyMap = new Map()

  for (const account of allAccounts) {
    const proxy = normalizeProxyConfig(account.proxy)
    if (!proxy) {
      continue
    }

    const proxyKey = buildProxyKey(proxy)
    if (!proxyMap.has(proxyKey)) {
      proxyMap.set(proxyKey, {
        key: proxyKey,
        proxy: {
          type: proxy.type,
          host: proxy.host,
          port: proxy.port,
          authEnabled: Boolean(proxy.username),
          usernameMasked: maskUsername(proxy.username)
        },
        _rawProxy: proxy,
        stats: {
          totalAccounts: 0,
          activeAccounts: 0,
          inactiveAccounts: 0,
          rateLimitedAccounts: 0,
          errorAccounts: 0
        },
        accounts: []
      })
    }

    const group = proxyMap.get(proxyKey)
    const statusInfo = resolveAccountStatus(account)
    group.stats.totalAccounts += 1
    group.stats.activeAccounts += statusInfo.isActive ? 1 : 0
    group.stats.inactiveAccounts += statusInfo.isActive ? 0 : 1
    group.stats.rateLimitedAccounts += statusInfo.rateLimited ? 1 : 0
    group.stats.errorAccounts += statusInfo.hasError ? 1 : 0

    group.accounts.push({
      id: account.id,
      name: account.name,
      platform: account.platform,
      status: statusInfo.status,
      isActive: statusInfo.isActive,
      rateLimited: statusInfo.rateLimited,
      hasError: statusInfo.hasError,
      schedulable: toBoolean(account.schedulable, true),
      errorMessage: account.errorMessage || ''
    })
  }

  const proxies = Array.from(proxyMap.values())
    .map((item) => {
      const mapped = { ...item }
      delete mapped._rawProxy
      mapped.status = computeProxyStatus(mapped.stats)
      mapped.accounts.sort((a, b) => a.platform.localeCompare(b.platform) || a.name.localeCompare(b.name))
      return mapped
    })
    .sort((a, b) => {
      if (b.stats.totalAccounts !== a.stats.totalAccounts) {
        return b.stats.totalAccounts - a.stats.totalAccounts
      }
      return `${a.proxy.type}-${a.proxy.host}-${a.proxy.port}`.localeCompare(
        `${b.proxy.type}-${b.proxy.host}-${b.proxy.port}`
      )
    })

  const proxyKeyToRawProxy = {}
  for (const [key, value] of proxyMap.entries()) {
    proxyKeyToRawProxy[key] = value._rawProxy
  }

  return {
    proxies,
    proxyKeyToRawProxy,
    summary: {
      totalAccounts: allAccounts.length,
      accountsWithProxy: proxies.reduce((sum, item) => sum + item.stats.totalAccounts, 0),
      totalProxies: proxies.length
    },
    sourceErrors: errors
  }
}

proxyCenterRouter.get('/proxy-center/overview', authenticateAdmin, async (req, res) => {
  try {
    const overview = await buildProxyOverview()
    return res.json({
      success: true,
      data: {
        proxies: overview.proxies,
        summary: overview.summary,
        sourceErrors: overview.sourceErrors,
        generatedAt: new Date().toISOString()
      }
    })
  } catch (error) {
    logger.error('[proxy-center] failed to build overview:', error)
    return res.status(500).json({
      success: false,
      message: `Failed to build proxy overview: ${error.message}`
    })
  }
})

proxyCenterRouter.post('/proxy-center/test', authenticateAdmin, async (req, res) => {
  const { proxyKey, target = 'anthropic' } = req.body || {}
  if (!proxyKey) {
    return res.status(400).json({ success: false, message: 'proxyKey is required' })
  }

  const targetUrl = PROXY_TEST_TARGETS[target] || PROXY_TEST_TARGETS.anthropic

  try {
    const overview = await buildProxyOverview()
    const rawProxy = overview.proxyKeyToRawProxy[proxyKey]
    if (!rawProxy) {
      return res.status(404).json({ success: false, message: 'Proxy not found' })
    }

    const proxyAgent = ProxyHelper.createProxyAgent(rawProxy)
    if (!proxyAgent) {
      return res.status(400).json({ success: false, message: 'Invalid proxy config' })
    }

    const start = Date.now()
    let response
    try {
      response = await axios.get(targetUrl, {
        timeout: 15000,
        proxy: false,
        httpAgent: proxyAgent,
        httpsAgent: proxyAgent,
        validateStatus: () => true,
        headers: {
          'User-Agent': 'CRS-Proxy-Center/1.0'
        }
      })
    } catch (networkError) {
      const latency = Date.now() - start
      return res.json({
        success: true,
        data: {
          proxyKey,
          target,
          targetUrl,
          reachable: false,
          httpStatus: null,
          latency,
          message: networkError.message || 'Network error'
        }
      })
    }

    const latency = Date.now() - start
    return res.json({
      success: true,
      data: {
        proxyKey,
        target,
        targetUrl,
        reachable: true,
        httpStatus: response.status,
        latency,
        message:
          response.status >= 200 && response.status < 400
            ? 'Proxy reachable'
            : `Proxy reachable, upstream returned ${response.status}`
      }
    })
  } catch (error) {
    logger.error('[proxy-center] proxy test failed:', error)
    return res.status(500).json({
      success: false,
      message: `Proxy test failed: ${error.message}`
    })
  }
})

module.exports = {
  /**
   * 在核心服务初始化完成后触发。
   * 适合放你自己的二开初始化逻辑，比如读取自定义配置、预热缓存、注册任务。
   */
  afterCoreInitialized: noop,

  /**
   * 在默认路由挂载后、404 之前触发。
   * 适合挂载你自己的扩展路由，比如 /admin/custom/* 或 /api/custom/*。
   */
  mountRoutes: async (app) => {
    app.use('/admin/custom', proxyCenterRouter)
    logger.info('Custom extension layer ready: src/custom (proxy-center enabled)')
  }
}
