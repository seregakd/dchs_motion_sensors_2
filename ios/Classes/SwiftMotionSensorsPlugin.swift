import Flutter
import UIKit
import CoreMotion

let GRAVITY = 9.8
let TYPE_ACCELEROMETER = 1
let TYPE_MAGNETIC_FIELD = 2
let TYPE_GYROSCOPE = 4
let TYPE_USER_ACCELEROMETER = 10
let TYPE_ORIENTATION = 11
let TYPE_ABSOLUTE_ORIENTATION = 15

public class SwiftMotionSensorsPlugin: NSObject, FlutterPlugin {
    private let accelerometerStreamHandler = AccelerometerStreamHandler()
    private let magnetometerStreamHandler = MagnetometerStreamHandler()
    private let gyroscopeStreamHandler = GyroscopeStreamHandler()
    private let userAccelerometerStreamHandler = UserAccelerometerStreamHandler()
    private let orientationStreamHandler = AttitudeStreamHandler(CMAttitudeReferenceFrame.xArbitraryCorrectedZVertical)
    private let absoluteOrientationStreamHandler = AttitudeStreamHandler(CMAttitudeReferenceFrame.xMagneticNorthZVertical)

    public static func register(with registrar: FlutterPluginRegistrar) {
        let METHOD_CHANNEL_NAME = "motion_sensors/method"
        let instance = SwiftMotionSensorsPlugin(registrar: registrar)
        let channel = FlutterMethodChannel(name: METHOD_CHANNEL_NAME, binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    init(registrar: FlutterPluginRegistrar) {
        super.init()

        let ACCELEROMETER_CHANNEL_NAME = "motion_sensors/accelerometer"
        let MAGNETOMETER_CHANNEL_NAME = "motion_sensors/magnetometer"
        let GYROSCOPE_CHANNEL_NAME = "motion_sensors/gyroscope"
        let USER_ACCELEROMETER_CHANNEL_NAME = "motion_sensors/user_accelerometer"
        let ORIENTATION_CHANNEL_NAME = "motion_sensors/orientation"
        let ABSOLUTE_ORIENTATION_CHANNEL_NAME = "motion_sensors/absolute_orientation"
        let SCREEN_ORIENTATION_CHANNEL_NAME = "motion_sensors/screen_orientation"

        let accelerometerChannel = FlutterEventChannel(name: ACCELEROMETER_CHANNEL_NAME, binaryMessenger: registrar.messenger())
        accelerometerChannel.setStreamHandler(accelerometerStreamHandler)

        let magnetometerChannel = FlutterEventChannel(name: MAGNETOMETER_CHANNEL_NAME, binaryMessenger: registrar.messenger())
        magnetometerChannel.setStreamHandler(magnetometerStreamHandler)

        let gyroscopeChannel = FlutterEventChannel(name: GYROSCOPE_CHANNEL_NAME, binaryMessenger: registrar.messenger())
        gyroscopeChannel.setStreamHandler(gyroscopeStreamHandler)

        let userAccelerometerChannel = FlutterEventChannel(name: USER_ACCELEROMETER_CHANNEL_NAME, binaryMessenger: registrar.messenger())
        userAccelerometerChannel.setStreamHandler(userAccelerometerStreamHandler)

        let orientationChannel = FlutterEventChannel(name: ORIENTATION_CHANNEL_NAME, binaryMessenger: registrar.messenger())
        orientationChannel.setStreamHandler(orientationStreamHandler)

        let absoluteOrientationChannel = FlutterEventChannel(name: ABSOLUTE_ORIENTATION_CHANNEL_NAME, binaryMessenger: registrar.messenger())
        absoluteOrientationChannel.setStreamHandler(absoluteOrientationStreamHandler)

        let screenOrientationChannel = FlutterEventChannel(name: SCREEN_ORIENTATION_CHANNEL_NAME, binaryMessenger: registrar.messenger())
        screenOrientationChannel.setStreamHandler(ScreenOrientationStreamHandler())
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isSensorAvailable":
            result(isSensorAvailable(call.arguments as! Int))
        case "setSensorUpdateInterval":
            let arguments = call.arguments as! NSDictionary
            setSensorUpdateInterval(arguments["sensorType"] as! Int, arguments["interval"] as! Int)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func isSensorAvailable(_ sensorType: Int) -> Bool {
        let motionManager = CMMotionManager()
        switch sensorType {
        case TYPE_ACCELEROMETER:
            return motionManager.isAccelerometerAvailable
        case TYPE_MAGNETIC_FIELD:
            return motionManager.isMagnetometerAvailable
        case TYPE_GYROSCOPE:
            return motionManager.isGyroAvailable
        case TYPE_USER_ACCELEROMETER:
            return motionManager.isDeviceMotionAvailable
        case TYPE_ORIENTATION:
            return motionManager.isDeviceMotionAvailable
        case TYPE_ABSOLUTE_ORIENTATION:
            return motionManager.isDeviceMotionAvailable
        default:
            return false
        }
    }

    public func setSensorUpdateInterval(_ sensorType: Int, _ interval: Int) {
        let timeInterval = TimeInterval(Double(interval) / 1000000.0)
        switch sensorType {
        case TYPE_ACCELEROMETER:
            accelerometerStreamHandler.setUpdateInterval(timeInterval)
        case TYPE_MAGNETIC_FIELD:
            magnetometerStreamHandler.setUpdateInterval(timeInterval)
        case TYPE_GYROSCOPE:
            gyroscopeStreamHandler.setUpdateInterval(timeInterval)
        case TYPE_USER_ACCELEROMETER:
            userAccelerometerStreamHandler.setUpdateInterval(timeInterval)
        case TYPE_ORIENTATION:
            orientationStreamHandler.setUpdateInterval(timeInterval)
        case TYPE_ABSOLUTE_ORIENTATION:
            absoluteOrientationStreamHandler.setUpdateInterval(timeInterval)
        default:
            break
        }
    }
}

class AccelerometerStreamHandler: NSObject, FlutterStreamHandler {
    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    private var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        if motionManager.isAccelerometerAvailable {
            motionManager.startAccelerometerUpdates(to: queue) { (data, error) in
                if let acceleration = data?.acceleration {
                    events([-acceleration.x * GRAVITY, -acceleration.y * GRAVITY, -acceleration.z * GRAVITY])
                }
            }
        }
        if motionManager.isAccelerometerAvailable {
            motionManager.startAccelerometerUpdates(to: queue) { [weak self] (data, error) in
                guard let self = self else { return }
                if let error = error {
                    self.eventSink?(FlutterError(code: "UNAVAILABLE", message: error.localizedDescription, details: nil))
                    return
                }
                if let data = data {
                    self.eventSink?([-data.acceleration.x * GRAVITY, -data.acceleration.y * GRAVITY, -data.acceleration.z * GRAVITY])
                }
            }
        } else {
            return FlutterError(code: "UNAVAILABLE", message: "Accelerometer not available", details: nil)
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        motionManager.stopAccelerometerUpdates()
        eventSink = nil
        return nil
    }

    func setUpdateInterval(_ interval: TimeInterval) {
        motionManager.accelerometerUpdateInterval = interval
    }

    deinit {
        motionManager.stopAccelerometerUpdates()
    }
}

class UserAccelerometerStreamHandler: NSObject, FlutterStreamHandler {
    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        if motionManager.isDeviceMotionAvailable {
            motionManager.startDeviceMotionUpdates(to: queue) { (data, error) in
                if let userAcceleration = data?.userAcceleration {
                    events([-userAcceleration.x * GRAVITY, -userAcceleration.y * GRAVITY, -userAcceleration.z * GRAVITY])
                }
            }
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        motionManager.stopDeviceMotionUpdates()
        return nil
    }

    func setUpdateInterval(_ interval: TimeInterval) {
        motionManager.deviceMotionUpdateInterval = interval
    }
}

class GyroscopeStreamHandler: NSObject, FlutterStreamHandler {
    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        if motionManager.isGyroAvailable {
            motionManager.startGyroUpdates(to: queue) { (data, error) in
                if let rotationRate = data?.rotationRate {
                    events([rotationRate.x, rotationRate.y, rotationRate.z])
                }
            }
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        motionManager.stopGyroUpdates()
        return nil
    }

    func setUpdateInterval(_ interval: TimeInterval) {
        motionManager.gyroUpdateInterval = interval
    }
}

class MagnetometerStreamHandler: NSObject, FlutterStreamHandler {
    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        if motionManager.isDeviceMotionAvailable {
            motionManager.showsDeviceMovementDisplay = true
            motionManager.startDeviceMotionUpdates(using: CMAttitudeReferenceFrame.xArbitraryCorrectedZVertical, to: queue) { (data, error) in
                if let magneticField = data?.magneticField.field {
                    events([magneticField.x, magneticField.y, magneticField.z])
                }
            }
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        motionManager.stopDeviceMotionUpdates()
        return nil
    }

    func setUpdateInterval(_ interval: TimeInterval) {
        motionManager.deviceMotionUpdateInterval = interval
    }
}

class AttitudeStreamHandler: NSObject, FlutterStreamHandler {
    private var attitudeReferenceFrame: CMAttitudeReferenceFrame
    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()

    init(_ referenceFrame: CMAttitudeReferenceFrame) {
        attitudeReferenceFrame = referenceFrame
        super.init()
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        if motionManager.isDeviceMotionAvailable {
            motionManager.showsDeviceMovementDisplay = true
            motionManager.startDeviceMotionUpdates(using: attitudeReferenceFrame, to: queue) { (data, error) in
                if let attitude = data?.attitude {
                    if self.attitudeReferenceFrame == .xMagneticNorthZVertical {
                        let yaw = (attitude.yaw + .pi + .pi / 2).truncatingRemainder(dividingBy: .pi * 2) - .pi
                        events([yaw, attitude.pitch, attitude.roll])
                    } else {
                        events([attitude.yaw, attitude.pitch, attitude.roll])
                    }
                }
            }
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        motionManager.stopDeviceMotionUpdates()
        return nil
    }

    func setUpdateInterval(_ interval: TimeInterval) {
        motionManager.deviceMotionUpdateInterval = interval
    }
}

class ScreenOrientationStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        NotificationCenter.default.addObserver(self, selector: #selector(orientationChanged), name: UIDevice.orientationDidChangeNotification, object: nil)
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        orientationChanged()
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.removeObserver(self)
        eventSink = nil
        return nil
    }

    @objc func orientationChanged() {
        guard let eventSink = eventSink else { return }
        switch UIApplication.shared.statusBarOrientation {
        case .portrait:
            eventSink(0.0)
        case .portraitUpsideDown:
            eventSink(180.0)
        case .landscapeLeft:
            eventSink(-90.0)
        case .landscapeRight:
            eventSink(90.0)
        default:
            eventSink(0.0)
        }
    }
}