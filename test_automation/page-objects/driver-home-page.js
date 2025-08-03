const FlutterHelpers = require('../utils/flutter-helpers');

class DriverHomePage {
  constructor(driver) {
    this.driver = driver;
    this.flutter = new FlutterHelpers(driver);
    
    // Element selectors for Driver Home Page
    this.appBar = 'type("AppBar")';
    this.onlineToggle = 'key("online_toggle")';
    this.mapView = 'key("driver_map")';
    this.ordersList = 'key("orders_list")';
    this.acceptOrderButton = 'key("accept_order_button")';
    this.startDeliveryButton = 'key("start_delivery_button")';
    this.chatButton = 'key("chat_button")';
    this.filterDropdown = 'key("filter_dropdown")';
    this.refreshButton = 'key("refresh_button")';
    
    // Alternative selectors
    this.onlineToggleAlt = 'text("ONLINE")';
    this.mapViewAlt = 'type("FlutterMap")';
    this.ordersListAlt = 'type("ListView")';
    this.acceptOrderButtonAlt = 'text("Accept Order")';
    this.startDeliveryButtonAlt = 'text("Start Delivery")';
    this.chatButtonAlt = 'type("FloatingActionButton")';
  }

  async waitForPageLoad() {
    try {
      console.log('📱 Loading Driver Home Page...');
      await this.flutter.waitForAppReady();
      await this.flutter.waitForElement(this.appBar, 15000);
      
      // Handle location permissions if prompted
      await this.flutter.handlePermissions();
      
      console.log('✅ Driver home page loaded successfully');
    } catch (error) {
      console.error('❌ Failed to load driver home page:', error.message);
      throw error;
    }
  }

  async toggleOnlineStatus() {
    try {
      console.log('🔄 Toggling online status...');
      
      if (await this.flutter.isElementExists(this.onlineToggle, 5000)) {
        await this.flutter.tapElement(this.onlineToggle);
      } else {
        await this.flutter.tapElement(this.onlineToggleAlt);
      }
      
      await this.driver.pause(2000);
      console.log('✅ Online status toggled');
    } catch (error) {
      console.error('❌ Failed to toggle online status:', error.message);
      throw error;
    }
  }

  async acceptFirstOrder() {
    try {
      console.log('✅ Accepting first available order...');
      
      // Wait for orders to load
      await this.flutter.waitForElement(this.ordersListAlt, 10000);
      
      if (await this.flutter.isElementExists(this.acceptOrderButton, 5000)) {
        await this.flutter.tapElement(this.acceptOrderButton);
      } else {
        await this.flutter.tapElement(this.acceptOrderButtonAlt);
      }
      
      await this.driver.pause(3000);
      console.log('✅ Order accepted');
    } catch (error) {
      console.error('❌ Failed to accept order:', error.message);
      throw error;
    }
  }

  async startDelivery() {
    try {
      console.log('🚚 Starting delivery...');
      
      if (await this.flutter.isElementExists(this.startDeliveryButton, 5000)) {
        await this.flutter.tapElement(this.startDeliveryButton);
      } else {
        await this.flutter.tapElement(this.startDeliveryButtonAlt);
      }
      
      await this.driver.pause(3000);
      console.log('✅ Delivery started');
    } catch (error) {
      console.error('❌ Failed to start delivery:', error.message);
      throw error;
    }
  }

  async openChat() {
    try {
      console.log('💬 Opening chat...');
      
      if (await this.flutter.isElementExists(this.chatButton, 5000)) {
        await this.flutter.tapElement(this.chatButton);
      } else {
        await this.flutter.tapElement(this.chatButtonAlt);
      }
      
      console.log('✅ Chat opened');
    } catch (error) {
      console.error('❌ Failed to open chat:', error.message);
      throw error;
    }
  }

  async applyFilter(filterType) {
    try {
      console.log(`🔧 Applying filter: ${filterType}`);
      
      await this.flutter.tapElement(this.filterDropdown);
      await this.driver.pause(1000);
      
      await this.flutter.tapElement(`text("${filterType}")`);
      await this.driver.pause(2000);
      
      console.log(`✅ Filter applied: ${filterType}`);
    } catch (error) {
      console.error('❌ Failed to apply filter:', error.message);
      throw error;
    }
  }

  async refreshOrders() {
    try {
      console.log('🔄 Refreshing orders...');
      
      // Pull to refresh or tap refresh button
      if (await this.flutter.isElementExists(this.refreshButton, 3000)) {
        await this.flutter.tapElement(this.refreshButton);
      } else {
        // Perform pull to refresh gesture
        await this.pullToRefresh();
      }
      
      await this.driver.pause(3000);
      console.log('✅ Orders refreshed');
    } catch (error) {
      console.error('❌ Failed to refresh orders:', error.message);
      throw error;
    }
  }

  async pullToRefresh() {
    try {
      const size = await this.driver.getWindowSize();
      const centerX = Math.floor(size.width / 2);
      const startY = Math.floor(size.height * 0.3);
      const endY = Math.floor(size.height * 0.7);
      
      await this.driver.touchAction([
        { action: 'press', x: centerX, y: startY },
        { action: 'wait', ms: 500 },
        { action: 'moveTo', x: centerX, y: endY },
        { action: 'release' }
      ]);
    } catch (error) {
      console.error('❌ Failed to pull to refresh:', error.message);
      throw error;
    }
  }

  async verifyMapIsLoaded() {
    try {
      console.log('🗺️ Verifying map is loaded...');
      
      const mapExists = await this.flutter.isElementExists(this.mapView, 10000) ||
                       await this.flutter.isElementExists(this.mapViewAlt, 10000);
      
      if (mapExists) {
        console.log('✅ Map is loaded');
        return true;
      } else {
        console.log('❌ Map is not loaded');
        return false;
      }
    } catch (error) {
      console.error('❌ Error verifying map:', error.message);
      return false;
    }
  }

  async getOrdersCount() {
    try {
      // This would need to be implemented based on your specific UI structure
      // For now, return a placeholder
      return 0;
    } catch (error) {
      console.error('❌ Error getting orders count:', error.message);
      return 0;
    }
  }

  async verifyDriverHomeElements() {
    try {
      console.log('✅ Verifying driver home page elements...');
      
      const elements = [
        { selector: this.appBar, name: 'App Bar' },
        { selector: this.ordersListAlt, name: 'Orders List' }
      ];
      
      for (const element of elements) {
        const exists = await this.flutter.isElementExists(element.selector, 5000);
        if (exists) {
          console.log(`✅ ${element.name} found`);
        } else {
          console.log(`⚠️ ${element.name} not found`);
        }
      }
      
      return true;
    } catch (error) {
      console.error('❌ Error verifying driver home elements:', error.message);
      return false;
    }
  }
}

module.exports = DriverHomePage;
