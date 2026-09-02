import SwiftUI
import Combine
import AppKit
@preconcurrency import PDFKit


struct ArtifactPDFPreviewRenderer: ArtifactPreviewRenderer {
    let identifier: ArtifactPreviewRendererIdentifier = .pdf
    let presentationStyle: ArtifactPreviewPresentationStyle = .adaptiveCanvas
    let capabilities: ArtifactPreviewRendererCapabilities = .pdf

    func supports(input: ArtifactPreviewInput) -> Bool {
        input.mediaType.classification == .pdf
            && input.localFileReference != nil
    }

    func makePreview(
        document: ArtifactReviewDocument,
        input: ArtifactPreviewInput,
        context: ArtifactPreviewContext
    ) -> AnyView {
        guard supports(input: input),
              let reference = input.localFileReference else {
            return AnyView(
                ArtifactPDFFailureView(
                    error: .unreadableFile,
                    retry: nil
                )
            )
        }

        return AnyView(
            ArtifactPDFPreviewView(
                documentID: document.id,
                reference: reference
            )
        )
    }
}


enum ArtifactPDFZoomMode: Equatable {
    case fitPage
    case fitWidth
    case percentage(Double)

    static let stops: [Double] = [
        0.10, 0.25, 0.50, 0.75, 1.00,
        1.25, 1.50, 2.00, 3.00, 4.00
    ]

    mutating func zoomIn(currentScale: Double) {
        let next = Self.stops.first {
            $0 > currentScale + 0.000_1
        } ?? ArtifactPDFPreviewSecurityPolicy.maximumZoom
        self = .percentage(
            min(ArtifactPDFPreviewSecurityPolicy.maximumZoom, next)
        )
    }

    mutating func zoomOut(currentScale: Double) {
        let next = Self.stops.last {
            $0 < currentScale - 0.000_1
        } ?? ArtifactPDFPreviewSecurityPolicy.minimumZoom
        self = .percentage(
            max(ArtifactPDFPreviewSecurityPolicy.minimumZoom, next)
        )
    }
}


enum ArtifactPDFLoadState {
    case idle
    case loading
    case ready(ArtifactPDFPreviewMetadata)
    case failed(ArtifactPDFPreviewError)
}


@MainActor
struct ArtifactPDFKitDocumentInspector {
    func prepare(
        _ document: PDFDocument,
        expectedMetadata: ArtifactPDFPreviewMetadata
    ) throws {
        guard !document.isEncrypted, !document.isLocked else {
            throw ArtifactPDFPreviewError.encryptedDocument
        }
        guard document.pageCount == expectedMetadata.pageCount else {
            throw ArtifactPDFPreviewError.corruptFile
        }

        for pageIndex in 0..<document.pageCount {
            try Task.checkCancellation()
            guard let page = document.page(at: pageIndex) else {
                throw ArtifactPDFPreviewError.corruptFile
            }
            for annotation in page.annotations {
                if annotation.type == PDFAnnotationSubtype.widget.rawValue {
                    throw ArtifactPDFPreviewError.unsafeFeature(.widget)
                }
                annotation.isReadOnly = true

                if let destination = annotation.destination {
                    try validate(destination: destination, in: document)
                }

                guard let action = annotation.action else {
                    annotation.url = nil
                    continue
                }

                if let goTo = action as? PDFActionGoTo {
                    try validate(destination: goTo.destination, in: document)
                } else if action is PDFActionURL
                            || action is PDFActionRemoteGoTo
                            || action is PDFActionNamed {
                    annotation.action = nil
                    annotation.url = nil
                } else {
                    throw ArtifactPDFPreviewError.unsafeFeature(.unknownAction)
                }
            }
        }
    }

    private func validate(
        destination: PDFDestination,
        in document: PDFDocument
    ) throws {
        guard let page = destination.page,
              document.index(for: page) != NSNotFound else {
            throw ArtifactPDFPreviewError.unsafeFeature(.unknownAction)
        }
    }
}


@MainActor
final class ArtifactPDFPreviewViewModel: ObservableObject {
    let documentID: UUID
    let reference: ArtifactReviewLocalFileReference

