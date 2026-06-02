# iOS In-App Purchase Testing Guide

## Prerequisites
- **Bundle ID**: `com.swastik.omeebaApp`
- **Product IDs**:
  - `omeeba_weekly_subscription`
  - `omeeba_monthly_subscription`
  - `omeeba_yearly_subscription`

---

## Step 1: Configure Products in App Store Connect

### 1.1 Create In-App Purchase Products
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to **My Apps** → Select your app → **Features** → **In-App Purchases**
3. Click the **+** button to create a new in-app purchase
4. For each product, fill in:

   **Product 1: Weekly Subscription**
   - **Type**: Auto-Renewable Subscription
   - **Product ID**: `omeeba_weekly_subscription`
   - **Reference Name**: Omeeba Weekly Subscription
   - **Subscription Group**: Create a new group (e.g., "Omeeba Verified Badge")
   - **Subscription Duration**: 1 Week
   - **Price**: Set your price
   - **Localizations**: Add at least English (US)
     - Display Name: "Weekly Subscription"
     - Description: "Weekly subscription for verified badge"

   **Product 2: Monthly Subscription**
   - **Type**: Auto-Renewable Subscription
   - **Product ID**: `omeeba_monthly_subscription`
   - **Reference Name**: Omeeba Monthly Subscription
   - **Subscription Group**: Same group as weekly
   - **Subscription Duration**: 1 Month
   - **Price**: Set your price
   - **Localizations**: Add at least English (US)

   **Product 3: Yearly Subscription**
   - **Type**: Auto-Renewable Subscription
   - **Product ID**: `omeeba_yearly_subscription`
   - **Reference Name**: Omeeba Yearly Subscription
   - **Subscription Group**: Same group as weekly
   - **Subscription Duration**: 1 Year
   - **Price**: Set your price
   - **Localizations**: Add at least English (US)

### 1.2 Important Notes
- ⚠️ **Product IDs are case-sensitive** - must match exactly
- ⚠️ Products must be in **"Ready to Submit"** status (not "Missing Metadata")
- ⚠️ All three products should be in the **same subscription group**
- ⚠️ You can test products even if your app is not yet submitted to App Store

---

## Step 2: Create Sandbox Tester Account

### 2.1 Create Test Account in App Store Connect
1. Go to **Users and Access** → **Sandbox Testers**
2. Click **+** to add a new tester
3. Fill in:
   - **First Name**: Test
   - **Last Name**: User
   - **Email**: Use a **real email** you can access (e.g., `test.omeeba@gmail.com`)
   - **Password**: Create a password (remember it!)
   - **Country/Region**: Select your country
   - **App Store Territory**: Select your territory
4. Click **Save**

### 2.2 Important Notes
- ⚠️ **DO NOT** use your real Apple ID email
- ⚠️ Sandbox accounts are **separate** from regular Apple IDs
- ⚠️ You can create multiple sandbox testers for different scenarios

---

## Step 3: Prepare Your iOS Device

### 3.1 Sign Out of App Store on Device
1. Open **Settings** app on your iPhone/iPad
2. Scroll down and tap **App Store**
3. Tap your Apple ID at the top
4. Tap **Sign Out**
5. **Important**: Stay signed out of App Store (but keep signed in to iCloud if needed)

### 3.2 Why Sign Out?
- When testing IAP, iOS will prompt you to sign in
- If you're already signed in with a real Apple ID, it won't use sandbox
- Signing out ensures sandbox tester account is used

---

## Step 4: Build and Install App on Device

### 4.1 Build for Device
```bash
# Make sure you're in the project directory
cd /Users/nikunjgoyani/AndroidStudioProjects/omeeba_new

# Clean build
flutter clean

# Get dependencies
flutter pub get

# Build for iOS device (connected via USB)
flutter build ios --release

# Or build and run directly
flutter run --release
```

### 4.2 Alternative: Use Xcode
1. Open `ios/Runner.xcodeproj` in Xcode
2. Select your device from the device dropdown
3. Click **Run** (▶️) or press `Cmd + R`
4. Make sure you're using a **Release** or **Profile** configuration (not Debug for IAP testing)

### 4.3 Important Notes
- ⚠️ **Use a real device** - StoreKit doesn't work reliably in Simulator
- ⚠️ Device must be connected via USB or have wireless debugging enabled
- ⚠️ Make sure your device is registered in Apple Developer Portal

---

## Step 5: Test the Purchase Flow

### 5.1 First Launch
1. Launch the app on your device
2. Navigate to the verified badge purchase screen
3. The app will attempt to load products from App Store Connect

