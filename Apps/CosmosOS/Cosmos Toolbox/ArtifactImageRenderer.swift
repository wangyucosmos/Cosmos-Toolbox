import SwiftUI
import Combine


struct ArtifactImagePreviewRenderer: ArtifactPreviewRenderer {
    let identifier: ArtifactPreviewRendererIdentifier = .image
    let presentationStyle: ArtifactPreviewPresentationStyle = .adaptiveCanvas
    let capabilities: ArtifactPreviewRendererCapabilities = .image

    func supports(input: ArtifactPreviewInput) -> Bool {
        input.mediaType.classification == .image
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
                ArtifactImageFailureView(
                    error: .unreadableFile,
                    retry: nil
                )
            )
        }

        return AnyView(
            ArtifactImagePreviewView(
                documentID: document.id,
                reference: reference
            )
        )
    }
}


enum ArtifactImageZoomState: Equatable {
    case fit
    case percentage(Double)

    static let minimum = 0.10
    static let maximum = 4.00
    static let stops: [Double] = [
        0.10, 0.25, 0.50, 0.75, 1.00,
        1.25, 1.50, 2.00, 3.00, 4.00
    ]

    var percentageValue: Double? {
        guard case .percentage(let value) = self else {
            return nil
        }
        return value
    }

    var displayName: String {
        switch self {
        case .fit:
            return "适应"
        case .percentage(let value):
            return "\(Int((value * 100).rounded()))%"
        }
    }

    mutating func showActualSize() {
        self = .percentage(1)
    }

    mutating func reset() {
        self = .fit
    }

    mutating func zoomIn() {
        let current = percentageValue ?? 1
        let next = Self.stops.first { $0 > current + 0.000_1 }
            ?? Self.maximum
        self = .percentage(min(Self.maximum, next))
    }

    mutating func zoomOut() {
        let current = percentageValue ?? 1
        let next = Self.stops.last { $0 < current - 0.000_1 }
            ?? Self.minimum
        self = .percentage(max(Self.minimum, next))
    }

    func scale(
        imagePixelSize: CGSize,
        availablePointSize: CGSize,
        displayScale: CGFloat
    ) -> CGFloat {
        let safeDisplayScale = max(displayScale, 1)
        let originalPointSize = CGSize(
            width: imagePixelSize.width / safeDisplayScale,
            height: imagePixelSize.height / safeDisplayScale
        )

        switch self {
        case .percentage(let value):
            return CGFloat(
                min(Self.maximum, max(Self.minimum, value))
            )
        case .fit:
            guard originalPointSize.width > 0,
                  originalPointSize.height > 0 else {
                return 1
            }
            let horizontal = availablePointSize.width
                / originalPointSize.width
            let vertical = availablePointSize.height
                / originalPointSize.height
            return min(1, max(0.01, min(horizontal, vertical)))
        }
    }
}


enum ArtifactImageLoadState {
    case idle
    case loading
    case ready(ArtifactImagePreviewResult)
    case failed(ArtifactImagePreviewError)
}


@MainActor
final class ArtifactImagePreviewViewModel: ObservableObject {
    let documentID: UUID
    let reference: ArtifactReviewLocalFileReference

    @Published private(set) var loadState: ArtifactImageLoadState = .idle
    @Published var zoomState: ArtifactImageZoomState = .fit

    private let loader: any ArtifactImagePreviewLoading
    private var generationToken = UUID()
    private var loadTask: Task<Void, Never>?

    init(
        documentID: UUID,
        reference: ArtifactReviewLocalFileReference,
        loader: (any ArtifactImagePreviewLoading)? = nil
    ) {
        self.documentID = documentID
        self.reference = reference
        self.loader = loader ?? ArtifactImagePreviewLoader()
    }

    func load() {
        loadTask?.cancel()
        let token = UUID()
        generationToken = token
        zoomState = .fit
        loadState = .loading

        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await loader.load(reference: reference)
                guard !Task.isCancelled,
                      generationToken == token else {
                    return
                }
                loadState = .ready(result)
            } catch let error as ArtifactImagePreviewError {
                guard !Task.isCancelled,
                      generationToken == token,
                      error != .cancelled else {
                    return
                }
                loadState = .failed(error)
            } catch {
                guard !Task.isCancelled,
                      generationToken == token else {
                    return
                }
                loadState = .failed(.corruptFile)
            }
        }
    }

    func cancel() {
        generationToken = UUID()
        loadTask?.cancel()
        loadTask = nil
    }

    deinit {
        loadTask?.cancel()
    }
}


private struct ArtifactImagePreviewView: View {
    @StateObject private var viewModel: ArtifactImagePreviewViewModel

