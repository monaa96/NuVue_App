//
//  PDD_Project_2App.swift
//  PDD Project 2
//
//  Created by Mona Agarwal on 4/21/25.
//

import Firebase
import SwiftUI

@main
struct YourProjectApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
