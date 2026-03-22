import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/user_profile_service.dart';
import '../../services/remote_config_service.dart';
import '../../services/web_notification_service.dart';
import '../../services/analytics_service.dart';
import '../../models/dispatched_job.dart';
import 'web_login_screen.dart';
import 'web_access_denied_screen.dart';
import 'web_shell.dart';
import 'web_dashboard_screen.dart';
import 'web_create_job_screen.dart';
import 'web_schedule_screen.dart';
import 'web_settings_screen.dart';
import '../company/team_management_screen.dart';
import '../company/company_sites_screen.dart';
import '../company/company_customers_screen.dart';
import '../company/company_pdf_design_screen.dart';

/// Converts a [Stream] into a [Listenable] for GoRouter's refreshListenable.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

GoRouter createWebRouter() {
  return GoRouter(
    initialLocation: '/jobs',
    refreshListenable: GoRouterRefreshStream(
      FirebaseAuth.instance.authStateChanges(),
    ),
    redirect: (context, state) async {
      final user = FirebaseAuth.instance.currentUser;
      final isLoggedIn = user != null;
      final isLoginPage = state.matchedLocation == '/login';
      final isAccessDenied = state.matchedLocation == '/access-denied';

      if (!isLoggedIn && !isLoginPage) return '/login';
      if (isLoggedIn && isLoginPage) {
        // Load profile before redirecting to dashboard
        await UserProfileService.instance.loadProfile(user.uid);
        await RemoteConfigService.instance.refreshForUser(user.email);
        // Initialize web push notifications
        WebNotificationService.instance.initialize(
          UserProfileService.instance.companyId ?? '',
          user.uid,
        );
        AnalyticsService.instance.logWebLogin();
        return '/jobs';
      }

      // Check role/company for authenticated pages (not login or access-denied)
      if (isLoggedIn && !isLoginPage && !isAccessDenied) {
        final profile = UserProfileService.instance;
        // Ensure profile is loaded (e.g. on page refresh while logged in)
        if (profile.companyId == null) {
          await profile.loadProfile(user.uid);
          await RemoteConfigService.instance.refreshForUser(user.email);
          // Initialize web push on page refresh
          WebNotificationService.instance.initialize(
            profile.companyId ?? '',
            user.uid,
          );
        }
        if (!profile.hasCompany) return '/access-denied?reason=noCompany';
        if (!profile.isDispatcherOrAdmin) return '/access-denied?reason=engineerOnly';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const WebLoginScreen(),
      ),
      GoRoute(
        path: '/access-denied',
        builder: (context, state) {
          final reason = state.uri.queryParameters['reason'];
          return WebAccessDeniedScreen(
            reason: reason == 'noCompany'
                ? WebAccessDeniedReason.noCompany
                : WebAccessDeniedReason.engineerOnly,
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) => WebShell(child: child),
        routes: [
          GoRoute(
            path: '/jobs',
            builder: (context, state) => const WebDashboardScreen(),
          ),
          GoRoute(
            path: '/jobs/create',
            builder: (context, state) {
              final editJob = state.extra as DispatchedJob?;
              return WebCreateJobScreen(editJob: editJob);
            },
          ),
          GoRoute(
            path: '/jobs/:id',
            builder: (context, state) {
              final jobId = state.pathParameters['id'];
              return WebDashboardScreen(initialJobId: jobId);
            },
          ),
          GoRoute(
            path: '/schedule',
            builder: (context, state) => const WebScheduleScreen(),
          ),
          GoRoute(
            path: '/team',
            builder: (context, state) => const TeamManagementScreen(),
          ),
          GoRoute(
            path: '/sites',
            builder: (context, state) => CompanySitesScreen(companyId: UserProfileService.instance.companyId ?? ''),
          ),
          GoRoute(
            path: '/customers',
            builder: (context, state) => CompanyCustomersScreen(companyId: UserProfileService.instance.companyId ?? ''),
          ),
          GoRoute(
            path: '/branding',
            builder: (context, state) => CompanyPdfDesignScreen(companyId: UserProfileService.instance.companyId ?? ''),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const WebSettingsScreen(),
          ),
        ],
      ),
    ],
  );
}
