import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/connectivity_viewmodel.dart';

/// Slim banner that appears at the top of a screen when the device is
/// offline. Each screen passes a context-specific [message] so the user
/// knows exactly what they're looking at ("showing cached catalog",
/// "showing trending from 3h ago", etc.).
///
/// When online, [OfflineBanner] renders a zero-height SizedBox so screens
/// don't need to branch their layout.
class OfflineBanner extends StatelessWidget {
  final String message;
  final DateTime? lastUpdated;

  const OfflineBanner({
    super.key,
    required this.message,
    this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityViewModel>();
    if (connectivity.isOnline) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final freshness = _formatFreshness(lastUpdated);

    return Material(
      color: cs.errorContainer.withValues(alpha: 0.55),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 18,
                color: cs.onErrorContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: message,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.onErrorContainer,
                        ),
                      ),
                      if (freshness != null)
                        TextSpan(
                          text: ' · $freshness',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: cs.onErrorContainer.withValues(alpha: 0.8),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String? _formatFreshness(DateTime? updated) {
    if (updated == null) return null;
    final diff = DateTime.now().difference(updated);
    if (diff.inMinutes < 1) return 'updated just now';
    if (diff.inMinutes < 60) return 'updated ${diff.inMinutes} min ago';
    if (diff.inHours < 24) return 'updated ${diff.inHours}h ago';
    return 'updated ${diff.inDays}d ago';
  }
}
