const { describe, it, before, after } = require('mocha');
const { expect } = require('chai');
const DriverManager = require('../../utils/driver-manager');

describe('Basic Android App Test', function() {
  this.timeout(120000);
  
  let driver;
  
  before(async function() {
    console.log('🚀 Starting Basic Android App Test...');
    driver = await DriverManager.createDriver('android');
  });
  
  after(async function() {
    if (driver) {
      await DriverManager.quitDriver(driver);
    }
  });

  it('should launch the app successfully', async function() {
    try {
      console.log('Testing app launch...');
      
      // Wait for app to load
      await driver.pause(5000);
      
      // Get page source to see what's available
      const pageSource = await driver.getPageSource();
      console.log('App launched successfully! Page source length:', pageSource.length);
      
      // Take a screenshot
      await DriverManager.takeScreenshot(driver, 'app_launched');
      
      // Try to find common elements
      const elements = await driver.$$('*');
      console.log(`Found ${elements.length} elements on screen`);
      
      expect(elements.length).to.be.greaterThan(0);
      
      console.log('✅ App launch test successful');
      await DriverManager.markTestStatus(driver, 'passed', 'App launched successfully');
      
    } catch (error) {
      console.error('❌ App launch failed:', error.message);
      await DriverManager.takeScreenshot(driver, 'app_launch_failed');
      await DriverManager.markTestStatus(driver, 'failed', `App launch test failed: ${error.message}`);
      throw error;
    }
  });

  it('should be able to interact with the app', async function() {
    try {
      console.log('Testing basic interactions...');
      
      // Get all clickable elements
      const clickableElements = await driver.$$('[clickable="true"]');
      console.log(`Found ${clickableElements.length} clickable elements`);
      
      // Get all text fields
      const textFields = await driver.$$('[class*="EditText"]');
      console.log(`Found ${textFields.length} text fields`);
      
      // Get all buttons
      const buttons = await driver.$$('[class*="Button"]');
      console.log(`Found ${buttons.length} buttons`);
      
      await DriverManager.takeScreenshot(driver, 'app_elements_analyzed');
      
      expect(clickableElements.length + textFields.length + buttons.length).to.be.greaterThan(0);
      
      console.log('✅ Basic interaction test successful');
      
    } catch (error) {
      console.error('❌ Basic interaction test failed:', error.message);
      await DriverManager.takeScreenshot(driver, 'interaction_test_failed');
      throw error;
    }
  });
});
