//
//  EnvironmentSwitcherViewController.swift
//  EnvironmentSwitchingKit
//
//  Native UITableView-based env switcher. Two sections, dynamic visibility,
//  bottom-pinned theme-styled action button.
//

import Combine
import PresentationKit
import UIKit

final class EnvironmentSwitcherViewController: UIViewController {

    // MARK: - Sections

    private enum Section: Int { case loaded, pending }

    // MARK: - Subviews

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let actionButton: BrandedActionButton
    private var actionButtonBottomConstraint: NSLayoutConstraint!

    // MARK: - Dependencies

    private let viewModel: EnvironmentSwitcherViewModel
    private let theme: EnvironmentSwitcherTheme

    // MARK: - State

    private var renderState: EnvironmentSwitcherState?
    private var subscriptions = Set<AnyCancellable>()

    // MARK: - Init

    init(viewModel: EnvironmentSwitcherViewModel, theme: EnvironmentSwitcherTheme) {
        self.viewModel = viewModel
        self.theme = theme
        self.actionButton = BrandedActionButton(theme: theme)
        super.init(nibName: nil, bundle: nil)
        title = "Environments"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureTableView()
        configureActionButton()
        configureNavigationItems()
        configureAdaptivePresentation()
        bindViewModel()
    }

    private func configureAdaptivePresentation() {
        // Catch interactive dismissal (the swipe-down gesture on form/page
        // sheets). When iOS dismisses the modal that way, our `.dismiss`
        // event never fires — the user bypasses the Close button entirely.
        // Without this hook the PresentationKit-created UIWindow stays alive
        // on top of the app, eating touches.
        navigationController?.presentationController?.delegate = self
        presentationController?.delegate = self
    }

    // MARK: - Configuration

    private func configureView() {
        view.backgroundColor = theme.background
        navigationController?.navigationBar.tintColor = theme.tint
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.keyboardDismissMode = .interactive
        tableView.register(EnvironmentRowCell.self, forCellReuseIdentifier: EnvironmentRowCell.reuseIdentifier)
        tableView.register(EnvironmentNameCell.self, forCellReuseIdentifier: EnvironmentNameCell.reuseIdentifier)
        tableView.register(EnvironmentFieldCell.self, forCellReuseIdentifier: EnvironmentFieldCell.reuseIdentifier)
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureActionButton() {
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
        view.addSubview(actionButton)
        actionButtonBottomConstraint = actionButton.bottomAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        NSLayoutConstraint.activate([
            actionButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            actionButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            actionButton.heightAnchor.constraint(equalToConstant: 52),
            actionButtonBottomConstraint
        ])
        tableView.contentInset.bottom = 84
        tableView.verticalScrollIndicatorInsets.bottom = 84
    }

    private func configureNavigationItems() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Close",
            style: .plain,
            target: self,
            action: #selector(closeTapped))
    }

    private func bindViewModel() {
        viewModel.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.render(state: state) }
            .store(in: &subscriptions)

