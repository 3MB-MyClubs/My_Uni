import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../services/app_colors.dart';
import '../services/app_strings.dart';
import '../services/locale_service.dart';

/// First-run intro carousel shown once per device, before any account exists.
/// Sells the app across a few slides, lets the user switch language via the
/// globe icon, then hands off to sign-up ([onGetStarted]) or login ([onLogIn]).
///
/// Copy is sourced from [S] getters and the parent's merged locale listener
/// rebuilds this screen when the globe switches language, so no local locale
/// listener is needed here.
class OnboardingCarouselScreen extends StatefulWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onLogIn;

  const OnboardingCarouselScreen({
    super.key,
    required this.onGetStarted,
    required this.onLogIn,
  });

  @override
  State<OnboardingCarouselScreen> createState() =>
      _OnboardingCarouselScreenState();
}

class _OnboardingCarouselScreenState extends State<OnboardingCarouselScreen>
    with SingleTickerProviderStateMixin {
  final PageController _controller = PageController();
  late final AnimationController _exitController;
  int _page = 0;
  bool _isLeaving = false;

  @override
  void initState() {
    super.initState();
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
      value: 1,
    );
  }

  // Rebuilt each build() so titles/subtitles re-read S.* after a language flip.
  // Every slide's hero sits in the same [_HeroBadge] frame; only the content
  // inside changes. The three Lottie animations are forced to AppColors.primaryRed
  // (via a Lottie colour delegate) to match slide 4's icon, so all four slides
  // share one badge and one accent colour.
  List<_IntroSlide> get _slides => [
    _IntroSlide(
      icon: Icons.explore_rounded,
      title: S.onboardingIntroDiscoverTitle,
      subtitle: S.onboardingIntroDiscoverSubtitle,
      // Nudge only the pin glyph down a touch. Transform.translate is a
      // paint-time shift, so it moves the Lottie inside its fixed 92px slot
      // without changing any layout — the 124px badge and the title/subtitle
      // stay exactly where they are on every other slide.
      illustration: Transform.translate(
        offset: const Offset(0, 4),
        child: _redLottie('assets/lottie/location_pin.json'),
      ),
    ),
    _IntroSlide(
      icon: Icons.event_available_rounded,
      title: S.onboardingIntroCalendarTitle,
      subtitle: S.onboardingIntroCalendarSubtitle,
      illustration: _redLottie('assets/lottie/calendar.json'),
    ),
    _IntroSlide(
      icon: Icons.groups_rounded,
      title: S.onboardingIntroClubsTitle,
      subtitle: S.onboardingIntroClubsSubtitle,
      illustration: _redLottie('assets/lottie/notification_bell.json'),
    ),
    _IntroSlide(
      icon: Icons.rocket_launch_rounded,
      title: S.onboardingIntroReadyTitle,
      subtitle: S.onboardingIntroReadySubtitle,
    ),
  ];

  /// A looping Lottie whose every colour is overridden to [AppColors.primaryRed]
  /// so the downloaded art matches the app's accent (and follows light/dark,
  /// since this getter re-runs each build). Both fill and stroke colours are
  /// overridden — the calendar's outline is drawn with strokes, not fills.
  Widget _redLottie(String asset) => Lottie.asset(
    asset,
    fit: BoxFit.contain,
    repeat: true,
    delegates: LottieDelegates(
      values: [
        ValueDelegate.color(const ['**'], value: AppColors.primaryRed),
        ValueDelegate.strokeColor(const ['**'], value: AppColors.primaryRed),
      ],
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    _exitController.dispose();
    super.dispose();
  }

  Future<void> _leave(VoidCallback destination) async {
    if (_isLeaving) return;
    setState(() => _isLeaving = true);
    await _exitController.reverse();
    if (mounted) destination();
  }

  void _openLanguageSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
              ),
              const SizedBox(height: 8),
              _LanguageRow(
                flag: '🇬🇧',
                label: 'English',
                selected: localeService.languageCode == 'en',
                onTap: () {
                  localeService.setLanguage('en');
                  Navigator.pop(sheetContext);
                },
              ),
              _LanguageRow(
                flag: '🇹🇷',
                label: 'Türkçe',
                selected: localeService.languageCode == 'tr',
                onTap: () {
                  localeService.setLanguage('tr');
                  Navigator.pop(sheetContext);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final slides = _slides;
    final isLast = _page == slides.length - 1;

    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _exitController,
        curve: Curves.easeOutCubic,
      ),
      child: SlideTransition(
        position:
            Tween<Offset>(
              begin: const Offset(-0.025, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: _exitController,
                curve: Curves.easeOutCubic,
              ),
            ),
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: _controller,
                        onPageChanged: (i) => setState(() => _page = i),
                        itemCount: slides.length,
                        itemBuilder: (_, i) => _Slide(slide: slides[i]),
                      ),
                    ),
                    _buildDots(slides.length),
                    const SizedBox(height: 28),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                      child: _buildActions(isLast),
                    ),
                  ],
                ),
                // Globe language switcher — fixed top-right on every slide.
                Positioned(
                  top: 4,
                  right: 8,
                  child: IconButton(
                    onPressed: _openLanguageSheet,
                    icon: Icon(
                      Icons.language_rounded,
                      color: AppColors.secondaryText,
                    ),
                    tooltip: S.language,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDots(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == _page;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? AppColors.primaryRed : AppColors.divider,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
        );
      }),
    );
  }

  Widget _buildActions(bool isLast) {
    // Fixed height keeps the dots steady as the action area swaps between the
    // single Skip button and the final slide's two-button layout.
    return SizedBox(
      height: 108,
      child: isLast
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLeaving
                        ? null
                        : () => _leave(widget.onGetStarted),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          S.onboardingIntroGetStarted,
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
                const SizedBox(height: 4),
                TextButton(
                  onPressed: _isLeaving ? null : () => _leave(widget.onLogIn),
                  child: Text(
                    S.onboardingIntroLogIn,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: TextButton(
                onPressed: _isLeaving ? null : () => _leave(widget.onLogIn),
                child: Text(
                  S.onboardingIntroSkip,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
            ),
    );
  }
}

class _IntroSlide {
  final IconData icon;
  final String title;
  final String subtitle;

  /// Optional hero animation. When null the slide falls back to the icon badge.
  final Widget? illustration;

  const _IntroSlide({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.illustration,
  });
}

class _Slide extends StatelessWidget {
  final _IntroSlide slide;

  const _Slide({required this.slide});

  // Every hero shares the same rounded-square badge (124 / lightRed / r34),
  // matching the theme/language choice screens. Inside it the content changes
  // per slide: the icon (slide 4) at size 90, or a recoloured Lottie sized to
  // ~92 to echo the icon's footprint. Badge size is fixed; only the content
  // scales.
  @override
  Widget build(BuildContext context) {
    final hero = _HeroBadge(
      child: slide.illustration != null
          ? SizedBox(width: 92, height: 92, child: slide.illustration)
          : Icon(slide.icon, color: AppColors.primaryRed, size: 90),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          hero,
          const SizedBox(height: 36),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared hero frame for the carousel slides: a 104 rounded-square in
/// [AppColors.lightRed], centring whatever content each slide supplies. Every
/// badged slide reuses this so the frame is pixel-identical across the carousel.
class _HeroBadge extends StatelessWidget {
  final Widget child;

  const _HeroBadge({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 124,
      height: 124,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.lightRed,
        borderRadius: const BorderRadius.all(Radius.circular(34)),
      ),
      child: child,
    );
  }
}

class _LanguageRow extends StatelessWidget {
  final String flag;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageRow({
    required this.flag,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Text(flag, style: const TextStyle(fontSize: 24)),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check_rounded, color: AppColors.primaryRed)
          : null,
    );
  }
}
