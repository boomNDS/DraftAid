//
//  DraftAidApp.swift
//  DraftAid
//
//  Created by Pa Sri on 2/9/2569 BE.
//

import SwiftUI

@main
struct DraftAidApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