    @Published private(set) var loadState: ArtifactPDFLoadState = .idle
    @Published var zoomMode: ArtifactPDFZoomMode = .fitPage
    @Published private(set) var currentScale = 1.0
    @Published private(set) var currentPage = 1
    @Published var pageEntry = "1"

    private(set) var pdfDocument: PDFDocument?
    private let loader: any ArtifactPDFPreviewLoading
    private let documentInspector: ArtifactPDFKitDocumentInspector
    private let loadTimeoutNanoseconds: UInt64
    private var generationToken = UUID()
    private var loadTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var bindingSession: ArtifactPDFRendererBindingSession?

    init(
        documentID: UUID,
        reference: ArtifactReviewLocalFileReference,
        loader: (any ArtifactPDFPreviewLoading)? = nil,
        documentInspector: ArtifactPDFKitDocumentInspector? = nil,
        loadTimeoutNanoseconds: UInt64 =
            ArtifactPDFPreviewSecurityPolicy.loadTimeoutNanoseconds
    ) {
        self.documentID = documentID
        self.reference = reference
        self.loader = loader ?? ArtifactPDFPreviewLoader()
        self.documentInspector = documentInspector ?? .init()
        self.loadTimeoutNanoseconds = loadTimeoutNanoseconds
    }

    func load() {
        tearDownCurrentBinding()
        cancelTasksAndInvalidateGeneration()
        releaseDocument()

        let token = UUID()
        generationToken = token
        bindingSession = ArtifactPDFRendererBindingSession(
            viewModel: self,
            generationToken: token
        )
        zoomMode = .fitPage
        currentScale = 1
        currentPage = 1
        pageEntry = "1"
        loadState = .loading

        let timeoutNanoseconds = loadTimeoutNanoseconds
        timeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(
                    nanoseconds: timeoutNanoseconds
                )
            } catch {
                return
            }
            guard let self,
                  self.generationToken == token,
                  case .loading = self.loadState else {
                return
            }
            self.bindingSession?.tearDown()
            self.loadState = .failed(.timedOut)
        }

        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await loader.load(reference: reference)
                guard !Task.isCancelled,
                      generationToken == token,
                      bindingSession?.isActive(
                        for: token,
                        viewModel: self
                      ) == true else {
                    return
                }
                guard let document = PDFDocument(data: result.data) else {
                    throw ArtifactPDFPreviewError.corruptFile
                }
                try documentInspector.prepare(
                    document,
                    expectedMetadata: result.metadata
                )
                guard !Task.isCancelled,
                      generationToken == token else {
                    return
                }

                timeoutTask?.cancel()
                timeoutTask = nil
                pdfDocument = document
                loadState = .ready(result.metadata)
            } catch let error as ArtifactPDFPreviewError {
                publish(error: error, token: token)
            } catch is CancellationError {
                return
            } catch {
                publish(error: .corruptFile, token: token)
            }
        }
    }

    func retry() {
        load()
    }

    func rendererBindingSession() -> ArtifactPDFRendererBindingSession {
        if let bindingSession,
           bindingSession.isActive(
            for: generationToken,
            viewModel: self
           ) {
            return bindingSession
        }
        let session = ArtifactPDFRendererBindingSession(
            viewModel: self,
            generationToken: generationToken
        )
        bindingSession = session
        return session
    }

    func cancel() {
        if let bindingSession {
            bindingSession.tearDown()
        } else {
            cancelTasksAndInvalidateGeneration()
            releaseDocument()
        }
    }

    func showFitPage() {
        zoomMode = .fitPage
    }

    func showFitWidth() {
        zoomMode = .fitWidth
    }

    func zoomIn() {
        zoomMode.zoomIn(currentScale: currentScale)
    }

    func zoomOut() {
        zoomMode.zoomOut(currentScale: currentScale)
    }

    func publishScaleIfNeeded(
        _ scale: Double,
        from session: ArtifactPDFRendererBindingSession,
        generationToken: UUID
    ) {
        guard isCurrent(session, generationToken: generationToken) else {
            return
        }
        let boundedScale = boundedScale(scale)
        guard abs(currentScale - boundedScale) > 0.0001 else {
            return
        }
        currentScale = boundedScale
    }

    func publishCurrentPageIfNeeded(
        _ page: Int,
        from session: ArtifactPDFRendererBindingSession,
        generationToken: UUID
    ) {
        guard isCurrent(session, generationToken: generationToken) else {
            return
        }
        let pageText = String(page)
        guard currentPage != page || pageEntry != pageText else {
            return
        }
        currentPage = page
        pageEntry = pageText
    }

    private func boundedScale(_ scale: Double) -> Double {
        min(
            ArtifactPDFPreviewSecurityPolicy.maximumZoom,
            max(ArtifactPDFPreviewSecurityPolicy.minimumZoom, scale)
        )
    }

    func goToPreviousPage() {
        bindingSession?.goToPreviousPage()
    }

    func goToNextPage() {
        bindingSession?.goToNextPage()
    }

    func goToEnteredPage() {
        guard let pageNumber = Int(pageEntry) else {
            pageEntry = String(currentPage)
            return
        }
        goToPage(pageNumber)
    }

    func goToPage(_ pageNumber: Int) {
        guard let document = pdfDocument,
              pageNumber >= 1,
              pageNumber <= document.pageCount,
              let page = document.page(at: pageNumber - 1) else {
            pageEntry = String(currentPage)
            return
        }
        bindingSession?.go(to: page)
        currentPage = pageNumber
        pageEntry = String(pageNumber)
    }

    deinit {
        loadTask?.cancel()
        timeoutTask?.cancel()
    }

    private func publish(
        error: ArtifactPDFPreviewError,
        token: UUID
    ) {
        guard !Task.isCancelled,
              generationToken == token,
              error != .cancelled else {
            return
        }
        timeoutTask?.cancel()
        timeoutTask = nil
        bindingSession?.tearDown()
        releaseDocument()
        loadState = .failed(error)
    }

    private func cancelTasksAndInvalidateGeneration() {
        generationToken = UUID()
        loadTask?.cancel()
        timeoutTask?.cancel()
        loadTask = nil
        timeoutTask = nil
    }

    func prepareForBindingTeardown(
        _ session: ArtifactPDFRendererBindingSession
    ) {
        guard bindingSession === session else { return }
        cancelTasksAndInvalidateGeneration()
        pdfDocument = nil
    }

    func completeBindingTeardown(
        _ session: ArtifactPDFRendererBindingSession
    ) {
        guard bindingSession === session else { return }
        bindingSession = nil
    }

    private func tearDownCurrentBinding() {
        bindingSession?.tearDown()
    }

    private func isCurrent(
        _ session: ArtifactPDFRendererBindingSession,
        generationToken: UUID
    ) -> Bool {
        bindingSession === session
            && self.generationToken == generationToken
            && session.isActive(for: generationToken, viewModel: self)
    }

    private func releaseDocument() {
        pdfDocument = nil
    }
}


