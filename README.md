# Translucent Mirror

A SwiftUI application that creates a translucent mirror using your Mac's camera.

## Features

- **Translucent Mirror**: Shows a horizontally flipped (mirrored) view from your camera with adjustable opacity
- **Maximized Window**: Launches with a maximized window that fills your screen (but not fullscreen mode)
- **Opacity Control**: Use the slider in the bottom-right corner to adjust the transparency level
- **Background Visibility**: The translucent window allows you to see whatever is behind the application

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

1. When you first run the app, macOS will ask for camera permissions - grant access to enable the mirror functionality
2. The application will launch with a maximized translucent window showing your camera feed (mirrored)
3. Use the opacity slider in the bottom-right corner to adjust transparency
4. The window allows you to see through to whatever applications or content are behind it
5. You can move other windows behind the mirror app to see them through the translucent overlay

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

