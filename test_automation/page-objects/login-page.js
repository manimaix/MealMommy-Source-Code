const FlutterHelpers = require('../utils/flutter-helpers');

class LoginPage {
  constructor(driver) {
    this.driver = driver;
    this.flutter = new FlutterHelpers(driver);
    
    // Element selectors for MealMommy login page
    this.emailField = 'key("email_field")';
    this.passwordField = 'key("password_field")';
    this.loginButton = 'key("login_button")';
    this.registerButton = 'key("register_button")';
    this.forgotPasswordLink = 'text("Forgot Password?")';
    this.emailValidationError = 'text("Please enter a valid email")';
    this.passwordValidationError = 'text("Password must be at least 6 characters")';
    this.loginErrorMessage = 'text("Invalid email or password")';
    this.loadingIndicator = 'type("CircularProgressIndicator")';
    
    // Alternative selectors if keys are not available
    this.emailFieldAlt = 'type("TextField")[0]';
    this.passwordFieldAlt = 'type("TextField")[1]';
    this.loginButtonAlt = 'text("Sign In")';
    this.registerButtonAlt = 'text("Register")';
  }

  async waitForPageLoad() {
    try {
      console.log('📱 Loading Login Page...');
      await this.flutter.waitForAppReady();
      
      // Wait for either the key-based or text-based login button
      const loginButtonExists = await this.flutter.isElementExists(this.loginButton, 5000);
      if (!loginButtonExists) {
        await this.flutter.waitForElement(this.loginButtonAlt, 10000);
      }
      
      console.log('✅ Login page loaded successfully');
    } catch (error) {
      console.error('❌ Failed to load login page:', error.message);
      throw error;
    }
  }

  async enterEmail(email) {
    try {
      console.log(`📧 Entering email: ${email}`);
      
      // Try key-based selector first, then fallback to type-based
      if (await this.flutter.isElementExists(this.emailField, 3000)) {
        await this.flutter.enterText(this.emailField, email);
      } else {
        await this.flutter.enterText(this.emailFieldAlt, email);
      }
      
      console.log('✅ Email entered successfully');
    } catch (error) {
      console.error('❌ Failed to enter email:', error.message);
      throw error;
    }
  }

  async enterPassword(password) {
    try {
      console.log('🔐 Entering password...');
      
      // Try key-based selector first, then fallback to type-based
      if (await this.flutter.isElementExists(this.passwordField, 3000)) {
        await this.flutter.enterText(this.passwordField, password);
      } else {
        await this.flutter.enterText(this.passwordFieldAlt, password);
      }
      
      console.log('✅ Password entered successfully');
    } catch (error) {
      console.error('❌ Failed to enter password:', error.message);
      throw error;
    }
  }

  async tapLoginButton() {
    try {
      console.log('👆 Tapping login button...');
      
      // Try key-based selector first, then fallback to text-based
      if (await this.flutter.isElementExists(this.loginButton, 3000)) {
        await this.flutter.tapElement(this.loginButton);
      } else {
        await this.flutter.tapElement(this.loginButtonAlt);
      }
      
      console.log('✅ Login button tapped');
    } catch (error) {
      console.error('❌ Failed to tap login button:', error.message);
      throw error;
    }
  }

  async tapRegisterButton() {
    try {
      console.log('👆 Tapping register button...');
      
      if (await this.flutter.isElementExists(this.registerButton, 3000)) {
        await this.flutter.tapElement(this.registerButton);
      } else {
        await this.flutter.tapElement(this.registerButtonAlt);
      }
      
      console.log('✅ Register button tapped');
    } catch (error) {
      console.error('❌ Failed to tap register button:', error.message);
      throw error;
    }
  }

  async waitForLoadingToComplete() {
    try {
      console.log('⏳ Waiting for login loading to complete...');
      
      // Wait for loading indicator to appear
      if (await this.flutter.isElementExists(this.loadingIndicator, 5000)) {
        // Wait for loading indicator to disappear
        await this.driver.$(this.loadingIndicator).waitForExist({ timeout: 30000, reverse: true });
      }
      
      console.log('✅ Loading completed');
    } catch (error) {
      console.log('ℹ️ No loading indicator found or loading completed');
    }
  }

  async getValidationError() {
    try {
      if (await this.flutter.isElementExists(this.emailValidationError, 3000)) {
        return await this.driver.$(this.emailValidationError).getText();
      }
      if (await this.flutter.isElementExists(this.passwordValidationError, 3000)) {
        return await this.driver.$(this.passwordValidationError).getText();
      }
      if (await this.flutter.isElementExists(this.loginErrorMessage, 3000)) {
        return await this.driver.$(this.loginErrorMessage).getText();
      }
      return null;
    } catch (error) {
      console.error('❌ Error getting validation message:', error.message);
      return null;
    }
  }

  async login(email, password) {
    try {
      console.log(`🔑 Logging in with email: ${email}`);
      
      await this.waitForPageLoad();
      await this.enterEmail(email);
      await this.enterPassword(password);
      await this.tapLoginButton();
      await this.waitForLoadingToComplete();
      
      // Wait a moment for navigation
      await this.driver.pause(3000);
      
      console.log('✅ Login process completed');
    } catch (error) {
      console.error('❌ Login failed:', error.message);
      throw error;
    }
  }

  // Verify successful login by checking if we're on a different page
  async isLoginSuccessful() {
    try {
      // Check if we're no longer on the login page
      const loginButtonExists = await this.flutter.isElementExists(this.loginButton, 3000) || 
                               await this.flutter.isElementExists(this.loginButtonAlt, 3000);
      
      return !loginButtonExists;
    } catch (error) {
      console.error('❌ Error checking login success:', error.message);
      return false;
    }
  }
}

module.exports = LoginPage;
