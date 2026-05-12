import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_constants.dart';
import 'core/services/location_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/storage_service.dart';
import 'core/services/voice_service.dart';
import 'core/services/api_service.dart';
import 'core/services/background_monitor_service.dart';
import 'core/services/mongo_service.dart';
import 'core/services/socket_service.dart';
import 'core/services/zone_service.dart';
import 'core/models/zone_model.dart';
import 'features/home/presentation/providers/home_provider.dart';
import 'features/location/data/repositories/location_repository_impl.dart';
import 'features/location/presentation/providers/location_provider.dart';
import 'features/sos/data/repositories/sos_repository_impl.dart';
import 'features/sos/presentation/providers/sos_provider.dart';
import 'features/voice/presentation/providers/voice_provider.dart';
import 'features/contacts/data/repositories/contact_repository_impl.dart';
import 'features/contacts/presentation/providers/contact_provider.dart';
import 'features/community/data/repositories/community_repository_impl.dart';
import 'features/community/presentation/providers/community_provider.dart';
import 'features/community/presentation/providers/sentinel_provider.dart';
import 'features/feed/presentation/providers/feed_provider.dart';
import 'features/alerts/data/repositories/alert_repository_impl.dart';
import 'features/profile/data/repositories/profile_repository_impl.dart';
import 'features/security/data/repositories/security_repository_impl.dart';
import 'core/providers/ml_provider.dart';
import 'core/providers/location_permission_provider.dart';
import 'features/routes/presentation/providers/routes_provider.dart';
import 'features/routes/presentation/screens/routes_screen.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/splash/presentation/screens/splash_screen.dart';
import 'features/onboarding/presentation/screens/onboarding_screen.dart';
import 'features/contacts/presentation/screens/contact_setup_screen.dart';
import 'features/contacts/presentation/screens/manage_contacts_screen.dart';
import 'features/location/presentation/screens/location_screen.dart';
import 'screens/main_screen.dart';
import 'screens/sos_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/setup_permissions_screen.dart';
import 'screens/system_permissions_screen.dart';
import 'providers/providers.dart';
import 'providers/permission_provider.dart';
import 'shared/widgets/location_blocking_overlay.dart';
import 'core/app_theme.dart' as new_theme;

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ─── Core Services ───────────────────────────────────────────────────
        Provider<StorageService>(create: (_) => StorageService()..init()),
        Provider<LocationService>(
          create: (_) => LocationService(),
          dispose: (_, service) => service.dispose(),
        ),
        Provider<NotificationService>(create: (_) => NotificationService()..initialize()),
        Provider<VoiceService>(
          create: (_) => VoiceService(),
          dispose: (_, service) => service.dispose(),
        ),
        Provider<ApiService>(create: (_) => ApiService()),
        Provider<SocketService>(
          create: (_) => SocketService(),
          dispose: (_, service) => service.dispose(),
        ),
        Provider<BackgroundMonitorService>(create: (_) => BackgroundMonitorService()..initialize()),
        Provider<MongoService>(
          create: (_) => MongoService()..connect(),
          dispose: (_, service) => service.disconnect(),
        ),

        // ─── Repositories ────────────────────────────────────────────────────
        Provider<SOSRepositoryImpl>(
          create: (context) => SOSRepositoryImpl(
            storageService: context.read<StorageService>(),
            notificationService: context.read<NotificationService>(),
            mongoService: context.read<MongoService>(),
          ),
        ),
        Provider<LocationRepositoryImpl>(
          create: (context) => LocationRepositoryImpl(context.read<LocationService>()),
        ),
        Provider<ContactRepositoryImpl>(
          create: (context) => ContactRepositoryImpl(
            context.read<MongoService>(),
            context.read<StorageService>(),
          ),
        ),
        Provider<AlertRepositoryImpl>(
          create: (context) => AlertRepositoryImpl(
            context.read<MongoService>(),
            context.read<StorageService>(),
          ),
        ),
        Provider<ProfileRepositoryImpl>(
          create: (context) => ProfileRepositoryImpl(context.read<MongoService>()),
        ),
        Provider<SecurityRepositoryImpl>(
          create: (context) => SecurityRepositoryImpl(
            context.read<MongoService>(),
            context.read<StorageService>(),
          ),
        ),
        Provider<CommunityRepositoryImpl>(create: (_) => CommunityRepositoryImpl()),

        // ─── Logic Providers ─────────────────────────────────────────────────
        ChangeNotifierProvider<MLProvider>(create: (_) => MLProvider()),
        ChangeNotifierProvider<LocationPermissionProvider>(
          create: (context) => LocationPermissionProvider(context.read<LocationService>()),
        ),
        ChangeNotifierProxyProvider2<LocationService, NotificationService, ZoneService>(
          create: (context) => ZoneService(
            context.read<LocationService>(),
            context.read<NotificationService>(),
          )..initialize(),
          update: (_, locationService, notificationService, zoneService) =>
              zoneService ?? ZoneService(locationService, notificationService)..initialize(),
        ),
        ChangeNotifierProxyProvider3<LocationRepositoryImpl, LocationService, StorageService, LocationProvider>(
          create: (context) => LocationProvider(
            locationRepository: context.read<LocationRepositoryImpl>(),
            locationService: context.read<LocationService>(),
            storageService: context.read<StorageService>(),
          ),
          update: (_, locationRepo, locationService, storageService, locationProvider) =>
              locationProvider ?? LocationProvider(
                    locationRepository: locationRepo,
                    locationService: locationService,
                    storageService: storageService,
                  ),
        ),
        ChangeNotifierProxyProvider4<SOSRepositoryImpl, LocationService, LocationProvider, ContactRepositoryImpl, SOSProvider>(
          create: (context) => SOSProvider(
            sosRepository: context.read<SOSRepositoryImpl>(),
            locationService: context.read<LocationService>(),
            locationProvider: context.read<LocationProvider>(),
            contactRepository: context.read<ContactRepositoryImpl>(),
          ),
          update: (_, sosRepo, locationService, locationProvider, contactRepo, sosProvider) =>
              sosProvider ?? SOSProvider(
                    sosRepository: sosRepo,
                    locationService: locationService,
                    locationProvider: locationProvider,
                    contactRepository: contactRepo,
                  ),
        ),
        ChangeNotifierProxyProvider<ContactRepositoryImpl, ContactProvider>(
          create: (context) => ContactProvider(
            contactRepository: context.read<ContactRepositoryImpl>(),
          ),
          update: (_, contactRepo, contactProvider) =>
              contactProvider ?? ContactProvider(contactRepository: contactRepo),
        ),
        ChangeNotifierProvider<VoiceProvider>(
          create: (_) => VoiceProvider(),
        ),
        ChangeNotifierProvider<FeedProvider>(create: (_) => FeedProvider()),
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(context.read<StorageService>()),
        ),
        ChangeNotifierProvider<HomeProvider>(create: (_) => HomeProvider()),
        ChangeNotifierProvider<RoutesProvider>(create: (_) => RoutesProvider()),
        ChangeNotifierProxyProvider<SocketService, CommunityProvider>(
          create: (context) => CommunityProvider(
            communityRepository: context.read<CommunityRepositoryImpl>(),
            socketService: context.read<SocketService>(),
          ),
          update: (_, socket, provider) => provider ?? CommunityProvider(
            communityRepository: CommunityRepositoryImpl(),
            socketService: socket,
          ),
        ),
        ChangeNotifierProxyProvider<SocketService, SentinelProvider>(
          create: (context) => SentinelProvider(socketService: context.read<SocketService>()),
          update: (_, socket, provider) => provider ?? SentinelProvider(socketService: socket),
        ),

        // ─── New UI Providers (Bridged) ──────────────────────────────────────
        ChangeNotifierProvider<PermissionProvider>(create: (_) => PermissionProvider()),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<LanguageProvider>(create: (_) => LanguageProvider()),
        ChangeNotifierProxyProvider6<SOSProvider, LocationProvider, MLProvider, ZoneService, VoiceProvider, CommunityProvider, SafetyProvider>(
          create: (context) => SafetyProvider(),
          update: (context, sos, loc, ml, zone, voice, community, safety) {
            final provider = safety ?? SafetyProvider();
            provider.update(sos, loc, ml, zone, voice, community);
            return provider;
          },
        ),
      ],
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, themeProvider, langProvider, child) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: new_theme.buildLightTheme(),
            darkTheme: new_theme.buildDarkTheme(),
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const AppBootstrap(),
            routes: {
              '/splash': (context) => SplashScreen(),
              '/onboarding': (context) => OnboardingScreen(),
              '/login': (context) => const LoginScreen(),
              '/setup_contacts': (context) => const ContactSetupScreen(),
              '/manage_contacts': (context) => const ManageContactsScreen(),
              '/home': (context) => const MainScreen(),
              '/sos': (context) => SOSScreen(),
              '/location': (context) => LocationScreen(),
              '/routes': (context) => RoutesScreen(),
              '/alerts': (context) => AlertsScreen(),
              '/profile': (context) => ProfileScreen(),
              '/system_permissions': (context) => const SystemPermissionsScreen(),
            },
          );
        },
      ),
    );
  }
}

