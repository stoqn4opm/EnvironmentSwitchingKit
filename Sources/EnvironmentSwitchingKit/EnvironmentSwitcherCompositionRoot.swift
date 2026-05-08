//
//  EnvironmentSwitcherCompositionRoot.swift
//  EnvironmentSwitchingKit
//
//  Wires the env-switching feature together. Two entry points: `handle(urlContexts:)`
//  for file imports (with the brand-supplied file extension, e.g. "ts4date"),
//  and `handleShake()` for the shake gesture. Brand callers may gate
//  `handleShake()` on any policy they want (e.g. `store.hasBeenSeen`).
//

import PresentationKit
import UIKit

public final class EnvironmentSwitcherCompositionRoot {

    // MARK: - Dependencies

    private let store: EnvironmentStore
    private let parser: EnvironmentFileParser
    private let applier: EnvironmentApplier
    private let theme: EnvironmentSwitcherTheme
    private let fileExtension: String

    // MARK: - State

    private weak var presentedSwitcher: EnvironmentSwitcherViewController?

    // MARK: - Init

    public init(
        store: EnvironmentStore,
        parser: EnvironmentFileParser,
        applier: EnvironmentApplier,
        theme: EnvironmentSwitcherTheme,
        fileExtension: String) {
            self.store = store
            self.parser = parser
            self.applier = applier
            self.theme = theme
            self.fileExtension = fileExtension.lowercased()
    }

    // MARK: - Entry Points

    @MainActor
    public func handle(urlContexts: Set<UIOpenURLContext>) {
        let urls = urlContexts.map { $0.url.absoluteString }
        print("[EnvironmentSwitcher] handle(urlContexts:) received \(urls.count) URL(s): \(urls)")

        guard presentedSwitcher == nil else {
            print("[EnvironmentSwitcher] ignoring — switcher already presented")
            return
        }
        guard let context = urlContexts.first(where: { $0.url.pathExtension.lowercased() == fileExtension }) else {
            print("[EnvironmentSwitcher] no .\(fileExtension) URL in this batch — bailing")
            return
        }

        let draft: LoadedEnvironment
        do {
            draft = try parser.parse(url: context.url)
        } catch {
            print("[EnvironmentSwitcher] parse failed: \(error)")
            presentParseError(error)
            return
        }

        print("[EnvironmentSwitcher] presenting switcher with imported draft \"\(draft.name)\"")
        present(mode: .file(originalDraft: draft))
        store.hasBeenSeen = true
    }

    /// Shows the switcher in shake-mode. Callers (typically the brand-side
    /// shake handler) are expected to gate this on whatever policy they
    /// want — e.g. `if store.hasBeenSeen { compositionRoot.handleShake() }`.
    @MainActor
    public func handleShake() {
        guard presentedSwitcher == nil else { return }
        present(mode: .shake)
    }

    // MARK: - Presentation

    @MainActor
    private func present(mode: EnvironmentSwitcherState.PresentationMode) {
        let viewModel = EnvironmentSwitcherViewModel(
            mode: mode,
            loaded: store.loaded,
            initialAppliedID: store.selectedID,
            persistAdd: { [weak self] environment in self?.store.add(environment) },
            persistDelete: { [weak self] id in self?.store.remove(id: id) },
            apply: { [weak self] environment in
                Task { @MainActor in await self?.applier.apply(environment) }
            })

        let switcher = EnvironmentSwitcherViewController(
            viewModel: viewModel,
            theme: theme)
        let navigationController = UINavigationController(rootViewController: switcher)
        navigationController.modalPresentationStyle = .formSheet
        navigationController.present(animated: true)
        presentedSwitcher = switcher
    }

    private func presentParseError(_ error: Error) {
        let alert = UIAlertController(
            title: "Could not load environment",
            message: error.localizedDescription,
            preferredStyle: .alert)
        alert.addAction(UIAlertAction.AlertAction(title: "OK", style: .default))
        alert.present(animated: true)
    }
}
