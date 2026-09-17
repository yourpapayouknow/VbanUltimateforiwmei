import Foundation

print("Testing Swift to Objective-C++ VBAN Bridge...")

let bridge = VbanBridge.shared()
guard bridge.startAll() else {
    fatalError("Failed to start VBAN Bridge")
}

let devs = bridge.getDevices()
print("Swift received \(devs.count) audio devices from CoreAudio:")
for d in devs.prefix(3) {
    print(" - Device: \(d.name) [UID: \(d.uid), In: \(d.inChannels)ch, Out: \(d.outChannels)ch]")
}

let snap = bridge.getSnapshot()
print("Initial snapshot:")
print(" - Active RX: \(snap.activeRx)")
print(" - Active TX: \(snap.activeTx)")
print(" - Audio Running: \(snap.audioRunning)")
print(" - Driver Installed: \(snap.driverInstalled)")

bridge.stopAll()
print("[PASS] Swift to Objective-C++ VBAN Bridge OK!")
