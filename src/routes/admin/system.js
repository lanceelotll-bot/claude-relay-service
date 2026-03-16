const express = require('express')
const fs = require('fs')
const path = require('path')
const axios = require('axios')
const util = require('util')
const { execFile } = require('child_process')
const claudeCodeHeadersService = require('../../services/claudeCodeHeadersService')
const claudeAccountService = require('../../services/account/claudeAccountService')
const redis = require('../../models/redis')
const { authenticateAdmin } = require('../../middleware/auth')
const logger = require('../../utils/logger')
const config = require('../../../config/config')

const router = express.Router()
const execFileAsync = util.promisify(execFile)
const repoRoot = path.join(__dirname, '../../../')

// ==================== Claude Code Headers 管理 ====================

// 获取所有 Claude Code headers
router.get('/claude-code-headers', authenticateAdmin, async (req, res) => {
  try {
    const allHeaders = await claudeCodeHeadersService.getAllAccountHeaders()

    // 获取所有 Claude 账号信息
    const accounts = await claudeAccountService.getAllAccounts()
    const accountMap = {}
    accounts.forEach((account) => {
      accountMap[account.id] = account.name
    })

    // 格式化输出
    const formattedData = Object.entries(allHeaders).map(([accountId, data]) => ({
      accountId,
      accountName: accountMap[accountId] || 'Unknown',
      version: data.version,
      userAgent: data.headers['user-agent'],
      updatedAt: data.updatedAt,
      headers: data.headers
    }))

    return res.json({
      success: true,
      data: formattedData
    })
  } catch (error) {
    logger.error('❌ Failed to get Claude Code headers:', error)
    return res
      .status(500)
      .json({ error: 'Failed to get Claude Code headers', message: error.message })
  }
})

// 🗑️ 清除指定账号的 Claude Code headers
router.delete('/claude-code-headers/:accountId', authenticateAdmin, async (req, res) => {
  try {
    const { accountId } = req.params
    await claudeCodeHeadersService.clearAccountHeaders(accountId)

    return res.json({
      success: true,
      message: `Claude Code headers cleared for account ${accountId}`
    })
  } catch (error) {
    logger.error('❌ Failed to clear Claude Code headers:', error)
    return res
      .status(500)
      .json({ error: 'Failed to clear Claude Code headers', message: error.message })
  }
})

// ==================== 系统更新检查 ====================

function compareVersions(current, latest) {
  const parseVersion = (v) => {
    const parts = String(v || '')
      .split('.')
      .map(Number)
    return {
      major: parts[0] || 0,
      minor: parts[1] || 0,
      patch: parts[2] || 0
    }
  }

  const currentV = parseVersion(current)
  const latestV = parseVersion(latest)

  if (currentV.major !== latestV.major) {
    return currentV.major - latestV.major
  }
  if (currentV.minor !== latestV.minor) {
    return currentV.minor - latestV.minor
  }
  return currentV.patch - latestV.patch
}

function isPanelUpdateEnabled() {
  const value = process.env.WEB_UPDATE_ENABLED
  if (typeof value !== 'string') {
    return false
  }

  const normalized = value.trim().toLowerCase()
  return normalized === 'true' || normalized === '1' || normalized === 'yes' || normalized === 'on'
}

function readLocalVersion() {
  const versionPath = path.join(repoRoot, 'VERSION')
  try {
    return fs.readFileSync(versionPath, 'utf8').trim()
  } catch (err) {
    logger.warn('⚠️ Could not read VERSION file:', err.message)
    return '1.0.0'
  }
}

function normalizeGithubRepo(remoteUrl) {
  if (!remoteUrl) {
    return ''
  }

  const normalized = remoteUrl.trim().replace(/\.git$/, '')
  const match = normalized.match(/github\.com[:/]([^/]+\/[^/]+)$/i)
  return match ? match[1] : ''
}

async function runGit(args, options = {}) {
  const { stdout } = await execFileAsync('git', args, {
    cwd: repoRoot,
    timeout: 15000,
    maxBuffer: 1024 * 1024,
    ...options
  })

  return stdout.trim()
}