@MainActor
final class ArtifactSecurePDFViewDelegate: NSObject, PDFViewDelegate {
    func pdfViewWillClick(
        onLink sender: PDFView,
        with url: URL
    ) {}

    func pdfViewOpenPDF(
        _ sender: PDFView,
        forRemoteGoToAction action: PDFActionRemoteGoTo
    ) {}

    func pdfViewPerformPrint(_ sender: PDFView) {}

    func pdfViewPerformFind(_ sender: PDFView) {}

    func pdfViewPerformGo(toPage sender: PDFView) {}
}


@MainActor
final class ArtifactSecurePDFView: PDFView {
    var allowsSecureCopy = false
    private var securityDelegate: ArtifactSecurePDFViewDelegate?
    private(set) weak var rendererBindingSession:
        ArtifactPDFRendererBindingSession?
    private(set) var didTearDownRendererBindings = false

    var hasActiveSecurityDelegate: Bool {
        guard let securityDelegate else { return false }
        return delegate === securityDelegate
    }

    var hasRetainedSecurityDelegate: Bool {
        securityDelegate != nil
    }

    var secureDocument: PDFDocument? {
        get { document }
        set {
            if document !== newValue {
                document = nil
            }
            document = newValue
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureSecurityBoundary()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureSecurityBoundary()
    }

    override func perform(_ action: PDFAction) {
        guard let goTo = action as? PDFActionGoTo,
              let document,
              let page = goTo.destination.page,
              document.index(for: page) != NSNotFound else {
            return
        }
        go(to: goTo.destination)
    }

    override func copy(_ sender: Any?) {
        guard allowsSecureCopy else {
            NSSound.beep()
            return
        }
        super.copy(sender)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                .contains(.command),
              let characters = event.charactersIgnoringModifiers?
                .lowercased() else {
            return super.performKeyEquivalent(with: event)
        }

        switch characters {
        case "c":
            copy(nil)
            return true
        case "p", "s":
            NSSound.beep()
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }

    override func tryToPerform(
        _ action: Selector,
        with object: Any?
    ) -> Bool {
        if Self.blockedResponderActions.contains(
            NSStringFromSelector(action)
        ) {
            NSSound.beep()
            return true
        }
        return super.tryToPerform(action, with: object)
    }

    func validateUserInterfaceItem(
        _ item: any NSValidatedUserInterfaceItem
    ) -> Bool {
        if item.action == #selector(copy(_:)) {
            return allowsSecureCopy && currentSelection != nil
        }
        if item.action == #selector(NSView.printView(_:)) {
            return false
        }
        if let action = item.action,
           Self.blockedResponderActions.contains(
            NSStringFromSelector(action)
           ) {
            return false
        }
        return true
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard allowsSecureCopy, currentSelection != nil else {
            return nil
        }
        let menu = NSMenu(title: "PDF")
        let copyItem = NSMenuItem(
            title: "拷贝",
            action: #selector(copy(_:)),
            keyEquivalent: "c"
        )
        copyItem.target = self
        menu.addItem(copyItem)
        return menu
    }

