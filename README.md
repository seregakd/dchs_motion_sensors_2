# motion_sensors

Flutter plugin for accessing the Android and iOS accelerometer, gyroscope, magnetometer and orientation sensors.
Updated version from https://github.com/zesage/motion_sensors

## Getting Started

To use this plugin, add `dchs_motion_sensors` as a [dependency in your pubspec.yaml
file](https://flutter.io/platform-plugins/).

```yaml
dependencies:
  motion_sensors: ^1.0.1
```

Import to your project.

``` dart
import 'package:dchs_motion_sensors/dchs_motion_sensors.dart';

motionSensors.magnetometer.listen((MagnetometerEvent event) {
    print(event);
});

```
