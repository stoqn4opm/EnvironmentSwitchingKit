//
//  EnvironmentSwitcherViewModelTests.swift
//  EnvironmentSwitchingKitTests
//

import XCTest
import Combine
@testable import EnvironmentSwitchingKit

@MainActor
final class EnvironmentSwitcherViewModelTests: XCTestCase {

    // MARK: - Recorders

    private final class Recorder {
        var addedEnvironments: [LoadedEnvironment] = []
        var deletedIDs: [UUID] = []
        var appliedEnvironments: [LoadedEnvironment] = []
    }

    private var recorder: Recorder!
    private var subscriptions: Set<AnyCancellable> = []

    override func setUp() {
        super.setUp()
        recorder = Recorder()
        subscriptions = []
    }

    override func tearDown() {
        recorder = nil
        subscriptions = []
        super.tearDown()
    }

    // MARK: - Fixtures

    private let prodID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let stagingID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

    private func production() -> LoadedEnvironment {
        LoadedEnvironment(id: prodID, name: "Production", fields: [
            .init(key: "baseURL", value: "https://prod.example.com"),
            .init(key: "version", value: "v1")
        ], isBuiltIn: true)
    }

    private func staging() -> LoadedEnvironment {
        LoadedEnvironment(id: stagingID, name: "Staging", fields: [
            .init(key: "baseURL", value: "https://staging.example.com"),
            .init(key: "version", value: "v1")
        ], isBuiltIn: false)
    }

    private func makeViewModel(
        mode: EnvironmentSwitcherState.PresentationMode,
        loaded: [LoadedEnvironment]? = nil,
        initialAppliedID: UUID? = nil
    ) -> EnvironmentSwitcherViewModel {
        let actualLoaded = loaded ?? [production(), staging()]
        let recorder = self.recorder!
        return EnvironmentSwitcherViewModel(
            mode: mode,
            loaded: actualLoaded,
            initialAppliedID: initialAppliedID ?? prodID,
            persistAdd: { recorder.addedEnvironments.append($0) },
            persistDelete: { recorder.deletedIDs.append($0) },
            apply: { recorder.appliedEnvironments.append($0) })
    }

    private func collectStates(_ viewModel: EnvironmentSwitcherViewModel)
    -> () -> [EnvironmentSwitcherState] {
        var states: [EnvironmentSwitcherState] = []
        viewModel.statePublisher
            .sink { states.append($0) }
            .store(in: &subscriptions)
        return { states }
    }

    private func collectEvents(_ viewModel: EnvironmentSwitcherViewModel)
    -> () -> [EnvironmentSwitcherEvent] {
        var events: [EnvironmentSwitcherEvent] = []
        viewModel.events
            .sink { events.append($0) }
            .store(in: &subscriptions)
        return { events }
    }

    // MARK: - tapAdd

    func test_tapAdd_withDuplicate_emitsAlertAndDoesNotPersist() {
        // The pending draft is content-equal to the existing staging env.
        let duplicate = LoadedEnvironment(
            id: UUID(),
            name: "Different name, same fields",
            fields: staging().fields,
            isBuiltIn: false)
        let vm = makeViewModel(mode: .file(originalDraft: duplicate))
        let events = collectEvents(vm)

        vm.tapAdd()

        guard case .duplicateAlert(let matchingID)? = events().first else {
            XCTFail("Expected duplicateAlert event, got \(events())")
            return
        }
        XCTAssertEqual(matchingID, stagingID)
        XCTAssertTrue(recorder.addedEnvironments.isEmpty)
    }

    func test_tapAdd_withUniqueDraft_persistsSelectsAndClearsPending() {
        let unique = LoadedEnvironment(
            id: UUID(),
            name: "Local",
            fields: [.init(key: "baseURL", value: "https://localhost.example.com")],
            isBuiltIn: false)
        let vm = makeViewModel(mode: .file(originalDraft: unique))
        let states = collectStates(vm)

        vm.tapAdd()

        XCTAssertEqual(recorder.addedEnvironments.map(\.id), [unique.id])
        let last = states().last
        XCTAssertEqual(last?.selectedID, unique.id)
        XCTAssertNil(last?.pending)
        XCTAssertTrue(last?.loaded.contains { $0.id == unique.id } ?? false)
    }

    // MARK: - tapPlus

