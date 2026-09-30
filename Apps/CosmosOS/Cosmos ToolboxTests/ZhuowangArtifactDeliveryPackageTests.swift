import Foundation
import CryptoKit
import XCTest
@testable import Cosmos_Toolbox


final class ZhuowangArtifactDeliveryPackageTests:
    XCTestCase {

    private var temporaryRoots: [URL] = []

    override func tearDown() {
        for root in temporaryRoots {
            try? FileManager.default.removeItem(
                at: root
            )
        }

        temporaryRoots = []
        super.tearDown()
    }


    // MARK: Real ZIP Fixture

    func testPythonDefaultZIPReaderRecognizesChineseNamesAndExtractsVerifiedContent()
        throws {
        let fixture = try makeFixture()
        let step = try XCTUnwrap(fixture.workflow.steps.first)
        let content = Data("# 中文交付物\n兼容性测试 ✓\n".utf8)
        let source = try writeFile(
            fixture: fixture, stepKind: step.kind,
            fileName: "中文文件_V1.md", data: content
        )
        let artifact = makeArtifact(
            fixture: fixture, step: step, name: "中文产物",
            type: .markdown, logicalKey: "unicode-fixture", location: source.path
        )
        let result = try ZhuowangArtifactDeliveryPackageService().export(
            request: fixture.request(
                selectedArtifacts: [artifact],
                destinationURL: fixture.root.appendingPathComponent("中文交付包.zip")
            ),
            snapshotProvider: { fixture.snapshot(artifacts: [artifact]) }
        )
        let item = try XCTUnwrap(result.manifest.items.first)
        try runPython(
            script: """
            import hashlib, json, pathlib, struct, sys, zipfile
            archive, expected_path, expected_hash, output = sys.argv[1:]
            raw = pathlib.Path(archive).read_bytes()
            with zipfile.ZipFile(archive) as z:
                assert z.testzip() is None
                assert {i.filename for i in z.infolist() if not i.is_dir()} == {
                    '交付清单.md', 'manifest.json', expected_path
                }
                assert expected_path.endswith('/中文文件_V1.md')
                for i in z.infolist():
                    assert i.flag_bits & 0x800
                    flags = struct.unpack_from('<H', raw, i.header_offset + 6)[0]
                    assert flags == i.flag_bits
                manifest = json.loads(z.read('manifest.json'))
                assert manifest['items'][0]['relativePath'] == expected_path
                assert manifest['items'][0]['sha256'] == expected_hash
                assert '中文产物' in z.read('交付清单.md').decode('utf-8')
                z.extractall(output)
                content = (pathlib.Path(output) / expected_path).read_bytes()
                assert content == '# 中文交付物\\n兼容性测试 ✓\\n'.encode('utf-8')
                assert hashlib.sha256(content).hexdigest() == expected_hash
                assert len(content) == manifest['items'][0]['byteCount']
            """,
            arguments: [result.archiveURL.path, item.relativePath, sha256(content),
                        fixture.root.appendingPathComponent("python-extraction").path]
        )
    }

    func testUTF8NormalizationOnlyChangesPairedFlagsAndRejectsInvalidRecordsBeforeWriting()
        throws {
        let fixture = try makeFixture()
        _ = try writeFile(
            fixture: fixture, stepKind: .brief,
            fileName: "中文原始.md", data: Data("压缩内容保持不变".utf8)
        )
        let rawURL = fixture.root.appendingPathComponent("raw.zip")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--norsrc", "--noextattr",
                             fixture.campaignWorkspaceURL.path + "/", rawURL.path]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
        let original = try Data(contentsOf: rawURL)
        let normalizedURL = fixture.root.appendingPathComponent("normalized.zip")
        try original.write(to: normalizedURL)
        let service = ZhuowangArtifactDeliveryPackageService()
        try service.normalizeZIPUTF8Flags(at: normalizedURL)

        try runPython(
            script: """
            import pathlib, struct, sys, zipfile
            before, after = [pathlib.Path(p).read_bytes() for p in sys.argv[1:]]
            expected = bytearray(before)
            end = before.rfind(b'PK\\x05\\x06')
            count = struct.unpack_from('<H', before, end + 10)[0]
            cursor = struct.unpack_from('<I', before, end + 16)[0]
            for _ in range(count):
                assert before[cursor:cursor+4] == b'PK\\x01\\x02'
                flags = struct.unpack_from('<H', before, cursor + 8)[0]
                n, e, c = struct.unpack_from('<3H', before, cursor + 28)
                local = struct.unpack_from('<I', before, cursor + 42)[0]
                name = before[cursor+46:cursor+46+n]
                assert name.decode('utf-8').encode('utf-8') == name
                assert name == before[local+30:local+30+n]
                assert struct.unpack_from('<H', before, local+6)[0] == flags
                struct.pack_into('<H', expected, cursor+8, flags | 0x800)
                struct.pack_into('<H', expected, local+6, flags | 0x800)
                cursor += 46 + n + e + c
            assert bytes(expected) == after, 'Unexpected change outside flag fields'
            with zipfile.ZipFile(sys.argv[2]) as z:
                assert z.testzip() is None
                assert any(i.filename.endswith('/中文原始.md') for i in z.infolist())
            """,
            arguments: [rawURL.path, normalizedURL.path]
        )

        let centralSignature = Data([0x50, 0x4b, 0x01, 0x02])
        let localSignature = Data([0x50, 0x4b, 0x03, 0x04])
        let central = try XCTUnwrap(original.range(of: centralSignature)).lowerBound
        let local = try XCTUnwrap(original.range(of: localSignature)).lowerBound
        for invalid in [true, false] {
            var damaged = original
            // Invalid UTF-8 in both names, or valid but inconsistent names.
            damaged[central + 46] = invalid ? 0xff : 0x41
            if invalid { damaged[local + 30] = 0xff }
            let damagedURL = fixture.root.appendingPathComponent("damaged-\(invalid).zip")
            try damaged.write(to: damagedURL)
            XCTAssertThrowsError(try service.normalizeZIPUTF8Flags(at: damagedURL))
            XCTAssertEqual(try Data(contentsOf: damagedURL), damaged)
        }
    }

    private func runPython(script: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["-c", script] + arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        process.waitUntilExit()
        let diagnostic = String(
            data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8
        ) ?? ""
        XCTAssertEqual(process.terminationStatus, 0, diagnostic)
    }

    func testRealArchiveContainsFilesManifestChecklistAndVerifiedHashes()
        throws {

        let fixture = try makeFixture()
        let planStep = try XCTUnwrap(
            fixture.workflow.steps.first {
                $0.kind == .plan
            }
        )
        let prototypeStep = try XCTUnwrap(
            fixture.workflow.steps.first {
                $0.kind == .prototype
            }
        )

        let markdownData = Data(
            "# 正式策划案\n内容\n".utf8
        )
        let binaryData = Data(
            [0x00, 0x01, 0x7f, 0xff, 0x42]
        )

        let markdownURL = try writeFile(
            fixture: fixture,
            stepKind: .plan,
            fileName: "完整策划案_V1.md",
            data: markdownData
        )
        let binaryURL = try writeFile(
            fixture: fixture,
            stepKind: .prototype,
            fileName: "prototype-image.png",
            data: binaryData
        )

        let artifacts = [
            makeArtifact(
                fixture: fixture,
                step: planStep,
                name: "完整策划案",
                type: .markdown,
                logicalKey:
                    "workflow.plan.primary",
                location: markdownURL.path
            ),
            makeArtifact(
                fixture: fixture,
                step: prototypeStep,
                name: "产品原型截图",
                type: .image,
                logicalKey:
                    "workflow.prototype.image",
                location: binaryURL.path,
                version: 3
            )
        ]

        let destination = fixture.root
            .appendingPathComponent(
                "Campaign-Delivery.zip"
            )
        let fixedDate = Date(
            timeIntervalSince1970: 1_800_000_000
        )
        let service =
            ZhuowangArtifactDeliveryPackageService(
                now: { fixedDate }
            )

        let snapshot = fixture.snapshot(
            artifacts: artifacts
        )
        let candidates = service.candidates(
            snapshot: snapshot,
            campaignWorkspaceURL:
                fixture.campaignWorkspaceURL
        )

        XCTAssertEqual(candidates.count, 2)
        XCTAssertTrue(
            candidates.allSatisfy(\.isEligible)
        )

        let result = try service.export(
            request: fixture.request(
                selectedArtifacts: artifacts,
                destinationURL: destination
            ),
            snapshotProvider: { snapshot }
        )

        XCTAssertEqual(
            result.archiveURL,
            destination
        )
        XCTAssertEqual(
            result.manifest.items.count,
            2
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: destination.path
            )
        )

        let extracted = try extractArchive(
            destination,
            under: fixture.root
        )
        let manifestData = try Data(
            contentsOf: extracted
                .appendingPathComponent(
                    "manifest.json"
                )
        )
        let decoded = try JSONDecoder().decode(
            ZhuowangArtifactDeliveryManifest.self,
            from: manifestData
        )
        let checklist = try String(
            contentsOf: extracted
                .appendingPathComponent(
                    "交付清单.md"
                ),
            encoding: .utf8
        )
        let manifestText = try XCTUnwrap(
            String(
                data: manifestData,
                encoding: .utf8
            )
        )

        XCTAssertEqual(decoded, result.manifest)
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(
            decoded.campaign.name,
            fixture.campaign.name
        )
        XCTAssertEqual(
            decoded.campaign.province,
            fixture.provinceName
        )
        XCTAssertFalse(
            checklist.contains(fixture.root.path)
        )
        XCTAssertFalse(
            manifestText.contains(fixture.root.path)
        )

        let expectedData = [
            "workflow.plan.primary": markdownData,
            "workflow.prototype.image": binaryData
        ]

        for item in decoded.items {
            XCTAssertFalse(item.relativePath.hasPrefix("/"))
            XCTAssertFalse(item.relativePath.contains(".."))

            let data = try Data(
                contentsOf: extracted
                    .appendingPathComponent(
                        item.relativePath
                    )
            )
            let expected = try XCTUnwrap(
                expectedData[item.logicalKey]
            )

            XCTAssertEqual(data, expected)
            XCTAssertEqual(
                item.byteCount,
                UInt64(expected.count)
            )
            XCTAssertEqual(
                item.sha256,
                sha256(expected)
            )
            XCTAssertTrue(
                checklist.contains(item.sha256)
            )
            XCTAssertTrue(
                checklist.contains(
                    item.relativePath
                )
            )
        }
    }


    // MARK: Adoption State

    func testNoAdoptedVersionNeverUsesLatestVersionFallback()
        throws {

        let fixture = try makeFixture()
        let step = try XCTUnwrap(
            fixture.workflow.steps.first
        )
        let firstURL = try writeFile(
            fixture: fixture,
            stepKind: step.kind,
            fileName: "draft_V1.md",
            data: Data("V1".utf8)
        )
        let secondURL = try writeFile(
            fixture: fixture,
            stepKind: step.kind,
            fileName: "draft_V2.md",
            data: Data("V2".utf8)
        )
        let artifacts = [
            makeArtifact(
                fixture: fixture,
                step: step,
                name: "无采用产物",
                type: .markdown,
                logicalKey: "no-adopted",
                location: firstURL.path,
                version: 1,
                isApproved: false
            ),
            makeArtifact(
                fixture: fixture,
                step: step,
                name: "无采用产物",
                type: .markdown,
                logicalKey: "no-adopted",
                location: secondURL.path,
                version: 2,
                isApproved: false
            )
        ]

        let candidate = try XCTUnwrap(
            ZhuowangArtifactDeliveryPackageService()
                .candidates(
                    snapshot:
                        fixture.snapshot(
                            artifacts: artifacts
                        ),
                    campaignWorkspaceURL:
                        fixture.campaignWorkspaceURL
                )
                .first
        )

        XCTAssertFalse(candidate.isEligible)
        XCTAssertNil(candidate.artifactID)
        XCTAssertNil(candidate.version)
        XCTAssertEqual(
            candidate.unavailableReason,
            .noAdoptedVersion
        )
    }


    func testMultipleAdoptedVersionsAreDisabled()
        throws {

        let fixture = try makeFixture()
        let step = try XCTUnwrap(
            fixture.workflow.steps.first
        )
        let firstURL = try writeFile(
            fixture: fixture,
            stepKind: step.kind,
            fileName: "duplicate_V1.md",
            data: Data("V1".utf8)
        )
        let secondURL = try writeFile(
            fixture: fixture,
            stepKind: step.kind,
            fileName: "duplicate_V2.md",
            data: Data("V2".utf8)
        )
        let artifacts = [
            makeArtifact(
                fixture: fixture,
                step: step,
                name: "异常产物",
                type: .markdown,
                logicalKey: "duplicate-adopted",
                location: firstURL.path,
                version: 1
            ),
            makeArtifact(
                fixture: fixture,
                step: step,
                name: "异常产物",
                type: .markdown,
                logicalKey: "duplicate-adopted",
                location: secondURL.path,
                version: 2
            )
        ]

        let candidate = try XCTUnwrap(
            ZhuowangArtifactDeliveryPackageService()
                .candidates(
                    snapshot:
                        fixture.snapshot(
                            artifacts: artifacts
                        ),
                    campaignWorkspaceURL:
                        fixture.campaignWorkspaceURL
                )
                .first
        )

        XCTAssertFalse(candidate.isEligible)
        XCTAssertEqual(
            candidate.unavailableReason,
            .multipleAdoptedVersions
        )
    }


    func testAdoptionChangeAfterSelectionRejectsExport()
        throws {

        let fixture = try makeFixture()
        let step = try XCTUnwrap(
            fixture.workflow.steps.first
        )
        let sourceURL = try writeFile(
            fixture: fixture,
            stepKind: step.kind,
            fileName: "selected.md",
            data: Data("selected".utf8)
        )
        let selectedArtifact = makeArtifact(
            fixture: fixture,
            step: step,
            name: "选择时已采用",
            type: .markdown,
            logicalKey: "adoption-change",
            location: sourceURL.path
        )
        let initialSnapshot = fixture.snapshot(
            artifacts: [selectedArtifact]
        )
        let service =
            ZhuowangArtifactDeliveryPackageService()
        let candidate = try XCTUnwrap(
            service.candidates(
                snapshot: initialSnapshot,
                campaignWorkspaceURL:
                    fixture.campaignWorkspaceURL
            ).first
        )
        XCTAssertEqual(
            candidate.artifactID,
            selectedArtifact.id
        )

        var changedArtifact = selectedArtifact
        changedArtifact.isApprovedVersion = false
        let changedSnapshot = fixture.snapshot(
            artifacts: [changedArtifact]
        )
        let destination = fixture.root
            .appendingPathComponent("changed.zip")

        XCTAssertThrowsError(
            try service.export(
                request: fixture.request(
                    selectedArtifacts:
                        [selectedArtifact],
                    destinationURL: destination
                ),
                snapshotProvider: {
                    changedSnapshot
                }
            )
        ) { error in
            guard case ZhuowangArtifactDeliveryError
                .selectionNoLongerAvailable = error
            else {
                return XCTFail(
                    "Unexpected error: \(error)"
                )
            }
        }

        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: destination.path
            )
        )
    }


    func testSwitchingAdoptedVersionAfterSelectionRejectsExport()
        throws {

        let fixture = try makeFixture()
        let step = try XCTUnwrap(
            fixture.workflow.steps.first
        )
        let firstURL = try writeFile(
            fixture: fixture,
            stepKind: step.kind,
            fileName: "selected_V1.md",
            data: Data("V1".utf8)
        )
        let secondURL = try writeFile(
            fixture: fixture,
            stepKind: step.kind,
            fileName: "selected_V2.md",
            data: Data("V2".utf8)
        )
        var selectedArtifact = makeArtifact(
            fixture: fixture,
            step: step,
            name: "选择时采用 V1",
            type: .markdown,
            logicalKey: "adopted-switch",
            location: firstURL.path,
            version: 1
        )
        let replacementArtifact = makeArtifact(
            fixture: fixture,
            step: step,
            name: "保存时采用 V2",
            type: .markdown,
            logicalKey: "adopted-switch",
            location: secondURL.path,
            version: 2
        )
        selectedArtifact.isApprovedVersion = false

        let destination = fixture.root
            .appendingPathComponent("switched.zip")
        let service =
            ZhuowangArtifactDeliveryPackageService()

        XCTAssertThrowsError(
            try service.export(
                request: fixture.request(
                    selectedArtifacts:
                        [selectedArtifact],
                    destinationURL: destination
                ),
                snapshotProvider: {
                    fixture.snapshot(
                        artifacts: [
                            selectedArtifact,
                            replacementArtifact
                        ]
                    )
                }
            )
        ) { error in
            guard case ZhuowangArtifactDeliveryError
                .selectionNoLongerAvailable = error
            else {
                return XCTFail(
                    "Unexpected error: \(error)"
                )
            }
        }

        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: destination.path
            )
        )
    }


    // MARK: Path Safety

    func testCaseVariantLocationFollowsFilesystemIdentityAndExportsVerifiedZIP()
        throws {
        let fixture = try makeFixture()
        let single = try makeSingleArtifact(
            fixture: fixture,
            logicalKey: "case-alias"
        )
        var artifact = single.artifact
        let originalURL = URL(fileURLWithPath: artifact.location)
        let aliasRoot = fixture.root.deletingLastPathComponent()
            .appendingPathComponent(fixture.root.lastPathComponent.lowercased())
        artifact.location = aliasRoot.path
            + originalURL.path.dropFirst(fixture.root.path.count)
        let originalData = try Data(contentsOf: originalURL)
        let aliasExists = FileManager.default.fileExists(atPath: aliasRoot.path)
        let service = ZhuowangArtifactDeliveryPackageService()
        let snapshot = fixture.snapshot(artifacts: [artifact])
        let candidate = try XCTUnwrap(service.candidates(
            snapshot: snapshot,
            campaignWorkspaceURL: fixture.campaignWorkspaceURL
        ).first)

        if !aliasExists {
            // On a case-sensitive volume the spelling is a different path.
            XCTAssertFalse(candidate.isEligible)
            XCTAssertEqual(candidate.unavailableReason, .missingFile)
            return
        }
        let originalAttributes = try FileManager.default.attributesOfItem(
            atPath: fixture.root.path
        )
        let aliasAttributes = try FileManager.default.attributesOfItem(
            atPath: aliasRoot.path
        )
        XCTAssertEqual(originalAttributes[.systemFileNumber] as? NSNumber,
                       aliasAttributes[.systemFileNumber] as? NSNumber)
        XCTAssertTrue(candidate.isEligible)
        let result = try service.export(
            request: fixture.request(
                selectedArtifacts: [artifact],
                destinationURL: fixture.root.appendingPathComponent("case-alias.zip")
            ),
            snapshotProvider: { snapshot }
        )
        let extracted = try extractArchive(result.archiveURL, under: fixture.root)
        let item = try XCTUnwrap(result.manifest.items.first)
        XCTAssertEqual(try Data(contentsOf: extracted.appendingPathComponent(item.relativePath)),
                       originalData)
        XCTAssertEqual(item.sha256, sha256(originalData))
        XCTAssertEqual(item.byteCount, UInt64(originalData.count))
        XCTAssertEqual(try Data(contentsOf: originalURL), originalData)
        XCTAssertEqual(artifact.location, snapshot.artifacts.first?.location)
        try assertNoTransactionDirectories(in: fixture.root)
    }

    func testAncestryRejectsPrefixSiblingTraversalAndDirectorySymlink()
        throws {
        let fixture = try makeFixture()
        let single = try makeSingleArtifact(fixture: fixture, logicalKey: "safety")
        let source = URL(fileURLWithPath: single.artifact.location)
        let sibling = fixture.campaignWorkspaceURL.deletingLastPathComponent()
            .appendingPathComponent(fixture.campaignWorkspaceURL.lastPathComponent + "-other")
        try FileManager.default.createDirectory(at: sibling, withIntermediateDirectories: false)
        let outside = sibling.appendingPathComponent("outside.md")
        try Data("outside".utf8).write(to: outside)
        let link = fixture.campaignWorkspaceURL.appendingPathComponent("linked-folder")
        try FileManager.default.createSymbolicLink(
            at: link, withDestinationURL: source.deletingLastPathComponent()
        )
        let cases: [(String, ZhuowangArtifactDeliveryUnavailableReason)] = [
            (outside.path, .outsideCampaignWorkspace),
            (fixture.campaignWorkspaceURL.path + "/../" + sibling.lastPathComponent
                + "/outside.md", .outsideCampaignWorkspace),
            (link.appendingPathComponent(source.lastPathComponent).path, .symbolicLink)
        ]
        let service = ZhuowangArtifactDeliveryPackageService()
        for (location, reason) in cases {
            var artifact = single.artifact
            artifact.location = location
            let candidate = try XCTUnwrap(service.candidates(
                snapshot: fixture.snapshot(artifacts: [artifact]),
                campaignWorkspaceURL: fixture.campaignWorkspaceURL
            ).first)
            XCTAssertFalse(candidate.isEligible)
            XCTAssertEqual(candidate.unavailableReason, reason)
        }
    }

    func testExternalMissingDirectorySymlinkAndOutsideFilesAreDisabled()
        throws {

        let fixture = try makeFixture()
        let step = try XCTUnwrap(
            fixture.workflow.steps.first
        )
        let outsideURL = fixture.root
            .appendingPathComponent(
                "Campaign Prefix Trap/outside.md"
            )
        try FileManager.default.createDirectory(
            at: outsideURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("outside".utf8).write(
            to: outsideURL
        )

        let directoryURL = fixture.campaignWorkspaceURL
            .appendingPathComponent(
                "directory-artifact",
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let realURL = try writeFile(
            fixture: fixture,
            stepKind: step.kind,
            fileName: "real.md",
            data: Data("real".utf8)
        )
        let symlinkURL = realURL
            .deletingLastPathComponent()
            .appendingPathComponent("linked.md")
        try FileManager.default.createSymbolicLink(
            at: symlinkURL,
            withDestinationURL: realURL
        )

        let artifacts = [
            makeArtifact(
                fixture: fixture,
                step: step,
                name: "外链",
                type: .figma,
                logicalKey: "figma-link",
                location: "https://figma.example/file"
            ),
            makeArtifact(
                fixture: fixture,
                step: step,
                name: "缺失",
                type: .markdown,
                logicalKey: "missing",
                location: fixture.campaignWorkspaceURL
                    .appendingPathComponent("missing.md")
                    .path
            ),
            makeArtifact(
                fixture: fixture,
                step: step,
                name: "目录",
                type: .other,
                logicalKey: "directory",
                location: directoryURL.path
            ),
            makeArtifact(
                fixture: fixture,
                step: step,
                name: "符号链接",
                type: .markdown,
                logicalKey: "symlink",
                location: symlinkURL.path
            ),
            makeArtifact(
                fixture: fixture,
                step: step,
                name: "Workspace 外",
                type: .markdown,
                logicalKey: "outside",
                location: outsideURL.path
            )
        ]

        let candidates =
            ZhuowangArtifactDeliveryPackageService()
                .candidates(
                    snapshot:
                        fixture.snapshot(
                            artifacts: artifacts
                        ),
                    campaignWorkspaceURL:
                        fixture.campaignWorkspaceURL
                )
        let reasons = Dictionary(
            uniqueKeysWithValues:
                candidates.map {
                    (
                        $0.groupKey,
                        $0.unavailableReason
                    )
                }
        )

        XCTAssertEqual(
            reasons["figma-link"],
            .externalReference
        )
        XCTAssertEqual(
            reasons["missing"],
            .missingFile
        )
        XCTAssertEqual(
            reasons["directory"],
            .notRegularFile
        )
        XCTAssertEqual(
            reasons["symlink"],
            .symbolicLink
        )
        XCTAssertEqual(
            reasons["outside"],
            .outsideCampaignWorkspace
        )
    }


    func testUnsafeSourceNameCannotCreateArchivePathTraversal()
        throws {

        let fixture = try makeFixture()
        let step = try XCTUnwrap(
            fixture.workflow.steps.first
        )
        let sourceURL = try writeFile(
            fixture: fixture,
            stepKind: step.kind,
            fileName: "..hidden",
            data: Data("safe".utf8)
        )
        let artifact = makeArtifact(
            fixture: fixture,
            step: step,
            name: "../../危险名称",
            type: .markdown,
            logicalKey: "safe-path",
            location: sourceURL.path
        )
        let destination = fixture.root
            .appendingPathComponent("safe.zip")
        let snapshot = fixture.snapshot(
            artifacts: [artifact]
        )
        let result = try
            ZhuowangArtifactDeliveryPackageService()
                .export(
                    request: fixture.request(
                        selectedArtifacts:
                            [artifact],
                        destinationURL:
                            destination
                    ),
                    snapshotProvider: {
                        snapshot
                    }
                )
        let path = try XCTUnwrap(
            result.manifest.items.first?
                .relativePath
        )

        XCTAssertFalse(path.hasPrefix("/"))
        XCTAssertFalse(path.contains(".."))
        XCTAssertTrue(path.hasSuffix("/artifact"))
    }


    // MARK: Transaction Failures

    func testSourceMutationAfterInitialHashFailsAndCleansTemporaryFiles()
        throws {

        let fixture = try makeFixture()
        let prepared = try makeSingleArtifact(
            fixture: fixture,
            logicalKey: "mutation"
        )
        var didMutate = false
        let service =
            ZhuowangArtifactDeliveryPackageService(
                checkpointHandler: {
                    checkpoint,
                    url in

                    guard checkpoint
                        == .afterSourceHash,
                          !didMutate
                    else {
                        return
                    }

                    didMutate = true
                    try Data("changed".utf8)
                        .write(to: url)
                }
            )
        let destination = fixture.root
            .appendingPathComponent("mutation.zip")

        XCTAssertThrowsError(
            try service.export(
                request: fixture.request(
                    selectedArtifacts:
                        [prepared.artifact],
                    destinationURL: destination
                ),
                snapshotProvider: {
                    prepared.snapshot
                }
            )
        ) { error in
            guard case ZhuowangArtifactDeliveryError
                .sourceChanged = error
            else {
                return XCTFail(
                    "Unexpected error: \(error)"
                )
            }
        }

        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: destination.path
            )
        )
        try assertNoTransactionDirectories(
            in: fixture.root
        )
    }


    func testExistingDestinationIsNeverOverwritten()
        throws {

        let fixture = try makeFixture()
        let prepared = try makeSingleArtifact(
            fixture: fixture,
            logicalKey: "existing-target"
        )
        let destination = fixture.root
            .appendingPathComponent("existing.zip")
        let sentinel = Data("user file".utf8)
        try sentinel.write(to: destination)

        XCTAssertThrowsError(
            try ZhuowangArtifactDeliveryPackageService()
                .export(
                    request: fixture.request(
                        selectedArtifacts:
                            [prepared.artifact],
                        destinationURL: destination
                    ),
                    snapshotProvider: {
                        prepared.snapshot
                    }
                )
        ) { error in
            XCTAssertEqual(
                error as?
                    ZhuowangArtifactDeliveryError,
                .destinationAlreadyExists
            )
        }

        XCTAssertEqual(
            try Data(contentsOf: destination),
            sentinel
        )
    }


    func testDestinationCreatedBeforePublishIsPreserved()
        throws {

        let fixture = try makeFixture()
        let prepared = try makeSingleArtifact(
            fixture: fixture,
            logicalKey: "publish-race"
        )
        let destination = fixture.root
            .appendingPathComponent("race.zip")
        let sentinel = Data("arrived first".utf8)
        let service =
            ZhuowangArtifactDeliveryPackageService(
                checkpointHandler: {
                    checkpoint,
                    url in

                    if checkpoint == .beforePublish {
                        try sentinel.write(to: url)
                    }
                }
            )

        XCTAssertThrowsError(
            try service.export(
                request: fixture.request(
                    selectedArtifacts:
                        [prepared.artifact],
                    destinationURL: destination
                ),
                snapshotProvider: {
                    prepared.snapshot
                }
            )
        ) { error in
            XCTAssertEqual(
                error as?
                    ZhuowangArtifactDeliveryError,
                .destinationAlreadyExists
            )
        }

        XCTAssertEqual(
            try Data(contentsOf: destination),
            sentinel
        )
        try assertNoTransactionDirectories(
            in: fixture.root
        )
    }


    func testCorruptArchiveAndArchiveToolFailureLeaveNoFinalZip()
        throws {

        let fixture = try makeFixture()
        let prepared = try makeSingleArtifact(
            fixture: fixture,
            logicalKey: "archive-failure"
        )
        let corruptDestination = fixture.root
            .appendingPathComponent("corrupt.zip")
        let corruptingService =
            ZhuowangArtifactDeliveryPackageService(
                checkpointHandler: {
                    checkpoint,
                    url in

                    if checkpoint == .afterArchive {
                        try Data("not a zip".utf8)
                            .write(to: url)
                    }
                }
            )

        XCTAssertThrowsError(
            try corruptingService.export(
                request: fixture.request(
                    selectedArtifacts:
                        [prepared.artifact],
                    destinationURL:
                        corruptDestination
                ),
                snapshotProvider: {
                    prepared.snapshot
                }
            )
        ) { error in
            XCTAssertEqual(
                error as?
                    ZhuowangArtifactDeliveryError,
                .archiveVerificationFailed
            )
        }

        let failedDestination = fixture.root
            .appendingPathComponent("failed.zip")
        let failingService =
            ZhuowangArtifactDeliveryPackageService(
                archiveExecutableURL: URL(
                    fileURLWithPath: "/usr/bin/false"
                )
            )

        XCTAssertThrowsError(
            try failingService.export(
                request: fixture.request(
                    selectedArtifacts:
                        [prepared.artifact],
                    destinationURL:
                        failedDestination
                ),
                snapshotProvider: {
                    prepared.snapshot
                }
            )
        ) { error in
            XCTAssertEqual(
                error as?
                    ZhuowangArtifactDeliveryError,
                .archiveCreationFailed
            )
        }

        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: corruptDestination.path
            )
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: failedDestination.path
            )
        )
        try assertNoTransactionDirectories(
            in: fixture.root
        )
    }


    // MARK: Fixture

    private struct Fixture {
        let root: URL
        let fileManager:
            ZhuowangWorkspaceFileManager
        let campaign: ZhuowangCampaign
        let provinceName: String
        let workflow: ZhuowangCampaignWorkflow
        let campaignWorkspaceURL: URL

        func snapshot(
            artifacts: [ZhuowangArtifact]
        ) -> ZhuowangArtifactDeliverySnapshot {
            ZhuowangArtifactDeliverySnapshot(
                campaignID: campaign.id,
                artifacts: artifacts,
                steps: workflow.steps
            )
        }

        func request(
            selectedArtifacts: [ZhuowangArtifact],
            destinationURL: URL
        ) -> ZhuowangArtifactDeliveryRequest {
            ZhuowangArtifactDeliveryRequest(
                campaign: campaign,
                provinceName: provinceName,
                campaignWorkspaceURL:
                    campaignWorkspaceURL,
                selections: Set(
                    selectedArtifacts.map {
                        ZhuowangArtifactDeliverySelection(
                            groupKey:
                                $0.versionGroupKey,
                            artifactID: $0.id
                        )
                    }
                ),
                destinationURL:
                    destinationURL
            )
        }
    }


    private func makeFixture() throws -> Fixture {
        let root = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "Cosmos-Delivery-Package-\(UUID().uuidString)",
                isDirectory: true
            )
        temporaryRoots.append(root)

        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )

        let campaign = ZhuowangCampaign(
            name: "交付包测试活动",
            scopeType: .province,
            startDate: Date(
                timeIntervalSince1970: 100
            ),
            endDate: Date(
                timeIntervalSince1970: 200
            )
        )
        let provinceName = "浙江"
        let manager = ZhuowangWorkspaceFileManager(
            rootURL: root
        )
        let campaignWorkspaceURL = try manager
            .createCampaignWorkspace(
                provinceName: provinceName,
                campaignName: campaign.name
            )
        let workflow =
            ZhuowangCampaignWorkflow.standard(
                campaignID: campaign.id
            )

        return Fixture(
            root: root,
            fileManager: manager,
            campaign: campaign,
            provinceName: provinceName,
            workflow: workflow,
            campaignWorkspaceURL:
                campaignWorkspaceURL
        )
    }


    private func writeFile(
        fixture: Fixture,
        stepKind: ZhuowangWorkflowStepKind,
        fileName: String,
        data: Data
    ) throws -> URL {
        let directory = fixture.fileManager
            .directoryURL(
                for: stepKind,
                provinceName:
                    fixture.provinceName,
                campaignName:
                    fixture.campaign.name
            )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let fileURL = directory
            .appendingPathComponent(fileName)
        try data.write(to: fileURL)
        return fileURL
    }


    private func makeArtifact(
        fixture: Fixture,
        step: ZhuowangWorkflowStep,
        name: String,
        type: ZhuowangArtifactType,
        logicalKey: String,
        location: String,
        version: Int = 1,
        isApproved: Bool = true
    ) -> ZhuowangArtifact {
        ZhuowangArtifact(
            campaignID: fixture.campaign.id,
            stepID: step.id,
            name: name,
            type: type,
            logicalKey: logicalKey,
            location: location,
            version: version,
            isApprovedVersion: isApproved
        )
    }


    private func makeSingleArtifact(
        fixture: Fixture,
        logicalKey: String
    ) throws -> (
        artifact: ZhuowangArtifact,
        snapshot: ZhuowangArtifactDeliverySnapshot
    ) {
        let step = try XCTUnwrap(
            fixture.workflow.steps.first
        )
        let sourceURL = try writeFile(
            fixture: fixture,
            stepKind: step.kind,
            fileName: "single.md",
            data: Data("single source".utf8)
        )
        let artifact = makeArtifact(
            fixture: fixture,
            step: step,
            name: "单文件产物",
            type: .markdown,
            logicalKey: logicalKey,
            location: sourceURL.path
        )

        return (
            artifact,
            fixture.snapshot(
                artifacts: [artifact]
            )
        )
    }


    private func extractArchive(
        _ archiveURL: URL,
        under root: URL
    ) throws -> URL {
        let extracted = root
            .appendingPathComponent(
                "independent-extraction-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: extracted,
            withIntermediateDirectories: false
        )

        let process = Process()
        process.executableURL = URL(
            fileURLWithPath: "/usr/bin/ditto"
        )
        process.arguments = [
            "-x",
            "-k",
            archiveURL.path,
            extracted.path
        ]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
        return extracted
    }


    private func sha256(
        _ data: Data
    ) -> String {
        SHA256.hash(data: data)
            .map {
                String(
                    format: "%02x",
                    $0
                )
            }
            .joined()
    }


    private func assertNoTransactionDirectories(
        in root: URL
    ) throws {
        let children = try FileManager.default
            .contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil
            )

        XCTAssertFalse(
            children.contains {
                $0.lastPathComponent
                    .hasPrefix(
                        ".cosmos-delivery-"
                    )
            }
        )
    }
}
