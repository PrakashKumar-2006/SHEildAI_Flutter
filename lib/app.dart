import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_constants.dart';
import 'core/services/location_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/storage_service.dart';
import 'core/services/voice_service.dart';
import 'core/theme/app_theme.dart';
import 'features/home/presentation/providers/home_provider.dart';
import 'features/location/data/repositories/location_repository_impl.dart';
import 'features/location/presentation/providers/location_provider.dart';
import 'features/location/presentation/screens/location_screen.dart';
import 'features/sos/data/repositories/sos_repository_impl.dart';
import 'features/sos/presentation/providers/sos_provider.dart';
import 'features/sos/presentation/screens/sos_screen.dart';
import 'features/voice/presentation/providers/voice_provider.dart';
import 'features/splash/presentation/screens/splash_screen.dart';
import 'features/onboarding/presentation/screens/onboarding_screen.dart';
import 'shared/widgets/main_navigation.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Services
        Provider<StorageService>(
          create: (_) => StorageService()..init(),
        ),
        Provider<LocationService>(
          create: (_) => LocationService(),
          dispose: (_, service) => service.dispose(),
        ),
        Provider<NotificationService>(
          create: (_) => NotificationService()..initialize(),
        ),
        Provider<VoiceService>(
          create: (_) => VoiceService(),
          dispose: (_, service) => service.dispose(),
        ),

        // Repositories
        Provider<SOSRepositoryImpl>(
          create: (context) => SOSRepositoryImpl(
            storageService: context.read<StorageService>(),
            notificationService: context.read<NotificationService>(),
          ),
        ),
        Provider<LocationRepositoryImpl>(
          create: (context) => LocationRepositoryImpl(
            context.read<LocationService>(),
          ),
        ),

        // Providers
        ChangeNotifierProxyProvider2<SOSRepositoryImpl, LocationService, SOSProvider>(
          create: (context) => SOSProvider(
            sosRepository: context.read<SOSRepositoryImpl>(),
            locationService: context.read<LocationService>(),
          ),
          update: (_, sosRepo, locationService, sosProvider) =>
              sosProvider ?? SOSProvider(
                    sosRepository: sosRepo,
                    locationService: locationService,
                  ),
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
        ChangeNotifierProxyProvider<VoiceService, VoiceProvider>(
          create: (context) => VoiceProvider(
            voiceService: context.read<VoiceService>(),
          )..initialize(),
          update: (_, voiceService, voiceProvider) =>
              voiceProvider ?? VoiceProvider(voiceService: voiceService)..initialize(),
        ),
        ChangeNotifierProvider<HomeProvider>(
          create: (_) => HomeProvider(),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        initialRoute: '/splash',
        routes: {
          '/splash': (context) => const SplashScreen(),
          '/onboarding': (context) => const OnboardingScreen(),
          '/home': (context) => const MainNavigation(),
          '/sos': (context) => const SOSScreen(),
          '/location': (context) => const LocationScreen(),
        },
      ),
    );
  }
}
