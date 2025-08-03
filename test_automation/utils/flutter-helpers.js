class FlutterHelpers {
  constructor(driver) {
    this.driver = driver;
  }

  // Flutter-specific element finding methods
  async findByKey(key, timeout = 10000) {
    try {
      return await this.driver.$(`key("${key}")`).waitForExist({ timeout });
    } catch (error) {
      console.error(`❌ Element with key "${key}" not found:`, error.message);
      throw error;
    }
  }

  async findByText(text, timeout = 10000) {
    try {
      return await this.driver.$(`text("${text}")`).waitForExist({ timeout });
    } catch (error) {
      console.error(`❌ Element with text "${text}" not found:`, error.message);
      throw error;
    }
  }

  async findByType(type, timeout = 10000) {
    try {
      return await this.driver.$(`type("${type}")`).waitForExist({ timeout });
    } catch (error) {
      console.error(`❌ Element with type "${type}" not found:`, error.message);
      throw error;
    }
  }

  // Wait for Flutter app to be ready
  async waitForAppReady(timeout = 30000) {
    try {
      console.log('⏳ Waiting for Flutter app to be ready...');
      // Wait for the main MaterialApp widget
      await this.driver.$('type("MaterialApp")').waitForExist({ timeout });
      console.log('✅ Flutter app is ready');
      await this.driver.pause(2000); // Additional pause for stability
    } catch (error) {
      console.error('❌ Flutter app failed to load:', error.message);
      throw error;
    }
  }

  // Input text into Flutter text fields
  async enterText(selector, text) {
    try {
      const element = await this.driver.$(selector);
      await element.waitForExist({ timeout: 10000 });
      await element.click();
      await element.clearValue();
      await element.setValue(text);
      console.log(`✅ Entered text "${text}" into ${selector}`);
    } catch (error) {
      console.error(`❌ Failed to enter text into ${selector}:`, error.message);
      throw error;
    }
  }

  // Tap on Flutter elements
  async tapElement(selector) {
    try {
      const element = await this.driver.$(selector);
      await element.waitForExist({ timeout: 10000 });
      await element.click();
      console.log(`✅ Tapped on element: ${selector}`);
    } catch (error) {
      console.error(`❌ Failed to tap element ${selector}:`, error.message);
      throw error;
    }
  }

  // Scroll actions
  async scrollDown(distance = 0.5) {
    try {
      const size = await this.driver.getWindowSize();
      const startY = Math.floor(size.height * 0.8);
      const endY = Math.floor(size.height * 0.2);
      const centerX = Math.floor(size.width / 2);
      
      await this.driver.touchAction([
        { action: 'press', x: centerX, y: startY },
        { action: 'wait', ms: 500 },
        { action: 'moveTo', x: centerX, y: endY },
        { action: 'release' }
      ]);
      console.log('✅ Scrolled down');
    } catch (error) {
      console.error('❌ Failed to scroll down:', error.message);
      throw error;
    }
  }

  async scrollUp(distance = 0.5) {
    try {
      const size = await this.driver.getWindowSize();
      const startY = Math.floor(size.height * 0.2);
      const endY = Math.floor(size.height * 0.8);
      const centerX = Math.floor(size.width / 2);
      
      await this.driver.touchAction([
        { action: 'press', x: centerX, y: startY },
        { action: 'wait', ms: 500 },
        { action: 'moveTo', x: centerX, y: endY },
        { action: 'release' }
      ]);
      console.log('✅ Scrolled up');
    } catch (error) {
      console.error('❌ Failed to scroll up:', error.message);
      throw error;
    }
  }

  // Wait for element to be visible and interactable
  async waitForElement(selector, timeout = 15000) {
    try {
      const element = await this.driver.$(selector);
      await element.waitForExist({ timeout });
      await element.waitForDisplayed({ timeout });
      console.log(`✅ Element found and ready: ${selector}`);
      return element;
    } catch (error) {
      console.error(`❌ Element not ready ${selector}:`, error.message);
      throw error;
    }
  }

  // Check if element exists without throwing error
  async isElementExists(selector, timeout = 5000) {
    try {
      await this.driver.$(selector).waitForExist({ timeout });
      return true;
    } catch (error) {
      return false;
    }
  }

  // Handle alerts and permissions
  async handlePermissions() {
    try {
      // Handle location permission
      if (await this.isElementExists('text("Allow")', 3000)) {
        await this.tapElement('text("Allow")');
        console.log('✅ Location permission granted');
      }
      
      // Handle notification permission
      if (await this.isElementExists('text("Allow")', 3000)) {
        await this.tapElement('text("Allow")');
        console.log('✅ Notification permission granted');
      }
      
      // Handle camera permission
      if (await this.isElementExists('text("Allow")', 3000)) {
        await this.tapElement('text("Allow")');
        console.log('✅ Camera permission granted');
      }
    } catch (error) {
      console.log('ℹ️ No permissions to handle or already granted');
    }
  }

  // Network simulation
  async simulateNetworkCondition(condition) {
    try {
      await this.driver.executeScript('browserstack_executor: {"action": "setNetworkProfile", "arguments": {"profile": "' + condition + '"}}');
      console.log(`✅ Network condition set to: ${condition}`);
    } catch (error) {
      console.error('❌ Failed to set network condition:', error.message);
    }
  }

  // Device orientation
  async setOrientation(orientation) {
    try {
      await this.driver.setOrientation(orientation.toUpperCase());
      console.log(`✅ Orientation set to: ${orientation}`);
    } catch (error) {
      console.error('❌ Failed to set orientation:', error.message);
    }
  }
}

module.exports = FlutterHelpers;
