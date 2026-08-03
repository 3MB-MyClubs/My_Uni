import 'package:flutter/material.dart';

import '../services/app_colors.dart';
import '../services/locale_service.dart';
import 'app_pressable.dart';

/// Compact language picker shared by Settings and the authentication flow.
class LanguageToggle extends StatelessWidget {
  final ValueChanged<String>? onLanguageSelected;

  const LanguageToggle({super.key, this.onLanguageSelected});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: localeService,
      builder: (context, _) {
        final current = localeService.languageCode;
        return Container(
          height: 34,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _segment('EN', current == 'en', () {
                _selectLanguage('en');
              }),
              _segment('TR', current == 'tr', () {
                _selectLanguage('tr');
              }),
            ],
          ),
        );
      },
    );
  }

  void _selectLanguage(String code) {
    if (code == localeService.languageCode) return;
    final handler = onLanguageSelected;
    if (handler != null) {
      handler(code);
    } else {
      localeService.setLanguage(code);
    }
  }

  Widget _segment(String label, bool active, VoidCallback onTap) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: AppPressable(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        pressedScale: 0.94,
        child: AnimatedContainer(
          key: ValueKey<String>('language-$label'),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.primaryRed : Colors.transparent,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              color: active ? Colors.white : AppColors.secondaryText,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