class AppBootstrap extends StatelessWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final safety = context.watch<SafetyProvider>();
    final sentinel = context.watch<SentinelProvider>();
    final zoneService = context.watch<ZoneService>();

    // Listen for zone alerts to show popup
    if (zoneService.alertTriggered && !zoneService.isAlertPopupShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Double check after frame to avoid race conditions
        if (zoneService.alertTriggered && !zoneService.isAlertPopupShowing) {
          zoneService.setAlertPopupShowing(true);
          _showZoneAlertPopup(context, zoneService);
        }
      });
    }

    return Stack(
      children: [
        _buildContent(context, auth, safety),
        const LocationBlockingOverlay(),
        if (sentinel.pendingPopup != null)
          _buildSentinelPopup(context, sentinel),
      ],
    );
  }

  void _showZoneAlertPopup(BuildContext context, ZoneService zoneService) {
    // Use the specific zone that triggered the alert, or fallback to current/nearest
    final zone = zoneService.triggeredZone ?? zoneService.currentZone ?? zoneService.nearestZone;
    if (zone == null) {
      zoneService.setAlertPopupShowing(false);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(
              zone.zoneType == ZoneType.critical ? Icons.dangerous_rounded : Icons.warning_rounded,
              color: zone.zoneType == ZoneType.critical ? Colors.red : Colors.orange,
            ),
            const SizedBox(width: 8),
            const Text('ZONE ALERT', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are entering/inside ${zone.name} (${zone.zoneLabel}).',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(zone.alertMessage),
            const SizedBox(height: 16),
            const Text(
              'Stay alert or send SOS if you feel unsafe.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              zoneService.stopSiren();
              zoneService.resetAlert();
              Navigator.pop(context);
            },
            child: const Text('DISMISS', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              zoneService.stopSiren();
              zoneService.resetAlert();
              Navigator.pop(context);
              context.read<SafetyProvider>().triggerSOSFlow();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('SEND SOS', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],

      ),
    );
  }

  Widget _buildSentinelPopup(BuildContext context, SentinelProvider sentinel) {
    final alert = sentinel.pendingPopup!;
    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emergency_share, color: Colors.red, size: 48),
              ),
              const SizedBox(height: 16),
              const Text(
                'SENTINEL ALERT',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${alert.name} needs help nearby!',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                'Distance: ${alert.distance.toStringAsFixed(2)} km away',
                style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => sentinel.dismissPopup(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.grey),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('DISMISS', style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        sentinel.dismissPopup();
                        Navigator.pushNamed(context, '/routes', arguments: {
                          'destLat': alert.latitude,
                          'destLon': alert.longitude,
                          'isSentinelTask': true,
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('NAVIGATE', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AuthProvider auth, SafetyProvider safety) {
    if (!safety.isAppReady) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF0D1B6E)),
              SizedBox(height: 16),
              Text('SHEild AI', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0D1B6E))),
            ],
          ),
        ),
      );
    }

    if (!auth.isAuthenticated) {
      return const LoginScreen();
    }

    final storage = context.read<StorageService>();

    final isSetupComplete = storage.getBool('@setup_complete') ?? false;
    final hasContacts = storage.getTrustedContacts().isNotEmpty;

    if (!isSetupComplete && !hasContacts) {
      return const ContactSetupScreen();
    }

    if (!safety.userProfile.isSetupComplete) {
      return const SetupPermissionsScreen();
    }

    return const MainScreen();
  }
}
