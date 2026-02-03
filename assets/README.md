# Assets Folder

This folder should contain your app icons and splash screen images.

## Required Files

### App Icons

1. **icon.png** (1024x1024 px)
   - Main app icon
   - Used for both iOS and Android
   - Should be a square PNG with no transparency

2. **adaptive-icon.png** (1024x1024 px)
   - Android adaptive icon foreground
   - Should have some padding (the system will crop it)

### Splash Screen

3. **splash-icon.png** (512x512 px or larger)
   - Splash screen image
   - Displayed while the app loads
   - Should be centered on a solid color background

4. **favicon.png** (48x48 px)
   - Web favicon (if you build for web)

## Creating Your Icons

### Option 1: Use a Design Tool
- Create icons in Figma, Sketch, or Adobe XD
- Export as PNG at the required sizes

### Option 2: Use an Online Generator
- https://appicon.co/
- https://www.appicon.build/
- https://icon.kitchen/

### Option 3: Use the Expo Icon Generator
Run this command to generate placeholder icons:
```bash
npx expo-optimize
```

## Suggested Design

For Sentinel 360, consider:
- Primary color: #4A6CF7 (blue)
- Secondary color: #6EDC9A (green)
- Icon design: A pulse/heart rate line or shield icon
- Keep the design simple and recognizable at small sizes

## Placeholder Creation

If you need quick placeholders, create simple colored squares:

```bash
# Install ImageMagick (macOS)
brew install imagemagick

# Create placeholder icons
convert -size 1024x1024 xc:#4A6CF7 icon.png
convert -size 1024x1024 xc:#4A6CF7 adaptive-icon.png
convert -size 512x512 xc:#4A6CF7 splash-icon.png
convert -size 48x48 xc:#4A6CF7 favicon.png
```

Or simply copy any 1024x1024 PNG and name it appropriately.
