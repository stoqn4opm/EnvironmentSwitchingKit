//
//  EnvironmentSwitcherViewModel.swift
//  EnvironmentSwitchingKit
//
//  State + input handler for EnvironmentSwitcherViewController. Decoupled
//  from services via injected closures. Two presentation modes:
//  .file(originalDraft:) when opened via file import, .shake when opened
//  via the shake gesture.
//

import Combine
import Foundation

// MARK: - State

public struct EnvironmentSwitcherState: Equatable {

    public enum CTAMode: Equatable {
        case add
        case apply
    }

    public enum PresentationMode: Equatable {
        case file(originalDraft: LoadedEnvironment)
        case shake
    }

    public let mode: PresentationMode
    public var loaded: [LoadedEnvironment]
    public var selectedID: UUID?
    public var pending: LoadedEnvironment?

    public var ctaMode: CTAMode { pending != nil ? .add : .apply }

    public func isCTAEnabled(initialAppliedID: UUID?) -> Bool {
        switch ctaMode {
        case .add: return true
        case .apply: return selectedID != initialAppliedID
        }
    }
}

// MARK: - Events

public enum EnvironmentSwitcherEvent {
    case duplicateAlert(matchingID: UUID)
    case dismiss
    /// Apply path: the VC must tear down the presentation FIRST (so the
    /// underlying main window is exposed), then invoke `action` which runs
    /// the env swap + app restart on the correct window.
    case closeThenRun(action: @MainActor () -> Void)
}

// MARK: - View Model

public final class EnvironmentSwitcherViewModel {

    // MARK: - Closure Dependencies

    private let persistAdd: (LoadedEnvironment) -> Void
    private let persistDelete: (UUID) -> Void
    private let apply: @MainActor (LoadedEnvironment) -> Void

    // MARK: - State

    @Published private var state: EnvironmentSwitcherState
    private let initialAppliedID: UUID?
    private let eventsSubject = PassthroughSubject<EnvironmentSwitcherEvent, Never>()

    // MARK: - Init

    public init(
        mode: EnvironmentSwitcherState.PresentationMode,
        loaded: [LoadedEnvironment],
        initialAppliedID: UUID?,
        persistAdd: @escaping (LoadedEnvironment) -> Void,
        persistDelete: @escaping (UUID) -> Void,
        apply: @escaping @MainActor (LoadedEnvironment) -> Void) {
            self.persistAdd = persistAdd
            self.persistDelete = persistDelete
            self.apply = apply
            self.initialAppliedID = initialAppliedID

            let initialPending: LoadedEnvironment?
            if case .file(let draft) = mode {
                initialPending = draft
            } else {
                initialPending = nil
            }
            self.state = EnvironmentSwitcherState(
                mode: mode,
                loaded: loaded,
                selectedID: initialAppliedID,
                pending: initialPending)
    }

    // MARK: - Outputs

    public var statePublisher: AnyPublisher<EnvironmentSwitcherState, Never> {
        Just(state).merge(with: $state).removeDuplicates().eraseToAnyPublisher()
    }

    public var events: AnyPublisher<EnvironmentSwitcherEvent, Never> {
        eventsSubject.eraseToAnyPublisher()
    }

    public var initialApplied: UUID? { initialAppliedID }

    // MARK: - Inputs

    public func selectExisting(id: UUID) {
        state.selectedID = id
        state.pending = nil
    }

    public func editPendingName(_ name: String) {
        guard var pending = state.pending else { return }
        pending.name = name
        state.pending = pending
    }

    public func editPendingField(index: Int, value: String) {
        guard var pending = state.pending,
              index >= 0,
              index < pending.fields.count else { return }
        pending.fields[index].value = value
        state.pending = pending
    }

    public func tapAdd() {
        guard let pending = state.pending else { return }
        if let duplicate = state.loaded.first(where: { $0.contentEquals(pending) }) {
            eventsSubject.send(.duplicateAlert(matchingID: duplicate.id))
            return
        }
        persistAdd(pending)
        state.loaded.append(pending)
        state.selectedID = pending.id
        state.pending = nil
    }

    @MainActor
    public func tapApply() {
        guard let id = state.selectedID,
              let environment = state.loaded.first(where: { $0.id == id }) else { return }
        let applyClosure = apply
        eventsSubject.send(.closeThenRun { applyClosure(environment) })
    }

    public func tapPlus() {
        switch state.mode {
        case .file(let originalDraft):
            state.pending = originalDraft
        case .shake:
            // No imported draft to restore; seed an empty draft using the
            // currently selected env's field shape so the user has the right
            // keys to fill in.
            let template = state.loaded.first(where: { $0.id == state.selectedID })
                ?? state.loaded.first
            guard let template else { return }
            state.pending = LoadedEnvironment(
                id: UUID(),
                name: "",
                fields: template.fields.map { LoadedEnvironment.Field(key: $0.key, value: "") },
                isBuiltIn: false)
        }
    }

    public func tapClose() {
        eventsSubject.send(.dismiss)
    }

    public func delete(id: UUID) {
        guard let environment = state.loaded.first(where: { $0.id == id }),
              !environment.isBuiltIn,
              id != state.selectedID else { return }
        persistDelete(id)
        state.loaded.removeAll { $0.id == id }
    }

    /// Called by the VC after the duplicate-alert OK is pressed.
    public func acknowledgeDuplicate(matchingID: UUID) {
        state.selectedID = matchingID
        state.pending = nil
    }
}
