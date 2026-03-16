<template>
  <!-- 顶部导航 -->
  <div
    class="glass-strong mb-4 rounded-xl p-3 shadow-xl sm:mb-6 sm:rounded-2xl sm:p-4 md:mb-8 md:rounded-3xl md:p-6"
    style="z-index: 10; position: relative"
  >
    <div class="flex flex-col items-center justify-between gap-3 sm:flex-row sm:gap-4">
      <div
        class="flex w-full items-center justify-center gap-2 sm:w-auto sm:justify-start sm:gap-3 md:gap-4"
      >
        <LogoTitle
          :loading="oemLoading"
          :logo-src="oemSettings.siteIconData || oemSettings.siteIcon"
          subtitle="管理后台"
          :title="oemSettings.siteName"
          title-class="text-white dark:text-gray-100"
        >
          <template #after-title>
            <!-- 版本信息 -->
            <div class="flex flex-wrap items-center gap-1 sm:gap-2">
              <span class="font-mono text-xs text-gray-400 dark:text-gray-500 sm:text-sm">
                上游 v{{ versionInfo.upstream.current || '...' }}
              </span>
              <a
                v-if="versionInfo.upstream.hasUpdate"
                class="inline-flex animate-pulse items-center gap-1 rounded-full border border-green-600 bg-green-500 px-2 py-0.5 text-xs text-white transition-colors hover:bg-green-600"
                :href="versionInfo.upstream.releaseInfo?.htmlUrl || '#'"
                target="_blank"
                title="上游有新版本可用"
              >
                <i class="fas fa-arrow-up text-[10px]" />
                <span>上游更新</span>
              </a>
              <span class="font-mono text-xs text-gray-400 dark:text-gray-500 sm:text-sm">
                二开 {{ versionInfo.custom.current || '...' }}
              </span>
              <a
                v-if="versionInfo.custom.hasUpdate"
                class="inline-flex items-center gap-1 rounded-full border border-amber-600 bg-amber-500 px-2 py-0.5 text-xs text-white transition-colors hover:bg-amber-600"
                :href="versionInfo.custom.compareUrl || versionInfo.custom.branchUrl || '#'"
                target="_blank"
                title="你的二开仓库有新提交可部署"
              >
                <i class="fas fa-code-branch text-[10px]" />
                <span>二开更新</span>
              </a>
            </div>
          </template>
        </LogoTitle>
      </div>
      <!-- 主题切换和用户菜单 -->
      <div class="flex items-center gap-2 sm:gap-4">
        <!-- 主题切换按钮 -->
        <div class="flex items-center">
          <ThemeToggle mode="dropdown" />
        </div>

        <!-- 分隔线 -->
        <div
          class="h-8 w-px bg-gradient-to-b from-transparent via-gray-300 to-transparent opacity-50 dark:via-gray-600"
        />

        <!-- 用户菜单 -->
        <div class="user-menu-container relative">
          <button
            class="user-menu-button flex items-center gap-2 rounded-2xl px-3 py-2 text-sm font-semibold text-white shadow-lg transition-all duration-200 hover:scale-105 hover:shadow-xl active:scale-95 sm:px-4 sm:py-2.5"
            @click="userMenuOpen = !userMenuOpen"
          >
            <i class="fas fa-user-circle text-sm sm:text-base" />
            <span class="hidden sm:inline">{{ currentUser.username || 'Admin' }}</span>
            <i
              class="fas fa-chevron-down ml-1 text-xs transition-transform duration-200"
              :class="{ 'rotate-180': userMenuOpen }"
            />
          </button>

          <!-- 悬浮菜单 -->
          <div
            v-if="userMenuOpen"
            class="user-menu-dropdown absolute right-0 top-full mt-2 w-48 rounded-xl border border-gray-200 bg-white py-2 shadow-xl dark:border-gray-700 dark:bg-gray-800 sm:w-56"
            style="z-index: 999999"
            @click.stop
          >
            <!-- 版本信息 -->
            <div class="space-y-3 border-b border-gray-100 px-4 py-3 dark:border-gray-700">
              <div class="rounded-xl border border-gray-100 p-3 dark:border-gray-700">
                <div class="flex items-center justify-between text-sm">
                  <span class="text-gray-500 dark:text-gray-400">上游版本</span>
                  <span class="font-mono text-gray-700 dark:text-gray-300">
                    v{{ versionInfo.upstream.current || '...' }}
                  </span>
                </div>
                <div v-if="versionInfo.upstream.hasUpdate" class="mt-2">
                  <div class="mb-2 flex items-center justify-between text-sm">
                    <span class="font-medium text-green-600 dark:text-green-400">
                      <i class="fas fa-arrow-up mr-1" />有上游更新
                    </span>
                    <span class="font-mono text-green-600 dark:text-green-400">
                      v{{ versionInfo.upstream.latest }}
                    </span>
                  </div>
                  <a
                    class="block w-full rounded-lg bg-green-500 px-3 py-1.5 text-center text-sm text-white transition-colors hover:bg-green-600"
                    :href="versionInfo.upstream.releaseInfo?.htmlUrl || '#'"
                    target="_blank"
                  >
                    <i class="fas fa-external-link-alt mr-1" />查看上游更新
                  </a>
                  <button
                    v-if="versionInfo.canSyncInPanel"
                    class="mt-2 block w-full rounded-lg bg-blue-500 px-3 py-1.5 text-center text-sm text-white transition-colors hover:bg-blue-600 disabled:cursor-not-allowed disabled:opacity-60"
                    :disabled="versionInfo.syncingUpdate"
                    @click="runPanelUpdate"
                  >
                    <i
                      :class="
                        versionInfo.syncingUpdate
                          ? 'fas fa-spinner fa-spin mr-1'
                          : 'fas fa-download mr-1'
                      "
                    />
                    {{ versionInfo.syncingUpdate ? '创建中...' : '创建同步分支' }}
                  </button>
                </div>
                <div
                  v-else-if="versionInfo.checkingUpdate"
                  class="mt-2 text-center text-xs text-gray-500 dark:text-gray-400"
                >
                  <i class="fas fa-spinner fa-spin mr-1" />检查版本中...
                </div>
                <div v-else class="mt-2 text-center">
                  <transition mode="out-in" name="fade">
                    <div
                      v-if="versionInfo.upstream.noUpdateMessage"
                      key="upstream-message"
                      class="inline-block rounded-lg border border-green-200 bg-green-100 px-3 py-1.5 dark:border-green-800 dark:bg-green-900/30"
                    >
                      <p class="text-xs font-medium text-green-700 dark:text-green-400">
                        <i class="fas fa-check-circle mr-1" />当前已是上游最新版
                      </p>
                    </div>
                    <button
                      v-else
                      key="upstream-button"
                      class="text-xs text-blue-500 transition-colors hover:text-blue-700 dark:text-blue-400 dark:hover:text-blue-300"
                      @click="checkForUpdates()"
                    >
                      <i class="fas fa-sync-alt mr-1" />检查上游更新
                    </button>
                  </transition>
                </div>
                <p
                  v-if="versionInfo.upstream.warning"
                  class="mt-2 text-xs text-amber-600 dark:text-amber-400"
                >
                  {{ versionInfo.upstream.warning }}
                </p>
              </div>

              <div class="rounded-xl border border-gray-100 p-3 dark:border-gray-700">
                <div class="flex items-center justify-between text-sm">
                  <span class="text-gray-500 dark:text-gray-400">二开版本</span>
                  <span class="font-mono text-gray-700 dark:text-gray-300">
                    {{ versionInfo.custom.current || '...' }}
                  </span>
                </div>
                <div class="mt-2 flex items-center justify-between text-sm">
                  <span
                    :class="
                      versionInfo.custom.hasUpdate
                        ? 'font-medium text-amber-600 dark:text-amber-400'
                        : 'font-medium text-green-600 dark:text-green-400'
                    "
                  >
                    <i
                      :class="
                        versionInfo.custom.hasUpdate
                          ? 'fas fa-code-branch mr-1'
                          : 'fas fa-check-circle mr-1'
                      "
                    />
                    {{ versionInfo.custom.hasUpdate ? '二开有更新' : '二开已同步' }}
                  </span>
                  <span
                    class="font-mono"
                    :class="
                      versionInfo.custom.hasUpdate
                        ? 'text-amber-600 dark:text-amber-400'
                        : 'text-green-600 dark:text-green-400'
                    "
                  >
                    {{ versionInfo.custom.latest || '...' }}
                  </span>
                </div>
                <a
                  v-if="versionInfo.custom.compareUrl || versionInfo.custom.branchUrl"
                  class="mt-2 block w-full rounded-lg bg-amber-500 px-3 py-1.5 text-center text-sm text-white transition-colors hover:bg-amber-600"
                  :href="versionInfo.custom.compareUrl || versionInfo.custom.branchUrl || '#'"
                  target="_blank"
                >
                  <i class="fas fa-external-link-alt mr-1" />
                  {{ versionInfo.custom.hasUpdate ? '查看二开差异' : '查看二开分支' }}
                </a>
                <p v-if="versionInfo.custom.branch" class="mt-2 text-xs text-gray-500 dark:text-gray-400">
                  跟踪分支：{{ versionInfo.custom.branch }}
                </p>
                <p
                  v-if="versionInfo.custom.warning"
                  class="mt-2 text-xs text-amber-600 dark:text-amber-400"
                >
                  {{ versionInfo.custom.warning }}
                </p>
              </div>
            </div>

            <button
              class="flex w-full items-center gap-3 px-4 py-3 text-left text-gray-700 transition-colors hover:bg-gray-50 dark:text-gray-300 dark:hover:bg-gray-700"
              @click="openChangePasswordModal"
            >
              <i class="fas fa-key text-blue-500" />
              <span>修改账户信息</span>
            </button>

            <hr class="my-2 border-gray-200 dark:border-gray-700" />

            <button
              class="flex w-full items-center gap-3 px-4 py-3 text-left text-gray-700 transition-colors hover:bg-gray-50 dark:text-gray-300 dark:hover:bg-gray-700"
              @click="logout"
            >
              <i class="fas fa-sign-out-alt text-red-500" />
              <span>退出登录</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>

  <!-- 修改账户信息模态框 -->
  <div
    v-if="showChangePasswordModal"
    class="modal fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4"
  >
    <div class="modal-content mx-auto flex max-h-[90vh] w-full max-w-md flex-col p-4 sm:p-6 md:p-8">
      <div class="mb-6 flex items-center justify-between">
        <div class="flex items-center gap-3">
          <div
            class="flex h-10 w-10 items-center justify-center rounded-xl bg-gradient-to-br from-blue-500 to-blue-600"
          >
            <i class="fas fa-key text-white" />
          </div>
          <h3 class="text-xl font-bold text-gray-900 dark:text-gray-100">修改账户信息</h3>
        </div>
        <button
          class="text-gray-400 transition-colors hover:text-gray-600 dark:hover:text-gray-300"
          @click="closeChangePasswordModal"
        >
          <i class="fas fa-times text-xl" />
        </button>
      </div>

      <form
        class="modal-scroll-content custom-scrollbar flex-1 space-y-6"
        @submit.prevent="changePassword"
      >
        <div>
          <label class="mb-3 block text-sm font-semibold text-gray-700 dark:text-gray-300"
            >当前用户名</label
          >
          <input
            class="form-input w-full cursor-not-allowed bg-gray-100 dark:bg-gray-700 dark:text-gray-300"
            disabled
            type="text"
            :value="currentUser.username || 'Admin'"
          />
          <p class="mt-2 text-xs text-gray-500 dark:text-gray-400">
            当前用户名，输入新用户名以修改
          </p>
        </div>

        <div>
          <label class="mb-3 block text-sm font-semibold text-gray-700 dark:text-gray-300"
            >新用户名</label
          >
          <input
            v-model="changePasswordForm.newUsername"
            class="form-input w-full"
            placeholder="输入新用户名（留空保持不变）"
            type="text"
          />
          <p class="mt-2 text-xs text-gray-500 dark:text-gray-400">留空表示不修改用户名</p>
        </div>

        <div>
          <label class="mb-3 block text-sm font-semibold text-gray-700 dark:text-gray-300"
            >当前密码</label
          >
          <div class="relative">
            <input
              v-model="changePasswordForm.currentPassword"
              class="form-input w-full pr-10"
              placeholder="请输入当前密码"
              required
              :type="showCurrentPassword ? 'text' : 'password'"
            />
            <button
              class="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 dark:text-gray-500 dark:hover:text-gray-300"
              type="button"
              @click="showCurrentPassword = !showCurrentPassword"
            >
              <i :class="showCurrentPassword ? 'fas fa-eye-slash' : 'fas fa-eye'" />
            </button>
          </div>
        </div>

        <div>
          <label class="mb-3 block text-sm font-semibold text-gray-700 dark:text-gray-300"
            >新密码</label
          >
          <input
            v-model="changePasswordForm.newPassword"
            class="form-input w-full"
            placeholder="请输入新密码"
            required
            type="password"
          />
          <p class="mt-2 text-xs text-gray-500 dark:text-gray-400">密码长度至少8位</p>
        </div>

        <div>
          <label class="mb-3 block text-sm font-semibold text-gray-700 dark:text-gray-300"
            >确认新密码</label
          >
          <input
            v-model="changePasswordForm.confirmPassword"
            class="form-input w-full"
            placeholder="请再次输入新密码"
            required
            type="password"
          />
        </div>

        <div class="flex gap-3 pt-4">
          <button
            class="flex-1 rounded-xl bg-gray-100 px-6 py-3 font-semibold text-gray-700 transition-colors hover:bg-gray-200 dark:bg-gray-700 dark:text-gray-300 dark:hover:bg-gray-600"
            type="button"
            @click="closeChangePasswordModal"
          >
            取消
          </button>
          <button
            class="btn btn-primary flex-1 px-6 py-3 font-semibold"
            :disabled="changePasswordLoading"
            type="submit"
          >
            <div v-if="changePasswordLoading" class="loading-spinner mr-2" />
            <i v-else class="fas fa-save mr-2" />
            {{ changePasswordLoading ? '保存中...' : '保存修改' }}
          </button>
        </div>
      </form>
    </div>
  </div>

  <!-- ConfirmModal -->
  <ConfirmModal
    :cancel-text="confirmModalConfig.cancelText"
    :confirm-text="confirmModalConfig.confirmText"
    :message="confirmModalConfig.message"
    :show="showConfirmModal"
    :title="confirmModalConfig.title"
    :type="confirmModalConfig.type"
    @cancel="handleCancelModal"
    @confirm="handleConfirmModal"
  />