        viewModel.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in self?.handle(event: event) }
            .store(in: &subscriptions)

        NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillShowNotification)
            .sink { [weak self] note in self?.adjustForKeyboard(note: note, isShowing: true) }
            .store(in: &subscriptions)

        NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] note in self?.adjustForKeyboard(note: note, isShowing: false) }
            .store(in: &subscriptions)
    }

    // MARK: - Keyboard

    private func adjustForKeyboard(note: Notification, isShowing: Bool) {
        let info = note.userInfo
        let keyboardFrame = (info?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect) ?? .zero
        let duration = (info?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        let curveRaw = (info?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int) ?? 0
        let options = UIView.AnimationOptions(rawValue: UInt(curveRaw) << 16)

        let safeBottom = view.safeAreaInsets.bottom
        let liftAboveKeyboard = isShowing
            ? max(keyboardFrame.height - safeBottom, 0)
            : 0
        actionButtonBottomConstraint.constant = -16 - liftAboveKeyboard

        let buttonClearance: CGFloat = 84
        tableView.contentInset.bottom = buttonClearance + liftAboveKeyboard
        tableView.verticalScrollIndicatorInsets.bottom = buttonClearance + liftAboveKeyboard

        UIView.animate(withDuration: duration, delay: 0, options: options) {
            self.view.layoutIfNeeded()
        }
    }

    // MARK: - Rendering

    private func render(state: EnvironmentSwitcherState) {
        let previous = renderState
        renderState = state
        updateActionButton(for: state)
        updatePlusButton(for: state)

        guard let previous = previous else {
            tableView.reloadData()
            return
        }
        animateTransition(from: previous, to: state)
    }

    private func animateTransition(from previous: EnvironmentSwitcherState,
                                   to next: EnvironmentSwitcherState) {
        let previousIDs = previous.loaded.map { $0.id }
        let nextIDs = next.loaded.map { $0.id }

        let insertedRows: [IndexPath] = nextIDs.enumerated().compactMap { index, id in
            previousIDs.contains(id) ? nil : IndexPath(row: index, section: Section.loaded.rawValue)
        }
        let deletedRows: [IndexPath] = previousIDs.enumerated().compactMap { index, id in
            nextIDs.contains(id) ? nil : IndexPath(row: index, section: Section.loaded.rawValue)
        }

        var insertSections = IndexSet()
        var deleteSections = IndexSet()
        let pendingWasVisible = previous.pending != nil
        let pendingIsVisible = next.pending != nil
        if pendingWasVisible && !pendingIsVisible {
            deleteSections.insert(Section.pending.rawValue)
        } else if !pendingWasVisible && pendingIsVisible {
            insertSections.insert(Section.pending.rawValue)
        }

        var rowsToReload: [IndexPath] = []
        if previous.selectedID != next.selectedID {
            // Row that lost the checkmark — must still exist in the new list
            // and must not be one we just inserted.
            if let oldID = previous.selectedID,
               let oldIndex = nextIDs.firstIndex(of: oldID) {
                let path = IndexPath(row: oldIndex, section: Section.loaded.rawValue)
                if !insertedRows.contains(path) { rowsToReload.append(path) }
            }
            // Row that gained the checkmark — same constraints.
            if let newID = next.selectedID,
               let newIndex = nextIDs.firstIndex(of: newID) {
                let path = IndexPath(row: newIndex, section: Section.loaded.rawValue)
                if !insertedRows.contains(path) && !rowsToReload.contains(path) {
                    rowsToReload.append(path)
                }
            }
        }

        let nothingChanged = insertedRows.isEmpty
            && deletedRows.isEmpty
            && insertSections.isEmpty
            && deleteSections.isEmpty
            && rowsToReload.isEmpty
        guard !nothingChanged else { return }

        tableView.performBatchUpdates {
            if !deleteSections.isEmpty { tableView.deleteSections(deleteSections, with: .fade) }
            if !insertSections.isEmpty { tableView.insertSections(insertSections, with: .fade) }
            if !deletedRows.isEmpty { tableView.deleteRows(at: deletedRows, with: .fade) }
            if !insertedRows.isEmpty { tableView.insertRows(at: insertedRows, with: .fade) }
            if !rowsToReload.isEmpty { tableView.reloadRows(at: rowsToReload, with: .fade) }
        }
    }

    private func updateActionButton(for state: EnvironmentSwitcherState) {
        let title = state.ctaMode == .add ? "Add" : "Apply"
        actionButton.setTitle(title, for: .normal)
        actionButton.isEnabled = state.isCTAEnabled(initialAppliedID: viewModel.initialApplied)
    }

    private func updatePlusButton(for state: EnvironmentSwitcherState) {
        // The + button shows whenever there's no draft being edited — it
        // either restores the imported draft (file mode) or seeds a blank
        // template (shake mode).
        if state.pending == nil {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .add,
                target: self,
                action: #selector(plusTapped))
        } else {
            navigationItem.rightBarButtonItem = nil
        }
    }

    // MARK: - Events

    private func handle(event: EnvironmentSwitcherEvent) {
        switch event {
        case .duplicateAlert(let matchingID):
            presentDuplicateAlert(matchingID: matchingID)
        case .dismiss:
            dismiss(animated: true) {
                // Defensive: under .formSheet the PK window's RootVC may not
                // get viewWillAppear, leaving its window alive on top.
                UIWindow.destroyPresentationKitWindow()
            }
        case .closeThenRun(let action):
            // Tear down the PresentationKit window FIRST while the modal is
            // still up — at this moment its `hasPresentedViewController` is
            // true so destroyPresentationKitWindow() actually restores the
            // original main window as key. Then run the action (apply +
            // restart) which will cross-dissolve on the correct window.
            UIWindow.destroyPresentationKitWindow()
            action()
        }
    }

    private func presentDuplicateAlert(matchingID: UUID) {
        let alert = UIAlertController(
            title: "Environment already added",
            message: "An environment with the same fields is already in the list. The matching one will be selected.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.viewModel.acknowledgeDuplicate(matchingID: matchingID)
        })
        present(alert, animated: true)
    }

    // MARK: - Actions

    @objc private func actionButtonTapped() {
        guard let state = renderState else { return }
        switch state.ctaMode {
        case .add: viewModel.tapAdd()
        case .apply: Task { @MainActor in viewModel.tapApply() }
        }
    }

    @objc private func plusTapped() {
        viewModel.tapPlus()
    }

    @objc private func closeTapped() {
        viewModel.tapClose()
    }
}

