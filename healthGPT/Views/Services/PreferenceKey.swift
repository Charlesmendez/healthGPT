//
//  PreferenceKey.swift
//  healthGPT
//
//  Created by Carlos Fernando Mendez Solano on 11/16/24.
//

import SwiftUICore

struct TooltipPositionPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint?

    static func reduce(value: inout CGPoint?, nextValue: () -> CGPoint?) {
        value = nextValue() ?? value
    }
}
