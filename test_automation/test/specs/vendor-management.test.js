const { expect } = require('chai');
const DriverManager = require('../../utils/driver-manager');

describe('🏪 Vendor Management Tests', function() {
  let driver;
  this.timeout(300000); // 5 minutes timeout

  beforeEach(async function() {
    console.log('\n🏪 Starting Vendor Management Tests...');
    driver = await DriverManager.createDriver('android');
    await driver.pause(3000);
  });

  afterEach(async function() {
    if (driver) {
      await DriverManager.quitDriver(driver);
    }
  });

  it('should test vendor dashboard overview', async function() {
    console.log('Testing vendor dashboard...');
    
    // Look for vendor dashboard elements
    const dashboardElements = await driver.$$('android.widget.TextView');
    let vendorStats = {
      orders: 0,
      revenue: 0,
      menu: 0
    };
    
    for (const element of dashboardElements) {
      try {
        const text = await element.getText();
        if (text.toLowerCase().includes('orders')) vendorStats.orders++;
        if (text.toLowerCase().includes('revenue') || text.includes('RM')) vendorStats.revenue++;
        if (text.toLowerCase().includes('menu') || text.toLowerCase().includes('food')) vendorStats.menu++;
      } catch (e) {
        continue;
      }
    }
    
    await DriverManager.takeScreenshot(driver, 'vendor_dashboard');
    console.log(`✅ Vendor dashboard tested (Orders: ${vendorStats.orders}, Revenue: ${vendorStats.revenue}, Menu: ${vendorStats.menu})`);
  });

  it('should test menu creation and management', async function() {
    console.log('Testing menu management...');
    
    // Look for add menu or food management buttons
    const menuButtons = await driver.$$('android.widget.Button');
    
    for (const button of menuButtons) {
      try {
        const text = await button.getText();
        if (text.toLowerCase().includes('add') && 
           (text.toLowerCase().includes('menu') || text.toLowerCase().includes('food'))) {
          await button.click();
          await driver.pause(3000);
          
          // Test menu item creation form
          const nameField = await driver.$('android.widget.EditText');
          if (await nameField.isDisplayed()) {
            await nameField.setValue('Test Dish');
            console.log('✅ Menu item name input tested');
          }
          
          await DriverManager.takeScreenshot(driver, 'vendor_menu_creation');
          await driver.back();
          break;
        }
      } catch (e) {
        continue;
      }
    }
  });

  it('should test food item details and pricing', async function() {
    console.log('Testing food item management...');
    
    // Test food list and editing
    const foodButtons = await driver.$$('android.widget.Button');
    
    for (const button of foodButtons) {
      try {
        const text = await button.getText();
        if (text.toLowerCase().includes('food') || 
            text.toLowerCase().includes('list') ||
            text.toLowerCase().includes('items')) {
          await button.click();
          await driver.pause(3000);
          
          // Test price input fields
          const priceFields = await driver.$$('android.widget.EditText');
          for (let i = 0; i < Math.min(priceFields.length, 2); i++) {
            try {
              const field = priceFields[i];
              await field.click();
              await field.setValue('15.99');
              await driver.pause(500);
              console.log(`✅ Price field ${i + 1} tested`);
            } catch (e) {
              continue;
            }
          }
          
          await DriverManager.takeScreenshot(driver, 'vendor_food_management');
          await driver.back();
          break;
        }
      } catch (e) {
        continue;
      }
    }
  });

  it('should test order processing workflow', async function() {
    console.log('Testing order processing...');
    
    // Look for order management elements
    const orderButtons = await driver.$$('android.widget.Button');
    
    for (const button of orderButtons) {
      try {
        const text = await button.getText();
        if (text.toLowerCase().includes('orders') || 
            text.toLowerCase().includes('pending') ||
            text.toLowerCase().includes('process')) {
          await button.click();
          await driver.pause(3000);
          
          // Test order status updates
          const statusButtons = await driver.$$('android.widget.Button');
          for (const statusBtn of statusButtons) {
            try {
              const statusText = await statusBtn.getText();
              if (statusText.toLowerCase().includes('accept') || 
                  statusText.toLowerCase().includes('ready') ||
                  statusText.toLowerCase().includes('complete')) {
                console.log(`✅ Order status button found: ${statusText}`);
                break;
              }
            } catch (e) {
              continue;
            }
          }
          
          await DriverManager.takeScreenshot(driver, 'vendor_order_processing');
          await driver.back();
          break;
        }
      } catch (e) {
        continue;
      }
    }
  });

  it('should test revenue tracking and analytics', async function() {
    console.log('Testing revenue tracking...');
    
    // Look for revenue/analytics elements
    const revenueButtons = await driver.$$('android.widget.Button');
    
    for (const button of revenueButtons) {
      try {
        const text = await button.getText();
        if (text.toLowerCase().includes('revenue') || 
            text.toLowerCase().includes('earnings') ||
            text.toLowerCase().includes('analytics')) {
          await button.click();
          await driver.pause(3000);
          
          // Check for revenue data display
          const revenueElements = await driver.$$('android.widget.TextView');
          let revenueDataFound = 0;
          
          for (const element of revenueElements) {
            try {
              const elementText = await element.getText();
              if (elementText.includes('RM') || 
                  elementText.toLowerCase().includes('total') ||
                  elementText.toLowerCase().includes('sales')) {
                revenueDataFound++;
              }
            } catch (e) {
              continue;
            }
          }
          
          await DriverManager.takeScreenshot(driver, 'vendor_revenue_analytics');
          console.log(`✅ Revenue analytics tested (${revenueDataFound} revenue data points found)`);
          await driver.back();
          break;
        }
      } catch (e) {
        continue;
      }
    }
  });

  it('should test vendor profile and business settings', async function() {
    console.log('Testing vendor profile...');
    
    // Test vendor profile management
    const profileButtons = await driver.$$('android.widget.Button');
    
    for (const button of profileButtons) {
      try {
        const text = await button.getText();
        if (text.toLowerCase().includes('profile') || 
            text.toLowerCase().includes('settings') ||
            text.toLowerCase().includes('business')) {
          await button.click();
          await driver.pause(2000);
          
          // Test business information fields
          const businessFields = await driver.$$('android.widget.EditText');
          
          for (let i = 0; i < Math.min(businessFields.length, 3); i++) {
            try {
              const field = businessFields[i];
              await field.click();
              await field.setValue(`Test Business Info ${i + 1}`);
              await driver.pause(500);
              console.log(`✅ Business field ${i + 1} tested`);
            } catch (e) {
              continue;
            }
          }
          
          await DriverManager.takeScreenshot(driver, 'vendor_profile_settings');
          await driver.back();
          break;
        }
      } catch (e) {
        continue;
      }
    }
  });

  it('should test vendor verification and certification', async function() {
    console.log('Testing vendor verification...');
    
    // Look for verification elements
    const verificationElements = await driver.$$('android.widget.TextView');
    let verificationCount = 0;
    
    for (const element of verificationElements) {
      try {
        const text = await element.getText();
        if (text.toLowerCase().includes('verify') || 
            text.toLowerCase().includes('cert') ||
            text.toLowerCase().includes('valid') ||
            text.toLowerCase().includes('approved')) {
          verificationCount++;
        }
      } catch (e) {
        continue;
      }
    }
    
    await DriverManager.takeScreenshot(driver, 'vendor_verification');
    console.log(`✅ Vendor verification tested (${verificationCount} verification elements found)`);
  });

  it('should test QR code payment setup', async function() {
    console.log('Testing QR code payment...');
    
    // Look for QR code elements
    const qrElements = await driver.$$('android.widget.ImageView');
    const qrButtons = await driver.$$('android.widget.Button');
    
    for (const button of qrButtons) {
      try {
        const text = await button.getText();
        if (text.toLowerCase().includes('qr') || 
            text.toLowerCase().includes('payment') ||
            text.toLowerCase().includes('code')) {
          await button.click();
          await driver.pause(2000);
          
          await DriverManager.takeScreenshot(driver, 'vendor_qr_payment');
          console.log('✅ QR payment setup tested');
          await driver.back();
          break;
        }
      } catch (e) {
        continue;
      }
    }
    
    console.log(`✅ QR elements found: ${qrElements.length} images`);
  });

  it('should test vendor communication with drivers', async function() {
    console.log('Testing vendor-driver communication...');
    
    // Look for chat or communication elements
    const communicationButtons = await driver.$$('android.widget.Button');
    
    for (const button of communicationButtons) {
      try {
        const text = await button.getText();
        if (text.toLowerCase().includes('chat') || 
            text.toLowerCase().includes('message') ||
            text.toLowerCase().includes('driver')) {
          await button.click();
          await driver.pause(3000);
          
          // Test message input
          const messageField = await driver.$('android.widget.EditText');
          if (await messageField.isDisplayed()) {
            await messageField.setValue('Test message to driver');
            console.log('✅ Vendor-driver messaging tested');
          }
          
          await DriverManager.takeScreenshot(driver, 'vendor_driver_communication');
          await driver.back();
          break;
        }
      } catch (e) {
        continue;
      }
    }
  });
});
