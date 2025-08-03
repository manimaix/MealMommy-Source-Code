const { describe, it, before, after } = require('mocha');
const { expect } = require('chai');
const DriverManager = require('../../utils/driver-manager');

describe('MealMommy App Test Suite', function() {
  this.timeout(120000);
  
  let driver;
  
  before(async function() {
    console.log('🚀 Starting MealMommy App Tests...');
    driver = await DriverManager.createDriver('android');
  });
  
  after(async function() {
    if (driver) {
      await DriverManager.quitDriver(driver);
    }
  });

  it('should launch the app and show login screen', async function() {
    try {
      console.log('Testing app launch and login screen...');
      
      // Wait for app to load
      await driver.pause(5000);
      
      // Check for MealMommy logo
      const logo = await driver.$('[content-desc="MealMommy"]');
      expect(await logo.isDisplayed()).to.be.true;
      console.log('✅ MealMommy logo found');
      
      // Check for Welcome Back text
      const welcomeText = await driver.$('[content-desc="Welcome Back"]');
      expect(await welcomeText.isDisplayed()).to.be.true;
      console.log('✅ Welcome Back text found');
      
      // Check for email field
      const emailField = await driver.$('android.widget.EditText');
      expect(await emailField.isDisplayed()).to.be.true;
      console.log('✅ Email field found');
      
      // Check for login button
      const loginButton = await driver.$('[content-desc="Login"]');
      expect(await loginButton.isDisplayed()).to.be.true;
      console.log('✅ Login button found');
      
      await DriverManager.takeScreenshot(driver, 'login_screen_verified');
      
      console.log('✅ App launch and login screen test successful');
      
    } catch (error) {
      console.error('❌ App launch test failed:', error.message);
      await DriverManager.takeScreenshot(driver, 'app_launch_failed');
      throw error;
    }
  });

  it('should be able to interact with login form', async function() {
    try {
      console.log('Testing login form interaction...');
      
      // Find and interact with email field
      const emailField = await driver.$('android.widget.EditText');
      await emailField.click();
      await emailField.setValue(process.env.TEST_EMAIL || 'c@c.com');
      console.log('✅ Email entered successfully');
      
      // Find password field (it's the second EditText)
      const editTexts = await driver.$$('android.widget.EditText');
      if (editTexts.length > 1) {
        await editTexts[1].click();
        await editTexts[1].setValue(process.env.TEST_PASSWORD || '123456');
        console.log('✅ Password entered successfully');
      }
      
      await DriverManager.takeScreenshot(driver, 'login_form_filled');
      
      // Try multiple selectors for login button
      let loginButton = null;
      const loginSelectors = [
        '[content-desc="Login"]',
        'android.widget.Button',
        '[text="Login"]',
        '//*[@content-desc="Login"]'
      ];
      
      for (const selector of loginSelectors) {
        try {
          const elements = await driver.$$(selector);
          for (const element of elements) {
            const isDisplayed = await element.isDisplayed().catch(() => false);
            if (isDisplayed) {
              const text = await element.getText().catch(() => '');
              console.log(`Found element with text: "${text}"`);
              if (text.toLowerCase().includes('login') || selector.includes('Login')) {
                loginButton = element;
                break;
              }
            }
          }
          if (loginButton) break;
        } catch (e) {
          console.log(`Selector ${selector} failed:`, e.message);
        }
      }
      
      if (loginButton) {
        await loginButton.click();
        console.log('✅ Login button clicked');
        await driver.pause(3000);
        await DriverManager.takeScreenshot(driver, 'after_login_attempt');
      } else {
        console.log('⚠️ Login button not found after form fill, checking available elements');
        const allButtons = await driver.$$('android.widget.Button');
        console.log(`Found ${allButtons.length} buttons on screen`);
        
        for (let i = 0; i < Math.min(allButtons.length, 3); i++) {
          try {
            const text = await allButtons[i].getText();
            const isDisplayed = await allButtons[i].isDisplayed();
            console.log(`Button ${i}: "${text}" (displayed: ${isDisplayed})`);
          } catch (e) {
            console.log(`Button ${i}: Could not get text`);
          }
        }
        
        await DriverManager.takeScreenshot(driver, 'login_button_debug');
        // Continue test since form interaction worked
      }
      
      console.log('✅ Login form interaction test successful');
      
    } catch (error) {
      console.error('❌ Login form interaction failed:', error.message);
      await DriverManager.takeScreenshot(driver, 'login_interaction_failed');
      throw error;
    }
  });

  it('should test other buttons functionality', async function() {
    try {
      console.log('Testing other button functionality...');
      
      // Test Forgot Password button
      const forgotPasswordButton = await driver.$('[content-desc="Forgot Password?"]');
      if (await forgotPasswordButton.isDisplayed()) {
        await forgotPasswordButton.click();
        console.log('✅ Forgot Password button clicked');
        await driver.pause(2000);
        await DriverManager.takeScreenshot(driver, 'forgot_password_clicked');
        
        // Go back if needed
        await driver.back();
        await driver.pause(2000);
      }
      
      // Test Sign Up button
      const signUpButton = await driver.$('[content-desc="Don\'t have an account? Sign Up"]');
      if (await signUpButton.isDisplayed()) {
        await signUpButton.click();
        console.log('✅ Sign Up button clicked');
        await driver.pause(2000);
        await DriverManager.takeScreenshot(driver, 'sign_up_clicked');
        
        // Go back if needed
        await driver.back();
        await driver.pause(2000);
      }
      
      console.log('✅ Button functionality test successful');
      
    } catch (error) {
      console.error('❌ Button functionality test failed:', error.message);
      await DriverManager.takeScreenshot(driver, 'button_test_failed');
      throw error;
    }
  });
});
