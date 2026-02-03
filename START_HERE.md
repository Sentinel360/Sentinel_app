# Sentinel 360 Mobile - Quick Start (2 Minutes)

## Prerequisites
- Node.js 18+ installed
- Expo Go app on your phone (iOS App Store or Google Play Store)

## Step 1: Install Dependencies (1 minute)
```bash
cd sentinel360-mobile
npm install
```

## Step 2: Create Placeholder Icons (30 seconds)
Create simple placeholder icons (or use your own):

### macOS/Linux:
```bash
# Create simple colored placeholder icons
mkdir -p assets
echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==" | base64 -d > assets/icon.png
cp assets/icon.png assets/adaptive-icon.png
cp assets/icon.png assets/splash-icon.png
cp assets/icon.png assets/favicon.png
```

### Windows (PowerShell):
```powershell
# Download a simple blue placeholder from the internet
# Or create any 1024x1024 PNG and name it icon.png
```

**Or just skip this step** - The app will still run, you'll just see a warning.

## Step 3: Start the App (30 seconds)
```bash
npx expo start -c
```

## Step 4: Open on Your Phone
1. Scan the QR code with:
   - **iOS**: Camera app
   - **Android**: Expo Go app
2. The app will load in Expo Go!

---

## That's It!

You should now see the Sentinel 360 app running on your phone.

### What You'll See:
1. **Onboarding** - 4 screens explaining the app
2. **Login** - Sign in screen (just tap any button to proceed)
3. **Home Dashboard** - Main status screen with device info
4. **Bottom Navigation** - Access Alerts, Analytics, Device, Settings
5. **Trip Tracking** - Start/stop trip timer
6. **Emergency Alert** - Countdown emergency screen

### Troubleshooting:
- If you see package errors, run: `npm install --legacy-peer-deps`
- If metro bundler gets stuck, press `r` to reload
- If the app crashes, try: `npx expo start -c` (clears cache)

### Need More Help?
See the full [README.md](./README.md) for detailed documentation.
