import 'package:flutter/material.dart';
import '../services/app_colors.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';
import '../services/personalization_service.dart';
import '../services/user_prefs_service.dart';
import '../services/user_state.dart';
import '../widgets/club_avatar.dart';

/// Lightweight onboarding bottom sheet: interests → major → times → clubs.
/// Call via [showKuDayOnboarding].
Future<void> showKuDayOnboarding(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => const _OnboardingSheet(),
  );
}

class _OnboardingSheet extends StatefulWidget {
  const _OnboardingSheet();

  @override
  State<_OnboardingSheet> createState() => _OnboardingSheetState();
}

class _OnboardingSheetState extends State<_OnboardingSheet> {
  final Set<String> _interests = {};
  final Set<String> _times = {};
  String _selectedMajor = '';
  final Set<String> _followedInOnboarding = {};
  int _step = 0; // 0 = interests, 1 = major, 2 = times, 3 = clubs

  // ── Club color helper (same palette as event screens) ─────────────────────

  Color _clubColor(String clubId) {
    const colors = [
      Color(0xFFB41C18),
      Color(0xFF1565C0),
      Color(0xFF2E7D32),
      Color(0xFF6A1B9A),
      Color(0xFFE65100),
      Color(0xFF00838F),
      Color(0xFF558B2F),
      Color(0xFF283593),
      Color(0xFF6D4C41),
      Color(0xFF00695C),
      Color(0xFF4527A0),
      Color(0xFFC62828),
    ];
    final idx = clubs.indexWhere((c) => c.id == clubId);
    return colors[(idx < 0 ? 0 : idx) % colors.length];
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _finish() async {
    final uid = authService.currentUser?.id ?? authService.currentAdmin?.id;
    if (uid == null) {
      Navigator.pop(context);
      return;
    }
    await personalizationService.completeOnboarding(
      uid,
      _interests,
      _times,
      _selectedMajor,
    );
    for (final clubId in _followedInOnboarding) {
      if (!userState.followedClubIds.contains(clubId)) {
        userState.toggleFollow(clubId);
      }
    }
    await userPrefsService.save(uid);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _skip() async {
    final uid = authService.currentUser?.id ?? authService.currentAdmin?.id;
    if (uid != null) {
      await personalizationService.completeOnboarding(uid, {}, {}, '');
    }
    if (mounted) Navigator.pop(context);
  }

  // ── Root build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: SingleChildScrollView(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: _step == 0
              ? _buildInterestsStep()
              : _step == 1
              ? _buildMajorStep()
              : _step == 2
              ? _buildTimesStep()
              : _buildClubsStep(),
        ),
      ),
    );
  }

  // ── Step dots ──────────────────────────────────────────────────────────────

  Widget _buildStepDots(int current) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: active ? 18 : 6,
          height: 6,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: active ? AppColors.primaryRed : AppColors.divider,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  Widget _dragHandle() => Center(
    child: Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _skipButton() => TextButton(
    key: ValueKey('ku-day-skip-step-$_step'),
    onPressed: _skip,
    child: Text(
      'Skip setup',
      style: TextStyle(
        color: AppColors.secondaryText,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  // ── Step 0 — Interests ─────────────────────────────────────────────────────

  Widget _buildInterestsStep() {
    return Column(
      key: const ValueKey('step0'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dragHandle(),
        const SizedBox(height: 10),
        Center(child: _buildStepDots(0)),
        const SizedBox(height: 14),
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.lightRed,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primaryRed,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your KU Day',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    'Quick setup — just 4 steps',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            _skipButton(),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'What are you into?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Pick as many as you like. We\'ll surface what matters to you.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.secondaryText,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kInterests.map((tag) {
            final selected = _interests.contains(tag);
            return GestureDetector(
              onTap: () => setState(() {
                if (selected) {
                  _interests.remove(tag);
                } else {
                  _interests.add(tag);
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primaryRed : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: selected ? AppColors.primaryRed : AppColors.divider,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected) ...[
                      Icon(Icons.check_rounded, size: 14, color: Colors.white),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      tag,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: selected ? Colors.white : AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const ValueKey('ku-day-next-step-0'),
            onPressed: () => setState(() => _step = 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: Text(
              'Next →',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }

  // ── Step 1 — Major ─────────────────────────────────────────────────────────

  Widget _buildMajorStep() {
    return Column(
      key: const ValueKey('step1'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dragHandle(),
        const SizedBox(height: 10),
        Center(child: _buildStepDots(1)),
        const SizedBox(height: 14),
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _step = 0),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'What\'s your major?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
            ),
            _skipButton(),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: EdgeInsets.only(left: 30),
          child: Text(
            'We\'ll suggest clubs that fit your field.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.secondaryText,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: kFaculties.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final faculty = kFaculties[i];
            final name = faculty['name'] as String;
            final depts = faculty['departments'] as String;
            final selected = _selectedMajor == name;
            return GestureDetector(
              key: ValueKey('ku-day-major-$name'),
              onTap: () => setState(() => _selectedMajor = name),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: selected ? AppColors.lightRed : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? AppColors.primaryRed : AppColors.divider,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.lightRed,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.school_outlined,
                        size: 18,
                        color: AppColors.primaryRed,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            depts,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? AppColors.primaryRed
                            : Colors.transparent,
                        border: Border.all(
                          color: selected
                              ? AppColors.primaryRed
                              : AppColors.divider,
                          width: 1.5,
                        ),
                      ),
                      child: selected
                          ? Icon(Icons.check, size: 12, color: Colors.white)
                          : null,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const ValueKey('ku-day-next-step-1'),
            onPressed: _selectedMajor.isNotEmpty
                ? () => setState(() => _step = 2)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.surfaceAlt,
              disabledForegroundColor: AppColors.secondaryText,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: Text(
              'Next →',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }

  // ── Step 2 — Times ─────────────────────────────────────────────────────────

  Widget _buildTimesStep() {
    const iconMap = {
      'Morning': Icons.wb_sunny_outlined,
      'Afternoon': Icons.wb_cloudy_outlined,
      'Evening': Icons.nights_stay_outlined,
      'Weekend': Icons.weekend_outlined,
    };

    return Column(
      key: const ValueKey('step2'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dragHandle(),
        const SizedBox(height: 10),
        Center(child: _buildStepDots(2)),
        const SizedBox(height: 14),
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _step = 1),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'When do you usually have time?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
            ),
            _skipButton(),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: EdgeInsets.only(left: 30),
          child: Text(
            'We\'ll prioritise events that fit your schedule.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.secondaryText,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.8,
          children: kTimeSlots.map((slot) {
            final selected = _times.contains(slot);
            return GestureDetector(
              onTap: () => setState(() {
                if (selected) {
                  _times.remove(slot);
                } else {
                  _times.add(slot);
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primaryRed : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? AppColors.primaryRed : AppColors.divider,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      iconMap[slot],
                      size: 18,
                      color: selected ? Colors.white : AppColors.secondaryText,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      slot,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const ValueKey('ku-day-next-step-2'),
            onPressed: () => setState(() => _step = 3),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: Text(
              'Next →',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }

  // ── Step 3 — Club recommendations ─────────────────────────────────────────

  Widget _buildClubsStep() {
    final alreadyFollowed = userState.followedClubIds;

    // Rank clubs by how many selected interests they match; exclude followed.
    final candidates =
        kClubInterestMap.keys
            .where((id) => !alreadyFollowed.contains(id))
            .map((id) => (id, personalizationService.interestMatchCount(id)))
            .toList()
          ..sort((a, b) => b.$2.compareTo(a.$2));

    final recommended = candidates.take(6).map((t) => t.$1).toList();

    return Column(
      key: const ValueKey('step3'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dragHandle(),
        const SizedBox(height: 10),
        Center(child: _buildStepDots(3)),
        const SizedBox(height: 14),
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _step = 2),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.lightRed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.groups_rounded,
                size: 18,
                color: AppColors.primaryRed,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Clubs picked for you',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    'Follow to see their posts.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            _skipButton(),
          ],
        ),
        if (recommended.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () =>
                  setState(() => _followedInOnboarding.addAll(recommended)),
              child: Text(
                'Follow all',
                style: TextStyle(
                  color: AppColors.primaryRed,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        if (_interests.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _interests
                .map(
                  (tag) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primaryRed.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primaryRed,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 14),
        if (recommended.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'No new clubs to suggest — you\'re already well-connected!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recommended.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final clubId = recommended[i];
              final club = clubs.firstWhere(
                (c) => c.id == clubId,
                orElse: () => clubs.first,
              );
              final color = _clubColor(clubId);
              final matchCount = personalizationService.interestMatchCount(
                clubId,
              );
              final isFollowed = _followedInOnboarding.contains(clubId);

              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isFollowed ? AppColors.lightRed : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isFollowed
                        ? AppColors.primaryRed.withValues(alpha: 0.45)
                        : AppColors.divider,
                  ),
                ),
                child: Row(
                  children: [
                    ClubAvatar(
                      clubId: clubId,
                      clubName: club.name,
                      color: color,
                      size: 44,
                      shape: 'rounded',
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            club.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (matchCount > 0) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accentGold.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$matchCount interest match${matchCount > 1 ? 'es' : ''}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.accentGold,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() {
                        if (_followedInOnboarding.contains(clubId)) {
                          _followedInOnboarding.remove(clubId);
                        } else {
                          _followedInOnboarding.add(clubId);
                        }
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: isFollowed
                              ? AppColors.primaryRed
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isFollowed
                                ? AppColors.primaryRed
                                : AppColors.primaryRed.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          isFollowed ? 'Following' : 'Follow',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isFollowed
                                ? Colors.white
                                : AppColors.primaryRed,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _finish,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: Text(
              'Let\'s go →',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Following ',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
                TextSpan(
                  text: '${_followedInOnboarding.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryRed,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: ' clubs',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
