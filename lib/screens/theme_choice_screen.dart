import 'package:flutter/material.dart';
import '../services/app_colors.dart';
import '../widgets/app_pressable.dart';
import '../services/theme_service.dart';
import '../l10n/app_localizations.dart';

/// Shown once, the first time an account signs in. Lets the user preview and
/// pick Light or Dark — tapping a card applies the theme live across the whole
/// app, and Continue locks it in before proceeding.
class ThemeChoiceScreen extends StatefulWidget {
  /// Called with the chosen mode (true = dark) when the user taps Continue.
  final Future<void> Function(bool isDark) onChoose;

  const ThemeChoiceScreen({super.key, required this.onChoose});

  @override
  State<ThemeChoiceScreen> createState() => _ThemeChoiceScreenState();
}

class _ThemeChoiceScreenState extends State<ThemeChoiceScreen> {
  late bool _dark = themeService.isDark; // starts light for first-timers
  bool _isSaving = false;

  void _select(bool dark) {
    setState(() => _dark = dark);
    themeService.setDark(
      dark,
      persistToAccount: false,
    ); // live preview across the app
  }

  Future<void> _continue() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await widget.onChoose(_dark);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.couldNotSaveChanges),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.lightRed,
                  borderRadius: BorderRadius.all(Radius.circular(18)),
                ),
                child: Icon(
                  Icons.palette_outlined,
                  color: AppColors.primaryRed,
                  size: 28,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.of(context)!.chooseYourLook,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.pickAppearanceHint,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: _ThemePreviewCard(
                      label: AppLocalizations.of(context)!.light,
                      dark: false,
                      selected: !_dark,
                      onTap: () => _select(false),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _ThemePreviewCard(
                      label: AppLocalizations.of(context)!.dark,
                      dark: true,
                      selected: _dark,
                      onTap: () => _select(true),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.continueWithTheme(
                                _dark
                                    ? AppLocalizations.of(context)!.dark
                                    : AppLocalizations.of(context)!.light,
                              ),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 20),
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
}

/// A tappable mini app mock rendered in a fixed Light or Dark palette so each
/// card always represents its option regardless of the live theme.
class _ThemePreviewCard extends StatelessWidget {
  final String label;
  final bool dark;
  final bool selected;
  final VoidCallback onTap;

  const _ThemePreviewCard({
    required this.label,
    required this.dark,
    required this.selected,
    required this.onTap,
  });

  // Fixed palettes (mirror the app's Light / Dark colors).
  static const _lightBg = Color(0xFFFBF7F5);
  static const _lightCard = Color(0xFFFFFFFF);
  static const _lightText = Color(0xFF1A0610);
  static const _lightSub = Color(0xFFD8C9C4);
  static const _darkBg = DarkColors.background;
  static const _darkCard = DarkColors.card;
  static const _darkText = Color(0xFFFFFFFF);
  static const _darkSub = Color(0xFFA8A8A8);
  static const _accent = Color(0xFF9E2045);

  @override
  Widget build(BuildContext context) {
    final bg = dark ? _darkBg : _lightBg;
    final card = dark ? _darkCard : _lightCard;
    final text = dark ? _darkText : _lightText;
    final sub = dark ? _darkSub : _lightSub;

    return AppPressable(
      onTap: onTap,
      pressedScale: 0.98,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(26)),
          border: Border.all(
            color: selected ? AppColors.primaryRed : AppColors.divider,
            width: selected ? 2.5 : 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primaryRed.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            // Mini mock
            Container(
              height: 168,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 46,
                        height: 8,
                        decoration: BoxDecoration(
                          color: text.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        dark
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        size: 16,
                        color: _accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < 3; i++)
                    Container(
                      margin: EdgeInsets.only(bottom: i == 2 ? 0 : 8),
                      height: 30,
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: _accent.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.all(
                                Radius.circular(5),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: i == 0 ? 70 : (i == 1 ? 54 : 40),
                            height: 7,
                            decoration: BoxDecoration(
                              color: sub,
                              borderRadius: BorderRadius.all(
                                Radius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Label + radio
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 18,
                    color: selected
                        ? AppColors.primaryRed
                        : AppColors.secondaryText,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: selected ? AppColors.primaryRed : AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
