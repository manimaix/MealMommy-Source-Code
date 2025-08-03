const { describe, it, before, after } = require('mocha');
const { expect } = require('chai');
const DriverManager = require('../../utils/driver-manager');
const FlutterHelpers = require('../../utils/flutter-helpers');
const LoginPage = require('../../page-objects/login-page');

describe('Vendor Features', function() {
  this.timeout(120000);
  
  let driver;
  let helpers;
  let loginPage;
  
  before(async function() {
    console.log('🏪 Starting Vendor Feature Tests...');
    driver = await DriverManager.createDriver('vendor');
    helpers = new FlutterHelpers(driver);
    loginPage = new LoginPage(driver);
  });
  
  after(async function() {
    if (driver) {
      await DriverManager.quitDriver(driver);
    }
  });

  describe('Vendor Authentication', function() {
    it('should allow vendor to login successfully', async function() {
      try {
        console.log('Testing vendor login...');
        
        // Navigate to vendor login
        await helpers.findAndTap('key', 'vendor_login_button');
        await driver.pause(2000);
        
        // Perform login
        await loginPage.login(
          process.env.VENDOR_EMAIL || 'vendor@test.com',
          process.env.VENDOR_PASSWORD || 'vendorpass123'
        );
        
        // Verify vendor dashboard is loaded
        const vendorDashboard = await helpers.waitForElement('key', 'vendor_dashboard', 15000);
        expect(vendorDashboard).to.exist;
        
        console.log('✅ Vendor login successful');
        await DriverManager.takeScreenshot(driver, 'vendor_login_success');
        
      } catch (error) {
        console.error('❌ Vendor login failed:', error.message);
        await DriverManager.takeScreenshot(driver, 'vendor_login_failed');
        throw error;
      }
    });

    it('should display vendor profile information', async function() {
      try {
        console.log('Verifying vendor profile...');
        
        // Check vendor name display
        const vendorName = await helpers.findByText(process.env.VENDOR_NAME || 'Test Vendor');
        expect(vendorName).to.exist;
        
        // Verify vendor dashboard elements
        const menuManagement = await helpers.findByKey('menu_management_button');
        const orderHistory = await helpers.findByKey('order_history_button');
        const analytics = await helpers.findByKey('analytics_button');
        
        expect(menuManagement).to.exist;
        expect(orderHistory).to.exist;
        expect(analytics).to.exist;
        
        console.log('✅ Vendor profile verification complete');
        await DriverManager.takeScreenshot(driver, 'vendor_profile_verified');
        
      } catch (error) {
        console.error('❌ Vendor profile verification failed:', error.message);
        await DriverManager.takeScreenshot(driver, 'vendor_profile_failed');
        throw error;
      }
    });
  });

  describe('Menu Management', function() {
    it('should access menu management section', async function() {
      try {
        console.log('Testing menu management access...');
        
        // Navigate to menu management
        await helpers.findAndTap('key', 'menu_management_button');
        await driver.pause(3000);
        
        // Verify menu management page loaded
        const menuTitle = await helpers.findByText('Menu Management');
        expect(menuTitle).to.exist;
        
        // Check for add item button
        const addItemButton = await helpers.findByKey('add_menu_item_button');
        expect(addItemButton).to.exist;
        
        console.log('✅ Menu management access successful');
        await DriverManager.takeScreenshot(driver, 'menu_management_accessed');
        
      } catch (error) {
        console.error('❌ Menu management access failed:', error.message);
        await DriverManager.takeScreenshot(driver, 'menu_management_failed');
        throw error;
      }
    });

    it('should be able to add a new menu item', async function() {
      try {
        console.log('Testing add menu item functionality...');
        
        // Tap add item button
        await helpers.findAndTap('key', 'add_menu_item_button');
        await driver.pause(2000);
        
        // Fill in item details
        await helpers.enterText('item_name_field', 'Test Burger');
        await helpers.enterText('item_description_field', 'Delicious test burger with fresh ingredients');
        await helpers.enterText('item_price_field', '12.99');
        await helpers.enterText('item_category_field', 'Main Course');
        
        // Save the item
        await helpers.findAndTap('key', 'save_menu_item_button');
        await driver.pause(3000);
        
        // Verify item was added
        const successMessage = await helpers.findByText('Item added successfully');
        expect(successMessage).to.exist;
        
        console.log('✅ Menu item added successfully');
        await DriverManager.takeScreenshot(driver, 'menu_item_added');
        
      } catch (error) {
        console.error('❌ Add menu item failed:', error.message);
        await DriverManager.takeScreenshot(driver, 'add_menu_item_failed');
        throw error;
      }
    });

    it('should be able to edit existing menu item', async function() {
      try {
        console.log('Testing edit menu item functionality...');
        
        // Find and tap edit button for first item
        await helpers.findAndTap('key', 'edit_menu_item_0');
        await driver.pause(2000);
        
        // Modify item price
        await helpers.clearAndEnterText('item_price_field', '14.99');
        
        // Save changes
        await helpers.findAndTap('key', 'save_menu_item_button');
        await driver.pause(3000);
        
        // Verify update success
        const successMessage = await helpers.findByText('Item updated successfully');
        expect(successMessage).to.exist;
        
        console.log('✅ Menu item edited successfully');
        await DriverManager.takeScreenshot(driver, 'menu_item_edited');
        
      } catch (error) {
        console.error('❌ Edit menu item failed:', error.message);
        await DriverManager.takeScreenshot(driver, 'edit_menu_item_failed');
        throw error;
      }
    });
  });

  describe('Order Management', function() {
    it('should display incoming orders', async function() {
      try {
        console.log('Testing order management...');
        
        // Navigate back to dashboard
        await helpers.findAndTap('key', 'back_button');
        await driver.pause(2000);
        
        // Access orders section
        await helpers.findAndTap('key', 'orders_button');
        await driver.pause(3000);
        
        // Check for orders list
        const ordersTitle = await helpers.findByText('Incoming Orders');
        expect(ordersTitle).to.exist;
        
        console.log('✅ Orders section accessed successfully');
        await DriverManager.takeScreenshot(driver, 'orders_section_accessed');
        
      } catch (error) {
        console.error('❌ Orders section access failed:', error.message);
        await DriverManager.takeScreenshot(driver, 'orders_section_failed');
        throw error;
      }
    });

    it('should be able to accept an order', async function() {
      try {
        console.log('Testing order acceptance...');
        
        // Look for first order (if available)
        const firstOrder = await helpers.findByKey('order_item_0');
        if (firstOrder) {
          // Tap to view order details
          await helpers.findAndTap('key', 'order_item_0');
          await driver.pause(2000);
          
          // Accept the order
          await helpers.findAndTap('key', 'accept_order_button');
          await driver.pause(3000);
          
          // Verify acceptance
          const acceptedStatus = await helpers.findByText('Order Accepted');
          expect(acceptedStatus).to.exist;
          
          console.log('✅ Order accepted successfully');
          await DriverManager.takeScreenshot(driver, 'order_accepted');
        } else {
          console.log('ℹ️ No orders available to accept');
          await DriverManager.takeScreenshot(driver, 'no_orders_available');
        }
        
      } catch (error) {
        console.error('❌ Order acceptance failed:', error.message);
        await DriverManager.takeScreenshot(driver, 'order_acceptance_failed');
        throw error;
      }
    });
  });

  describe('Analytics & Reports', function() {
    it('should access analytics dashboard', async function() {
      try {
        console.log('Testing analytics access...');
        
        // Navigate back to main dashboard
        await helpers.findAndTap('key', 'dashboard_button');
        await driver.pause(2000);
        
        // Access analytics
        await helpers.findAndTap('key', 'analytics_button');
        await driver.pause(3000);
        
        // Verify analytics page loaded
        const analyticsTitle = await helpers.findByText('Analytics Dashboard');
        expect(analyticsTitle).to.exist;
        
        // Check for key metrics
        const revenue = await helpers.findByKey('total_revenue_metric');
        const orders = await helpers.findByKey('total_orders_metric');
        
        expect(revenue).to.exist;
        expect(orders).to.exist;
        
        console.log('✅ Analytics dashboard accessed successfully');
        await DriverManager.takeScreenshot(driver, 'analytics_accessed');
        
      } catch (error) {
        console.error('❌ Analytics access failed:', error.message);
        await DriverManager.takeScreenshot(driver, 'analytics_failed');
        throw error;
      }
    });

    it('should display revenue charts', async function() {
      try {
        console.log('Testing revenue charts...');
        
        // Look for chart elements
        const dailyRevenue = await helpers.findByKey('daily_revenue_chart');
        const monthlyRevenue = await helpers.findByKey('monthly_revenue_chart');
        
        expect(dailyRevenue).to.exist;
        expect(monthlyRevenue).to.exist;
        
        console.log('✅ Revenue charts displayed successfully');
        await DriverManager.takeScreenshot(driver, 'revenue_charts_displayed');
        
      } catch (error) {
        console.error('❌ Revenue charts display failed:', error.message);
        await DriverManager.takeScreenshot(driver, 'revenue_charts_failed');
        throw error;
      }
    });
  });

  describe('Vendor Settings', function() {
    it('should access vendor settings', async function() {
      try {
        console.log('Testing vendor settings access...');
        
        // Navigate to settings
        await helpers.findAndTap('key', 'settings_button');
        await driver.pause(3000);
        
        // Verify settings page
        const settingsTitle = await helpers.findByText('Vendor Settings');
        expect(settingsTitle).to.exist;
        
        // Check for key settings options
        const profileSettings = await helpers.findByKey('profile_settings_option');
        const businessHours = await helpers.findByKey('business_hours_option');
        const notifications = await helpers.findByKey('notification_settings_option');
        
        expect(profileSettings).to.exist;
        expect(businessHours).to.exist;
        expect(notifications).to.exist;
        
        console.log('✅ Vendor settings accessed successfully');
        await DriverManager.takeScreenshot(driver, 'vendor_settings_accessed');
        
      } catch (error) {
        console.error('❌ Vendor settings access failed:', error.message);
        await DriverManager.takeScreenshot(driver, 'vendor_settings_failed');
        throw error;
      }
    });

    it('should be able to update business hours', async function() {
      try {
        console.log('Testing business hours update...');
        
        // Access business hours settings
        await helpers.findAndTap('key', 'business_hours_option');
        await driver.pause(2000);
        
        // Update opening time
        await helpers.findAndTap('key', 'opening_time_field');
        await driver.pause(1000);
        await helpers.findAndTap('key', 'time_9_00_am');
        
        // Update closing time
        await helpers.findAndTap('key', 'closing_time_field');
        await driver.pause(1000);
        await helpers.findAndTap('key', 'time_10_00_pm');
        
        // Save changes
        await helpers.findAndTap('key', 'save_business_hours_button');
        await driver.pause(3000);
        
        // Verify update success
        const successMessage = await helpers.findByText('Business hours updated');
        expect(successMessage).to.exist;
        
        console.log('✅ Business hours updated successfully');
        await DriverManager.takeScreenshot(driver, 'business_hours_updated');
        
      } catch (error) {
        console.error('❌ Business hours update failed:', error.message);
        await DriverManager.takeScreenshot(driver, 'business_hours_failed');
        throw error;
      }
    });
  });

  describe('Vendor Logout', function() {
    it('should allow vendor to logout successfully', async function() {
      try {
        console.log('Testing vendor logout...');
        
        // Navigate to profile/logout
        await helpers.findAndTap('key', 'vendor_profile_button');
        await driver.pause(2000);
        
        // Tap logout
        await helpers.findAndTap('key', 'logout_button');
        await driver.pause(2000);
        
        // Confirm logout
        await helpers.findAndTap('key', 'confirm_logout_button');
        await driver.pause(3000);
        
        // Verify we're back to login/welcome screen
        const welcomeScreen = await helpers.findByText('Welcome to MealMommy');
        expect(welcomeScreen).to.exist;
        
        console.log('✅ Vendor logout successful');
        await DriverManager.takeScreenshot(driver, 'vendor_logout_success');
        await DriverManager.markTestStatus(driver, 'passed', 'Vendor logout test completed successfully');
        
      } catch (error) {
        console.error('❌ Vendor logout failed:', error.message);
        await DriverManager.takeScreenshot(driver, 'vendor_logout_failed');
        await DriverManager.markTestStatus(driver, 'failed', `Vendor logout test failed: ${error.message}`);
        throw error;
      }
    });
  });
});
