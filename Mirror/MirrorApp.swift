import SwiftUI
@preconcurrency import AVFoundation
import AppKit

@main
struct MirrorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

struct ContentView: View {
    @State private var opacity: Double = 0.7
    @StateObject private var cameraManager = CameraManager()
    
    var body: some View {
        ZStack {
            // Camera view with mirror effect
            CameraView(cameraManager: cameraManager)
                .scaleEffect(x: -1, y: 1) // Mirror horizontally
                .opacity(opacity)
            
            // Opacity slider
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack {
                        Text("Opacity")
                            .foregroundColor(.white)
                            .font(.caption)
                        Slider(value: $opacity, in: 0.1...1.0)
                            .frame(width: 200)
                            .accentColor(.white)
                    }
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(10)
                    .padding()
                }
            }
        }
        .background(Color.clear)
        .onAppear {
            setupWindow()
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
    
    private func setupWindow() {
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                // Make window translucent
                window.isOpaque = false
                window.backgroundColor = NSColor.clear
                window.hasShadow = false
                
                // Maximize window (but not fullscreen)
                if let screen = NSScreen.main {
                    let screenFrame = screen.visibleFrame
                    window.setFrame(screenFrame, display: true)
                }
                
                // Allow window to be behind other windows when not active
                window.level = .normal
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            }
        }
    }
}

struct CameraView: NSViewRepresentable {
    let cameraManager: CameraManager
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let previewLayer = cameraManager.previewLayer
        previewLayer.frame = view.bounds
        previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer = previewLayer
        view.wantsLayer = true
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Update the frame when the view size changes
        cameraManager.previewLayer.frame = nsView.bounds
    }
}

class CameraManager: NSObject, ObservableObject {
    private let captureSession = AVCaptureSession()
    let previewLayer: AVCaptureVideoPreviewLayer
    private var videoDeviceInput: AVCaptureDeviceInput?
    
    override init() {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        super.init()
    }
    
    func startSession() {
        guard !captureSession.isRunning else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.configureSession()
            self?.captureSession.startRunning()
        }
    }
    
    func stopSession() {
        guard captureSession.isRunning else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }
    
    private func configureSession() {
        captureSession.beginConfiguration()
        
        // Configure session preset
        if captureSession.canSetSessionPreset(.high) {
            captureSession.sessionPreset = .high
        }
        
        // Add video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) ?? AVCaptureDevice.default(for: .video) else {
            print("Failed to get video device")
            captureSession.commitConfiguration()
            return
        }
        
        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if captureSession.canAddInput(videoDeviceInput) {
                captureSession.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
            } else {
                print("Couldn't add video device input to the session")
            }
        } catch {
            print("Couldn't create video device input: \(error)")
        }
        
        captureSession.commitConfiguration()
    }
}