async function getUpstreamVersionStatus(forceRefresh = false) {
  const currentVersion = readLocalVersion()
  const cacheKey = 'version_check_cache:upstream'
  const client = redis.getClient()

  try {
    const cached = await client.get(cacheKey)
    if (cached && !forceRefresh) {
      const cachedData = JSON.parse(cached)
      const cacheAge = Date.now() - cachedData.timestamp

      if (cacheAge < 3600000) {
        return {
          source: 'upstream',
          label: '上游版本',
          current: currentVersion,
          latest: cachedData.latest,
          hasUpdate: compareVersions(currentVersion, cachedData.latest) < 0,
          releaseInfo: cachedData.releaseInfo,
          cached: true,
          canSyncInPanel: isPanelUpdateEnabled(),
          warning: cachedData.warning || ''
        }
      }
    }

    const githubRepo = 'wei-shaw/claude-relay-service'
    const response = await axios.get(`https://api.github.com/repos/${githubRepo}/releases/latest`, {
      headers: {
        Accept: 'application/vnd.github.v3+json',
        'User-Agent': 'Claude-Relay-Service'
      },
      timeout: 10000
    })

    const release = response.data
    const latestVersion = String(release.tag_name || '').replace(/^v/, '') || currentVersion
    const releaseInfo = {
      name: release.name,
      body: release.body,
      publishedAt: release.published_at,
      htmlUrl: release.html_url
    }

    await client.set(
      cacheKey,
      JSON.stringify({
        latest: latestVersion,
        releaseInfo,
        timestamp: Date.now()
      }),
      'EX',
      3600
    )

    return {
      source: 'upstream',
      label: '上游版本',
      current: currentVersion,
      latest: latestVersion,
      hasUpdate: compareVersions(currentVersion, latestVersion) < 0,
      releaseInfo,
      cached: false,
      canSyncInPanel: isPanelUpdateEnabled(),
      warning: ''
    }
  } catch (error) {
    const message = error.message || 'Failed to check upstream updates'

    if (error.response && error.response.status === 404) {
      return {
        source: 'upstream',
        label: '上游版本',
        current: currentVersion,
        latest: currentVersion,
        hasUpdate: false,
        releaseInfo: {
          name: 'No releases found',
          body: 'The upstream repository has no releases yet.',
          publishedAt: new Date().toISOString(),
          htmlUrl: '#'
        },
        cached: false,
        canSyncInPanel: isPanelUpdateEnabled(),
        warning: '上游仓库暂未发布 release'
      }
    }

    if (['ECONNREFUSED', 'ETIMEDOUT', 'ENOTFOUND'].includes(error.code)) {
      const cached = await client.get(cacheKey)
      if (cached) {
        const cachedData = JSON.parse(cached)
        return {
          source: 'upstream',
          label: '上游版本',
          current: currentVersion,
          latest: cachedData.latest,
          hasUpdate: compareVersions(currentVersion, cachedData.latest) < 0,
          releaseInfo: cachedData.releaseInfo,
          cached: true,
          canSyncInPanel: isPanelUpdateEnabled(),
          warning: '网络异常，当前显示缓存的上游版本信息'
        }
      }
    }

    logger.error('❌ Failed to check upstream updates:', message)
    return {
      source: 'upstream',
      label: '上游版本',
      current: currentVersion,
      latest: currentVersion,
      hasUpdate: false,
      releaseInfo: {
        name: 'Update check failed',
        body: `Unable to check for updates: ${message}`,
        publishedAt: new Date().toISOString(),
        htmlUrl: '#'
      },
      cached: false,
      canSyncInPanel: isPanelUpdateEnabled(),
      warning: message
    }
  }
}

