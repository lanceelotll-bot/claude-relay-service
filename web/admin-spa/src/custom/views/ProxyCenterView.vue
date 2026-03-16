<template>
  <div class="space-y-6">
    <section
      class="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm dark:border-gray-700 dark:bg-gray-800"
    >
      <div class="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 class="text-lg font-semibold text-gray-900 dark:text-gray-100">代理中心</h2>
          <p class="text-sm text-gray-500 dark:text-gray-400">
            查看当前所有代理、绑定账号和实时连通性状态
          </p>
        </div>
        <div class="flex items-center gap-2">
          <select
            v-model="testTarget"
            class="rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-700 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-200"
          >
            <option value="anthropic">Anthropic</option>
            <option value="openai">OpenAI</option>
            <option value="gemini">Gemini</option>
          </select>
          <button
            class="rounded-lg bg-blue-600 px-3 py-2 text-sm font-medium text-white transition hover:bg-blue-700 disabled:cursor-not-allowed disabled:opacity-60"
            :disabled="loading"
            @click="loadOverview"
          >
            <i :class="loading ? 'fas fa-spinner fa-spin mr-1' : 'fas fa-sync-alt mr-1'" />
            {{ loading ? '刷新中' : '刷新' }}
          </button>
        </div>
      </div>

      <div class="mt-4 grid gap-3 sm:grid-cols-3">
        <div
          class="rounded-xl border border-gray-100 bg-gray-50 p-3 dark:border-gray-700 dark:bg-gray-900/30"
        >
          <p class="text-xs text-gray-500 dark:text-gray-400">代理总数</p>
          <p class="mt-1 text-2xl font-semibold text-gray-900 dark:text-gray-100">
            {{ summary.totalProxies }}
          </p>
        </div>
        <div
          class="rounded-xl border border-gray-100 bg-gray-50 p-3 dark:border-gray-700 dark:bg-gray-900/30"
        >
          <p class="text-xs text-gray-500 dark:text-gray-400">使用代理账号</p>
          <p class="mt-1 text-2xl font-semibold text-gray-900 dark:text-gray-100">
            {{ summary.accountsWithProxy }}
          </p>
        </div>
        <div
          class="rounded-xl border border-gray-100 bg-gray-50 p-3 dark:border-gray-700 dark:bg-gray-900/30"
        >
          <p class="text-xs text-gray-500 dark:text-gray-400">账号总数</p>
          <p class="mt-1 text-2xl font-semibold text-gray-900 dark:text-gray-100">
            {{ summary.totalAccounts }}
          </p>
        </div>
      </div>

      <div v-if="sourceErrors.length" class="mt-3">
        <button
          class="inline-flex items-center gap-1 rounded-md border border-amber-200 bg-amber-50 px-2 py-1 text-xs text-amber-700 transition hover:bg-amber-100 dark:border-amber-700 dark:bg-amber-900/20 dark:text-amber-300 dark:hover:bg-amber-900/40"
          @click="showSourceErrors = !showSourceErrors"
        >
          <i :class="showSourceErrors ? 'fas fa-chevron-down' : 'fas fa-chevron-right'" />
          加载告警 {{ sourceErrors.length }} 条
        </button>
        <div
          v-if="showSourceErrors"
          class="mt-2 rounded-lg border border-amber-200 bg-amber-50 p-2 text-xs text-amber-700 dark:border-amber-700 dark:bg-amber-900/20 dark:text-amber-300"
        >
          <div v-for="item in sourceErrors" :key="item.platform" class="mb-1 last:mb-0">
            {{ item.platform }}: {{ item.message }}
          </div>
        </div>
      </div>
    </section>

    <section
      class="overflow-hidden rounded-2xl border border-gray-200 bg-white shadow-sm dark:border-gray-700 dark:bg-gray-800"
    >
      <div
        v-if="loading"
        class="flex items-center justify-center gap-2 p-8 text-sm text-gray-500 dark:text-gray-400"
      >
        <i class="fas fa-spinner fa-spin" />
        正在加载代理信息...
      </div>

      <div
        v-else-if="proxies.length === 0"
        class="p-8 text-center text-sm text-gray-500 dark:text-gray-400"
      >
        暂无代理配置
      </div>

      <div v-else class="divide-y divide-gray-100 dark:divide-gray-700">
        <div v-for="proxy in proxies" :key="proxy.key" class="p-4">
          <div class="flex flex-wrap items-start justify-between gap-3">
            <div>
              <div class="flex flex-wrap items-center gap-2">
                <span
                  class="rounded-md bg-gray-100 px-2 py-1 text-xs font-semibold text-gray-700 dark:bg-gray-700 dark:text-gray-200"
                >
                  {{ proxy.proxy.type.toUpperCase() }}
                </span>
                <span class="font-mono text-sm text-gray-800 dark:text-gray-100">
                  {{ proxy.proxy.host }}:{{ proxy.proxy.port }}
                </span>
                <span
                  class="rounded-full px-2 py-0.5 text-xs font-semibold"
                  :class="proxyStatusClass(proxy.status)"
                >
                  {{ proxyStatusText(proxy.status) }}
                </span>
                <span
                  v-if="proxy.proxy.authEnabled"
                  class="rounded-full bg-indigo-100 px-2 py-0.5 text-xs font-semibold text-indigo-700 dark:bg-indigo-500/20 dark:text-indigo-300"
                >
                  鉴权 {{ proxy.proxy.usernameMasked || 'enabled' }}
                </span>
              </div>
              <div class="mt-2 flex flex-wrap gap-2 text-xs text-gray-500 dark:text-gray-400">
                <span>绑定账号 {{ proxy.stats.totalAccounts }}</span>
                <span>可用 {{ proxy.stats.activeAccounts }}</span>
                <span>停用 {{ proxy.stats.inactiveAccounts }}</span>
                <span>限流 {{ proxy.stats.rateLimitedAccounts }}</span>
                <span>异常 {{ proxy.stats.errorAccounts }}</span>
              </div>
            </div>
            <div class="flex items-center gap-2">
              <button
                class="rounded-lg bg-emerald-600 px-3 py-2 text-xs font-semibold text-white transition hover:bg-emerald-700 disabled:cursor-not-allowed disabled:opacity-60"
                :disabled="isTesting(proxy.key)"
                @click="testProxy(proxy.key)"
              >
                <i
                  :class="
                    isTesting(proxy.key) ? 'fas fa-spinner fa-spin mr-1' : 'fas fa-heartbeat mr-1'
                  "
                />
                {{ isTesting(proxy.key) ? '测试中' : '测试代理' }}
              </button>
            </div>
          </div>

          <div
            v-if="testResults[proxy.key]"
            class="mt-3 rounded-lg border p-3 text-xs"
            :class="testResultClass(testResults[proxy.key])"
          >
            <p class="font-semibold">{{ testResults[proxy.key].message }}</p>
            <p class="mt-1">
              延迟：{{ testResults[proxy.key].latency }}ms
              <span v-if="testResults[proxy.key].httpStatus !== null">
                ，HTTP：{{ testResults[proxy.key].httpStatus }}
              </span>
            </p>
            <p class="mt-1 text-[11px] opacity-80">目标：{{ testResults[proxy.key].targetUrl }}</p>
          </div>

          <div class="mt-3 flex flex-wrap gap-2">
            <span
              v-for="account in proxy.accounts"
              :key="account.id"
              class="inline-flex items-center gap-1 rounded-full border px-2 py-1 text-xs"
              :class="accountTagClass(account)"
            >
              <span>{{ account.platform }}</span>
              <span>{{ account.name }}</span>
            </span>
          </div>
        </div>
      </div>
    </section>
  </div>
