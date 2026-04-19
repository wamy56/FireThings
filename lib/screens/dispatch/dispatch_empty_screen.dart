import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../services/remote_config_service.dart';
import '../../widgets/background_decoration.dart';
import '../company/create_company_screen.dart';
import '../company/join_company_screen.dart';

class DispatchEmptyScreen extends StatelessWidget {
  const DispatchEmptyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dispatchEnabled = RemoteConfigService.instance.dispatchEnabled;

    return Scaffold(
      body: Stack(
        children: [
          const BackgroundDecoration(),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.screenPadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      AppIcons.routing,
                      size: 48,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Dispatch & Team Management',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    dispatchEnabled
                        ? 'Create or join a company to dispatch jobs, '
                          'manage your team, and coordinate field work.'
                        : 'Team dispatch and job management is coming soon. '
                          'Stay tuned for updates.',
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (dispatchEnabled) ...[
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          adaptivePageRoute(
                            builder: (_) => const CreateCompanyScreen(),
                          ),
                        ),
                        icon: const Icon(AppIcons.add),
                        label: const Text('Create a Company'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          adaptivePageRoute(
                            builder: (_) => const JoinCompanyScreen(),
                          ),
                        ),
                        icon: const Icon(AppIcons.people),
                        label: const Text('Join a Company'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
