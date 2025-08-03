const FlutterHelpers = require('../utils/flutter-helpers');

class CustomerHomePage {
  constructor(driver) {
    this.driver = driver;
    this.flutter = new FlutterHelpers(driver);
    
    // Element selectors for Customer Home Page
    this.appBar = 'type("AppBar")';
    this.searchField = 'key("search_field")';
    this.profileButton = 'key("profile_button")';
    this.notificationButton = 'key("notification_button")';
    this.menuList = 'type("ListView")';
    this.mealCard = 'type("Card")';
    this.cartButton = 'key("cart_button")';
    this.orderHistoryButton = 'text("Order History")';
    this.settingsButton = 'text("Settings")';
    
    // Alternative selectors
    this.searchFieldAlt = 'type("TextField")';
    this.profileButtonAlt = 'type("CircleAvatar")';
    this.mealCardAlt = 'type("GestureDetector")';
  }

  async waitForPageLoad() {
    try {
      console.log('📱 Loading Customer Home Page...');
      await this.flutter.waitForAppReady();
      await this.flutter.waitForElement(this.appBar, 15000);
      console.log('✅ Customer home page loaded successfully');
    } catch (error) {
      console.error('❌ Failed to load customer home page:', error.message);
      throw error;
    }
  }

  async searchForMeal(searchTerm) {
    try {
      console.log(`🔍 Searching for meal: ${searchTerm}`);
      
      if (await this.flutter.isElementExists(this.searchField, 5000)) {
        await this.flutter.enterText(this.searchField, searchTerm);
      } else {
        await this.flutter.enterText(this.searchFieldAlt, searchTerm);
      }
      
      // Press enter or search button
      await this.driver.pressKeyCode(66); // Enter key
      await this.driver.pause(2000);
      
      console.log('✅ Search completed');
    } catch (error) {
      console.error('❌ Failed to search for meal:', error.message);
      throw error;
    }
  }

  async selectFirstMeal() {
    try {
      console.log('👆 Selecting first meal...');
      
      if (await this.flutter.isElementExists(this.mealCard, 5000)) {
        await this.flutter.tapElement(this.mealCard);
      } else {
        await this.flutter.tapElement(this.mealCardAlt);
      }
      
      console.log('✅ First meal selected');
    } catch (error) {
      console.error('❌ Failed to select meal:', error.message);
      throw error;
    }
  }

  async openProfile() {
    try {
      console.log('👤 Opening profile...');
      
      if (await this.flutter.isElementExists(this.profileButton, 5000)) {
        await this.flutter.tapElement(this.profileButton);
      } else {
        await this.flutter.tapElement(this.profileButtonAlt);
      }
      
      console.log('✅ Profile opened');
    } catch (error) {
      console.error('❌ Failed to open profile:', error.message);
      throw error;
    }
  }

  async openCart() {
    try {
      console.log('🛒 Opening cart...');
      await this.flutter.tapElement(this.cartButton);
      console.log('✅ Cart opened');
    } catch (error) {
      console.error('❌ Failed to open cart:', error.message);
      throw error;
    }
  }

  async scrollToFindMeal(mealName) {
    try {
      console.log(`📜 Scrolling to find meal: ${mealName}`);
      
      let attempts = 0;
      const maxAttempts = 5;
      
      while (attempts < maxAttempts) {
        if (await this.flutter.isElementExists(`text("${mealName}")`, 2000)) {
          console.log(`✅ Found meal: ${mealName}`);
          return true;
        }
        
        await this.flutter.scrollDown();
        attempts++;
        await this.driver.pause(1000);
      }
      
      console.log(`❌ Meal not found after ${maxAttempts} scroll attempts`);
      return false;
    } catch (error) {
      console.error('❌ Error while scrolling to find meal:', error.message);
      return false;
    }
  }

  async verifyCustomerHomeElements() {
    try {
      console.log('✅ Verifying customer home page elements...');
      
      const elements = [
        { selector: this.appBar, name: 'App Bar' },
        { selector: this.menuList, name: 'Menu List' }
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
      console.error('❌ Error verifying customer home elements:', error.message);
      return false;
    }
  }
}

module.exports = CustomerHomePage;