</template>

<script setup>
import { onMounted, ref } from 'vue'
import request from '@/utils/request'
import { showToast } from '@/utils/tools'

const loading = ref(false)
const proxies = ref([])
const summary = ref({
  totalProxies: 0,
  accountsWithProxy: 0,
  totalAccounts: 0
})
const sourceErrors = ref([])
const showSourceErrors = ref(false)
const testTarget = ref('anthropic')
const testingState = ref({})
const testResults = ref({})

const loadOverview = async () => {
  loading.value = true
  const result = await request({
    url: '/admin/custom/proxy-center/overview',
    method: 'GET'
  })
  loading.value = false

  if (!result.success) {
    showToast(result.message || '加载代理中心失败', 'error')
    return
  }

  proxies.value = result.data?.proxies || []
  summary.value = result.data?.summary || summary.value
  sourceErrors.value = result.data?.sourceErrors || []
  showSourceErrors.value = false
}

const isTesting = (proxyKey) => Boolean(testingState.value[proxyKey])

const testProxy = async (proxyKey) => {
  testingState.value = { ...testingState.value, [proxyKey]: true }
  const result = await request({
    url: '/admin/custom/proxy-center/test',
    method: 'POST',
    data: {
      proxyKey,
      target: testTarget.value
    }
  })
  testingState.value = { ...testingState.value, [proxyKey]: false }

  if (!result.success) {
    showToast(result.message || '代理测试失败', 'error')
    return
  }

  const data = result.data || {}
  testResults.value = {
    ...testResults.value,
    [proxyKey]: {
      success: Boolean(data.reachable),
      message: data.message || (data.reachable ? '代理可用' : '代理不可用'),
      latency: Number(data.latency || 0),
      httpStatus: data.httpStatus ?? null,
      targetUrl: data.targetUrl || ''
    }
  }

  showToast(
    data.reachable ? `代理可用，延迟 ${data.latency}ms` : data.message || '代理不可用',
    data.reachable ? 'success' : 'warning'
  )
}

const proxyStatusClass = (status) => {
  if (status === 'healthy') {
    return 'bg-green-100 text-green-700 dark:bg-green-500/20 dark:text-green-300'
  }
  if (status === 'warning') {
    return 'bg-amber-100 text-amber-700 dark:bg-amber-500/20 dark:text-amber-300'
  }
  return 'bg-red-100 text-red-700 dark:bg-red-500/20 dark:text-red-300'
}

const proxyStatusText = (status) => {
  if (status === 'healthy') return '健康'
  if (status === 'warning') return '注意'
  return '异常'
}

const testResultClass = (result) => {
  return result.success
    ? 'border-green-200 bg-green-50 text-green-700 dark:border-green-700 dark:bg-green-900/20 dark:text-green-300'
    : 'border-red-200 bg-red-50 text-red-700 dark:border-red-700 dark:bg-red-900/20 dark:text-red-300'
}

const accountTagClass = (account) => {
  if (account.hasError) {
    return 'border-red-200 bg-red-50 text-red-700 dark:border-red-700 dark:bg-red-900/20 dark:text-red-300'
  }
  if (account.rateLimited || !account.isActive) {
    return 'border-amber-200 bg-amber-50 text-amber-700 dark:border-amber-700 dark:bg-amber-900/20 dark:text-amber-300'
  }
  return 'border-green-200 bg-green-50 text-green-700 dark:border-green-700 dark:bg-green-900/20 dark:text-green-300'
}

onMounted(() => {
  loadOverview()
})
</script>