### 5.2 When Prompted to Sign In
1. When you tap "Purchase", iOS will show a sign-in dialog
2. **Enter your sandbox tester credentials** (the email/password from Step 2)
3. This is **NOT** your regular Apple ID - it's the sandbox account
4. iOS will confirm "You're signing in to the App Store. This account is for testing only."

### 5.3 Complete Purchase
1. After signing in with sandbox account, the purchase dialog appears
2. Tap **Buy** or **Subscribe**
3. The purchase will complete **immediately** (no real charge)
4. You'll see a confirmation dialog

### 5.4 Verify Purchase
- Check that the purchase is processed in your app
- The app should show success message
- Verify the purchase is synced to your backend (if implemented)

---

## Step 6: Testing Different Scenarios

### 6.1 Test All Three Plans
- Test weekly subscription
- Test monthly subscription  
- Test yearly subscription
- Verify all product IDs load correctly

### 6.2 Test Restore Purchases
1. In your app, find the "Restore Purchases" option
2. Tap it
3. Sign in with sandbox account if prompted
4. Verify previous purchases are restored

### 6.3 Test Subscription Renewal
- Sandbox subscriptions renew **much faster** than production:
  - Weekly: Renews every 3 minutes
  - Monthly: Renews every 5 minutes
  - Yearly: Renews every 1 hour
- Use this to test renewal logic

### 6.4 Test Cancellation
1. Go to **Settings** → **App Store** → Tap your sandbox account
2. Tap **Manage Subscriptions**
3. Cancel a subscription
4. Test how your app handles cancelled subscriptions

---

## Step 7: Troubleshooting

### Problem: "Failed to get response from platform"
**Solutions:**
- ✅ Verify product IDs match exactly (case-sensitive)
- ✅ Check products are "Ready to Submit" in App Store Connect
- ✅ Ensure you're signed out of App Store on device
- ✅ Make sure you're testing on a **real device** (not simulator)
- ✅ Check internet connection
- ✅ Wait a few minutes after creating products (propagation delay)

### Problem: Products don't load
**Solutions:**
- ✅ Check product IDs in code match App Store Connect exactly
- ✅ Verify products are in the same subscription group
- ✅ Make sure products have all required metadata filled
- ✅ Try force-refreshing: Close app completely and reopen

### Problem: "This Apple ID has not yet been used with the App Store"
**Solutions:**
- ✅ This is normal for new sandbox accounts
- ✅ Tap **Review** and accept terms
- ✅ Complete the account setup

### Problem: Real Apple ID keeps signing in instead of sandbox
**Solutions:**
- ✅ Make sure you signed out of App Store in Settings
- ✅ Don't use Face ID/Touch ID for App Store purchases during testing
- ✅ When prompted, manually enter sandbox credentials

### Problem: Purchase completes but app doesn't recognize it
**Solutions:**
- ✅ Check console logs for StoreKit errors
- ✅ Verify purchase stream listener is set up correctly
- ✅ Check that `completePurchase()` is called after verification
- ✅ Ensure product IDs in purchase match your expected IDs

---

## Step 8: View Purchase Receipts

### 8.1 In App Store Connect
1. Go to **Sales and Trends** → **In-App Purchases**
2. View sandbox purchases (they appear with a "Sandbox" label)

### 8.2 On Device
1. Settings → App Store → [Sandbox Account]
2. Tap **Manage Subscriptions**
3. View active subscriptions

---

## Step 9: Clean Up After Testing

### 9.1 Cancel Test Subscriptions
- Go to Settings → App Store → Manage Subscriptions
- Cancel all test subscriptions

### 9.2 Sign Back In
- After testing, sign back into App Store with your real Apple ID
- This restores normal App Store functionality

---

## Additional Tips

1. **Console Logging**: Check Xcode console for detailed StoreKit logs
2. **Network**: Ensure device has stable internet connection
3. **Time**: Wait 5-10 minutes after creating products in App Store Connect
4. **Multiple Devices**: You can test on multiple devices with same sandbox account
5. **Production Testing**: Once app is live, use TestFlight for production-like testing

---

## Quick Checklist

- [ ] Products created in App Store Connect with correct IDs
- [ ] Products are "Ready to Submit" status
- [ ] Sandbox tester account created
- [ ] Signed out of App Store on test device
- [ ] App built and installed on real device
- [ ] Testing with sandbox account credentials
- [ ] All three subscription plans tested
- [ ] Restore purchases tested
- [ ] Console logs checked for errors

---

## Need Help?

If you encounter issues:
1. Check Xcode console for detailed error messages
2. Verify product IDs match exactly
3. Ensure products are properly configured in App Store Connect
4. Make sure you're using a real device (not simulator)
5. Check that you're signed out of App Store before testing

Good luck with your testing! 🚀
