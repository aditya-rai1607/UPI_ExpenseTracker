import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/sms_listener_service.dart';

class PermissionsOnboardingScreen extends StatefulWidget {
  const PermissionsOnboardingScreen({super.key});

  @override
  State<PermissionsOnboardingScreen> createState() =>
      _PermissionsOnboardingScreenState();
}

class _PermissionsOnboardingScreenState
    extends State<PermissionsOnboardingScreen> {
  bool _smsPermissionGranted = false;
  bool _notificationPermissionGranted = false;
  bool _isRequestingPermissions = false;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _checkCurrentPermissions();
  }

  Future<void> _checkCurrentPermissions() async {
    if (!_isAndroid) {
      setState(() {
        _smsPermissionGranted = true;
        _notificationPermissionGranted = true;
      });
      return;
    }

    final smsStatus = await Permission.sms.status;
    final notificationStatus = await Permission.notification.status;

    setState(() {
      _smsPermissionGranted = smsStatus.isGranted;
      _notificationPermissionGranted = notificationStatus.isGranted;
    });
  }

  Future<void> _requestSmsPermission() async {
    if (!_isAndroid) {
      setState(() => _smsPermissionGranted = true);
      return;
    }

    setState(() => _isRequestingPermissions = true);

    final status = await Permission.sms.request();

    setState(() {
      _smsPermissionGranted = status.isGranted;
      _isRequestingPermissions = false;
    });

    if (status.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'SMS permission is required for auto-detect feature.',
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (!_isAndroid) {
      setState(() => _notificationPermissionGranted = true);
      return;
    }

    setState(() => _isRequestingPermissions = true);

    final status = await Permission.notification.request();

    setState(() {
      _notificationPermissionGranted = status.isGranted;
      _isRequestingPermissions = false;
    });

    if (status.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notification permission helps alert you of new transactions.',
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _proceedToApp() async {
    // Start SMS listener if SMS permission is granted
    if (_smsPermissionGranted && _isAndroid) {
      SmsListenerService.startListening();
    }

    // Mark onboarding as complete and navigate to dashboard
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Permissions'), elevation: 0),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Let\'s get you set up',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'We need a few permissions to enable the auto-detect feature.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isDark
                      ? const Color(0xFFB0B7C3)
                      : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 32),

              // SMS Permission Card
              _buildPermissionCard(
                context: context,
                icon: Icons.sms,
                title: 'SMS Auto-Detect',
                description:
                    'Read incoming SMS to automatically detect bank transactions.',
                isGranted: _smsPermissionGranted,
                onRequest: _requestSmsPermission,
                isRequired: true,
              ),
              const SizedBox(height: 16),

              // Notification Permission Card
              if (_isAndroid)
                _buildPermissionCard(
                  context: context,
                  icon: Icons.notifications,
                  title: 'Notifications',
                  description: 'Get alerts to categorize your transactions.',
                  isGranted: _notificationPermissionGranted,
                  onRequest: _requestNotificationPermission,
                  isRequired: true,
                ),

              const SizedBox(height: 32),

              // Continue Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _isRequestingPermissions ||
                          !_smsPermissionGranted ||
                          !_notificationPermissionGranted
                      ? null
                      : _proceedToApp,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isRequestingPermissions
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Continue to App',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // Info Text
              Center(
                child: Text(
                  'SMS and notification permissions are required.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? const Color(0xFF808B99)
                        : const Color(0xFF9CA3AF),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onRequest,
    required bool isRequired,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3140) : const Color(0xFFE5E7EB),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: isGranted
                      ? Colors.green.shade100
                      : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(12),
                child: Icon(
                  isGranted ? Icons.check_circle : icon,
                  color: isGranted
                      ? Colors.green.shade700
                      : Colors.blue.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isRequired)
                          Text(
                            '(Required)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? const Color(0xFFB0B7C3)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: isGranted ? null : onRequest,
              child: Text(isGranted ? 'Granted' : 'Grant Permission'),
            ),
          ),
        ],
      ),
    );
  }
}
