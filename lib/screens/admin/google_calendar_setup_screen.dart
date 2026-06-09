import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/colors.dart';
import '../../repositories/api_client.dart';

class GoogleCalendarSetupScreen extends StatefulWidget {
  const GoogleCalendarSetupScreen({super.key});

  @override
  State<GoogleCalendarSetupScreen> createState() =>
      _GoogleCalendarSetupScreenState();
}

class _GoogleCalendarSetupScreenState
    extends State<GoogleCalendarSetupScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _status;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data =
          await ApiClient.get('/counselling/calendar/meet-status') as Map<String, dynamic>;
      setState(() => _status = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openAuthUrl() async {
    final url = _status?['authorization_url'] as String?;
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the authorization URL.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Meet Setup'),
        actions: [
          IconButton(
            onPressed: _fetch,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
          : _error != null
          ? _ErrorView(message: _error!, onRetry: _fetch)
          : _StatusView(status: _status!, onConnect: _openAuthUrl),
    );
  }
}

class _StatusView extends StatelessWidget {
  const _StatusView({required this.status, required this.onConnect});

  final Map<String, dynamic> status;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final authorized = status['authorized'] as bool? ?? false;
    final message = status['message'] as String? ?? '';
    final instructions = status['instructions'] as String?;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _StatusBanner(authorized: authorized, message: message),
        const SizedBox(height: 20),
        _HowItWorksCard(),
        if (!authorized) ...[
          const SizedBox(height: 20),
          _ConnectCard(onConnect: onConnect),
        ],
        if (instructions != null && !authorized) ...[
          const SizedBox(height: 20),
          _InstructionsCard(instructions: instructions),
        ],
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.authorized, required this.message});

  final bool authorized;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = authorized ? AppColors.secondary : AppColors.accent;
    final icon =
        authorized ? Icons.check_circle_rounded : Icons.warning_amber_rounded;
    final label = authorized ? 'Connected' : 'Not Connected';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Google Calendar — $label',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'How it works',
      icon: Icons.info_outline_rounded,
      iconColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Bullet(
            'When a mentor creates a counselling slot, a Google Meet link is auto-generated.',
          ),
          _Bullet(
            'When a student books a slot that has no link (e.g., created before setup), the link is generated at booking time.',
          ),
          _Bullet(
            'Direct session bookings also receive an auto-generated link when start and end times are provided.',
          ),
          _Bullet(
            'All generated links appear in the booking confirmation and session list.',
          ),
        ],
      ),
    );
  }
}

class _ConnectCard extends StatelessWidget {
  const _ConnectCard({required this.onConnect});

  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Connect Google Calendar',
      icon: Icons.add_link_rounded,
      iconColor: const Color(0xFF1A73E8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Click below to open Google sign-in. Sign in with the Google account that will host all Meet calls. '
            'You will be redirected back automatically after authorization.',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onConnect,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Authorize with Google'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1A73E8),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionsCard extends StatelessWidget {
  const _InstructionsCard({required this.instructions});

  final String instructions;

  @override
  Widget build(BuildContext context) {
    final steps = instructions
        .split(RegExp(r'\d+\.\s'))
        .where((s) => s.trim().isNotEmpty)
        .toList();

    return _Card(
      title: 'Step-by-step',
      icon: Icons.list_alt_rounded,
      iconColor: AppColors.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(right: 10, top: 1),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      steps[i].trim(),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.muted.withValues(alpha: 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.softRed),
            const SizedBox(height: 12),
            Text(
              'Could not load status',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
