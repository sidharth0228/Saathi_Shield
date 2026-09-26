import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/otp_verify_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/profile/medical_profile_screen.dart';
import '../features/contacts/emergency_contacts_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/tracking/sos_tracking_screen.dart';
import '../features/tracking/public_tracking_screen.dart';
import '../features/travel/travel_mode_screen.dart';
import '../features/community/community_dashboard_screen.dart';
import '../features/community/responder_dispatch_screen.dart';
import '../features/notifications/notification_center_screen.dart';
import '../features/safety/disaster_alerts_screen.dart';
import '../features/demo/demo_controller_screen.dart';
import '../providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Watch auth state changes to force navigation redirects
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final subloc = state.matchedLocation;
      
      // If we are initializing or loading, keep on splash screen
      if (authState is AuthInitial || authState is AuthLoading) {
        return subloc == '/' ? null : '/';
      }

      // If unauthorized, lock pages to login/register unless already there or accessing public tracking
      if (authState is Unauthenticated) {
        if (subloc == '/login' || subloc == '/register' || subloc.startsWith('/public-track/')) {
          return null;
        }
        return '/login';
      }

      // If registration/login OTP verification is required, force redirect
      if (authState is OTPVerificationRequired) {
        if (subloc == '/verify-otp') {
          return null;
        }
        return '/verify-otp';
      }

      // If authorized, prevent login/register page visits
      if (authState is Authenticated) {
        if (subloc == '/' || subloc == '/login' || subloc == '/register' || subloc == '/verify-otp') {
          return '/dashboard';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/verify-otp',
        builder: (context, state) {
          final phone = authState is OTPVerificationRequired ? authState.phone : '';
          return OTPVerifyScreen(phone: phone);
        },
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/medical-profile',
        builder: (context, state) => const MedicalProfileScreen(),
      ),
      GoRoute(
        path: '/emergency-contacts',
        builder: (context, state) => const EmergencyContactsScreen(),
      ),
      GoRoute(
        path: '/sos-tracking/:secureToken',
        builder: (context, state) => SosTrackingScreen(
          secureToken: state.pathParameters['secureToken'] ?? '',
        ),
      ),
      GoRoute(
        path: '/public-track/:secureToken',
        builder: (context, state) => PublicTrackingScreen(
          secureToken: state.pathParameters['secureToken'] ?? '',
        ),
      ),
      GoRoute(
        path: '/travel-mode',
        builder: (context, state) => const TravelModeScreen(),
      ),
      GoRoute(
        path: '/community-dashboard',
        builder: (context, state) => const CommunityDashboardScreen(),
      ),
      GoRoute(
        path: '/responder-dispatch',
        builder: (context, state) => const ResponderDispatchScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationCenterScreen(),
      ),
      GoRoute(
        path: '/disaster-alerts',
        builder: (context, state) => const DisasterAlertsScreen(),
      ),
      GoRoute(
        path: '/demo-controller',
        builder: (context, state) => const DemoControllerScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Navigation error: ${state.error}'),
      ),
    ),
  );
});
