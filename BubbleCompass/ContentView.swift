//
//  ContentView.swift
//  BubbleCompass
//
//  Created by Nathan Cho on 12/23/25.
//

import SwiftUI
import CoreLocation
import CoreMotion
import Combine

// MARK: - Compass Manager
class CompassManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let motionManager = CMMotionManager()
    
    @Published var currentLocation: CLLocation?
    @Published var heading: Double = 0 // Device heading in degrees
    @Published var bearingToTarget: Double = 0 // Direction to target
    @Published var distance: Double = 0 // Distance to target in meters
    @Published var pitch: Double = 0 // Phone tilt forward/back
    @Published var roll: Double = 0 // Phone tilt left/right
    
    // Target: Tottenham Hotspur Stadium
    let targetLocation = CLLocationCoordinate2D(latitude: 51.6043, longitude: -0.0664)
    
    override init() {
        super.init()
        setupLocationManager()
        setupMotionManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }
    
    private func setupMotionManager() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.1
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
                guard let motion = motion, let self = self else { return }
                
                // Get pitch and roll from gyroscope
                // Pitch: forward/backward tilt (in radians)
                // Roll: left/right tilt (in radians)
                DispatchQueue.main.async {
                    self.pitch = motion.attitude.pitch * 180 / .pi
                    self.roll = motion.attitude.roll * 180 / .pi
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        updateBearingAndDistance()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        updateBearingAndDistance()
    }
    
    private func updateBearingAndDistance() {
        guard let current = currentLocation else { return }
        
        // Calculate bearing to target
        let lat1 = current.coordinate.latitude * .pi / 180
        let lon1 = current.coordinate.longitude * .pi / 180
        let lat2 = targetLocation.latitude * .pi / 180
        let lon2 = targetLocation.longitude * .pi / 180
        
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x) * 180 / .pi
        
        bearingToTarget = (bearing + 360).truncatingRemainder(dividingBy: 360)
        
        // Calculate distance
        let target = CLLocation(latitude: targetLocation.latitude, longitude: targetLocation.longitude)
        distance = current.distance(from: target)
    }
    
    // Arrow rotation angle (relative to device orientation)
    var arrowRotation: Double {
        let angle = bearingToTarget - heading
        return angle
    }
}

// MARK: - Main View
struct ContentView: View {
    @StateObject private var compass = CompassManager()
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Text("Tottenham Hotspur Stadium")
                    .font(.title)
                    .fontWeight(.bold)
                
                // 3D Bubble Compass
                ZStack {
                    // Outer shadow (moves with tilt for 3D effect)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.black.opacity(0.3), Color.clear],
                                center: .center,
                                startRadius: 120,
                                endRadius: 160
                            )
                        )
                        .frame(width: 320, height: 320)
                        .blur(radius: 20)
                        .offset(
                            x: compass.roll * 0.5,
                            y: 10 + compass.pitch * 0.5
                        )
                    
                    // Main bubble
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.9),
                                    Color.blue.opacity(0.3),
                                    Color.blue.opacity(0.6)
                                ],
                                center: UnitPoint(
                                    x: 0.4 - compass.roll * 0.002,
                                    y: 0.3 - compass.pitch * 0.002
                                ),
                                startRadius: 0,
                                endRadius: 150
                            )
                        )
                        .frame(width: 300, height: 300)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.5), lineWidth: 3)
                        )
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                        .rotation3DEffect(
                            .degrees(compass.pitch * 0.3),
                            axis: (x: 1, y: 0, z: 0)
                        )
                        .rotation3DEffect(
                            .degrees(compass.roll * 0.3),
                            axis: (x: 0, y: 1, z: 0)
                        )
                    
                    // Inner highlight (gives 3D effect, moves with tilt)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.6), Color.clear],
                                center: UnitPoint(
                                    x: 0.3 - compass.roll * 0.003,
                                    y: 0.25 - compass.pitch * 0.003
                                ),
                                startRadius: 0,
                                endRadius: 80
                            )
                        )
                        .frame(width: 250, height: 250)
                        .blur(radius: 5)
                    
                    // Arrow pointing to target (tilts with phone)
                    Image(systemName: "arrow.up")
                        .font(.system(size: 80, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.red, Color.orange],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 3)
                        .rotationEffect(.degrees(compass.arrowRotation))
                        .rotation3DEffect(
                            .degrees(compass.pitch * 0.2),
                            axis: (x: 1, y: 0, z: 0)
                        )
                        .rotation3DEffect(
                            .degrees(compass.roll * 0.2),
                            axis: (x: 0, y: 1, z: 0)
                        )
                        .animation(.easeInOut(duration: 0.3), value: compass.arrowRotation)
                }
                
                // Info display
                VStack(spacing: 16) {
                    HStack {
                        Text("Distance:")
                            .font(.headline)
                        Spacer()
                        Text(formatDistance(compass.distance))
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.bold)
                    }
                    
                    HStack {
                        Text("Bearing:")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(compass.bearingToTarget))°")
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.bold)
                    }
                    
                    HStack {
                        Text("Your heading:")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(compass.heading))°")
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.bold)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.9))
                .cornerRadius(15)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top, 60)
        }
    }
    
    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters)) m"
        } else {
            let km = meters / 1000
            return String(format: "%.1f km", km)
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