// MARK: - UIAdaptivePresentationControllerDelegate

extension EnvironmentSwitcherViewController: UIAdaptivePresentationControllerDelegate {

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        // Interactive swipe-to-dismiss bypassed our normal `.dismiss` event,
        // so PresentationKit's window is now invisible-but-alive on top of
        // the app. Tear it down explicitly.
        UIWindow.destroyPresentationKitWindow()
    }
}

// MARK: - UITableViewDataSource

extension EnvironmentSwitcherViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        guard let state = renderState else { return 0 }
        return state.pending == nil ? 1 : 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let state = renderState else { return 0 }
        switch Section(rawValue: section) {
        case .loaded:
            return state.loaded.count
        case .pending:
            return 1 + (state.pending?.fields.count ?? 0)
        case .none:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .loaded: return "LOADED ENVIRONMENTS"
        case .pending: return "NEW ENVIRONMENT"
        case .none: return nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let state = renderState else { return UITableViewCell() }
        switch Section(rawValue: indexPath.section) {
        case .loaded:
            let environment = state.loaded[indexPath.row]
            let cell = tableView.dequeueReusableCell(
                withIdentifier: EnvironmentRowCell.reuseIdentifier,
                for: indexPath) as! EnvironmentRowCell
            cell.configure(
                environment: environment,
                isSelected: environment.id == state.selectedID,
                theme: theme)
            return cell

        case .pending:
            guard let pending = state.pending else { return UITableViewCell() }
            if indexPath.row == 0 {
                let cell = tableView.dequeueReusableCell(
                    withIdentifier: EnvironmentNameCell.reuseIdentifier,
                    for: indexPath) as! EnvironmentNameCell
                cell.configure(name: pending.name) { [weak self] newValue in
                    self?.viewModel.editPendingName(newValue)
                }
                return cell
            }
            let fieldIndex = indexPath.row - 1
            let field = pending.fields[fieldIndex]
            let cell = tableView.dequeueReusableCell(
                withIdentifier: EnvironmentFieldCell.reuseIdentifier,
                for: indexPath) as! EnvironmentFieldCell
            cell.configure(field: field) { [weak self] newValue in
                self?.viewModel.editPendingField(index: fieldIndex, value: newValue)
            }
            return cell

        case .none:
            return UITableViewCell()
        }
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard let state = renderState,
              Section(rawValue: indexPath.section) == .loaded else { return false }
        let environment = state.loaded[indexPath.row]
        return !environment.isBuiltIn && environment.id != state.selectedID
    }

    func tableView(_ tableView: UITableView,
                   commit editingStyle: UITableViewCell.EditingStyle,
                   forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete,
              let state = renderState,
              Section(rawValue: indexPath.section) == .loaded else { return }
        let id = state.loaded[indexPath.row].id
        viewModel.delete(id: id)
    }
}

// MARK: - UITableViewDelegate

