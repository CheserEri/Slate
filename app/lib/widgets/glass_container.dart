import 'dart:ui';
import 'package:flutter/material.dart';

class GlassNavItem {
  final Widget icon;
  final Widget? selectedIcon;
  final String label;
  const GlassNavItem({required this.icon, this.selectedIcon, required this.label});
}

/// 玻璃拟态容器
/// 支持模糊、半透明背景、边框光效
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final double blur;
  final Color? tint;
  final double? width;
  final double? height;
  final Border? border;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.blur = 20,
    this.tint,
    this.width,
    this.height,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(20),
        border: border,
      ),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint ?? Colors.white.withValues(alpha: 0.06),
            borderRadius: borderRadius ?? BorderRadius.circular(20),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 玻璃拟态底部栏
class GlassBottomBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<GlassNavItem> destinations;

  const GlassBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            color: Colors.black.withValues(alpha: 0.4),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: destinations.asMap().entries.map((entry) {
                    final index = entry.key;
                    final dest = entry.value;
                    final isSelected = index == selectedIndex;
                    return GestureDetector(
                      onTap: () => onDestinationSelected(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            isSelected ? (dest.selectedIcon ?? dest.icon) : dest.icon,
                            const SizedBox(height: 2),
                            Text(
                              dest.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 杂志风日期标题
class MagazineDateHeader extends StatelessWidget {
  final String text;
  const MagazineDateHeader(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: Color(0xE6FFFFFF),
          letterSpacing: -0.8,
          height: 1.2,
        ),
      ),
    );
  }
}

/// 左侧色条状态指示容器
class StatusCard extends StatelessWidget {
  final Widget child;
  final Color statusColor;
  final VoidCallback? onTap;

  const StatusCard({
    super.key,
    required this.child,
    required this.statusColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 64,
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: child),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}
