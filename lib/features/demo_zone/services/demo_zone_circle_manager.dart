import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import '../utils/demo_zone_config.dart';

class DemoZoneCircleManager {
  Circle buildDemoCircle() {
    return Circle(
      circleId: const CircleId('demo_high_risk_zone'),
      center: const LatLng(DemoZoneConfig.demoZoneLat, DemoZoneConfig.demoZoneLng),
      radius: DemoZoneConfig.demoZoneRadius,
      fillColor: Colors.red.withOpacity(0.3),
      strokeColor: Colors.red,
      strokeWidth: 2,
    );
  }
}