    func installSecurityDelegate(
        _ securityDelegate: ArtifactSecurePDFViewDelegate,
        bindingSession: ArtifactPDFRendererBindingSession
    ) {
        self.securityDelegate = securityDelegate
        rendererBindingSession = bindingSession
        delegate = securityDelegate
        didTearDownRendererBindings = false
    }

    func clearRendererBindings() {
        delegate = nil
        securityDelegate = nil
        rendererBindingSession = nil
        allowsSecureCopy = false
        secureDocument = nil
        didTearDownRendererBindings = true
    }

    private func configureSecurityBoundary() {
        displayMode = .singlePageContinuous
        displayDirection = .vertical
        displaysPageBreaks = true
        displayBox = .cropBox
        autoScales = false
        minScaleFactor = ArtifactPDFPreviewSecurityPolicy.minimumZoom
        maxScaleFactor = ArtifactPDFPreviewSecurityPolicy.maximumZoom
        acceptsDraggedFiles = false
        // PDFKit still exposes this macOS switch even though the typed name is
        // deprecated; KVC keeps generated URL annotations disabled on new SDKs.
        setValue(false, forKey: "enableDataDetectors")
        isInMarkupMode = false
        backgroundColor = .windowBackgroundColor
    }

    private static let blockedResponderActions: Set<String> = [
        "print:",
        "printDocument:",
        "printView:",
        "saveDocument:",
        "saveDocumentAs:",
        "saveTo:",
        "export:"
    ]
}


@MainActor
final class ArtifactPDFRendererBindingSession {
    private(set) weak var viewModel: ArtifactPDFPreviewViewModel?
    private(set) weak var pdfView: ArtifactSecurePDFView?
    private(set) var securityDelegate: ArtifactSecurePDFViewDelegate?
    private var observerTokens: [NSObjectProtocol] = []
    private var generationToken: UUID
    private var pendingScale: Double?
    private var pendingScaleTask: Task<Void, Never>?
    private var pendingPage: Int?
    private var pendingPageTask: Task<Void, Never>?

    private(set) var didTearDownRendererBindings = false

    var observerTokenCount: Int { observerTokens.count }
    var hasPendingStatePublication: Bool {
        pendingScaleTask != nil || pendingPageTask != nil
    }

    init(
        viewModel: ArtifactPDFPreviewViewModel,
        generationToken: UUID
    ) {
        self.viewModel = viewModel
        self.generationToken = generationToken
    }

