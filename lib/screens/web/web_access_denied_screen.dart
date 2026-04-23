import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/web_theme.dart';
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
      backgroundColor: FtColors.primary,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            decoration: BoxDecoration(
              color: FtColors.bg,
              borderRadius: FtRadii.lgAll,
              boxShadow: FtShadows.lg,
            ),
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: FtColors.accentSoft,
                    borderRadius: FtRadii.lgAll,
                  ),
                  child: Icon(icon, color: FtColors.accent, size: 32),
                ),
                const SizedBox(height: 20),
                Text(title, style: FtText.cardTitle),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: FtText.bodySoft.copyWith(height: 1.5),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    icon: Icon(AppIcons.logout),
                    label: const Text('Sign Out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FtColors.fg1,
                      side: BorderSide(color: FtColors.border, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: FtRadii.mdAll),
                      textStyle: FtText.button,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
