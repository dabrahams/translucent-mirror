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
        
        // Adjustable mode toggle
        let adjustableItem = NSMenuItem(title: mirrorController.isAdjustable ? "Lock Position & Size" : "Unlock Position & Size", 
                                       action: #selector(toggleAdjustableMode), 
                                       keyEquivalent: "")
        adjustableItem.target = self
        menu.addItem(adjustableItem)
        
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
        
        // Update menu when adjustable mode changes
        mirrorController.onModeChange = { [weak self] in
            self?.updateStatusBarMenu()
        }
    }
    
    @objc private func toggleMirror() {
        mirrorController.toggle()
    }
    
    @objc private func toggleAdjustableMode() {
        mirrorController.toggleAdjustableMode()
    }
    
    private func updateStatusBarMenu() {
        guard let menu = statusItem?.menu else { return }
        if let toggleItem = menu.item(at: 0) {
            toggleItem.title = mirrorController.isEnabled ? "Turn Off Mirror" : "Turn On Mirror"
        }
        if let adjustableItem = menu.item(at: 2) { // Item at index 2 (after separator)
            adjustableItem.title = mirrorController.isAdjustable ? "Lock Position & Size" : "Unlock Position & Size"
        }
    }
}

class MirrorController: ObservableObject {
    @Published var isEnabled: Bool = true
    @Published var opacity: Double = 0.7
    @Published var isAdjustable: Bool = false
    var onStateChange: (() -> Void)?
    var onModeChange: (() -> Void)?
    
    // Store the desired locked mode frame (starts as full primary screen)
    var lockedModeFrame: NSRect = {
        return NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
    }()
    
    func toggle() {
        isEnabled.toggle()
        onStateChange?()
    }
    
    func toggleAdjustableMode() {
        isAdjustable.toggle()
        onModeChange?()
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
        .onChange(of: mirrorController.isAdjustable) { _ in
            // Delay the window configuration to avoid layout recursion
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let window = NSApplication.shared.windows.first {
                    self.configureWindowForCurrentMode(window)
                }
            }
        }
    }
    
    private func setupWindow() {
        // Delay initial setup to ensure SwiftUI layout is complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if let window = NSApplication.shared.windows.first {
                self.configureWindowForCurrentMode(window)
            }
        }
    }
    
    private func configureWindowForCurrentMode(_ window: NSWindow) {
        print("Configuring window for mode: \(mirrorController.isAdjustable ? "adjustable" : "locked")")
        
        // Prevent configuration during layout operations
        guard !window.inLiveResize else {
            print("Skipping configuration during live resize")
            return
        }
        
        // Basic translucent properties always apply
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.hasShadow = mirrorController.isAdjustable // Show shadow only in adjustable mode
        
        if mirrorController.isAdjustable {
            // Adjustable mode: resizable, draggable, visible frame
            window.ignoresMouseEvents = false
            window.level = .normal
            window.styleMask = [.titled, .resizable, .closable, .miniaturizable]
            window.title = "Translucent Mirror"
            window.isMovable = true
            window.collectionBehavior = [.canJoinAllSpaces]
            window.isExcludedFromWindowsMenu = false
            
            // Set window to the stored locked mode frame (so user can adjust it)
            window.setFrame(mirrorController.lockedModeFrame, display: true)
            
            // Make sure window is visible and ordered front
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        } else {
            // Store the current window frame before switching to locked mode
            mirrorController.lockedModeFrame = window.frame
            print("Stored frame for locked mode: \(mirrorController.lockedModeFrame)")
            
            // Locked mode: click-through, always on top, use stored frame
            window.ignoresMouseEvents = true
            window.level = .floating
            window.styleMask = [.borderless]
            window.isMovable = false
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            window.isExcludedFromWindowsMenu = true
            
            // Use the stored frame (which was just updated above)
            window.setFrame(mirrorController.lockedModeFrame, display: true)
            print("Set locked mode frame: \(mirrorController.lockedModeFrame)")
            
            // Ensure window remains visible in locked mode too
            window.orderFrontRegardless()
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
    private var isConfigured = false
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    
    override init() {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        super.init()
        configureSession()
    }
    
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            if !self.captureSession.isRunning && self.isConfigured {
                self.captureSession.startRunning()
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
    }
    
    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Don't configure if already configured
            if self.isConfigured {
                return
            }
            
            self.captureSession.beginConfiguration()
            
            // Configure session preset
            if self.captureSession.canSetSessionPreset(.high) {
                self.captureSession.sessionPreset = .high
            }
            
            // Add video input
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) ?? AVCaptureDevice.default(for: .video) else {
                print("Failed to get video device")
                self.captureSession.commitConfiguration()
                return
            }
            
            do {
                let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
                
                if self.captureSession.canAddInput(videoDeviceInput) {
                    self.captureSession.addInput(videoDeviceInput)
                    self.videoDeviceInput = videoDeviceInput
                } else {
                    print("Couldn't add video device input to the session")
                }
            } catch {
                print("Couldn't create video device input: \(error)")
            }
            
            self.captureSession.commitConfiguration()
            self.isConfigured = true
        }
    }
}
