# SHEild AI - Women Safety App

A production-ready Flutter application for women's safety featuring SOS emergency system, live location tracking, voice trigger detection, and offline-first reliability.

## Features

- **SOS Emergency System**: One-tap SOS activation with automatic location sharing and notifications
- **Live Location Tracking**: Real-time GPS tracking with map visualization
- **Voice Trigger Detection**: Hands-free SOS activation using voice commands (help, SOS, emergency)
- **Offline-First Reliability**: Works without internet connection using local storage
- **Emergency Contacts**: Quick access to emergency numbers (Police: 100, Women Helpline: 1091, Ambulance: 102)
- **Clean Architecture**: Modular, scalable, and maintainable codebase
- **Modern UI**: Minimal design inspired by Uber, Google Maps, and WhatsApp

## Architecture

The app follows **Clean Architecture** with feature-based modular structure:

```
lib/
 ├── core/
 │    ├── constants/       # App constants and configuration
 │    ├── utils/           # Utility functions
 │    ├── theme/           # App theme, colors, and styling
 │    ├── services/        # Global services (storage, location, notification, voice)
 │    └── error/           # Error handling and failures
 │
 ├── features/
 │    ├── auth/            # Authentication (future-ready)
 │    ├── home/            # Home screen with SOS button
 │    ├── sos/             # SOS emergency feature
 │    │    ├── data/       # Data layer (repositories, data sources)
 │    │    ├── domain/     # Business logic (models, repositories)
 │    │    └── presentation/ # UI (screens, widgets, providers)
 │    ├── location/        # Location tracking feature
 │    └── voice/           # Voice trigger detection
 │
 ├── shared/
 │    ├── widgets/         # Reusable widgets
 │    └── models/          # Shared models
 │
 ├── app.dart              # App configuration with Provider setup
 └── main.dart             # Entry point
```

## Dependencies

### State Management
- `provider: ^6.1.1` - State management
- `equatable: ^2.0.5` - Value equality
- `dartz: ^0.10.1` - Functional programming (Either type)

### Location & Maps
- `geolocator: ^12.0.0` - Location services
- `google_maps_flutter: ^2.6.1` - Map integration

### Permissions
- `permission_handler: ^11.3.0` - Runtime permissions

### Offline Storage
- `shared_preferences: ^2.2.2` - Key-value storage
- `flutter_secure_storage: ^9.0.0` - Secure storage
- `sqflite: ^2.3.0` - SQLite database
- `path_provider: ^2.1.2` - File system paths

### Network & Connectivity
- `http: ^1.2.0` - HTTP requests
- `connectivity_plus: ^5.0.2` - Network connectivity

### Voice Detection
- `speech_to_text: ^6.6.0` - Speech recognition

### Notifications
- `flutter_local_notifications: ^16.3.2` - Local notifications

### Emergency Features
- `url_launcher: ^6.2.3` - Launch URLs and calls

### UI Components
- `flutter_svg: ^2.0.9` - SVG support
- `shimmer: ^3.0.0` - Loading shimmer effects

## Setup Instructions

### Prerequisites
- Flutter SDK (3.11.5 or higher)
- Dart SDK
- Android Studio / Xcode (for mobile development)
- Google Maps API Key (for map functionality)

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd sheild_ai
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure Google Maps API:
   - Add your Google Maps API key to `android/app/src/main/AndroidManifest.xml`
   - Add your Google Maps API key to `ios/Runner/Info.plist`

4. Configure Permissions:
   - Android: Permissions are already configured in `AndroidManifest.xml`
   - iOS: Add permissions in `ios/Runner/Info.plist`

5. Run the app:
```bash
flutter run
```

## Usage

### SOS Activation
1. Tap the large SOS button on the home screen
2. The app will:
   - Get your current GPS location
   - Send notifications to emergency contacts
   - Store SOS history locally
   - Show active SOS status

### Location Tracking
1. Navigate to the Location screen from home
2. Enable location tracking
3. View your real-time location on the map
4. Location updates are saved locally

### Voice Trigger
1. Enable voice trigger in settings (coming soon)
2. Say "help", "SOS", "emergency", "save me", or "danger"
3. The app will automatically activate SOS

### Emergency Numbers
Quick access to:
- Police: 100
- Women Helpline: 1091
- Ambulance: 102

## Security Features

- **Secure Storage**: Sensitive data encrypted using flutter_secure_storage
- **Local-First**: Emergency features work offline
- **Permission Management**: Runtime permission requests
- **Location Privacy**: Location data stored locally, not shared without consent

## Testing

Run tests:
```bash
flutter test
```

## License

This project is licensed under the MIT License.

## Contributing

Contributions are welcome! Please follow these steps:
1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## Support

For issues and questions, please open an issue on the repository.

## Future Enhancements

- [ ] User authentication
- [ ] Community alert system
- [ ] Real-time backend integration
- [ ] Video recording during SOS
- [ ] Fake call feature
- [ ] Safe route navigation
- [ ] Nearby safe places (police stations, hospitals)
- [ ] Multi-language support
