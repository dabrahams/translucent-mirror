import SwiftUI
@preconcurrency import AVFoundation
import AppKit

@main
struct MirrorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate.mirrorController)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var statusItem: NSStatusItem?
    var mirrorController = MirrorController()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide the app from the dock
        NSApp.setActivationPolicy(.accessory)
        
        // Create status bar item
        setupStatusBarItem()
        
        // Hide the regular menu bar for this app
        NSApp.mainMenu = NSMenu()
    }
    
    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // Use a more visible text/emoji for the menu bar
            button.title = "Mirror"
            button.toolTip = "Translucent Mirror"
            print("Status bar button created with title: \(button.title)")
        }
        
        let menu = NSMenu()
        menu.title = "Translucent Mirror"
        
        // Mirror toggle
        let toggleItem = NSMenuItem(title: mirrorController.isEnabled ? "Turn Off Mirror" : "Turn On Mirror", 
                                   action: #selector(toggleMirror), 
                                   keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Opacity slider menu item
        let opacityMenuItem = NSMenuItem()
        opacityMenuItem.title = "Opacity"
        let opacityView = OpacitySliderView(mirrorController: mirrorController)
        let hostingView = NSHostingView(rootView: opacityView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 200, height: 50)
        opacityMenuItem.view = hostingView
        menu.addItem(opacityMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit item
        let quitItem = NSMenuItem(title: "Quit Translucent Mirror", 
                                 action: #selector(NSApplication.terminate(_:)), 
                                 keyEquivalent: "q")
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
        
        print("Status bar item setup complete. Menu items: \(menu.items.count)")
        
        // Update menu when mirror state changes
        mirrorController.onStateChange = { [weak self] in
            self?.updateStatusBarMenu()
        }
    }
    
    @objc private func toggleMirror() {
        mirrorController.toggle()
    }
    
    private func updateStatusBarMenu() {
        guard let menu = statusItem?.menu else { return }
        if let toggleItem = menu.item(at: 0) {
            toggleItem.title = mirrorController.isEnabled ? "Turn Off Mirror" : "Turn On Mirror"
        }
    }
}

class MirrorController: ObservableObject {
    @Published var isEnabled: Bool = true
    @Published var opacity: Double = 0.7
    var onStateChange: (() -> Void)?
    
    func toggle() {
        isEnabled.toggle()
        onStateChange?()
    }
}

struct OpacitySliderView: View {
    @ObservedObject var mirrorController: MirrorController
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Opacity:")
                Spacer()
                Text("\(Int(mirrorController.opacity * 100))%")
            }
            .font(.caption)
            
            Slider(value: $mirrorController.opacity, in: 0.1...1.0)
                .controlSize(.mini)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct ContentView: View {
    @EnvironmentObject var mirrorController: MirrorController
    @StateObject private var cameraManager = CameraManager()
    
    var body: some View {
        Group {
            if mirrorController.isEnabled {
                // Camera view with mirror effect - no UI elements
                CameraView(cameraManager: cameraManager)
                    .scaleEffect(x: -1, y: 1) // Mirror horizontally
                    .opacity(mirrorController.opacity)
            } else {
                // Empty transparent view when disabled
                Color.clear
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
                // Make window translucent and click-through
                window.isOpaque = false
                window.backgroundColor = NSColor.clear
                window.hasShadow = false
                
                // Make window ignore mouse events (click-through)
                window.ignoresMouseEvents = true
                
                // Always on top
                window.level = .floating
                
                // Maximize window to cover entire screen
                if let screen = NSScreen.main {
                    let screenFrame = screen.frame // Use full screen frame, not visibleFrame
                    window.setFrame(screenFrame, display: true)
                }
                
                // Allow window to appear on all spaces and stay on top
                window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
                
                // Remove window from window list (Cmd+Tab, Mission Control, etc.)
                window.isExcludedFromWindowsMenu = true
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
