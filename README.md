# DaWarIch Companion

An iOS companion app project written in Swift.  
This repository contains the Xcode project, source files, and tests for DaWarIch Companion.
This App is intended to be used with the (self hosted) [DaWarIch](https://github.com/Freika/dawarich) Location Timeline app

---

## Main Files and Directories

- **DaWarIch Companion (directory)**  
  Contains Swift source files for the app’s functionality:
  - `AppDelegate.swift` and `DaWarIch_CompanionApp.swift`: App lifecycle and entry point.
  - `ContentView.swift`: Main SwiftUI view for the app.
  - `LocationHelper.swift`: Handles location tracking and permissions.
  - `Extensions.swift`: Utility extensions for common data types.
  - `Models.swift`: Data models for location items and supporting structures.
  - `Assets.xcassets`: Image and color assets used by the app.
  - `Preview Content/Preview Assets.xcassets`: Additional resources for SwiftUI Previews.

---

## Getting Started

1. **Clone the repository**:
   ```bash
   git clone https://github.com/your-user/DaWarIch-Companion.git
   cd DaWarIch-Companion
   ```
2. **Open the project**:
   - Open `DaWarIch Companion.xcodeproj` in Xcode.

3. **Select a Simulator or a connected device**:
   - In Xcode, choose a device or simulator from the scheme selector at the top.

4. **Build and Run**:
   - Press `Cmd + R` to build and run the app.

---

## Location Tracking

This app uses Core Location to track user location in the background and foreground. Make sure to enable location permissions in iOS settings when prompted by the app. Relevant strings are provided in **Info.plist** under `NSLocationAlwaysUsageDescription` and `NSLocationWhenInUseUsageDescription`.

---
```
