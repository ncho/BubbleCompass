import SwiftUI
import CoreLocation
import CoreMotion
import UIKit
import Combine

// MARK: - Compass Manager
class CompassManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let motionManager = CMMotionManager()
    
    @Published var currentLocation: CLLocation?
    @Published var heading: Double = 0
    @Published var bearingToTarget: Double = 0
    @Published var distance: Double = 0
    @Published var pitch: Double = 0
    @Published var roll: Double = 0
    
    private let haptic = UIImpactFeedbackGenerator(style: .medium)
    private var didFireHaptic = false
    
    let targetLocation = CLLocationCoordinate2D(latitude: 51.6043, longitude: -0.0664)
    
    override init() {
        super.init()
        setupLocation()
        setupMotion()
        haptic.prepare()
    }
    
    private func setupLocation() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }
    
    private func setupMotion() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.pitch = motion.attitude.pitch * 180 / .pi
            self.roll  = motion.attitude.roll  * 180 / .pi
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
        update()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        update()
    }
    
    private func update() {
        guard let current = currentLocation else { return }
        
        let lat1 = current.coordinate.latitude * .pi / 180
        let lon1 = current.coordinate.longitude * .pi / 180
        let lat2 = targetLocation.latitude * .pi / 180
        let lon2 = targetLocation.longitude * .pi / 180
        
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        
        let bearing = atan2(y, x) * 180 / .pi
        bearingToTarget = (bearing + 360).truncatingRemainder(dividingBy: 360)
        
        distance = current.distance(
            from: CLLocation(latitude: targetLocation.latitude,
                             longitude: targetLocation.longitude)
        )
    }
    
    var arrowRotation: Double {
        bearingToTarget - heading
    }
    
    var isAligned: Bool {
        abs((arrowRotation + 180).truncatingRemainder(dividingBy: 360) - 180) < 5
    }
    
    func handleHaptics() {
        if isAligned && !didFireHaptic {
            haptic.impactOccurred()
            didFireHaptic = true
        }
        if !isAligned { didFireHaptic = false }
    }
}

// MARK: - View
struct ContentView: View {
    @StateObject private var compass = CompassManager()
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.08, blue: 0.15),
                         Color(red: 0.1, green: 0.15, blue: 0.25)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Text("Tottenham Hotspur Stadium")
                    .font(.system(.title, design: .serif))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                ZStack {
                    // MARK: Glass body
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.97),
                                    Color.white.opacity(0.9),
                                    Color.white.opacity(0.85)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    // MARK: Inner refraction ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.6),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 6
                        )
                        .padding(12)
                    
                    // MARK: Specular highlight
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.7), .clear],
                                center: UnitPoint(
                                    x: 0.32 - compass.roll * 0.002,
                                    y: 0.28 - compass.pitch * 0.002
                                ),
                                startRadius: 0,
                                endRadius: 140
                            )
                        )
                    
                    // MARK: Beveled rim
                    Circle()
                        .stroke(
                            compass.isAligned ? Color.green : Color.white.opacity(0.85),
                            lineWidth: compass.isAligned ? 10 : 8
                        )
                        .shadow(color: .black.opacity(0.25), radius: 6, y: 4)
                    
                    // MARK: Compass markings
                    ForEach([0,45,90,135,180,225,270,315], id: \.self) { degree in
                        VStack(spacing: 4) {
                            Rectangle()
                                .fill(Color.black.opacity(0.7))
                                .frame(width: 3, height: degree % 90 == 0 ? 22 : 12)
                            
                            if degree % 90 == 0 {
                                Text(label(for: degree))
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.black.opacity(0.75))
                            }
                        }
                        .offset(y: -115)
                        .rotationEffect(.degrees(Double(degree)))
                    }
                    
                    // MARK: Arrow
                    Image(systemName: "arrow.up")
                        .font(.system(size: 80, weight: .bold))
                        .foregroundColor(.black.opacity(0.75))
                        .rotationEffect(.degrees(compass.arrowRotation))
                        .animation(.easeInOut(duration: 0.25), value: compass.arrowRotation)
                }
                .frame(width: 300, height: 300)
                .onChange(of: compass.arrowRotation) {
                    compass.handleHaptics()
                }
                
                infoPanel
                Spacer()
            }
            .padding(.top, 60)
        }
    }
    
    private var infoPanel: some View {
        VStack(spacing: 14) {
            row("Distance", format(compass.distance))
            row("Bearing", "\(Int(compass.bearingToTarget))°")
            row("Heading", "\(Int(compass.heading))°")
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text("\(title):")
            Spacer()
            Text(value)
        }
        .font(.system(.body, design: .monospaced))
        .foregroundColor(.black.opacity(0.8))
    }
    
    private func format(_ meters: Double) -> String {
        meters < 1000
        ? "\(Int(meters)) m"
        : String(format: "%.1f km", meters / 1000)
    }
    
    private func label(for degree: Int) -> String {
        switch degree {
        case 0: return "N"
        case 90: return "E"
        case 180: return "S"
        case 270: return "W"
        default: return ""
        }
    }
}
