import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_constants.dart';
import 'core/services/location_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/storage_service.dart';
import 'core/services/voice_service.dart';
import 'core/services/hive_service.dart';
import 'core/services/sync_service.dart';
import 'core/services/api_service.dart';
import 'core/services/background_monitor_service.dart';
import 'core/services/mongo_service.dart';
import 'core/services/zone_service.dart';
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
import 'core/providers/ml_provider.dart';
import 'core/providers/location_permission_provider.dart';
import 'features/routes/presentation/providers/routes_provider.dart';
import 'features/routes/presentation/screens/routes_screen.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/splash/presentation/screens/splash_screen.dart';
import 'features/onboarding/presentation/screens/onboarding_screen.dart';
import 'features/location/presentation/screens/location_screen.dart';
import 'screens/main_screen.dart';
import 'screens/home_screen.dart';
import 'screens/sos_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/signin_screen.dart';
import 'screens/setup_permissions_screen.dart';
import 'providers/providers.dart';
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
        Provider<HiveService>(create: (_) => HiveService()),
        Provider<SyncService>(
          create: (_) => SyncService()..initialize(),
          dispose: (_, service) => service.dispose(),
        ),
        Provider<ApiService>(create: (_) => ApiService()),
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
            hiveService: context.read<HiveService>(),
            syncService: context.read<SyncService>(),
          ),
        ),
        Provider<LocationRepositoryImpl>(
          create: (context) => LocationRepositoryImpl(context.read<LocationService>()),
        ),
        Provider<ContactRepositoryImpl>(
          create: (context) => ContactRepositoryImpl(context.read<HiveService>()),
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
        ChangeNotifierProxyProvider2<LocationRepositoryImpl, LocationService, LocationProvider>(
          create: (context) => LocationProvider(
            locationRepository: context.read<LocationRepositoryImpl>(),
            locationService: context.read<LocationService>(),
          ),
          update: (_, locationRepo, locationService, locationProvider) =>
              locationProvider ?? LocationProvider(
                    locationRepository: locationRepo,
                    locationService: locationService,
                  ),
        ),
        ChangeNotifierProxyProvider3<SOSRepositoryImpl, LocationService, LocationProvider, SOSProvider>(
          create: (context) => SOSProvider(
            sosRepository: context.read<SOSRepositoryImpl>(),
            locationService: context.read<LocationService>(),
            locationProvider: context.read<LocationProvider>(),
          ),
          update: (_, sosRepo, locationService, locationProvider, sosProvider) =>
              sosProvider ?? SOSProvider(
                    sosRepository: sosRepo,
                    locationService: locationService,
                    locationProvider: locationProvider,
                  ),
        ),
        ChangeNotifierProxyProvider<ContactRepositoryImpl, ContactProvider>(
          create: (context) => ContactProvider(
            contactRepository: context.read<ContactRepositoryImpl>(),
          ),
          update: (_, contactRepo, contactProvider) =>
              contactProvider ?? ContactProvider(contactRepository: contactRepo),
        ),
        ChangeNotifierProxyProvider2<VoiceService, SOSProvider, VoiceProvider>(
          create: (context) => VoiceProvider(voiceService: context.read<VoiceService>())..initialize(),
          update: (_, voiceService, sosProvider, voiceProvider) {
            final provider = voiceProvider ?? VoiceProvider(voiceService: voiceService)..initialize();
            provider.updateSOSProvider(sosProvider);
            return provider;
          },
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(context.read<StorageService>()),
        ),
        ChangeNotifierProvider<HomeProvider>(create: (_) => HomeProvider()),
        ChangeNotifierProvider<RoutesProvider>(create: (_) => RoutesProvider()),
        ChangeNotifierProvider<CommunityProvider>(
          create: (context) => CommunityProvider(
            communityRepository: context.read<CommunityRepositoryImpl>(),
          )..loadNearbyReports(latitude: 22.7196, longitude: 75.8577),
        ),

        // ─── New UI Providers (Bridged) ──────────────────────────────────────
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<LanguageProvider>(create: (_) => LanguageProvider()),
        ChangeNotifierProxyProvider5<SOSProvider, LocationProvider, MLProvider, ZoneService, VoiceProvider, SafetyProvider>(
          create: (context) => SafetyProvider(),
          update: (context, sos, loc, ml, zone, voice, safety) {
            final provider = safety ?? SafetyProvider();
            provider.update(sos, loc, ml, zone, voice);
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
              '/home': (context) => const MainScreen(),
              '/sos': (context) => SOSScreen(),
              '/location': (context) => LocationScreen(),
              '/routes': (context) => RoutesScreen(),
              '/alerts': (context) => AlertsScreen(),
              '/profile': (context) => ProfileScreen(),
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

    if (!safety.userProfile.isSetupComplete) {
      return const SetupPermissionsScreen();
    }

    return const MainScreen();
  }
}
