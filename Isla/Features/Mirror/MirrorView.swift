//
//  MirrorView.swift
//  Isla
//
//  A quick look at yourself before a call. The camera runs only while the
//  Mirror is on screen and video never leaves the Mac.
//

@preconcurrency import AVFoundation
import SwiftUI

@Observable
@MainActor
final class CameraMirror {
    static let shared = CameraMirror()

    private(set) var isRunning = false
    private(set) var status: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    private(set) var hasCamera = true
    var isFlipped = true

    @ObservationIgnored let session = AVCaptureSession()
    @ObservationIgnored private var configured = false
    @ObservationIgnored private let queue = DispatchQueue(label: "isla.mirror")

    private init() {}

    func start() {
        status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            run()
        case .notDetermined:
            Task {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                self.status = granted ? .authorized : .denied
                if granted { self.run() }
            }
        default:
            break
        }
    }

    func stop() {
        let session = self.session
        queue.async { if session.isRunning { session.stopRunning() } }
        isRunning = false
    }

    private func run() {
        if !configured {
            session.beginConfiguration()
            session.sessionPreset = .high
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(for: .video)
            guard let device, let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
                session.commitConfiguration()
                hasCamera = false
                return
            }
            session.addInput(input)
            session.commitConfiguration()
            configured = true
        }
        let session = self.session
        queue.async { if !session.isRunning { session.startRunning() } }
        isRunning = true
    }
}

struct MirrorView: View {
    @Bindable var model: NotchViewModel
    @Bindable private var mirror = CameraMirror.shared

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if mirror.status == .authorized && mirror.hasCamera {
                    CameraPreview(session: mirror.session, flipped: mirror.isFlipped)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(.white.opacity(0.12), lineWidth: 0.8)
                        }
                } else if !mirror.hasCamera {
                    NotchEmptyState(symbol: "video.slash", title: "No camera found")
                } else {
                    NotchEmptyState(symbol: "person.crop.square", title: "Check yourself before a call",
                                    message: "Isla needs camera access to show the Mirror. Video never leaves your Mac.",
                                    actionTitle: mirror.status == .notDetermined ? "Turn On Mirror" : "Open Camera Settings") {
                        if mirror.status == .notDetermined { mirror.start() } else { SystemSettings.open("Privacy_Camera") }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 8) {
                Button { mirror.isFlipped.toggle() } label: { Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill") }
                    .buttonStyle(NotchIconButtonStyle(size: 32))
                    .help(String(localized: "Flip"))
                Button { model.isPinned.toggle() } label: { Image(systemName: model.isPinned ? "pin.fill" : "pin") }
                    .buttonStyle(NotchIconButtonStyle(size: 32))
                    .help(String(localized: "Keep open"))
                Spacer()
                if let meeting = CalendarService.shared.upcoming.first(where: { $0.meetingURL != nil }), let url = meeting.meetingURL {
                    Button { NSWorkspace.shared.open(url) } label: { Image(systemName: "video.fill") }
                        .buttonStyle(NotchIconButtonStyle(size: 32, prominent: true))
                        .help(String(localized: "Join \(meeting.title)"))
                }
            }
        }
        .onAppear { mirror.start() }
        .onDisappear { mirror.stop() }
    }
}

struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession
    var flipped: Bool

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateNSView(_ nsView: PreviewView, context: Context) {
        nsView.previewLayer.connection?.automaticallyAdjustsVideoMirroring = false
        nsView.previewLayer.connection?.isVideoMirrored = flipped
    }

    final class PreviewView: NSView {
        let previewLayer = AVCaptureVideoPreviewLayer()

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            layer = CALayer()
            layer?.addSublayer(previewLayer)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

        override func layout() {
            super.layout()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            previewLayer.frame = bounds
            CATransaction.commit()
        }
    }
}
