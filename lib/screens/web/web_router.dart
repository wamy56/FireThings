import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/permission.dart';
import '../../services/user_profile_service.dart';
import '../../services/remote_config_service.dart';
import '../../services/web_notification_service.dart';
import '../../services/analytics_service.dart';
import '../../models/asset.dart';
import '../../models/dispatched_job.dart';
import '../../models/company_site.dart';
import '../../models/floor_plan.dart';
import '../../services/company_service.dart';
import '../../services/floor_plan_service.dart';
import '../assets/site_asset_register_screen.dart';
import '../assets/add_edit_asset_screen.dart';
import '../assets/asset_detail_screen.dart';
import '../assets/asset_type_config_screen.dart';
import '../assets/compliance_report_screen.dart';
import '../bs5839/bs5839_system_config_screen.dart';
import '../bs5839/visit_history_screen.dart';
import '../bs5839/visit_detail_screen.dart';
import '../bs5839/variations_register_screen.dart';
import '../bs5839/competency_screen.dart';
import '../bs5839/logbook_screen.dart';
import '../floor_plans/floor_plan_list_screen.dart';
import '../floor_plans/upload_floor_plan_screen.dart';
import '../floor_plans/interactive_floor_plan_screen.dart';
import 'web_login_screen.dart';
import 'web_access_denied_screen.dart';
import 'web_shell.dart';
import 'web_dashboard_screen.dart';
import 'web_create_job_screen.dart';
import 'web_schedule_screen.dart';
import 'web_settings_screen.dart';
import 'web_quotes_screen.dart';
import 'web_create_quote_screen.dart';
import 'web_invoices_screen.dart';
import 'web_create_invoice_screen.dart';
import '../company/team_management_screen.dart';
import '../company/company_sites_screen.dart';
import '../company/company_customers_screen.dart';
import 'web_branding_screen.dart';
import '../../models/quote.dart';
import '../../models/invoice.dart';

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
    refreshListenable: Listenable.merge([
      GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
      UserProfileService.instance,
    ]),
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
        if (!profile.hasPermission(AppPermission.webPortalAccess)) return '/access-denied?reason=noWebAccess';
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
            path: '/team/competency',
            redirect: (context, state) {
              if (!RemoteConfigService.instance.bs5839CompetencyTrackingEnabled) {
                return '/team';
              }
              return null;
            },
            builder: (context, state) => const CompetencyScreen(),
          ),
          GoRoute(
            path: '/sites',
            builder: (context, state) => CompanySitesScreen(companyId: UserProfileService.instance.companyId ?? ''),
          ),
          GoRoute(
            path: '/sites/:siteId/assets',
            redirect: (context, state) {
              if (!RemoteConfigService.instance.assetRegisterEnabled) {
                return '/sites';
              }
              return null;
            },
            builder: (context, state) {
              final companyId = UserProfileService.instance.companyId ?? '';
              final basePath = 'companies/$companyId';
              final siteId = state.pathParameters['siteId']!;
              final extra = state.extra is Map<String, dynamic> ? state.extra as Map<String, dynamic> : null;
              return _SiteDataLoader(
                companyId: companyId,
                siteId: siteId,
                cachedName: extra?['siteName'] as String?,
                cachedAddress: extra?['siteAddress'] as String?,
                builder: (site) => SiteAssetRegisterScreen(
                  siteId: siteId,
                  siteName: site?.name ?? 'Site',
                  siteAddress: site?.address ?? '',
                  basePath: basePath,
                ),
              );
            },
            routes: [
              GoRoute(
                path: 'add',
                builder: (context, state) {
                  final companyId = UserProfileService.instance.companyId ?? '';
                  final basePath = 'companies/$companyId';
                  final siteId = state.pathParameters['siteId']!;
                  return AddEditAssetScreen(
                    basePath: basePath,
                    siteId: siteId,
                  );
                },
              ),
              GoRoute(
                path: 'types',
                builder: (context, state) {
                  final companyId = UserProfileService.instance.companyId ?? '';
                  final basePath = 'companies/$companyId';
                  final siteId = state.pathParameters['siteId']!;
                  return AssetTypeConfigScreen(basePath: basePath, siteId: siteId);
                },
              ),
              GoRoute(
                path: 'report',
                builder: (context, state) {
                  final companyId = UserProfileService.instance.companyId ?? '';
                  final basePath = 'companies/$companyId';
                  final siteId = state.pathParameters['siteId']!;
                  final extra = state.extra is Map<String, dynamic> ? state.extra as Map<String, dynamic> : null;
                  return _SiteDataLoader(
                    companyId: companyId,
                    siteId: siteId,
                    cachedName: extra?['siteName'] as String?,
                    cachedAddress: extra?['siteAddress'] as String?,
                    builder: (site) => ComplianceReportScreen(
                      basePath: basePath,
                      siteId: siteId,
                      siteName: site?.name ?? 'Site',
                      siteAddress: site?.address ?? '',
                    ),
                  );
                },
              ),
              GoRoute(
                path: 'bs5839-config',
                redirect: (context, state) {
                  if (!RemoteConfigService.instance.bs5839ModeEnabled) {
                    return '/sites';
                  }
                  return null;
                },
                builder: (context, state) {
                  final companyId = UserProfileService.instance.companyId ?? '';
                  final basePath = 'companies/$companyId';
                  final siteId = state.pathParameters['siteId']!;
                  final extra = state.extra is Map<String, dynamic> ? state.extra as Map<String, dynamic> : null;
                  return _SiteDataLoader(
                    companyId: companyId,
                    siteId: siteId,
                    cachedName: extra?['siteName'] as String?,
                    cachedAddress: extra?['siteAddress'] as String?,
                    builder: (site) => Bs5839SystemConfigScreen(
                      basePath: basePath,
                      siteId: siteId,
                      siteName: site?.name ?? 'Site',
                    ),
                  );
                },
              ),
              GoRoute(
                path: 'bs5839-visits',
                redirect: (context, state) {
                  if (!RemoteConfigService.instance.bs5839ModeEnabled) {
                    return '/sites';
                  }
                  return null;
                },
                builder: (context, state) {
                  final companyId = UserProfileService.instance.companyId ?? '';
                  final basePath = 'companies/$companyId';
                  final siteId = state.pathParameters['siteId']!;
                  final extra = state.extra is Map<String, dynamic> ? state.extra as Map<String, dynamic> : null;
                  return _SiteDataLoader(
                    companyId: companyId,
                    siteId: siteId,
                    cachedName: extra?['siteName'] as String?,
                    builder: (site) => VisitHistoryScreen(
                      basePath: basePath,
                      siteId: siteId,
                      siteName: site?.name ?? 'Site',
                    ),
                  );
                },
                routes: [
                  GoRoute(
                    path: ':visitId',
                    builder: (context, state) {
                      final companyId = UserProfileService.instance.companyId ?? '';
                      final basePath = 'companies/$companyId';
                      final siteId = state.pathParameters['siteId']!;
                      final visitId = state.pathParameters['visitId']!;
                      final extra = state.extra is Map<String, dynamic> ? state.extra as Map<String, dynamic> : null;
                      return _SiteDataLoader(
                        companyId: companyId,
                        siteId: siteId,
                        cachedName: extra?['siteName'] as String?,
                        builder: (site) => VisitDetailScreen(
                          basePath: basePath,
                          siteId: siteId,
                          siteName: site?.name ?? 'Site',
                          visitId: visitId,
                        ),
                      );
                    },
                  ),
                ],
              ),
              GoRoute(
                path: 'bs5839-variations',
                redirect: (context, state) {
                  if (!RemoteConfigService.instance.bs5839ModeEnabled) {
                    return '/sites';
                  }
                  return null;
                },
                builder: (context, state) {
                  final companyId = UserProfileService.instance.companyId ?? '';
                  final basePath = 'companies/$companyId';
                  final siteId = state.pathParameters['siteId']!;
                  final extra = state.extra is Map<String, dynamic> ? state.extra as Map<String, dynamic> : null;
                  return _SiteDataLoader(
                    companyId: companyId,
                    siteId: siteId,
                    cachedName: extra?['siteName'] as String?,
                    builder: (site) => VariationsRegisterScreen(
                      basePath: basePath,
                      siteId: siteId,
                      siteName: site?.name ?? 'Site',
                    ),
                  );
                },
              ),
              GoRoute(
                path: 'bs5839-logbook',
                redirect: (context, state) {
                  if (!RemoteConfigService.instance.bs5839ModeEnabled) {
                    return '/sites';
                  }
                  return null;
                },
                builder: (context, state) {
                  final companyId = UserProfileService.instance.companyId ?? '';
                  final basePath = 'companies/$companyId';
                  final siteId = state.pathParameters['siteId']!;
                  final extra = state.extra is Map<String, dynamic> ? state.extra as Map<String, dynamic> : null;
                  return _SiteDataLoader(
                    companyId: companyId,
                    siteId: siteId,
                    cachedName: extra?['siteName'] as String?,
                    builder: (site) => LogbookScreen(
                      basePath: basePath,
                      siteId: siteId,
                      siteName: site?.name ?? 'Site',
                    ),
                  );
                },
              ),
              GoRoute(
                path: ':assetId',
                builder: (context, state) {
                  final companyId = UserProfileService.instance.companyId ?? '';
                  final basePath = 'companies/$companyId';
                  final siteId = state.pathParameters['siteId']!;
                  final assetId = state.pathParameters['assetId']!;
                  return AssetDetailScreen(
                    basePath: basePath,
                    siteId: siteId,
                    assetId: assetId,
                  );
                },
              ),
              GoRoute(
                path: ':assetId/edit',
                builder: (context, state) {
                  final companyId = UserProfileService.instance.companyId ?? '';
                  final basePath = 'companies/$companyId';
                  final siteId = state.pathParameters['siteId']!;
                  final asset = state.extra as Asset?;
                  return AddEditAssetScreen(
                    basePath: basePath,
                    siteId: siteId,
                    asset: asset,
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/sites/:siteId/floor-plans',
            redirect: (context, state) {
              if (!RemoteConfigService.instance.assetRegisterEnabled) {
                return '/sites';
              }
              return null;
            },
            builder: (context, state) {
              final companyId = UserProfileService.instance.companyId ?? '';
              final basePath = 'companies/$companyId';
              final siteId = state.pathParameters['siteId']!;
              final extra = state.extra is Map<String, dynamic> ? state.extra as Map<String, dynamic> : null;
              return _SiteDataLoader(
                companyId: companyId,
                siteId: siteId,
                cachedName: extra?['siteName'] as String?,
                builder: (site) => FloorPlanListScreen(
                  siteId: siteId,
                  siteName: site?.name ?? 'Site',
                  basePath: basePath,
                ),
              );
            },
            routes: [
              GoRoute(
                path: 'upload',
                builder: (context, state) {
                  final companyId = UserProfileService.instance.companyId ?? '';
                  final basePath = 'companies/$companyId';
                  final siteId = state.pathParameters['siteId']!;
                  return UploadFloorPlanScreen(
                    siteId: siteId,
                    basePath: basePath,
                  );
                },
              ),
              GoRoute(
                path: ':planId',
                builder: (context, state) {
                  final companyId = UserProfileService.instance.companyId ?? '';
                  final basePath = 'companies/$companyId';
                  final siteId = state.pathParameters['siteId']!;
                  final planId = state.pathParameters['planId']!;
                  final floorPlan = state.extra as FloorPlan?;
                  return _FloorPlanLoader(
                    basePath: basePath,
                    siteId: siteId,
                    planId: planId,
                    cachedPlan: floorPlan,
                    builder: (plan) => InteractiveFloorPlanScreen(
                      basePath: basePath,
                      siteId: siteId,
                      floorPlan: plan,
                    ),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/quotes',
            redirect: (context, state) {
              if (!RemoteConfigService.instance.quotingEnabled) return '/jobs';
              return null;
            },
            builder: (context, state) => const WebQuotesScreen(),
          ),
          GoRoute(
            path: '/quotes/create',
            redirect: (context, state) {
              if (!RemoteConfigService.instance.quotingEnabled) return '/jobs';
              return null;
            },
            builder: (context, state) {
              final editQuote = state.extra as Quote?;
              return WebCreateQuoteScreen(editQuote: editQuote);
            },
          ),
          GoRoute(
            path: '/quotes/:id',
            redirect: (context, state) {
              if (!RemoteConfigService.instance.quotingEnabled) return '/jobs';
              return null;
            },
            builder: (context, state) {
              final quoteId = state.pathParameters['id'];
              return WebQuotesScreen(initialQuoteId: quoteId);
            },
          ),
          GoRoute(
            path: '/invoices',
            builder: (context, state) => const WebInvoicesScreen(),
          ),
          GoRoute(
            path: '/invoices/create',
            builder: (context, state) {
              final editInvoice = state.extra as Invoice?;
              return WebCreateInvoiceScreen(editInvoice: editInvoice);
            },
          ),
          GoRoute(
            path: '/invoices/:id',
            builder: (context, state) {
              final invoiceId = state.pathParameters['id'];
              return WebInvoicesScreen(initialInvoiceId: invoiceId);
            },
          ),
          GoRoute(
            path: '/customers',
            builder: (context, state) => CompanyCustomersScreen(companyId: UserProfileService.instance.companyId ?? ''),
          ),
          GoRoute(
            path: '/branding',
            builder: (context, state) => const WebBrandingScreen(),
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

/// Loads site data from cache or Firestore for route builders.
class _SiteDataLoader extends StatelessWidget {
  final String companyId;
  final String siteId;
  final String? cachedName;
  final String? cachedAddress;
  final Widget Function(CompanySite?) builder;

  const _SiteDataLoader({
    required this.companyId,
    required this.siteId,
    this.cachedName,
    this.cachedAddress,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    // If we have cached data, use it immediately
    if (cachedName != null) {
      return builder(CompanySite(
        id: siteId,
        name: cachedName!,
        address: cachedAddress ?? '',
        createdBy: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }

    // Otherwise load from Firestore
    return FutureBuilder<CompanySite?>(
      future: CompanyService.instance.getSite(companyId, siteId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return builder(snapshot.data);
      },
    );
  }
}

/// Loads a floor plan from cache or Firestore for route builders.
class _FloorPlanLoader extends StatelessWidget {
  final String basePath;
  final String siteId;
  final String planId;
  final FloorPlan? cachedPlan;
  final Widget Function(FloorPlan plan) builder;

  const _FloorPlanLoader({
    required this.basePath,
    required this.siteId,
    required this.planId,
    this.cachedPlan,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    if (cachedPlan != null) {
      return builder(cachedPlan!);
    }

    return FutureBuilder<FloorPlan?>(
      future: FloorPlanService.instance.getFloorPlan(basePath, siteId, planId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == null) {
          return const Scaffold(
            body: Center(child: Text('Floor plan not found')),
          );
        }
        return builder(snapshot.data!);
      },
    );
  }
}
