const { remote } = require('webdriverio');
const browserStackConfig = require('../config/browserstack.config');

class DriverManager {
  constructor() {
    this.driver = null;
  }

  async createDriver(platform = 'android', deviceIndex = 0) {
    const config = browserStackConfig[platform.toLowerCase()];
    if (!config || !config.devices[deviceIndex]) {
      throw new Error(`Invalid platform ${platform} or device index ${deviceIndex}`);
    }

    const device = config.devices[deviceIndex];
    const capabilities = device.capabilities; // Use device capabilities directly

    const options = {
      protocol: 'https',
      hostname: browserStackConfig.server,
      port: 443,
      path: '/wd/hub',
      user: browserStackConfig.user,
      key: browserStackConfig.key,
      capabilities,
      logLevel: 'info',
      waitforTimeout: 30000,
      connectionRetryTimeout: 120000,
      connectionRetryCount: 3
    };

    try {
      this.driver = await remote(options);
      console.log(`✅ Driver created successfully for ${device.deviceName} (${device.platformName} ${device.platformVersion})`);
      return this.driver;
    } catch (error) {
      console.error('❌ Failed to create driver:', error.message);
      throw error;
    }
  }

  async quitDriver() {
    if (this.driver) {
      try {
        await this.driver.deleteSession();
        console.log('✅ Driver session ended successfully');
      } catch (error) {
        console.error('❌ Error ending driver session:', error.message);
      }
      this.driver = null;
    }
  }

  getDriver() {
    if (!this.driver) {
      throw new Error('Driver not initialized. Call createDriver() first.');
    }
    return this.driver;
  }

  async takeScreenshot(name) {
    if (this.driver) {
      try {
        const screenshot = await this.driver.takeScreenshot();
        console.log(`📸 Screenshot taken: ${name}`);
        return screenshot;
      } catch (error) {
        console.error('❌ Failed to take screenshot:', error.message);
      }
    }
  }

  async markTestStatus(status, reason) {
    if (this.driver) {
      try {
        await this.driver.executeScript('browserstack_executor: {"action": "setSessionStatus", "arguments": {"status":"' + status + '", "reason": "' + reason + '"}}');
        console.log(`✅ Test marked as ${status}: ${reason}`);
      } catch (error) {
        console.error('❌ Failed to mark test status:', error.message);
      }
    }
  }

  // Static methods for easier testing
  static async createDriver(testType = 'android') {
    const manager = new DriverManager();
    const platform = testType.toLowerCase().includes('ios') ? 'ios' : 'android';
    return await manager.createDriver(platform, 0);
  }

  static async quitDriver(driver) {
    if (driver) {
      try {
        await driver.deleteSession();
        console.log('✅ Driver session ended successfully');
      } catch (error) {
        console.error('❌ Error ending driver session:', error.message);
      }
    }
  }

  static async takeScreenshot(driver, name) {
    if (driver) {
      try {
        const screenshot = await driver.takeScreenshot();
        console.log(`📸 Screenshot taken: ${name}`);
        return screenshot;
      } catch (error) {
        console.error('❌ Failed to take screenshot:', error.message);
      }
    }
  }

  static async markTestStatus(driver, status, reason) {
    if (driver) {
      try {
        await driver.executeScript('browserstack_executor: {"action": "setSessionStatus", "arguments": {"status":"' + status + '", "reason": "' + reason + '"}}');
        console.log(`✅ Test marked as ${status}: ${reason}`);
      } catch (error) {
        console.error('❌ Failed to mark test status:', error.message);
      }
    }
  }
}

module.exports = DriverManager;