async function getCustomVersionStatus(forceRefresh = false) {
  const cacheKey = 'version_check_cache:custom'
  const client = redis.getClient()

  try {
    const branchRaw = await runGit(['rev-parse', '--abbrev-ref', 'HEAD'])
    const currentBranch = branchRaw && branchRaw !== 'HEAD' ? branchRaw : process.env.CUSTOM_UPDATE_BRANCH || 'develop'
    const currentCommit = await runGit(['rev-parse', 'HEAD'])
    const currentShortCommit = await runGit(['rev-parse', '--short', 'HEAD'])
    const originUrl = await runGit(['config', '--get', 'remote.origin.url'])
    const originRepo = normalizeGithubRepo(originUrl)

    if (!originRepo) {
      return {
        source: 'custom',
        label: '二开版本',
        branch: currentBranch,
        repo: '',
        current: `${currentBranch}@${currentShortCommit}`,
        latest: `${currentBranch}@${currentShortCommit}`,
        hasUpdate: false,
        compareUrl: '',
        branchUrl: '',
        warning: '未检测到 origin GitHub 仓库，暂时无法检查二开更新',
        cached: false
      }
    }

    const cached = await client.get(cacheKey)
    if (cached && !forceRefresh) {
      const cachedData = JSON.parse(cached)
      const cacheAge = Date.now() - cachedData.timestamp
      if (
        cacheAge < 300000 &&
        cachedData.currentCommit === currentCommit &&
        cachedData.branch === currentBranch &&
        cachedData.repo === originRepo
      ) {
        return cachedData.payload
      }
    }

    await runGit(['fetch', 'origin', currentBranch, '--prune'])

    const remoteRef = `origin/${currentBranch}`
    const remoteCommit = await runGit(['rev-parse', remoteRef])
    const remoteShortCommit = await runGit(['rev-parse', '--short', remoteRef])
    const counts = await runGit(['rev-list', '--left-right', '--count', `HEAD...${remoteRef}`])
    const [aheadCountRaw, behindCountRaw] = counts.split(/\s+/)
    const aheadCount = Number(aheadCountRaw || 0)
    const behindCount = Number(behindCountRaw || 0)
    const hasUpdate = behindCount > 0
    const compareUrl = `https://github.com/${originRepo}/compare/${currentCommit}...${currentBranch}`
    const branchUrl = `https://github.com/${originRepo}/tree/${currentBranch}`

    const payload = {
      source: 'custom',
      label: '二开版本',
      branch: currentBranch,
      repo: originRepo,
      current: `${currentBranch}@${currentShortCommit}`,
      latest: `${currentBranch}@${remoteShortCommit}`,
      hasUpdate,
      compareUrl,
      branchUrl,
      releaseInfo: {
        name: `${currentBranch} 分支`,
        body: hasUpdate
          ? `你的本地部署落后于 origin/${currentBranch}，可先查看差异再决定是否拉取。`
          : `当前部署已经对齐 origin/${currentBranch}。`,
        publishedAt: new Date().toISOString(),
        htmlUrl: hasUpdate ? compareUrl : branchUrl
      },
      cached: false,
      warning: '',
      aheadCount,
      behindCount,
      currentCommit,
      remoteCommit
    }

    await client.set(
      cacheKey,
      JSON.stringify({
        timestamp: Date.now(),
        currentCommit,
        branch: currentBranch,
        repo: originRepo,
        payload
      }),
      'EX',
      300
    )

    return payload
  } catch (error) {
    const message = error.message || 'Failed to check custom updates'
    logger.warn('⚠️ Failed to check custom updates:', message)

    return {
      source: 'custom',
      label: '二开版本',
      branch: process.env.CUSTOM_UPDATE_BRANCH || 'develop',
      repo: '',
      current: 'unknown',
      latest: 'unknown',
      hasUpdate: false,
      compareUrl: '',
      branchUrl: '',
      warning: `无法检查二开更新：${message}`,
      cached: false,
      releaseInfo: {
        name: 'Custom update check failed',
        body: message,
        publishedAt: new Date().toISOString(),
        htmlUrl: '#'
      }
    }
  }
}

router.get('/check-updates', authenticateAdmin, async (req, res) => {
  const forceRefresh = Boolean(req.query.force)
  const [upstream, custom] = await Promise.all([
    getUpstreamVersionStatus(forceRefresh),
    getCustomVersionStatus(forceRefresh)
  ])

  return res.json({
    success: true,
    data: {
      upstream,
      custom,
      canSyncInPanel: upstream.canSyncInPanel === true
    }
  })
})