extension EnvironmentSwitcherViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let state = renderState else { return }

        switch Section(rawValue: indexPath.section) {
        case .loaded:
            let id = state.loaded[indexPath.row].id
            viewModel.selectExisting(id: id)
        case .pending:
            (tableView.cellForRow(at: indexPath) as? FocusableInputCell)?.focusInput()
        case .none:
            break
        }
    }
}

// MARK: - Focusable Input Cell

private protocol FocusableInputCell: AnyObject {
    func focusInput()
}

// MARK: - Cells

private final class EnvironmentRowCell: UITableViewCell {

    static let reuseIdentifier = "EnvironmentRowCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func configure(environment: LoadedEnvironment, isSelected: Bool, theme: EnvironmentSwitcherTheme) {
        textLabel?.text = environment.name
        textLabel?.textColor = theme.foreground
        detailTextLabel?.text = environment.isBuiltIn ? "Built-in" : (environment.fields.first?.value ?? "")
        detailTextLabel?.textColor = theme.foregroundSecondary
        accessoryType = isSelected ? .checkmark : .none
        tintColor = theme.tint
        backgroundColor = theme.cellBackground
    }
}

private final class EnvironmentNameCell: UITableViewCell, FocusableInputCell {

    static let reuseIdentifier = "EnvironmentNameCell"

    func focusInput() { valueField.becomeFirstResponder() }

    private let keyLabel = UILabel()
    private let valueField = UITextField()
    private var onChange: ((String) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)

        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        keyLabel.font = .preferredFont(forTextStyle: .footnote)
        keyLabel.text = "environment name"
        keyLabel.setContentHuggingPriority(.required, for: .horizontal)
        keyLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        valueField.translatesAutoresizingMaskIntoConstraints = false
        valueField.autocorrectionType = .no
        valueField.autocapitalizationType = .words
        valueField.textAlignment = .right
        valueField.addTarget(self, action: #selector(textChanged), for: .editingChanged)

        contentView.addSubview(keyLabel)
        contentView.addSubview(valueField)
        NSLayoutConstraint.activate([
            keyLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            keyLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            valueField.leadingAnchor.constraint(equalTo: keyLabel.trailingAnchor, constant: 12),
            valueField.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            valueField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            valueField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func configure(name: String, onChange: @escaping (String) -> Void) {
        valueField.text = name
        self.onChange = onChange
    }

    @objc private func textChanged() {
        onChange?(valueField.text ?? "")
    }
}

private final class EnvironmentFieldCell: UITableViewCell, FocusableInputCell {

    static let reuseIdentifier = "EnvironmentFieldCell"

    func focusInput() { valueField.becomeFirstResponder() }

    private let keyLabel = UILabel()
    private let valueField = UITextField()
    private var onChange: ((String) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)

        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        keyLabel.font = .preferredFont(forTextStyle: .footnote)
        keyLabel.setContentHuggingPriority(.required, for: .horizontal)
        keyLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        valueField.translatesAutoresizingMaskIntoConstraints = false
        valueField.autocorrectionType = .no
        valueField.autocapitalizationType = .none
        valueField.keyboardType = .URL
        valueField.textAlignment = .right
        valueField.addTarget(self, action: #selector(textChanged), for: .editingChanged)

        contentView.addSubview(keyLabel)
        contentView.addSubview(valueField)
        NSLayoutConstraint.activate([
            keyLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            keyLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            valueField.leadingAnchor.constraint(equalTo: keyLabel.trailingAnchor, constant: 12),
            valueField.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            valueField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            valueField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func configure(field: LoadedEnvironment.Field, onChange: @escaping (String) -> Void) {
        keyLabel.text = field.key
        valueField.text = field.value
        self.onChange = onChange
    }

    @objc private func textChanged() {
        onChange?(valueField.text ?? "")
    }
}

// MARK: - Branded Action Button

private final class BrandedActionButton: UIButton {

    init(theme: EnvironmentSwitcherTheme) {
        super.init(frame: .zero)
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule
        config.baseBackgroundColor = theme.actionButtonBackground
        config.baseForegroundColor = theme.actionButtonForeground
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 17, weight: .semibold)
            return outgoing
        }
        configuration = config
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}
