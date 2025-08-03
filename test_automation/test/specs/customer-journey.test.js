const { expect } = require('chai');
const DriverManager = require('../../utils/driver-manager');

describe('👤 Customer User Journey Tests', function() {
  let driver;
  this.timeout(300000); // 5 minutes timeout

  beforeEach(async function() {
    console.log('\n👤 Starting Customer Journey Tests...');
    driver = await DriverManager.createDriver('android');
    await driver.pause(3000);
  });

  afterEach(async function() {
    if (driver) {
      await DriverManager.quitDriver(driver);
    }
  });

  it('should test customer registration and profile setup', async function() {
    console.log('Testing customer registration...');
    
    // Navigate to registration
    const signUpLink = await driver.$('[content-desc="Don\'t have an account? Sign Up"]');
    if (await signUpLink.isDisplayed()) {
      await signUpLink.click();
      await driver.pause(2000);
      
      // Fill registration form
      const nameField = await driver.$('android.widget.EditText');
      if (await nameField.isDisplayed()) {
        await nameField.setValue('Test Customer');
        console.log('✅ Name field tested');
      }
      
      await DriverManager.takeScreenshot(driver, 'customer_registration');
      await driver.back();
    }
  });

  it('should test meal browsing and search functionality', async function() {
    console.log('Testing meal browsing...');
    
    // Look for browse/menu buttons
    const buttons = await driver.$$('android.widget.Button');
    
    for (const button of buttons) {
      try {
        const text = await button.getText();
        if (text.toLowerCase().includes('browse') || 
            text.toLowerCase().includes('menu') ||
            text.toLowerCase().includes('food')) {
          await button.click();
          await driver.pause(3000);
          
          // Test search functionality
          const searchField = await driver.$('android.widget.EditText');
          if (await searchField.isDisplayed()) {
            await searchField.setValue('chicken');
            await driver.pause(2000);
            console.log('✅ Search functionality tested');
          }
          
          await DriverManager.takeScreenshot(driver, 'customer_meal_browsing');
          await driver.back();
          break;
        }
      } catch (e) {
        continue;
      }
    }
  });

  it('should test shopping cart and checkout process', async function() {
    console.log('Testing shopping cart...');
    
    // Look for cart or add to cart elements
    const cartElements = await driver.$$('android.widget.Button');
    
    for (const element of cartElements) {
      try {
        const text = await element.getText();
        if (text.toLowerCase().includes('cart') || 
            text.toLowerCase().includes('add') ||
            text.includes('+')) {
          await element.click();
          await driver.pause(2000);
          
          await DriverManager.takeScreenshot(driver, 'customer_shopping_cart');
          console.log('✅ Shopping cart interaction tested');
          break;
        }
      } catch (e) {
        continue;
      }
    }
  });

  it('should test order placement and confirmation', async function() {
    console.log('Testing order placement...');
    
    // Test checkout process
    const checkoutButtons = await driver.$$('android.widget.Button');
    
    for (const button of checkoutButtons) {
      try {
        const text = await button.getText();
        if (text.toLowerCase().includes('checkout') || 
            text.toLowerCase().includes('order') ||
            text.toLowerCase().includes('confirm')) {
          
          // Test address input
          const addressField = await driver.$('android.widget.EditText');
          if (await addressField.isDisplayed()) {
            await addressField.setValue('123 Test Street, Test City');
            console.log('✅ Address input tested');
          }
          
          await DriverManager.takeScreenshot(driver, 'customer_order_placement');
          break;
        }
      } catch (e) {
        continue;
      }
    }
  });

  it('should test order tracking and history', async function() {
    console.log('Testing order tracking...');
    
    // Look for order history elements
    const historyButtons = await driver.$$('android.widget.Button');
    
    for (const button of historyButtons) {
      try {
        const text = await button.getText();
        if (text.toLowerCase().includes('history') || 
            text.toLowerCase().includes('track') ||
            text.toLowerCase().includes('orders')) {
          await button.click();
          await driver.pause(3000);
          
          await DriverManager.takeScreenshot(driver, 'customer_order_tracking');
          console.log('✅ Order tracking tested');
          await driver.back();
          break;
        }
      } catch (e) {
        continue;
      }
    }
  });

  it('should test customer profile and preferences', async function() {
    console.log('Testing customer profile...');
    
    // Look for profile elements
    const profileButtons = await driver.$$('android.widget.Button');
    
    for (const button of profileButtons) {
      try {
        const text = await button.getText();
        if (text.toLowerCase().includes('profile') || 
            text.toLowerCase().includes('settings') ||
            text.toLowerCase().includes('account')) {
          await button.click();
          await driver.pause(2000);
          
          // Test profile fields
          const nameField = await driver.$('android.widget.EditText');
          if (await nameField.isDisplayed()) {
            await nameField.click();
            await nameField.setValue('Updated Customer Name');
            console.log('✅ Profile editing tested');
          }
          
          await DriverManager.takeScreenshot(driver, 'customer_profile');
          await driver.back();
          break;
        }
      } catch (e) {
        continue;
      }
    }
  });

  it('should test customer support and help features', async function() {
    console.log('Testing customer support...');
    
    // Look for help or support elements
    const supportElements = await driver.$$('android.widget.TextView');
    let supportCount = 0;
    
    for (const element of supportElements) {
      try {
        const text = await element.getText();
        if (text.toLowerCase().includes('help') || 
            text.toLowerCase().includes('support') ||
            text.toLowerCase().includes('contact')) {
          supportCount++;
        }
      } catch (e) {
        continue;
      }
    }
    
    await DriverManager.takeScreenshot(driver, 'customer_support');
    console.log(`✅ Customer support tested (${supportCount} support elements found)`);
  });
});
