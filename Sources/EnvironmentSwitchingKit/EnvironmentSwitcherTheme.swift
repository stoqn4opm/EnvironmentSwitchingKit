//
//  EnvironmentSwitcherTheme.swift
//  EnvironmentSwitchingKit
//
//  Colour palette consumed by EnvironmentSwitcherViewController. Brand-agnostic
//  — brands provide a concrete impl that bridges their own branding system.
//

import UIKit

public protocol EnvironmentSwitcherTheme {
    var background: UIColor { get }
    var cellBackground: UIColor { get }
    var foreground: UIColor { get }
    var foregroundSecondary: UIColor { get }
    var tint: UIColor { get }
    var actionButtonBackground: UIColor { get }
    var actionButtonForeground: UIColor { get }
}

// MARK: - Default (System Colours)

public struct DefaultEnvironmentSwitcherTheme: EnvironmentSwitcherTheme {

    public init() {}

    public var background: UIColor { .systemGroupedBackground }
    public var cellBackground: UIColor { .secondarySystemGroupedBackground }
    public var foreground: UIColor { .label }
    public var foregroundSecondary: UIColor { .secondaryLabel }
    public var tint: UIColor { .tintColor }
    public var actionButtonBackground: UIColor { .tintColor }
    public var actionButtonForeground: UIColor { .white }
}
