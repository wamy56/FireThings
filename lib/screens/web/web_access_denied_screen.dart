import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';

enum WebAccessDeniedReason { noCompany, engineerOnly }

class WebAccessDeniedScreen extends StatelessWidget {
  final WebAccessDeniedReason reason;

  const WebAccessDeniedScreen({super.key, required this.reason});

  @override
  Widget build(BuildContext context) {
    final title = reason == WebAccessDeniedReason.noCompany
        ? 'Company Required'
        : 'Mobile App Only';

    final message = reason == WebAccessDeniedReason.noCompany
        ? 'You need to join a company from the mobile app before you can use the web portal.'
        : 'The web portal is for dispatchers and admins. As an engineer, please use the FireThings mobile app for your work.';

    final icon = reason == WebAccessDeniedReason.noCompany
        ? AppIcons.building
        : AppIcons.global;

    return Scaffold(
      backgroundColor: AppTheme.primaryBlue,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppTheme.accentOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: AppTheme.accentOrange, size: 32),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.mediumGrey,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      icon: Icon(AppIcons.logout),
                      label: const Text('Sign Out'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
