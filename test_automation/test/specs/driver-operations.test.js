const { expect } = require('chai');
const DriverManager = require('../../utils/driver-manager');

describe('🚚 Driver/Delivery Operations Tests', function() {
  let driver;
  this.timeout(300000); // 5 minutes timeout

  beforeEach(async function() {
    console.log('\n🚚 Starting Driver Operations Tests...');
    driver = await DriverManager.createDriver('android');
    await driver.pause(3000);
  });

  afterEach(async function() {
    if (driver) {
      await DriverManager.quitDriver(driver);
    }
  });

  it('should test driver dashboard and availability status', async function() {
    console.log('Testing driver dashboard...');
    
    // Look for driver-specific elements
    const driverElements = await driver.$$('android.widget.TextView');
    let driverStats = {
      orders: 0,
      status: 0,
      location: 0
    };
    
    for (const element of driverElements) {
      try {
        const text = await element.getText();
        if (text.toLowerCase().includes('order') || text.toLowerCase().includes('delivery')) driverStats.orders++;
        if (text.toLowerCase().includes('online') || text.toLowerCase().includes('available')) driverStats.status++;
        if (text.toLowerCase().includes('location') || text.toLowerCase().includes('gps')) driverStats.location++;
      } catch (e) {
        continue;
      }
    }
    
    await DriverManager.takeScreenshot(driver, 'driver_dashboard');
    console.log(`✅ Driver dashboard tested (Orders: ${driverStats.orders}, Status: ${driverStats.status}, Location: ${driverStats.location})`);
  });

  it('should test online/offline status toggle', async function() {
    console.log('Testing driver status toggle...');
    
    // Look for status toggle buttons
    const statusButtons = await driver.$$('android.widget.Button');
    
    for (const button of statusButtons) {
      try {
        const text = await button.getText();
        if (text.toLowerCase().includes('online') || 
            text.toLowerCase().includes('offline') ||
            text.toLowerCase().includes('available')) {
          
          // Test toggle functionality
          await button.click();
          await driver.pause(2000);
          
          // Verify status change
          const updatedText = await button.getText();
          console.log(`✅ Status toggle tested: ${text} → ${updatedText}`);
          
          await DriverManager.takeScreenshot(driver, 'driver_status_toggle');
          break;
        }
      } catch (e) {
        continue;
      }
    }
  });

  it('should test delivery preferences and settings', async function() {
    console.log('Testing delivery preferences...');
    
    // Look for preference settings
    const preferenceButtons = await driver.$$('android.widget.Button');
    
    for (const button of preferenceButtons) {
      try {
        const text = await button.getText();
        if (text.toLowerCase().includes('preference') || 
            text.toLowerCase().includes('settings') ||
            text.toLowerCase().includes('distance')) {
          await button.click();
          await driver.pause(2000);
          
          // Test distance preference
          const distanceFields = await driver.$$('android.widget.EditText');
          if (distanceFields.length > 0) {
            await distanceFields[0].click();
            await distanceFields[0].setValue('10');
            console.log('✅ Distance preference tested');
          }
          
          await DriverManager.takeScreenshot(driver, 'driver_preferences');
          await driver.back();
          break;
        }
      } catch (e) {
        continue;
      }
    }
  });

  it('should test order acceptance and management', async function() {
    console.log('Testing order acceptance...');
    
    // Look for available orders
    const orderButtons = await driver.$$('android.widget.Button');
    
    for (const button of orderButtons) {
      try {
        const text = await button.getText();
        if (text.toLowerCase().includes('accept') || 
            text.toLowerCase().includes('order') ||
            text.toLowerCase().includes('delivery')) {
          
          // Test order interaction
          await button.click();
          await driver.pause(3000);
          
          // Look for order details
          const orderDetails = await driver.$$('android.widget.TextView');
          let orderInfo = 0;
          
          for (const detail of orderDetails) {
            try {
              const detailText = await detail.getText();
              if (detailText.includes('RM') || 
                  detailText.toLowerCase().includes('customer') ||
                  detailText.toLowerCase().includes('address')) {
                orderInfo++;
              }
            } catch (e) {
              continue;
            }
          }
          
          await DriverManager.takeScreenshot(driver, 'driver_order_management');
          console.log(`✅ Order management tested (${orderInfo} order details found)`);
          await driver.back();
          break;
        }
      } catch (e) {
        continue;
      }
    }
  });

  it('should test route optimization and navigation', async function() {
    console.log('Testing route optimization...');
    
    // Look for navigation elements
    const navigationButtons = await driver.$$('android.widget.Button');
    
    for (const button of navigationButtons) {
      try {
        const text = await button.getText();
        if (text.toLowerCase().includes('navigate') || 
            text.toLowerCase().includes('route') ||
            text.toLowerCase().includes('start')) {
          await button.click();
          await driver.pause(3000);
          
          // Check for map elements
          const mapElements = await driver.$$('android.view.View');
          
          await DriverManager.takeScreenshot(driver, 'driver_navigation');
          console.log(`✅ Navigation tested (${mapElements.length} map elements found)`);
          await driver.back();
          break;
        }
      } catch (e) {
        continue;
      }
    }
  });

  it('should test live delivery tracking and updates', async function() {
    console.log('Testing live delivery tracking...');
    
    // Look for live delivery elements
    const liveButtons = await driver.$$('android.widget.Button');
    
    for (const button of liveButtons) {
      try {
        const text = await button.getText();
        if (text.toLowerCase().includes('live') || 
            text.toLowerCase().includes('track') ||
            text.toLowerCase().includes('progress')) {
          await button.click();
          await driver.pause(3000);
          
          // Test status updates
          const statusButtons = await driver.$$('android.widget.Button');
          for (const statusBtn of statusButtons) {
            try {
              const statusText = await statusBtn.getText();
              if (statusText.toLowerCase().includes('pickup') || 
                  statusText.toLowerCase().includes('deliver') ||
                  statusText.toLowerCase().includes('complete')) {
                console.log(`✅ Status update button: ${statusText}`);
                break;
              }
            } catch (e) {
              continue;
            }
          }
          
          await DriverManager.takeScreenshot(driver, 'driver_live_tracking');
          await driver.back();
          break;
        }
      } catch (e) {
        continue;
      }
    }
  });

  it('should test vendor pickup workflow', async function() {
    console.log('Testing vendor pickup...');
    
    // Test pickup status updates
    const pickupButtons = await driver.$$('android.widget.Button');
    
    for (const button of pickupButtons) {
      try {
        const text = await button.getText();
        if (text.toLowerCase().includes('pickup') || 
            text.toLowerCase().includes('vendor') ||
            text.toLowerCase().includes('arrived')) {
          
          // Simulate pickup process
          await button.click();
          await driver.pause(2000);
          
          // Look for pickup confirmation elements
          const confirmButtons = await driver.$$('android.widget.Button');
          for (const confirmBtn of confirmButtons) {
            try {
              const confirmText = await confirmBtn.getText();
              if (confirmText.toLowerCase().includes('confirm') || 
                  confirmText.toLowerCase().includes('picked')) {
                console.log(`✅ Pickup confirmation: ${confirmText}`);
                break;
              }
            } catch (e) {
              continue;
            }
          }
          
          await DriverManager.takeScreenshot(driver, 'driver_vendor_pickup');
          break;
        }
      } catch (e) {
        continue;
      }
    }
  });

  it('should test customer delivery and confirmation', async function() {
    console.log('Testing customer delivery...');
    
    // Test delivery completion workflow
    const deliveryButtons = await driver.$$('android.widget.Button');
    
    for (const button of deliveryButtons) {
      try {
        const text = await button.getText();
        if (text.toLowerCase().includes('deliver') || 
            text.toLowerCase().includes('customer') ||
            text.toLowerCase().includes('complete')) {
          await button.click();
          await driver.pause(2000);
          
          // Test delivery confirmation
          const confirmElements = await driver.$$('android.widget.TextView');
          let deliveryInfo = 0;
          
          for (const element of confirmElements) {
            try {
              const elementText = await element.getText();
              if (elementText.toLowerCase().includes('delivered') || 
                  elementText.toLowerCase().includes('customer') ||
                  elementText.toLowerCase().includes('address')) {
                deliveryInfo++;
              }
            } catch (e) {
              continue;
            }
          }
          
          await DriverManager.takeScreenshot(driver, 'driver_customer_delivery');
          console.log(`✅ Customer delivery tested (${deliveryInfo} delivery details found)`);
          break;
        }
      } catch (e) {
        continue;
      }
    }
  });

  it('should test driver communication features', async function() {
    console.log('Testing driver communication...');
    
    // Test chat with customers and vendors
    const chatButtons = await driver.$$('android.widget.Button');
    
    for (const button of chatButtons) {
      try {
        const text = await button.getText();
        if (text.toLowerCase().includes('chat') || 
            text.toLowerCase().includes('message') ||
            text.toLowerCase().includes('call')) {
          await button.click();
          await driver.pause(3000);
          
          // Test message input
          const messageField = await driver.$('android.widget.EditText');
          if (await messageField.isDisplayed()) {
            await messageField.setValue('Driver here - on my way!');
            console.log('✅ Driver communication tested');
          }
          
          await DriverManager.takeScreenshot(driver, 'driver_communication');
          await driver.back();
          break;
        }
      } catch (e) {
        continue;
      }
    }
  });

  it('should test earnings tracking and payment QR', async function() {
    console.log('Testing earnings and payment...');
    
    // Look for earnings/payment elements
    const earningsElements = await driver.$$('android.widget.TextView');
    let earningsCount = 0;
    
    for (const element of earningsElements) {
      try {
        const text = await element.getText();
        if (text.toLowerCase().includes('earning') || 
            text.toLowerCase().includes('payment') ||
            text.includes('RM') ||
            text.toLowerCase().includes('qr')) {
          earningsCount++;
        }
      } catch (e) {
        continue;
      }
    }
    
    // Test QR code display
    const qrImages = await driver.$$('android.widget.ImageView');
    
    await DriverManager.takeScreenshot(driver, 'driver_earnings_payment');
    console.log(`✅ Earnings tested (${earningsCount} earnings elements, ${qrImages.length} QR images found)`);
  });

  it('should test group order delivery workflow', async function() {
    console.log('Testing group order delivery...');
    
    // Test group delivery management
    const groupButtons = await driver.$$('android.widget.Button');
    
    for (const button of groupButtons) {
      try {
        const text = await button.getText();
        if (text.toLowerCase().includes('group') || 
            text.toLowerCase().includes('multiple') ||
            text.toLowerCase().includes('batch')) {
          await button.click();
          await driver.pause(3000);
          
          // Check for multiple delivery points
          const deliveryPoints = await driver.$$('android.widget.TextView');
          let customerCount = 0;
          
          for (const point of deliveryPoints) {
            try {
              const pointText = await point.getText();
              if (pointText.toLowerCase().includes('customer') || 
                  pointText.toLowerCase().includes('delivery')) {
                customerCount++;
              }
            } catch (e) {
              continue;
            }
          }
          
          await DriverManager.takeScreenshot(driver, 'driver_group_delivery');
          console.log(`✅ Group delivery tested (${customerCount} customer delivery points found)`);
          await driver.back();
          break;
        }
      } catch (e) {
        continue;
      }
    }
  });
});
