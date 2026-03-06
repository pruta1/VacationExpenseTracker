//
//  ContentView.swift
//  VacationCostTracker
//
//  Created by Phillip Ruta on 2/20/26.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("hasConsented") private var hasConsented = false

    var body: some View {
        if hasConsented {
            TripsListView()
        } else {
            ConsentView {
                hasConsented = true
            }
        }
    }
}
