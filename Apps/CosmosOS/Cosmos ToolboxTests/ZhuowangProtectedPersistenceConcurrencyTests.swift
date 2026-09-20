import XCTest
@testable import Cosmos_Toolbox

/// Real multi-threaded races against `ZhuowangProtectedPersistence`.
///
/// The Stores themselves are driven from the main thread by SwiftUI, so
/// the helper is exercised directly here: several threads share one
/// domain + primary key (and therefore one registry lock) and hammer it
/// through `DispatchQueue.concurrentPerform`. The data source records the
/// maximum number of overlapping accesses; `1` proves the shared lock
/// really serialised every read and write.
nonisolated final class ZhuowangProtectedPersistenceConcurrencyTests: XCTestCase {

    private nonisolated struct Counter: Codable, Equatable {
        var value: Int
        var origin: String
    }

    private static let primaryKey = "concurrency.primary"
    private static let backupKey = "concurrency.backup"

    private var primaryKey: String { Self.primaryKey }
    private var backupKey: String { Self.backupKey }

    private static func makePersistence(
        dataSource: ZhuowangConcurrentInMemoryDataSource
    ) -> ZhuowangProtectedPersistence<Counter> {
        ZhuowangProtectedPersistence(
            dataSource: dataSource,
            primaryKey: primaryKey,
            backupKey: backupKey
        )
    }

    private func makePersistence(
        dataSource: ZhuowangConcurrentInMemoryDataSource
    ) -> ZhuowangProtectedPersistence<Counter> {
        Self.makePersistence(dataSource: dataSource)
    }


    func testConcurrentInitializationWritesExactlyOnePrimary() throws {
        let dataSource = ZhuowangConcurrentInMemoryDataSource()
        let threads = 16
        let gate = DispatchSemaphore(value: 0)
        let resultsLock = NSLock()
        var loadedValues: [Counter] = []
        var loadedBaselines: Set<Data> = []
        var failures = 0

        // Every thread has its own persistence instance (as two Stores
        // would) and its own *distinct* default value, so a second write
        // would be visible as a different origin.
        DispatchQueue.concurrentPerform(iterations: threads) { index in
            let persistence = Self.makePersistence(dataSource: dataSource)
            _ = gate.wait(timeout: .now() + 0.05)

            switch persistence.loadOrInitialize(
                defaultValue: Counter(value: 0, origin: "thread-\(index)")
            ) {
            case .loaded(let value, let baseline):
                resultsLock.lock()
                loadedValues.append(value)
                loadedBaselines.insert(baseline)
                resultsLock.unlock()

            default:
                resultsLock.lock()
                failures += 1
                resultsLock.unlock()
            }
        }

        XCTAssertEqual(failures, 0)
        XCTAssertEqual(loadedValues.count, threads)

        // Exactly one primary write, no backup write, and every loader
        // observed that single value with the same baseline bytes.
        XCTAssertEqual(dataSource.writeCount(forKey: primaryKey), 1)
        XCTAssertEqual(dataSource.writeCount(forKey: backupKey), 0)
        XCTAssertEqual(dataSource.writeCount, 1)
        XCTAssertEqual(loadedBaselines.count, 1)

        let winner = try XCTUnwrap(loadedValues.first)
        XCTAssertTrue(loadedValues.allSatisfy { $0 == winner })
        XCTAssertTrue(winner.origin.hasPrefix("thread-"))
        XCTAssertEqual(
            dataSource.snapshot(forKey: primaryKey),
            loadedBaselines.first
        )

        // No overlapping data-source access ever happened.
        XCTAssertEqual(dataSource.maxConcurrentAccesses, 1)
    }


    func testConcurrentMutationsAreSerialisedWithoutLostUpdates() throws {
        let dataSource = ZhuowangConcurrentInMemoryDataSource()
        let bootstrap = makePersistence(dataSource: dataSource)
        guard case .loaded(_, let initialBaseline) =
            bootstrap.loadOrInitialize(
                defaultValue: Counter(value: 0, origin: "seed")
            )
        else {
            return XCTFail("Seed load failed")
        }

        let threads = 8
        let incrementsPerThread = 25
        let statsLock = NSLock()
        var committed = 0
        var staleRejections = 0
        var otherFailures = 0

        // Each thread behaves like an independent Store instance: it
        // starts from the seed baseline, and on `.staleConflict` it
        // re-reads the current primary (as a re-created Store would) and
        // retries. Every increment must eventually land exactly once.
        let primaryKey = Self.primaryKey
        DispatchQueue.concurrentPerform(iterations: threads) { index in
            let persistence = Self.makePersistence(dataSource: dataSource)
            var baseline = initialBaseline

            for _ in 0..<incrementsPerThread {
                var done = false

                while !done {
                    switch persistence.transact(
                        baselineData: baseline,
                        mutate: { counter in
                            counter.value += 1
                            counter.origin = "thread-\(index)"
                            return true
                        }
                    ) {
                    case .committed(_, let newBaseline):
                        baseline = newBaseline
                        done = true
                        statsLock.lock()
                        committed += 1
                        statsLock.unlock()

                    case .staleConflict:
                        statsLock.lock()
                        staleRejections += 1
                        statsLock.unlock()
                        // Reload the current primary and retry.
                        baseline = dataSource.snapshot(forKey: primaryKey)
                            ?? baseline

                    default:
                        statsLock.lock()
                        otherFailures += 1
                        statsLock.unlock()
                        done = true
                    }
                }
            }
        }

        let expectedTotal = threads * incrementsPerThread

        XCTAssertEqual(otherFailures, 0)
        XCTAssertEqual(committed, expectedTotal)

        // Design contract: a stale instance never silently loses an
        // update — it is rejected and must retry with a fresh baseline.
        // With real contention some rejections are expected.
        XCTAssertGreaterThan(
            staleRejections,
            0,
            "Test did not create real contention; tune threads/delay"
        )

        let final = try JSONDecoder().decode(
            Counter.self,
            from: try XCTUnwrap(dataSource.snapshot(forKey: primaryKey))
        )
        XCTAssertEqual(final.value, expectedTotal)

        // Every committed transaction wrote backup then primary, and
        // nothing else touched the data source.
        XCTAssertEqual(dataSource.writeCount(forKey: primaryKey), expectedTotal + 1)
        XCTAssertEqual(dataSource.writeCount(forKey: backupKey), expectedTotal)

        // The backup is always the previous committed primary: it must
        // decode and hold exactly `final.value - 1`.
        let backup = try JSONDecoder().decode(
            Counter.self,
            from: try XCTUnwrap(dataSource.snapshot(forKey: backupKey))
        )
        XCTAssertEqual(backup.value, expectedTotal - 1)

        // The shared lock serialised every data-source access.
        XCTAssertEqual(dataSource.maxConcurrentAccesses, 1)
    }


    func testOverlapCounterDetectsParallelAccessWithoutSharedLock() {
        // Control experiment for the two tests above. It proves only that
        // `maxConcurrentAccesses` can exceed 1 when two threads hit an
        // *unlocked* data source, so the `== 1` assertions above are not
        // vacuous. It does not by itself prove that two different domains
        // ran their persistence work in parallel; that separation is
        // covered structurally by `ZhuowangStorePersistenceBoundaryTests
        // .testSameKeyUsesSharedLockWhileDomainAndKeyRemainIsolated`.
        let first = ZhuowangConcurrentInMemoryDataSource(
            domainIdentifier: "domain-a",
            accessDelay: 0.02
        )
        let second = ZhuowangConcurrentInMemoryDataSource(
            domainIdentifier: "domain-b",
            accessDelay: 0.02
        )
        let probe = ZhuowangConcurrentInMemoryDataSource(
            domainIdentifier: "unlocked-probe",
            accessDelay: 0.02
        )

        let group = DispatchGroup()
        for source in [first, second] {
            group.enter()
            DispatchQueue.global().async {
                let persistence = Self.makePersistence(dataSource: source)
                _ = persistence.loadOrInitialize(
                    defaultValue: Counter(
                        value: 0,
                        origin: source.domainIdentifier
                    )
                )
                // Unlocked accesses from both threads for ~400 ms each.
                for _ in 0..<20 {
                    _ = probe.data(forKey: "probe")
                }
                group.leave()
            }
        }
        XCTAssertEqual(group.wait(timeout: .now() + 20), .success)

        XCTAssertEqual(first.writeCount, 1)
        XCTAssertEqual(second.writeCount, 1)
        XCTAssertGreaterThan(
            probe.maxConcurrentAccesses,
            1,
            "Unlocked probe should have observed overlapping access"
        )
    }
}
