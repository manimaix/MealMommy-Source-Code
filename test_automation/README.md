# MealMommy BrowserStack Appium Test Suite

This is a comprehensive test automation suite for the MealMommy Flutter application using Appium and BrowserStack cloud infrastructure.

## 🚀 Quick Start

### Prerequisites

1. **Node.js** (v16 or higher)
2. **BrowserStack Account** with Automate Mobile plan
3. **MealMommy App** uploaded to BrowserStack App Storage

### Installation

1. **Clone and navigate to test directory:**
   ```bash
   cd test_automation
   npm install
   ```

2. **Configure environment variables:**
   ```bash
   cp .env.example .env
   # Edit .env file with your BrowserStack credentials and app URL
   ```

3. **Upload your app to BrowserStack:**
   ```bash
   # Upload APK/IPA to BrowserStack App Storage
   curl -u "USERNAME:ACCESS_KEY" \
   -X POST "https://api-cloud.browserstack.com/app-automate/upload" \
   -F "file=@/path/to/your/app.apk"
   ```

## 📱 Test Configuration

### Environment Variables (.env)

```env
# BrowserStack Credentials
BROWSERSTACK_USERNAME=your_username
BROWSERSTACK_ACCESS_KEY=your_access_key

# App Configuration
APP_URL=bs://your_app_url_after_upload

# Test Data
TEST_EMAIL=customer@mealmommy.com
TEST_PASSWORD=password123
DRIVER_EMAIL=driver@mealmommy.com
DRIVER_PASSWORD=driverpass123
VENDOR_EMAIL=vendor@mealmommy.com
VENDOR_PASSWORD=vendorpass123
```

### Supported Devices

#### Android Devices:
- Samsung Galaxy S23 (Android 13.0)
- Google Pixel 7 (Android 13.0)

#### iOS Devices:
- iPhone 14 (iOS 16)
- iPhone 13 (iOS 15)

## 🧪 Running Tests

### All Tests
```bash
npm test
```

### Platform Specific Tests
```bash
# Android only
npm run test:android

# iOS only
npm run test:ios
```

### Feature Specific Tests
```bash
# Login functionality
npm run test:login

# Customer features
npm run test:customer

# Driver features
npm run test:driver

# Smoke tests only
npm run test:smoke
```

### Parallel Testing
```bash
# Run tests on multiple devices simultaneously
npm run test:parallel
```

## 📂 Project Structure

```
test_automation/
├── config/
│   └── browserstack.config.js    # BrowserStack configuration
├── utils/
│   ├── driver-manager.js         # WebDriver management
│   └── flutter-helpers.js        # Flutter-specific helpers
├── page-objects/
│   ├── login-page.js             # Login page actions
│   ├── customer-home-page.js     # Customer home page
│   └── driver-home-page.js       # Driver home page
├── test/
│   └── specs/
│       ├── smoke.test.js         # Basic functionality tests
│       ├── customer.test.js      # Customer flow tests
│       ├── driver.test.js        # Driver flow tests
│       └── vendor.test.js        # Vendor flow tests
├── package.json
├── .env.example
└── README.md
```

## 🔧 Test Features

### Core Functionality Tested

#### 🔐 Authentication
- [x] Login form validation
- [x] Invalid credential handling
- [x] Successful login for all user types
- [x] Session management

#### 👥 Customer Features
- [x] Home page loading
- [x] Menu browsing
- [x] Search functionality
- [x] Meal selection
- [x] Cart operations
- [x] Profile access

#### 🚚 Driver Features
- [x] Driver dashboard
- [x] Online/offline toggle
- [x] Order acceptance
- [x] Map functionality
- [x] Delivery management
- [x] Chat functionality

#### 🏪 Vendor Features
- [x] Vendor dashboard
- [x] Menu management
- [x] Order processing
- [x] Revenue tracking

### Cross-Platform Testing
- [x] Android and iOS compatibility
- [x] Screen orientation handling
- [x] Network condition simulation
- [x] Permission handling
- [x] App lifecycle management

## 📊 BrowserStack Integration

### Features Utilized
- **Real Device Testing**: Tests run on actual mobile devices
- **Video Recording**: All test sessions recorded
- **Screenshot Capture**: Automatic screenshots on failures
- **Network Simulation**: Test under different network conditions
- **Debug Logs**: Comprehensive logging for troubleshooting
- **Parallel Execution**: Run multiple tests simultaneously

### BrowserStack Dashboard
Access your test results at: https://app-automate.browserstack.com/

## 🐛 Debugging

### Common Issues

1. **App Upload Issues**
   ```bash
   # Verify app upload
   curl -u "USERNAME:ACCESS_KEY" \
   -X GET "https://api-cloud.browserstack.com/app-automate/recent_apps"
   ```

2. **Element Not Found**
   - Check if element selectors match your app's current state
   - Use BrowserStack's inspector tool
   - Add explicit waits for dynamic content

3. **Session Timeout**
   - Increase timeout values in test configuration
   - Check network connectivity
   - Verify BrowserStack credit availability

### Debugging Commands
```bash
# Run with verbose logging
DEBUG=true npm test

# Run single test file
npx mocha test/specs/smoke.test.js --timeout 60000

# Generate detailed reports
npm test -- --reporter spec
```

## 📈 Test Reports

### Screenshot Management
- Screenshots automatically captured on test failures
- Success screenshots for key user flows
- Stored in BrowserStack dashboard with session videos

### Test Status Marking
Tests automatically mark BrowserStack sessions as:
- ✅ **Passed**: All assertions successful
- ❌ **Failed**: Test failures with error details
- ⚠️ **Skipped**: Tests skipped due to conditions

## 🔄 CI/CD Integration

### GitHub Actions Example
```yaml
name: MealMommy Mobile Tests
on: [push, pull_request]

jobs:
  mobile-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
      - run: cd test_automation && npm install
      - run: cd test_automation && npm run test:smoke
        env:
          BROWSERSTACK_USERNAME: ${{ secrets.BROWSERSTACK_USERNAME }}
          BROWSERSTACK_ACCESS_KEY: ${{ secrets.BROWSERSTACK_ACCESS_KEY }}
          APP_URL: ${{ secrets.APP_URL }}
```

## 📚 Best Practices

### Test Writing
1. **Use Page Object Model**: Organize code by page/screen
2. **Explicit Waits**: Always wait for elements before interaction
3. **Error Handling**: Implement robust error handling and recovery
4. **Test Data Management**: Use environment variables for test data
5. **Screenshot Strategy**: Capture evidence for debugging

### Performance
1. **Parallel Execution**: Run tests in parallel when possible
2. **Test Isolation**: Each test should be independent
3. **Resource Cleanup**: Properly close sessions and free resources
4. **Selective Testing**: Use tags to run specific test suites

## 🆘 Support

### Documentation Links
- [BrowserStack Appium Documentation](https://www.browserstack.com/docs/app-automate)
- [Flutter Driver Documentation](https://flutter.dev/docs/cookbook/testing/integration/introduction)
- [WebDriverIO Documentation](https://webdriver.io/)

### Troubleshooting
1. Check BrowserStack dashboard for detailed logs
2. Verify app permissions and capabilities
3. Ensure test data is valid and accessible
4. Review network conditions and device availability

## 📝 Contributing

1. **Add new tests**: Create new spec files in `test/specs/`
2. **Extend page objects**: Add new methods to existing page objects
3. **Update configuration**: Modify `browserstack.config.js` for new devices
4. **Improve helpers**: Enhance Flutter helpers for better element handling

---

**Happy Testing! 🎉**

For questions or support, please refer to the BrowserStack documentation or contact your QA team.
