require('dotenv').config();

const browserStackConfig = {
  user: process.env.BROWSERSTACK_USERNAME,
  key: process.env.BROWSERSTACK_ACCESS_KEY,
  server: 'hub-cloud.browserstack.com',
  
  // Android specific configurations
  android: {
    devices: [
      {
        deviceName: 'Samsung Galaxy S23',
        platformName: 'Android',
        platformVersion: '13.0',
        capabilities: {
          'bstack:options': {
            projectName: process.env.PROJECT_NAME || 'MealMommy Automation',
            buildName: process.env.BUILD_NAME || `MealMommy Build ${new Date().getTime()}`,
            sessionName: 'Android Samsung Galaxy S23 Test',
            debug: true,
            networkLogs: true,
            video: true,
            appiumLogs: true,
            deviceName: 'Samsung Galaxy S23',
            osVersion: '13.0'
          },
          platformName: 'Android',
          'appium:app': process.env.APP_URL,
          'appium:automationName': 'UiAutomator2',
          'appium:autoGrantPermissions': true,
          'appium:noReset': false,
          'appium:fullReset': false
        }
      },
      {
        deviceName: 'Google Pixel 7',
        platformName: 'Android',
        platformVersion: '13.0',
        capabilities: {
          'bstack:options': {
            projectName: process.env.PROJECT_NAME || 'MealMommy Automation',
            buildName: process.env.BUILD_NAME || `MealMommy Build ${new Date().getTime()}`,
            sessionName: 'Android Google Pixel 7 Test',
            debug: true,
            networkLogs: true,
            video: true,
            appiumLogs: true,
            deviceName: 'Google Pixel 7',
            osVersion: '13.0'
          },
          platformName: 'Android',
          'appium:app': process.env.APP_URL,
          'appium:automationName': 'UiAutomator2',
          'appium:autoGrantPermissions': true,
          'appium:noReset': false,
          'appium:fullReset': false
        }
      }
    ]
  },

  // iOS specific configurations (disabled until iOS app is available)
  ios: {
    devices: [
      {
        deviceName: 'iPhone 14',
        platformName: 'iOS',
        platformVersion: '16',
        capabilities: {
          'bstack:options': {
            projectName: process.env.PROJECT_NAME || 'MealMommy Automation',
            buildName: process.env.BUILD_NAME || `MealMommy Build ${new Date().getTime()}`,
            sessionName: 'iOS iPhone 14 Test',
            debug: true,
            networkLogs: true,
            video: true,
            appiumLogs: true,
            deviceName: 'iPhone 14',
            osVersion: '16'
          },
          platformName: 'iOS',
          'appium:app': process.env.IOS_APP_URL || 'bs://your_ios_app_url_here',
          'appium:automationName': 'XCUITest',
          'appium:autoAcceptAlerts': true,
          'appium:noReset': false,
          'appium:fullReset': false
        }
      }
    ]
  }
};

module.exports = browserStackConfig;
