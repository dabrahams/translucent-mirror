# Translucent Mirror

A SwiftUI application that creates a translucent mirror using your Mac's camera.

## Features

- **Always-On-Top Mirror**: Translucent mirrored camera view that stays on top of all windows
- **Click-Through Interface**: All clicks and interactions pass through to applications below
- **Menu Bar Control**: Discrete menu bar item (no dock icon) with opacity slider and toggle
- **Full Screen Coverage**: Covers entire screen while remaining completely transparent to input
- **Background App**: Runs as a background utility without cluttering your dock or app switcher

## Requirements

- macOS 13.0 or later
- Camera access permissions

## Building and Running

1. Clone or download this project
2. Open Terminal and navigate to the project directory
3. Build the project:
   ```bash
   swift build
   ```
4. Run the application:
   ```bash
   swift run
   ```

## Usage

1. **Launch**: Run the app - it appears as a menu bar item (mirror icon) in the top-right corner
2. **Permissions**: Grant camera access when prompted by macOS
3. **Mirror Control**: Click the menu bar item to access:
   - **Turn On/Off Mirror**: Toggle the mirror overlay
   - **Opacity Slider**: Adjust transparency (10% - 100%)
   - **Quit**: Exit the application
4. **Seamless Operation**: The mirror overlay is completely click-through - use your computer normally
5. **Always Available**: The mirror stays on top but never interferes with your workflow

## Privacy

This application only accesses your camera to display the mirror view locally on your Mac. No video data is transmitted, stored, or shared.

## App Store Ready

This project is now configured for Mac App Store distribution with:

- ✅ Proper Xcode project structure
- ✅ App icon set (all required sizes)
- ✅ Info.plist with required metadata
- ✅ Entitlements for camera access and sandboxing
- ✅ Bundle identifier: `com.translucentmirror.app`
- ✅ App category: Utilities
- ✅ macOS 13.0+ deployment target

### Building for App Store

1. Open `Mirror.xcodeproj` in Xcode
2. Set your development team in the project settings
3. Archive the project (Product → Archive)
4. Upload to App Store Connect

