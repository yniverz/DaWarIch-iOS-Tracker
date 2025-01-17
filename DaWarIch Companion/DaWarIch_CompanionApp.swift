//
//  DaWarIch_CompanionApp.swift
//  DaWarIch Companion
//
//  Created by yniverz on 17.01.25.
//

import SwiftUI

@main
struct DaWarIch_CompanionApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(appDelegate)
        }
    }
}