    init(
        documentID: UUID,
        reference: ArtifactReviewLocalFileReference
    ) {
        _viewModel = StateObject(
            wrappedValue: ArtifactImagePreviewViewModel(
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
            case .ready(let result):
                readyView(result)
            case .failed(let error):
                ArtifactImageFailureView(
                    error: error,
                    retry: error.isRecoverable
                        ? { viewModel.load() }
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
            Text("正在安全加载图片")
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
        _ result: ArtifactImagePreviewResult
    ) -> some View {
        VStack(spacing: 0) {
            ArtifactImageToolbar(
                zoomState: $viewModel.zoomState,
                metadata: result.metadata
            )
            Divider()
            ArtifactImageCanvas(
                result: result,
                zoomState: viewModel.zoomState
            )
        }
    }
}


private struct ArtifactImageToolbar: View {
    @Binding var zoomState: ArtifactImageZoomState
    let metadata: ArtifactImagePreviewMetadata

    var body: some View {
        HStack(spacing: CosmosDesign.spacingS) {
            Button("适应窗口") {
                zoomState = .fit
            }
            .buttonStyle(.bordered)

            Button("100%") {
                zoomState.showActualSize()
            }
            .buttonStyle(.bordered)

            Button {
                zoomState.zoomOut()
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(.bordered)
            .help("缩小")

            Text(zoomState.displayName)
                .font(.caption.monospacedDigit())
                .frame(minWidth: 52)

            Button {
                zoomState.zoomIn()
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .buttonStyle(.bordered)
            .help("放大")

            Button {
                zoomState.reset()
            } label: {
                Label("重置", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)

            Spacer(minLength: CosmosDesign.spacingM)

            Text(metadataText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, CosmosDesign.spacingM)
        .padding(.vertical, CosmosDesign.spacingS)
    }

    private var metadataText: String {
        let byteCount = ByteCountFormatter.string(
            fromByteCount: metadata.fileSize,
            countStyle: .file
        )
        return "\(metadata.format.displayName) · "
            + "\(metadata.pixelWidth)×\(metadata.pixelHeight) · "
            + byteCount
    }
}


private struct ArtifactImageCanvas: View {
    let result: ArtifactImagePreviewResult
    let zoomState: ArtifactImageZoomState

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { proxy in
            let availableSize = CGSize(
                width: max(1, proxy.size.width - 48),
                height: max(1, proxy.size.height - 48)
            )
            let pixelSize = CGSize(
                width: result.metadata.pixelWidth,
                height: result.metadata.pixelHeight
            )
            let scale = zoomState.scale(
                imagePixelSize: pixelSize,
                availablePointSize: availableSize,
                displayScale: displayScale
            )
            let originalPointSize = CGSize(
                width: pixelSize.width / max(displayScale, 1),
                height: pixelSize.height / max(displayScale, 1)
            )
            let displayedSize = CGSize(
                width: originalPointSize.width * scale,
                height: originalPointSize.height * scale
            )

            ScrollView([.horizontal, .vertical]) {
                ZStack {
                    ArtifactImageCheckerboard()
                    Image(
                        decorative: result.image,
                        scale: 1,
                        orientation: .up
                    )
                    .resizable()
                    .interpolation(.high)
                }
                .frame(
                    width: displayedSize.width,
                    height: displayedSize.height
                )
                .clipShape(Rectangle())
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                .padding(24)
                .frame(
                    minWidth: proxy.size.width,
                    minHeight: proxy.size.height
                )
            }
            .background(Color.primary.opacity(0.028))
        }
    }
}


private struct ArtifactImageCheckerboard: View {
    private let squareSize: CGFloat = 12

    var body: some View {
        Canvas { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color.primary.opacity(0.035))
            )

            let columns = Int(ceil(size.width / squareSize))
            let rows = Int(ceil(size.height / squareSize))
            for row in 0..<rows {
                for column in 0..<columns where (row + column).isMultiple(of: 2) {
                    context.fill(
                        Path(
                            CGRect(
                                x: CGFloat(column) * squareSize,
                                y: CGFloat(row) * squareSize,
                                width: squareSize,
                                height: squareSize
                            )
                        ),
                        with: .color(Color.primary.opacity(0.075))
                    )
                }
            }
        }
    }
}


struct ArtifactImageFailureView: View {
    let error: ArtifactImagePreviewError
    let retry: (() -> Void)?

    var body: some View {
        VStack(spacing: CosmosDesign.spacingM) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.secondary)
            Text(error.title)
                .font(.headline)
            Text(error.message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)

            if let retry {
                Button("重新加载", action: retry)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(CosmosDesign.spacingXL)
    }
}
