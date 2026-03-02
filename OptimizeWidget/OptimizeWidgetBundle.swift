//
//  OptimizeWidgetBundle.swift
//  OptimizeWidget
//
//  Widget extension entry point providing Lock Screen, Home Small, and Home Medium widgets.
//

import WidgetKit
import SwiftUI

@main
struct OptimizeWidgetBundle: WidgetBundle {
    var body: some Widget {
        OptimizeSavingsWidget()
        OptimizeCompactWidget()
        CompressionLiveActivity()
        if #available(iOSApplicationExtension 18.0, *) {
            OptimizeLockScreenWidget()
        }
    }
}