</template>

<script setup>
import { ref, reactive, computed, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { showToast } from '@/utils/tools'

import { checkUpdatesApi, changePasswordApi, syncUpdatesApi } from '@/utils/http_apis'
import LogoTitle from '@/components/common/LogoTitle.vue'
import ThemeToggle from '@/components/common/ThemeToggle.vue'
import ConfirmModal from '@/components/common/ConfirmModal.vue'

const router = useRouter()
const authStore = useAuthStore()

// 当前用户信息
const currentUser = computed(() => authStore.user || { username: 'Admin' })

// OEM设置
const oemSettings = computed(() => authStore.oemSettings || {})
const oemLoading = computed(() => authStore.oemLoading)

// 版本信息
const versionInfo = ref({
  upstream: {
    current: '...',
    latest: '',
    hasUpdate: false,
    releaseInfo: null,
    noUpdateMessage: false,
    warning: ''
  },
  custom: {
    current: '...',
    latest: '',
    hasUpdate: false,
    compareUrl: '',
    branchUrl: '',
    branch: '',
    warning: ''
  },
  checkingUpdate: false,
  lastChecked: null,
  canSyncInPanel: false,
  syncingUpdate: false
})

// 用户菜单状态
const userMenuOpen = ref(false)

// 修改密码模态框
const showChangePasswordModal = ref(false)
const changePasswordLoading = ref(false)
const showCurrentPassword = ref(false)
const changePasswordForm = reactive({
  currentPassword: '',
  newPassword: '',
  confirmPassword: '',
  newUsername: ''
})

// ConfirmModal 状态
const showConfirmModal = ref(false)
const confirmModalConfig = ref({
  title: '',
  message: '',
  type: 'primary',
  confirmText: '确认',
  cancelText: '取消'
})
const confirmResolve = ref(null)

const showConfirm = (
  title,
  message,
  confirmText = '确认',
  cancelText = '取消',
  type = 'primary'
) => {
  return new Promise((resolve) => {
    confirmModalConfig.value = { title, message, confirmText, cancelText, type }
    confirmResolve.value = resolve
    showConfirmModal.value = true
  })
}
const handleConfirmModal = () => {
  showConfirmModal.value = false
  confirmResolve.value?.(true)
}
const handleCancelModal = () => {
  showConfirmModal.value = false
  confirmResolve.value?.(false)
}

// 检查更新（同时获取版本信息）
const checkForUpdates = async () => {
  if (versionInfo.value.checkingUpdate) {
    return
  }

  versionInfo.value.checkingUpdate = true

  try {
    const result = await checkUpdatesApi()

    if (result.success) {
      const data = result.data

      versionInfo.value.upstream = {
        ...versionInfo.value.upstream,
        ...(data.upstream || {})
      }
      versionInfo.value.custom = {
        ...versionInfo.value.custom,
        ...(data.custom || {})
      }
      versionInfo.value.canSyncInPanel = data.canSyncInPanel === true
      versionInfo.value.lastChecked = new Date()

      localStorage.setItem(
        'versionInfoV2',
        JSON.stringify({
          upstream: versionInfo.value.upstream,
          custom: versionInfo.value.custom,
          lastChecked: versionInfo.value.lastChecked,
          canSyncInPanel: versionInfo.value.canSyncInPanel
        })
      )

      if (!versionInfo.value.upstream.hasUpdate) {
        versionInfo.value.upstream.noUpdateMessage = true
        setTimeout(() => {
          versionInfo.value.upstream.noUpdateMessage = false
        }, 3000)
      }
    }
  } catch (error) {
    console.error('Error checking for updates:', error)

    const cached = localStorage.getItem('versionInfoV2')
    if (cached) {
      const cachedInfo = JSON.parse(cached)
      versionInfo.value.upstream = {
        ...versionInfo.value.upstream,
        ...(cachedInfo.upstream || {})
      }
      versionInfo.value.custom = {
        ...versionInfo.value.custom,
        ...(cachedInfo.custom || {})
      }
      versionInfo.value.canSyncInPanel =
        cachedInfo.canSyncInPanel === true || versionInfo.value.canSyncInPanel
      versionInfo.value.lastChecked = new Date(cachedInfo.lastChecked)
    }
  } finally {
    versionInfo.value.checkingUpdate = false
  }
}

const runPanelUpdate = async () => {
  if (versionInfo.value.syncingUpdate) {
    return
  }

  const confirmed = await showConfirm(
    '创建上游同步分支',
    '这不会直接改你的 develop，而是基于当前 develop 创建一个上游同步分支，供你审核和测试后再决定是否合并。是否继续？',
    '创建分支',
    '取消',
    'warning'
  )

  if (!confirmed) {
    return
  }

  versionInfo.value.syncingUpdate = true

  try {
    const result = await syncUpdatesApi()
    const compareUrl = result?.data?.compareUrl
    const syncBranch = result?.data?.syncBranch
    const message = compareUrl
      ? `已创建分支 ${syncBranch}，可到 GitHub 审核后再合并`
      : result.message || '已创建上游同步分支，请审核后再合并'

    showToast(message, 'success', '同步分支已创建', 6000)
    await checkForUpdates()
  } catch (error) {
    const message =
      error?.response?.data?.message ||
      error?.response?.data?.data?.output ||
      error?.message ||
      '页面内同步失败'
    showToast(message, 'error', '上游同步失败', 6000)
  } finally {
    versionInfo.value.syncingUpdate = false
  }
}

// 打开修改密码弹窗
const openChangePasswordModal = () => {
  changePasswordForm.currentPassword = ''
  changePasswordForm.newPassword = ''
  changePasswordForm.confirmPassword = ''
  changePasswordForm.newUsername = ''
  showChangePasswordModal.value = true
  userMenuOpen.value = false
}

// 关闭修改密码弹窗
const closeChangePasswordModal = () => {
  showChangePasswordModal.value = false
}

// 修改密码
const changePassword = async () => {
  if (changePasswordForm.newPassword !== changePasswordForm.confirmPassword) {
    showToast('两次输入的密码不一致', 'error')
    return
  }

  if (changePasswordForm.newPassword.length < 8) {
    showToast('新密码长度至少8位', 'error')
    return
  }

  changePasswordLoading.value = true

  try {
    const data = await changePasswordApi({
      currentPassword: changePasswordForm.currentPassword,
      newPassword: changePasswordForm.newPassword,
      newUsername: changePasswordForm.newUsername || undefined
    })

    if (data.success) {
      const message = changePasswordForm.newUsername
        ? '账户信息修改成功，请重新登录'
        : '密码修改成功，请重新登录'
      showToast(message, 'success')
      closeChangePasswordModal()

      // 延迟后退出登录
      setTimeout(() => {
        authStore.logout()
        router.push('/login')
      }, 1500)
    } else {
      showToast(data.message || '修改失败', 'error')
    }
  } catch (error) {
    showToast('修改密码失败', 'error')
  } finally {
    changePasswordLoading.value = false
  }
}

// 退出登录
const logout = async () => {
  const confirmed = await showConfirm(
    '退出登录',
    '确定要退出登录吗？',
    '确定退出',
    '取消',
    'warning'
  )
  if (confirmed) {
    authStore.logout()
    router.push('/login')
    showToast('已安全退出', 'success')
  }
  userMenuOpen.value = false
}

// 点击外部关闭菜单
const handleClickOutside = (event) => {
  const userMenuContainer = event.target.closest('.user-menu-container')
  if (!userMenuContainer && userMenuOpen.value) {
    userMenuOpen.value = false
  }
}

onMounted(() => {
  checkForUpdates()

  // 设置自动检查更新（每小时检查一次）
  setInterval(() => {
    checkForUpdates()
  }, 3600000) // 1小时

  document.addEventListener('click', handleClickOutside)
})

onUnmounted(() => {
  document.removeEventListener('click', handleClickOutside)
})
</script>

<style scoped>
/* 用户菜单按钮样式 */
.user-menu-button {
  position: relative;
  overflow: hidden;
  min-height: 38px;
  background: linear-gradient(135deg, var(--primary-color) 0%, var(--secondary-color) 100%);
  box-shadow: 0 4px 12px rgba(var(--primary-rgb), 0.3);
}

.user-menu-button:hover {
  box-shadow: 0 6px 16px rgba(var(--primary-rgb), 0.4);
}

/* 添加光泽效果 */
.user-menu-button::before {
  content: '';
  position: absolute;
  top: 0;
  left: -100%;
  width: 100%;
  height: 100%;
  background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.2), transparent);
  transition: left 0.5s;
}

.user-menu-button:hover::before {
  left: 100%;
}

/* 用户菜单样式优化 */
.user-menu-dropdown {
  margin-top: 8px;
  animation: slideDown 0.3s ease-out;
}

@keyframes slideDown {
  from {
    opacity: 0;
    transform: translateY(-10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

/* fade过渡动画 */
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.3s;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