router.post('/sync-updates', authenticateAdmin, async (req, res) => {
  if (!isPanelUpdateEnabled()) {
    return res.status(403).json({
      success: false,
      message: '页面内更新未启用，请设置 WEB_UPDATE_ENABLED=true 后重试'
    })
  }

  const syncScript = path.join(repoRoot, 'scripts/git-create-sync-branch.sh')

  if (!fs.existsSync(syncScript)) {
    return res.status(500).json({
      success: false,
      message: '未找到同步脚本 scripts/git-create-sync-branch.sh'
    })
  }

  try {
    const { stdout, stderr } = await execFileAsync('/bin/bash', [syncScript], {
      cwd: repoRoot,
      timeout: 5 * 60 * 1000,
      maxBuffer: 1024 * 1024
    })

    const output = [stdout, stderr].filter(Boolean).join('\n').trim()
    const branchMatch = output.match(/SYNC_BRANCH=(.+)/)
    const compareUrlMatch = output.match(/COMPARE_URL=(.+)/)
    const syncBranch = branchMatch ? branchMatch[1].trim() : ''
    const compareUrl = compareUrlMatch ? compareUrlMatch[1].trim() : ''

    logger.info(`✅ Panel update sync branch prepared successfully: ${syncBranch || 'unknown'}`)

    return res.json({
      success: true,
      message: '已创建上游同步分支，请审核确认后再合并进 develop',
      data: {
        output,
        syncBranch,
        compareUrl
      }
    })
  } catch (error) {
    const output = [error.stdout || '', error.stderr || '', error.message || 'Unknown error']
      .filter(Boolean)
      .join('\n')
      .trim()

    logger.error('❌ Panel update sync failed:', output)

    return res.status(500).json({
      success: false,
      message: '创建同步分支失败，常见原因是上游合并冲突或 Git 远程配置异常',
      data: {
        output
      }
    })
  }
})

// ==================== OEM 设置管理 ====================

// 获取OEM设置（公开接口，用于显示）
// 注意：这个端点没有 authenticateAdmin 中间件，因为前端登录页也需要访问
router.get('/oem-settings', async (req, res) => {
  try {
    const client = redis.getClient()
    const oemSettings = await client.get('oem:settings')

    // 默认设置
    const defaultSettings = {
      siteName: 'CRS Lance 二开版',
      siteIcon: '',
      siteIconData: '', // Base64编码的图标数据
      showAdminButton: true, // 是否显示管理后台按钮
      apiStatsNotice: {
        enabled: false,
        title: '',
        content: ''
      },
      updatedAt: new Date().toISOString()
    }

    let settings = defaultSettings
    if (oemSettings) {
      try {
        settings = { ...defaultSettings, ...JSON.parse(oemSettings) }
      } catch (err) {
        logger.warn('⚠️ Failed to parse OEM settings, using defaults:', err.message)
      }
    }

    // 添加 LDAP 启用状态到响应中
    return res.json({
      success: true,
      data: {
        ...settings,
        ldapEnabled: config.ldap && config.ldap.enabled === true
      }
    })
  } catch (error) {
    logger.error('❌ Failed to get OEM settings:', error)
    return res.status(500).json({ error: 'Failed to get OEM settings', message: error.message })
  }
})

// 更新OEM设置
router.put('/oem-settings', authenticateAdmin, async (req, res) => {
  try {
    const { siteName, siteIcon, siteIconData, showAdminButton, apiStatsNotice } = req.body

    // 验证输入
    if (!siteName || typeof siteName !== 'string' || siteName.trim().length === 0) {
      return res.status(400).json({ error: 'Site name is required' })
    }

    if (siteName.length > 100) {
      return res.status(400).json({ error: 'Site name must be less than 100 characters' })
    }

    // 验证图标数据大小（如果是base64）
    if (siteIconData && siteIconData.length > 500000) {
      // 约375KB
      return res.status(400).json({ error: 'Icon file must be less than 350KB' })
    }

    // 验证图标URL（如果提供）
    if (siteIcon && !siteIconData) {
      // 简单验证URL格式
      try {
        new URL(siteIcon)
      } catch (err) {
        return res.status(400).json({ error: 'Invalid icon URL format' })
      }
    }

    const settings = {
      siteName: siteName.trim(),
      siteIcon: (siteIcon || '').trim(),
      siteIconData: siteIconData || '',
      showAdminButton: showAdminButton !== false,
      apiStatsNotice: {
        enabled: apiStatsNotice && apiStatsNotice.enabled === true,
        title: (apiStatsNotice && apiStatsNotice.title ? apiStatsNotice.title : '').trim(),
        content: (apiStatsNotice && apiStatsNotice.content ? apiStatsNotice.content : '').trim()
      },
      updatedAt: new Date().toISOString()
    }

    const client = redis.getClient()
    await client.set('oem:settings', JSON.stringify(settings))

    return res.json({ success: true, data: settings })
  } catch (error) {
    logger.error('❌ Failed to update OEM settings:', error)
    return res.status(500).json({ error: 'Failed to update OEM settings', message: error.message })
  }
})

module.exports = router