    func test_tapPlus_inFileMode_restoresOriginalDraft() {
        let original = LoadedEnvironment(
            id: UUID(),
            name: "Imported",
            fields: [.init(key: "baseURL", value: "https://imported.example.com")],
            isBuiltIn: false)
        let vm = makeViewModel(mode: .file(originalDraft: original))
        let states = collectStates(vm)
        // Hide the pending section first by selecting an existing env.
        vm.selectExisting(id: stagingID)
        XCTAssertNil(states().last?.pending)

        vm.tapPlus()

        XCTAssertEqual(states().last?.pending?.id, original.id)
        XCTAssertEqual(states().last?.pending?.name, original.name)
    }

    func test_tapPlus_inShakeMode_seedsBlankDraftFromSelectedTemplate() {
        let vm = makeViewModel(mode: .shake, initialAppliedID: stagingID)
        let states = collectStates(vm)

        vm.tapPlus()

        let pending = states().last?.pending
        XCTAssertNotNil(pending)
        XCTAssertEqual(pending?.name, "")
        XCTAssertFalse(pending?.isBuiltIn ?? true)
        // Field keys must mirror the staging template; values blanked.
        XCTAssertEqual(pending?.fields.map(\.key), staging().fields.map(\.key))
        XCTAssertTrue(pending?.fields.allSatisfy { $0.value.isEmpty } ?? false)
    }

    // MARK: - delete

    func test_delete_builtIn_isIgnored() {
        let vm = makeViewModel(mode: .shake, initialAppliedID: stagingID)
        vm.delete(id: prodID)
        XCTAssertTrue(recorder.deletedIDs.isEmpty)
    }

    func test_delete_currentlySelected_isIgnored() {
        let vm = makeViewModel(mode: .shake, initialAppliedID: stagingID)
        // The store's currently-selected (initial) is staging — VM mirrors
        // it as state.selectedID at construction.
        vm.delete(id: stagingID)
        XCTAssertTrue(recorder.deletedIDs.isEmpty)
    }

    func test_delete_userImportedNonSelected_persistsDelete() {
        let local = LoadedEnvironment(
            id: UUID(),
            name: "Local",
            fields: [.init(key: "baseURL", value: "https://l.example.com")],
            isBuiltIn: false)
        let vm = makeViewModel(
            mode: .shake,
            loaded: [production(), staging(), local],
            initialAppliedID: stagingID)

        vm.delete(id: local.id)

        XCTAssertEqual(recorder.deletedIDs, [local.id])
    }

    // MARK: - isCTAEnabled

    func test_isCTAEnabled_inApplyMode_falseWhenSelectionUnchanged_trueWhenChanged() {
        let vm = makeViewModel(mode: .shake, initialAppliedID: stagingID)
        let states = collectStates(vm)

        // Initial state: selection equals initialApplied → Apply is disabled.
        let initial = states().last
        XCTAssertEqual(initial?.ctaMode, .apply)
        XCTAssertFalse(initial?.isCTAEnabled(initialAppliedID: stagingID) ?? true)

        // Pick a different env → Apply is enabled.
        vm.selectExisting(id: prodID)
        let after = states().last
        XCTAssertEqual(after?.ctaMode, .apply)
        XCTAssertTrue(after?.isCTAEnabled(initialAppliedID: stagingID) ?? false)
    }

    // MARK: - acknowledgeDuplicate

    func test_acknowledgeDuplicate_selectsMatchingAndClearsPending() {
        let duplicate = LoadedEnvironment(
            id: UUID(),
            name: "X",
            fields: staging().fields,
            isBuiltIn: false)
        let vm = makeViewModel(mode: .file(originalDraft: duplicate))
        let states = collectStates(vm)

        vm.acknowledgeDuplicate(matchingID: stagingID)

        let last = states().last
        XCTAssertEqual(last?.selectedID, stagingID)
        XCTAssertNil(last?.pending)
    }

    // MARK: - tapApply

    func test_tapApply_emitsCloseThenRunEvent_whoseClosureCallsApplyWithSelected() {
        let vm = makeViewModel(mode: .shake, initialAppliedID: prodID)
        let events = collectEvents(vm)
        vm.selectExisting(id: stagingID)

        vm.tapApply()

        // The event payload is a closure; firing it should run the apply
        // closure with the currently-selected environment.
        guard case .closeThenRun(let action)? = events().last else {
            XCTFail("Expected closeThenRun event, got \(events())")
            return
        }
        action()
        XCTAssertEqual(recorder.appliedEnvironments.map(\.id), [stagingID])
    }
}