    func isActive(
        for generationToken: UUID,
        viewModel: ArtifactPDFPreviewViewModel
    ) -> Bool {
        !didTearDownRendererBindings
            && self.generationToken == generationToken
            && self.viewModel === viewModel
    }

    func attach(
        _ view: ArtifactSecurePDFView,
        document: PDFDocument?
    ) {
        guard !didTearDownRendererBindings else { return }
        if let existingView = pdfView,
           existingView !== view {
            tearDown()
            return
        }

        if pdfView == nil {
            pdfView = view
            let delegate = ArtifactSecurePDFViewDelegate()
            securityDelegate = delegate
            view.installSecurityDelegate(
                delegate,
                bindingSession: self
            )
            installObservers(for: view)
        }
        view.secureDocument = document
        view.allowsSecureCopy = document?.allowsCopying == true
    }

    func applyZoom(
        _ mode: ArtifactPDFZoomMode,
        availableSize: CGSize
    ) {
        guard !didTearDownRendererBindings,
              let view = pdfView,
              let document = view.document,
              let page = view.currentPage ?? document.page(at: 0) else {
            return
        }

        let scale: CGFloat
        switch mode {
        case .fitWidth:
            view.autoScales = true
            scale = view.scaleFactorForSizeToFit
        case .fitPage:
            view.autoScales = false
            let pageSize = page.bounds(for: .cropBox).size
            let widthScale = max(1, availableSize.width - 36)
                / pageSize.width
            let heightScale = max(1, availableSize.height - 36)
                / pageSize.height
            scale = min(widthScale, heightScale)
            view.scaleFactor = bounded(scale)
        case .percentage(let value):
            view.autoScales = false
            scale = CGFloat(value)
            view.scaleFactor = bounded(scale)
        }
        scheduleScaleSynchronization(Double(bounded(scale)))
    }

    func scheduleScaleSynchronization(_ scale: Double) {
        guard !didTearDownRendererBindings else { return }
        pendingScale = min(
            ArtifactPDFPreviewSecurityPolicy.maximumZoom,
            max(ArtifactPDFPreviewSecurityPolicy.minimumZoom, scale)
        )
        guard pendingScaleTask == nil else { return }

        let scheduledGeneration = generationToken
        pendingScaleTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self else { return }
            self.pendingScaleTask = nil
            guard !Task.isCancelled,
                  !self.didTearDownRendererBindings,
                  self.generationToken == scheduledGeneration,
                  let scale = self.pendingScale,
                  let viewModel = self.viewModel,
                  self.isActive(
                    for: scheduledGeneration,
                    viewModel: viewModel
                  ) else {
                self.pendingScale = nil
                return
            }
            self.pendingScale = nil
            viewModel.publishScaleIfNeeded(
                scale,
                from: self,
                generationToken: scheduledGeneration
            )
        }
    }

    func scheduleCurrentPageSynchronization(from view: PDFView) {
        guard !didTearDownRendererBindings,
              view === pdfView,
              let document = view.document,
              let page = view.currentPage else {
            return
        }
        let index = document.index(for: page)
        guard index != NSNotFound else { return }

        pendingPage = index + 1
        guard pendingPageTask == nil else { return }

        let scheduledGeneration = generationToken
        pendingPageTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self else { return }
            self.pendingPageTask = nil
            guard !Task.isCancelled,
                  !self.didTearDownRendererBindings,
                  self.generationToken == scheduledGeneration,
                  let page = self.pendingPage,
                  let viewModel = self.viewModel,
                  self.isActive(
                    for: scheduledGeneration,
                    viewModel: viewModel
                  ) else {
                self.pendingPage = nil
                return
            }
            self.pendingPage = nil
            viewModel.publishCurrentPageIfNeeded(
                page,
                from: self,
                generationToken: scheduledGeneration
            )
        }
    }

    func goToPreviousPage() {
        guard !didTearDownRendererBindings else { return }
        pdfView?.goToPreviousPage(nil)
    }

    func goToNextPage() {
        guard !didTearDownRendererBindings else { return }
        pdfView?.goToNextPage(nil)
    }

    func go(to page: PDFPage) {
        guard !didTearDownRendererBindings else { return }
        pdfView?.go(to: page)
    }

    func tearDown() {
        guard !didTearDownRendererBindings else { return }
        didTearDownRendererBindings = true

        let currentViewModel = viewModel
        generationToken = UUID()
        pendingScaleTask?.cancel()
        pendingPageTask?.cancel()
        pendingScaleTask = nil
        pendingPageTask = nil
        pendingScale = nil
        pendingPage = nil
        currentViewModel?.prepareForBindingTeardown(self)

        let center = NotificationCenter.default
        observerTokens.forEach(center.removeObserver)
        observerTokens.removeAll()

        let currentView = pdfView
        currentView?.clearRendererBindings()
        pdfView = nil
        securityDelegate = nil

        currentViewModel?.completeBindingTeardown(self)
        viewModel = nil
    }

    private func installObservers(for view: ArtifactSecurePDFView) {
        let center = NotificationCenter.default
        observerTokens.append(
            center.addObserver(
                forName: .PDFViewPageChanged,
                object: view,
                queue: .main
            ) { [weak self, weak view] _ in
                guard let self, let view else { return }
                MainActor.assumeIsolated {
                    guard !self.didTearDownRendererBindings else { return }
                    self.scheduleCurrentPageSynchronization(from: view)
                }
            }
        )
        observerTokens.append(
            center.addObserver(
                forName: .PDFViewScaleChanged,
                object: view,
                queue: .main
            ) { [weak self, weak view] _ in
                guard let self, let view else { return }
                MainActor.assumeIsolated {
                    guard !self.didTearDownRendererBindings else { return }
                    self.scheduleScaleSynchronization(view.scaleFactor)
                }
            }
        )
    }

    private func bounded(_ scale: CGFloat) -> CGFloat {
        min(
            ArtifactPDFPreviewSecurityPolicy.maximumZoom,
            max(ArtifactPDFPreviewSecurityPolicy.minimumZoom, scale)
        )
    }

    deinit {
        pendingScaleTask?.cancel()
        pendingPageTask?.cancel()
        observerTokens.forEach(NotificationCenter.default.removeObserver)
    }
}


