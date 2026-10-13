import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_mode_provider.dart';
import '../theme/app_theme.dart';

/// An interactive toggle button at the top of the app to switch between
/// Light and Dark modes.
class ThemeModeToggle extends ConsumerWidget {
  const ThemeModeToggle({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IconButton(
      tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, anim) => RotationTransition(
          turns: anim,
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: Icon(
          isDark ? Icons.light_mode_rounded : Icons.dark_mode_outlined,
          key: ValueKey<bool>(isDark),
          color: color ?? (isDark ? Colors.amber : AppColors.textBlue),
        ),
      ),
      onPressed: () {
        ref.read(themeModeProvider.notifier).toggle(isCurrentlyDark: isDark);
      },
    );
  }
}
