//
//  DemoViewController.swift
//  EnvironmentSwitchingKitExample
//
//  Single-screen demo: renders the currently-applied environment's name
//  and field values. A button opens the env switcher in shake-mode so you
//  can pick between Production and Staging (seeded on first launch).
//

import EnvironmentSwitchingKit
import UIKit

final class DemoViewController: UIViewController {

    private let nameLabel = UILabel()
    private let fieldsLabel = UILabel()
    private let openSwitcherButton = UIButton(configuration: .filled())

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemGroupedBackground
        title = "EnvironmentSwitchingKit"

        nameLabel.font = .preferredFont(forTextStyle: .largeTitle)
        nameLabel.textAlignment = .center

        fieldsLabel.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        fieldsLabel.textColor = .secondaryLabel
        fieldsLabel.numberOfLines = 0
        fieldsLabel.textAlignment = .center

        var buttonConfig = UIButton.Configuration.filled()
        buttonConfig.cornerStyle = .capsule
        buttonConfig.title = "Open Switcher"
        buttonConfig.contentInsets = .init(top: 14, leading: 24, bottom: 14, trailing: 24)
        openSwitcherButton.configuration = buttonConfig
        openSwitcherButton.addAction(UIAction { [weak self] _ in
            self?.openSwitcher()
        }, for: .primaryActionTriggered)

        let stack = UIStackView(arrangedSubviews: [nameLabel, fieldsLabel, openSwitcherButton])
        stack.axis = .vertical
        stack.spacing = 24
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])

        renderCurrentEnvironment()
    }

    private func renderCurrentEnvironment() {
        let store = DemoComposition.store
        let selectedID = store.selectedID
        let current = store.loaded.first(where: { $0.id == selectedID }) ?? store.loaded.first
        nameLabel.text = current?.name ?? "—"
        fieldsLabel.text = current?.fields
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "\n") ?? ""
    }

    @MainActor
    private func openSwitcher() {
        DemoComposition.switcher.handleShake()
    }

    // MARK: - Shake-to-open

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        guard motion == .motionShake else { return }
        Task { @MainActor in DemoComposition.switcher.handleShake() }
    }
}