private struct ArtifactPDFPreviewView: View {
    @StateObject private var viewModel: ArtifactPDFPreviewViewModel

    init(
        documentID: UUID,
        reference: ArtifactReviewLocalFileReference
    ) {
        _viewModel = StateObject(
            wrappedValue: ArtifactPDFPreviewViewModel(
                documentID: documentID,
                reference: reference
            )
        )
    }

    var body: some View {
        Group {
            switch viewModel.loadState {
            case .idle, .loading:
                loadingView
            case .ready(let metadata):
                readyView(metadata)
            case .failed(let error):
                ArtifactPDFFailureView(
                    error: error,
                    retry: error.isRecoverable
                        ? { viewModel.retry() }
                        : nil
                )
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task(id: viewModel.documentID) {
            viewModel.load()
        }
        .onDisappear {
            viewModel.cancel()
        }
    }

    private var loadingView: some View {
        VStack(spacing: CosmosDesign.spacingM) {
            ProgressView()
                .controlSize(.large)
            Text("正在安全检查 PDF")
                .font(.headline)
            Text(viewModel.reference.url.lastPathComponent)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(CosmosDesign.spacingXL)
    }

    private func readyView(
        _ metadata: ArtifactPDFPreviewMetadata
    ) -> some View {
        VStack(spacing: 0) {
            ArtifactPDFToolbar(
                viewModel: viewModel,
                metadata: metadata
            )
            Divider()
            GeometryReader { proxy in
                ArtifactPDFViewBridge(
                    viewModel: viewModel,
                    availableSize: proxy.size
                )
            }
        }
    }
}


private struct ArtifactPDFToolbar: View {
    @ObservedObject var viewModel: ArtifactPDFPreviewViewModel
    let metadata: ArtifactPDFPreviewMetadata

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: CosmosDesign.spacingS) {
                zoomControls
                Divider().frame(height: 20)
                pageControls
                Spacer(minLength: CosmosDesign.spacingS)
                metadataLabel
            }
            VStack(alignment: .leading, spacing: CosmosDesign.spacingS) {
                HStack(spacing: CosmosDesign.spacingS) {
                    zoomControls
                    Spacer(minLength: CosmosDesign.spacingS)
                    metadataLabel
                }
                pageControls
            }
        }
        .padding(.horizontal, CosmosDesign.spacingM)
        .padding(.vertical, CosmosDesign.spacingS)
    }

