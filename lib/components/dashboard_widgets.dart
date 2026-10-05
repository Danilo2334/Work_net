import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class DashboardHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final VoidCallback? onAvatarTap;

  const DashboardHeader({super.key, required this.title, this.onBack, this.trailing, this.onAvatarTap});

  @override
  Widget build(BuildContext context) {
    final primaryBlue = const Color(0xFF0F62FE);
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: onBack != null ? IconButton(
        icon: const Icon(LucideIcons.arrowLeft, color: Colors.black87),
        onPressed: onBack,
      ) : null,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: primaryBlue, borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.work, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 16)),
        ],
      ),
      actions: [
        if (trailing != null) trailing!,
        const SizedBox(width: 16),
        GestureDetector(
          onTap: onAvatarTap,
          child: CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey.shade200,
            child: Icon(LucideIcons.user, size: 18, color: Colors.grey.shade600),
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class KPICard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color trendColor;
  final String? trendText;
  final Widget? customBody;

  const KPICard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.trendColor = Colors.green,
    this.trendText,
    this.customBody,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600)),
              if (icon != null) Icon(icon, size: 16, color: Colors.grey.shade400),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
          if (trendText != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.trending_up, size: 14, color: trendColor),
                const SizedBox(width: 4),
                Text(trendText!, style: TextStyle(color: trendColor, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
          if (customBody != null) ...[
            const SizedBox(height: 12),
            customBody!,
          ]
        ],
      ),
    );
  }
}

class AnimatedProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  final double height;

  const AnimatedProgressBar({super.key, required this.value, this.color = const Color(0xFF0F62FE), this.height = 6});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: const Duration(seconds: 1),
      curve: Curves.easeOutCubic,
      builder: (context, val, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: LinearProgressIndicator(
            value: val,
            backgroundColor: Colors.grey.shade100,
            color: color,
            minHeight: height,
          ),
        );
      },
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionTitle({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
