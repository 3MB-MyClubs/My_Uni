/// The search area's design tokens now live in [clubup_design.dart] — the
/// ClubUp-Desings handoff turned out to use one palette across every area, so
/// there is nothing search-specific left here.
///
/// This file stays as a re-export so the search screens keep compiling against
/// the old `SearchColors` name. New code should import `clubup_design.dart`
/// and use [ClubUpColors] directly.
library;

export 'clubup_design.dart';

import 'clubup_design.dart';

/// Former name for [ClubUpColors], kept for the search screens.
typedef SearchColors = ClubUpColors;
