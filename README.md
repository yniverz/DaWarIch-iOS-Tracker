# DaWarIch Companion (NO LONGER MAINTAINED)

An iOS [DaWarIch](https://github.com/Freika/dawarich) high density companion app written in Swift.  
This App is intended to be used with the (self hosted) [DaWarIch](https://github.com/Freika/dawarich) Location Timeline service.

---

## Getting Started

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yniverz/DaWarIch-iOS-Tracker
   cd DaWarIch-iOS-Tracker
   ```
2. **Open the project**:
   - Open `DaWarIch Companion.xcodeproj` in Xcode.

3. **Select a Simulator or a connected device**:
   - In Xcode, choose a device or simulator from the scheme selector at the top.

4. **Build and Run**:
   - Press `Cmd + R` to build and run the app.

---

## Location Tracking

This app uses Core Location to track user location in the background. Make sure to enable location permissions in iOS settings when prompted by the app. The key feature of this app is its high density of tracking points. It will automatically detect when the user starts moving and begin tracking every GPS fix until the user stops again.

---

As Apple requires any developer to publicly display their full government name when publishing an app, I will currently not be publishing this app in the App Store.
This project uses a logo designed by [Freika](https://github.com/Freika), used under the terms of the GNU AGPLv3. The original logo can be found at [android-chrome-512x512.png](https://github.com/Freika/dawarich/blob/master/app/assets/images/favicon/android-chrome-512x512.png).
