const logger = require('../utils/logger')

const noop = async () => {}

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
  mountRoutes: async () => {
    logger.info('Custom extension layer ready: src/custom')
  }
}