    private var zoomControls: some View {
        HStack(spacing: CosmosDesign.spacingS) {
            Button("适应页面") { viewModel.showFitPage() }
                .buttonStyle(.bordered)
            Button("适应宽度") { viewModel.showFitWidth() }
                .buttonStyle(.bordered)
            Button { viewModel.zoomOut() } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(.bordered)
            .help("缩小")
            Text("\(Int((viewModel.currentScale * 100).rounded()))%")
                .font(.caption.monospacedDigit())
                .frame(minWidth: 52)
            Button { viewModel.zoomIn() } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .buttonStyle(.bordered)
            .help("放大")
        }
    }

    private var pageControls: some View {
        HStack(spacing: CosmosDesign.spacingS) {
            Button { viewModel.goToPreviousPage() } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.currentPage <= 1)

            TextField("页码", text: $viewModel.pageEntry)
                .textFieldStyle(.roundedBorder)
                .frame(width: 54)
                .multilineTextAlignment(.trailing)
                .onSubmit { viewModel.goToEnteredPage() }
            Text("/ \(metadata.pageCount)")
                .font(.caption.monospacedDigit())

            Button { viewModel.goToNextPage() } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.currentPage >= metadata.pageCount)
        }
    }

    private var metadataLabel: some View {
        let pageIndex = max(
            0,
            min(metadata.pageCount - 1, viewModel.currentPage - 1)
        )
        let page = metadata.pages[pageIndex]
        let byteCount = ByteCountFormatter.string(
            fromByteCount: metadata.fileSize,
            countStyle: .file
        )
        return Text(
            "PDF · \(metadata.pageCount) 页 · "
                + "\(Int(page.widthPoints.rounded()))×"
                + "\(Int(page.heightPoints.rounded())) pt · "
                + byteCount
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}


struct ArtifactPDFViewBridge: NSViewRepresentable {
    @ObservedObject var viewModel: ArtifactPDFPreviewViewModel
    let availableSize: CGSize

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeNSView(context: Context) -> ArtifactSecurePDFView {
        let view = ArtifactSecurePDFView(frame: .zero)
        context.coordinator.attach(view)
        return view
    }

    func updateNSView(
        _ view: ArtifactSecurePDFView,
        context: Context
    ) {
        context.coordinator.attach(view)
        context.coordinator.applyZoom(
            viewModel.zoomMode,
            availableSize: availableSize
        )
    }

    static func dismantleNSView(
        _ view: ArtifactSecurePDFView,
        coordinator: Coordinator
    ) {
        coordinator.tearDown()
    }

    @MainActor
    final class Coordinator {
        let viewModel: ArtifactPDFPreviewViewModel
        let bindingSession: ArtifactPDFRendererBindingSession

        init(viewModel: ArtifactPDFPreviewViewModel) {
            self.viewModel = viewModel
            bindingSession = viewModel.rendererBindingSession()
        }

        func attach(_ view: ArtifactSecurePDFView) {
            bindingSession.attach(
                view,
                document: viewModel.pdfDocument
            )
        }

        func applyZoom(
            _ mode: ArtifactPDFZoomMode,
            availableSize: CGSize
        ) {
            bindingSession.applyZoom(
                mode,
                availableSize: availableSize
            )
        }

        func tearDown() {
            bindingSession.tearDown()
        }
    }
}


struct ArtifactPDFFailureView: View {
    let error: ArtifactPDFPreviewError
    let retry: (() -> Void)?

    var body: some View {
        VStack(spacing: CosmosDesign.spacingM) {
            Image(systemName: "doc.badge.ellipsis")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.secondary)
            Text(error.title)
                .font(.headline)
            Text(error.message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)
            if let retry {
                Button("重新加载", action: retry)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(CosmosDesign.spacingXL)
    }
}
