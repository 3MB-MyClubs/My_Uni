// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get goodMorning => 'Good morning';

  @override
  String get goodAfternoon => 'Good afternoon';

  @override
  String get goodEvening => 'Good evening';

  @override
  String get stillUp => 'Still up';

  @override
  String get thisWeek => 'THIS WEEK';

  @override
  String get eventsOnCampus => 'Events on campus';

  @override
  String get campusHappening => 'Here\'s what\'s happening on campus.';

  @override
  String get membersHappening => 'Here\'s what your members are up to.';

  @override
  String get seeAll => 'See all';

  @override
  String get fromYourClubs => 'FROM YOUR CLUBS';

  @override
  String get clubFeed => 'CLUB FEED';

  @override
  String get following => 'Following';

  @override
  String get all => 'All';

  @override
  String get latest => 'Latest';

  @override
  String get nothingHere => 'Nothing here yet';

  @override
  String get followClubs =>
      'Follow clubs to see their posts\nand events in your feed';

  @override
  String get endOfFeed => 'That\'s it for today 😀';

  @override
  String get exploreClubs => 'Explore All Clubs';

  @override
  String get peopleMightKnow => 'People You Might Know';

  @override
  String get suggestedForYou => 'Suggested for you';

  @override
  String get followBack => 'Follow back';

  @override
  String get clubMightLike => 'Club You Might Like';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get explore => 'Explore';

  @override
  String get discoverClubs => 'Discover Clubs';

  @override
  String get findPeople => 'Find People';

  @override
  String get searchClubs => 'Search…';

  @override
  String get searchPeople => 'Search…';

  @override
  String get allClubs => 'All clubs';

  @override
  String get exploreContentTab => 'Events';

  @override
  String get searchEventsPosts => 'Search events…';

  @override
  String get upcomingEvents => 'Upcoming events';

  @override
  String get noContentMatch => 'No matches found';

  @override
  String get noClubsMatch => 'No clubs match';

  @override
  String get tryDifferentSearch => 'Try a different search term';

  @override
  String get studentProfile => 'Student profile';

  @override
  String get joined => 'Joined ✓';

  @override
  String get join => 'Join';

  @override
  String get follow => 'Follow';

  @override
  String get noOneMatches => 'No one found';

  @override
  String get tryNameSearch => 'Try a name, surname, or email';

  @override
  String get discoverEvents => 'Discover events';

  @override
  String get searchEvents => 'Search events, clubs, topics';

  @override
  String get anyDate => 'Any date';

  @override
  String get past => 'Past';

  @override
  String get live => 'Live';

  @override
  String get allEvents => 'All events';

  @override
  String get allPosts => 'All posts';

  @override
  String get overview => 'Overview';

  @override
  String get everythingOnCampus => 'Everything happening on campus';

  @override
  String get followingOnly => 'Only clubs you follow';

  @override
  String get showEventsFrom => 'Show events from';

  @override
  String get pickDate => 'Pick a date';

  @override
  String get clear => 'Clear';

  @override
  String get showAllDates => 'Show all dates';

  @override
  String get noEventsFound => 'No events found';

  @override
  String get tryDifferentKeyword =>
      'Try a different keyword or clear your filters.';

  @override
  String get nothingScheduled =>
      'Nothing scheduled here yet — check another date.';

  @override
  String get checkBackLater =>
      'Nothing on the calendar right now — check back soon!';

  @override
  String get resetFilters => 'Reset filters';

  @override
  String get newEvents => 'New events';

  @override
  String get allCaughtUp => 'All caught up';

  @override
  String get newEventsHint =>
      'Newly created events will appear here until you open their details.';

  @override
  String get going => 'Going';

  @override
  String get rsvp => 'Let\'s Go';

  @override
  String get ended => 'Ended';

  @override
  String get notifications => 'Notifications';

  @override
  String get filterYou => 'You';

  @override
  String get filterEvents => 'Events';

  @override
  String get filterClubs => 'Clubs';

  @override
  String get newSection => 'New';

  @override
  String get earlier => 'Earlier';

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String get nothingHereNotif => 'Nothing here';

  @override
  String get eventPass => 'Event Pass';

  @override
  String get eventPassHint => 'Show this code at the door to check in.';

  @override
  String get showMyPass => 'Show my pass';

  @override
  String get scanCheckins => 'Scan check-ins';

  @override
  String get scanInvalidPass => 'Not a valid Event Pass';

  @override
  String get scanWrongEvent => 'Pass belongs to another event';

  @override
  String get scanAlreadyIn => 'already checked in';

  @override
  String get scanNotAdmitted => 'Not admitted';

  @override
  String get scanNoRsvpTitle => 'No RSVP found';

  @override
  String scanNoRsvpBody(String name) {
    return '$name didn\'t RSVP to this event. Admit anyway?';
  }

  @override
  String get scanAdmitAnyway => 'Admit anyway';

  @override
  String checkedInCounter(int checked, int total) {
    return '$checked / $total checked in';
  }

  @override
  String get checkedIn => 'Checked in';

  @override
  String get addPoll => 'Add poll';

  @override
  String get pollQuestionHint => 'Ask a question…';

  @override
  String pollOptionHint(int n) {
    return 'Option $n';
  }

  @override
  String pollVotes(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n votes',
      one: '1 vote',
    );
    return '$_temp0';
  }

  @override
  String get announcement => 'Announcement';

  @override
  String get markAsAnnouncement => 'Post as announcement';

  @override
  String get comments => 'Comments';

  @override
  String get addComment => 'Add a comment…';

  @override
  String get noCommentsYet => 'No comments yet. Be the first!';

  @override
  String get deleteComment => 'Delete comment';

  @override
  String get posts => 'Posts';

  @override
  String get clubs => 'Clubs';

  @override
  String get followers => 'Followers';

  @override
  String get myClubs => 'My Clubs';

  @override
  String get myContent => 'My Content';

  @override
  String get boardMembers => 'Board Members';

  @override
  String get board => 'Board';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get superAdmin => 'Super Admin';

  @override
  String get clubAdmin => 'Club Admin';

  @override
  String get addMajorYear => 'Add major & year';

  @override
  String get addBio => 'Add a bio…';

  @override
  String get noClubsYet => 'You haven\'t followed any clubs yet.';

  @override
  String get exploreClubsHint => 'Explore clubs and follow the ones you like.';

  @override
  String get noBoardMembers => 'No board members yet.';

  @override
  String get approvedHere => 'Approved requests will appear here.';

  @override
  String get noPostsYet => 'No posts yet.';

  @override
  String get noEventsYet => 'No events yet.';

  @override
  String get noFollowersYet => 'No followers yet.';

  @override
  String get notFollowingAnyone => 'Not following anyone yet.';

  @override
  String get changePhoto => 'Change Profile Photo';

  @override
  String get takePhoto => 'Take a Photo';

  @override
  String get useCamera => 'Use your camera right now';

  @override
  String get chooseFromLib => 'Choose from Library';

  @override
  String get pickFromLib => 'Pick from your photo library';

  @override
  String get removePhoto => 'Remove photo';

  @override
  String get majorYearLabel => 'Major & Year';

  @override
  String get selectMajor => 'Select your major';

  @override
  String get selectMajorHint => 'Select major';

  @override
  String get yearLabel => 'Year';

  @override
  String get bioLabel => 'Bio';

  @override
  String get bioHint => 'Tell people a little about yourself';

  @override
  String get useThisPhoto => 'Use this photo?';

  @override
  String get usePhoto => 'Use Photo';

  @override
  String get deletePost => 'Delete post?';

  @override
  String get deletePostMsg => 'This post will be permanently removed.';

  @override
  String get deleteEvent => 'Delete event?';

  @override
  String get deleteEventMsg => 'This event will be permanently removed.';

  @override
  String get eventDeletedConfirmation => 'Event deleted';

  @override
  String get majorNotAdded => 'Major not added';

  @override
  String get yearNotAdded => 'Year not added';

  @override
  String get addBioIntro => 'Add a bio to introduce yourself.';

  @override
  String get home => 'Home';

  @override
  String get events => 'Events';

  @override
  String get search => 'Search';

  @override
  String get alerts => 'Alerts';

  @override
  String get profile => 'Profile';

  @override
  String get admin => 'Admin';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get appearance => 'Appearance';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get switchToDark => 'Switch to dark theme';

  @override
  String get switchToLight => 'Switch to light theme';

  @override
  String get help => 'Help';

  @override
  String get supportAndLegal => 'Support & Legal';

  @override
  String get supportCenter => 'Support Center';

  @override
  String get supportCenterSubtitle => 'Help, FAQs & contact';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get privacyPolicySubtitle => 'How ClubUp handles your data';

  @override
  String get termsOfUse => 'Terms of Use';

  @override
  String get termsOfUseSubtitle => 'Community rules & safety enforcement';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountSubtitle =>
      'Request permanent account & data deletion';

  @override
  String get couldNotOpenPage => 'Could not open this page.';

  @override
  String get account => 'Account';

  @override
  String get logOut => 'Log Out';

  @override
  String get confirmLogoutTitle => 'Log out?';

  @override
  String get confirmLogoutMessage =>
      'Are you sure you want to log out of your account?';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get editProfileSubtitle => 'Photo, bio, major & year';

  @override
  String get changeMyName => 'Change My Name';

  @override
  String get changeNameSubtitle =>
      'Choose the name people see on your student profile.';

  @override
  String get displayName => 'Display name';

  @override
  String get nameTaken => 'That name is already taken.';

  @override
  String get useRealName => 'Use Real Name';

  @override
  String get saveName => 'Save Name';

  @override
  String get notSetConfigure => 'Not set — tap to configure';

  @override
  String get replayTutorial => 'Replay App Tutorial';

  @override
  String get replayTutorialSubtitle =>
      'Take the guided tour of every area again — anytime';

  @override
  String get safetyHero => 'A safe campus community starts with everyone';

  @override
  String get safetyIntro =>
      'Please review and accept the Terms of Use before creating an account or signing in.';

  @override
  String get communitySafetyTerms => 'COMMUNITY SAFETY TERMS';

  @override
  String get zeroTolerance => 'Zero tolerance';

  @override
  String get zeroToleranceBody =>
      'Objectionable content, harassment, threats, hate, sexual exploitation, scams, and abusive users are not allowed.';

  @override
  String get reportHarmfulContent => 'Report harmful content';

  @override
  String get reportHarmfulContentBody =>
      'Use the report option on posts and profiles. ClubUp reviews reports and acts on violations within 24 hours.';

  @override
  String get blockAbusiveUsers => 'Block abusive users';

  @override
  String get blockAbusiveUsersBody =>
      'Blocking reports the account to ClubUp and immediately removes that user and their content from your experience.';

  @override
  String get enforcement => 'Enforcement';

  @override
  String get enforcementBody =>
      'ClubUp may remove violating content and suspend or permanently eject the responsible account.';

  @override
  String get readFullTerms => 'Read full Terms of Use';

  @override
  String get agreeToSafetyTerms =>
      'I agree to the Terms of Use and Community Safety Terms.';

  @override
  String get agreeAndContinue => 'Agree and continue';

  @override
  String get couldNotOpenThisPage => 'Could not open this page.';

  @override
  String get whyReportPost => 'Why are you reporting this post?';

  @override
  String get whyReportUser => 'Why are you reporting this user?';

  @override
  String get whyBlockUser => 'Why are you blocking this user?';

  @override
  String get chooseReportReason =>
      'Choose the reason that best describes the issue. Reports are reviewed within 24 hours.';

  @override
  String moderationReasonLabel(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'harassment': 'Harassment or bullying',
      'hate_or_discrimination': 'Hate or discrimination',
      'sexual_content': 'Sexual or explicit content',
      'violence_or_danger': 'Violence or dangerous behavior',
      'spam_or_scam': 'Spam or scam',
      'other': 'Something else',
    });
    return '$_temp0';
  }

  @override
  String moderationReasonDetail(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'harassment': 'Targets, threatens, or abuses a person or group.',
      'hate_or_discrimination':
          'Attacks people based on a protected characteristic.',
      'sexual_content': 'Contains unwanted nudity or sexual material.',
      'violence_or_danger': 'Threatens harm or promotes dangerous conduct.',
      'spam_or_scam': 'Misleads people or repeatedly posts unwanted material.',
      'other': 'Another violation of the ClubUp Terms of Use.',
    });
    return '$_temp0';
  }

  @override
  String get reportPost => 'Report post';

  @override
  String get reportUser => 'Report user';

  @override
  String get reportUserSubtitle => 'Send this profile to ClubUp for review.';

  @override
  String get blockAndReportUser => 'Block and report user';

  @override
  String get blockAndReportSubtitle =>
      'Immediately hide this user and notify ClubUp.';

  @override
  String blockUserQuestion(String name) {
    return 'Block $name?';
  }

  @override
  String get blockUserExplanation =>
      'Their profile and content will be removed from your experience immediately. ClubUp will also receive a safety report.';

  @override
  String get userReported =>
      'User reported. Our team will review it within 24 hours.';

  @override
  String get reportSendFailed => 'Could not send the report. Please try again.';

  @override
  String get userBlockedAndReported => 'User blocked and reported.';

  @override
  String get userBlockedOffline =>
      'User blocked on this device. The report could not be sent; please try again when online.';

  @override
  String get postReportedAndRemoved =>
      'Post reported and removed from your feed.';

  @override
  String get postHiddenOffline =>
      'Post hidden. The report could not be sent; please try again when online.';

  @override
  String get safetyOptions => 'Safety options';

  @override
  String get contentSafetyRejected =>
      'This content cannot be published because it may violate the ClubUp Community Safety Terms.';

  @override
  String get profileSection => 'Profile';

  @override
  String get clubSection => 'Club';

  @override
  String get clubName => 'Club Name';

  @override
  String get clubNameLabel => 'Club name';

  @override
  String get clubPhoto => 'Club Photo';

  @override
  String get changeClubPhoto => 'Change Club Photo';

  @override
  String get tapToChangeLogo => 'Tap to change your club logo';

  @override
  String get clubCategories => 'Club Categories';

  @override
  String get chooseTagsHint =>
      'Choose tags that help students discover your club.';

  @override
  String get customTags => 'Custom tags';

  @override
  String get customTagsHint => 'Design, Gaming, Culture';

  @override
  String get separateWithCommas => 'Separate custom tags with commas';

  @override
  String get saveCategories => 'Save Categories';

  @override
  String get addDiscoveryTags => 'Add discovery tags';

  @override
  String get clubDescription => 'Club Description';

  @override
  String get clubDescriptionHint => 'What is this club about?';

  @override
  String get manageBoardMembers => 'Manage Board Members';

  @override
  String get manageBoardSubtitle => 'Add or remove board members & roles';

  @override
  String get post => 'Post';

  @override
  String get addPhoto => 'Add photo';

  @override
  String get whatsHappeningAtClub => 'What\'s happening at your club?';

  @override
  String get tapForDetails => 'Tap for details';

  @override
  String get pastEventsHint => 'Events that finished during the last 7 days.';

  @override
  String get upcomingEventsHint => 'What\'s on across campus — next month.';

  @override
  String get yesterday => 'Yesterday';

  @override
  String noNotificationsFor(String label) {
    return 'No ${label}notifications right now. We\'ll let you know when something happens.';
  }

  @override
  String get profilesWillAppear =>
      'Profiles will appear here after users sign up';

  @override
  String get graduate => 'Graduate';

  @override
  String get addedToBothCalendars => 'Added to both calendars';

  @override
  String get enableCalendarAccessHint =>
      'You\'re going! Enable calendar access in Settings to also sync to your phone.';

  @override
  String get publishErrorRlsPolicy =>
      'Could not publish post. Check club_posts RLS policies for this club account.';

  @override
  String get publishErrorMigration =>
      'Could not publish post. Run the latest club_posts SQL migration.';

  @override
  String get publishErrorStorage =>
      'Could not upload photo. Check the post-images bucket policies.';

  @override
  String get publishErrorGeneric =>
      'Could not publish post. Check Supabase settings.';

  @override
  String get confirm => 'Confirm';

  @override
  String get liveNowLabel => 'LIVE';

  @override
  String get clubFallbackName => 'Club';

  @override
  String get clubEmailPasscodeRequired =>
      'Club email and passcode are required';

  @override
  String get passcodeMustBe8Digits => 'Passcode must be exactly 8 digits';

  @override
  String get invalidClubCredentials => 'Invalid club email or passcode';

  @override
  String get clubNotLinked => 'This login is not linked to a club';

  @override
  String get linkedClubNotFound => 'Linked club was not found';

  @override
  String get clubLoginNotReady =>
      'Club login is not ready. Check club_auth_accounts in Supabase.';

  @override
  String get clubAdminLoginTitle => 'Club Admin Login';

  @override
  String get clubAdminLoginSubtitle =>
      'Enter the club email and 8 digit passcode to manage your club.';

  @override
  String get platformAdminLoginTitle => 'Platform Admin Login';

  @override
  String get platformAdminLoginSubtitle =>
      'Restricted access for the ClubUp platform administrator.';

  @override
  String get adminEmailLabel => 'Admin email';

  @override
  String get adminCredentialsRequired =>
      'Admin email and passcode are required';

  @override
  String get invalidAdminCredentials => 'Invalid admin email or passcode';

  @override
  String get notPlatformAdmin =>
      'These credentials are not assigned to the platform administrator';

  @override
  String get clubEmailLabel => 'Club Email';

  @override
  String get eightDigitPasscodeLabel => '8 digit passcode';

  @override
  String get eightDigitsHint => '8 digits';

  @override
  String get forgotPasscode => 'Forgot passcode?';

  @override
  String get signInAsAdmin => 'Sign In as Admin';

  @override
  String get supabaseNotConfigured => 'Supabase is not configured.';

  @override
  String get passwordResetRequestFailed => 'Password reset request failed.';

  @override
  String get couldNotReachResetServer =>
      'Could not reach the password reset server. Please try again.';

  @override
  String resetCredentialTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'passcode': 'Reset passcode',
      'other': 'Reset password',
    });
    return '$_temp0';
  }

  @override
  String get checkYourEmailTitle => 'Check your email';

  @override
  String createNewCredentialTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'passcode': 'Create new passcode',
      'other': 'Create new password',
    });
    return '$_temp0';
  }

  @override
  String credentialUpdatedTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'passcode': 'Passcode updated',
      'other': 'Password updated',
    });
    return '$_temp0';
  }

  @override
  String get enterKuEmailSubtitle => 'Enter the KU email for your account.';

  @override
  String get enterAccountEmailSubtitle => 'Enter the email for your account.';

  @override
  String enterCodeSubtitle(String email) {
    return 'Enter the one-time code sent to $email.';
  }

  @override
  String newCredentialSubtitle(String kind, int length) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'passcode':
          'Use a $length-digit numbers-only passcode for future sign-ins.',
      'other': 'Use a $length-digit numbers-only password for future sign-ins.',
    });
    return '$_temp0';
  }

  @override
  String credentialUpdatedSubtitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'passcode': 'You can now sign in with your new passcode.',
      'other': 'You can now sign in with your new password.',
    });
    return '$_temp0';
  }

  @override
  String get sendCodeButton => 'Send code';

  @override
  String get verifyCodeButton => 'Verify code';

  @override
  String updateCredentialButton(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'passcode': 'Update passcode',
      'other': 'Update password',
    });
    return '$_temp0';
  }

  @override
  String get backToSignIn => 'Back to sign in';

  @override
  String get kuEmailLabel => 'KU Email';

  @override
  String get oneTimeCodeLabel => 'One-time code';

  @override
  String get enterSixDigitCodeHint => 'Enter 6-digit code';

  @override
  String get sendingEllipsis => 'Sending...';

  @override
  String get sendNewCode => 'Send a new code';

  @override
  String newCredentialLabel(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'passcode': 'New passcode',
      'other': 'New password',
    });
    return '$_temp0';
  }

  @override
  String digitPinHint(int length) {
    return '$length-digit PIN';
  }

  @override
  String confirmCredentialLabel(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'passcode': 'Confirm passcode',
      'other': 'Confirm password',
    });
    return '$_temp0';
  }

  @override
  String reenterDigitPinHint(int length) {
    return 'Re-enter $length-digit PIN';
  }

  @override
  String exactlyNDigits(int length) {
    return 'Exactly $length digits';
  }

  @override
  String get numbersOnly => 'Numbers only';

  @override
  String get pleaseEnterKuEmail => 'Please enter your KU email.';

  @override
  String get useKuEmailAddress => 'Use your @ku.edu.tr email address.';

  @override
  String get useValidEmailAddress => 'Enter a valid email address.';

  @override
  String get newCodeSent => 'New code sent.';

  @override
  String get enterSixDigitCode => 'Enter the 6-digit code.';

  @override
  String credentialMustBeNDigits(String kind, int length) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'passcode': 'Passcode must be exactly $length digits.',
      'other': 'Password must be exactly $length digits.',
    });
    return '$_temp0';
  }

  @override
  String credentialNumbersOnly(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'passcode': 'Passcode must contain numbers only.',
      'other': 'Password must contain numbers only.',
    });
    return '$_temp0';
  }

  @override
  String get passwordsDoNotMatch => 'Passwords do not match.';

  @override
  String get aboutThisEvent => 'About this event';

  @override
  String get accountReadyRedirecting =>
      'Your account is ready.\nRedirecting you to sign in.';

  @override
  String actorCommentedOnYourPost(String actor) {
    return '$actor commented on your post';
  }

  @override
  String actorLikedYourPost(String actor) {
    return '$actor liked your post';
  }

  @override
  String actorRsvpdToEvent(String actor, String event) {
    return '$actor RSVP\'d to $event';
  }

  @override
  String get add => 'Add';

  @override
  String get addAPhotoTitle => 'Add a photo';

  @override
  String get addCoverPhotoOptional => 'Add cover photo (optional)';

  @override
  String get addCustomTagHint => 'Add custom tag…';

  @override
  String get addEventToCampusCalendar => 'Add an event to the campus calendar';

  @override
  String get addFollowerAboveHint =>
      'Add a follower above to show them publicly on the Board tab.';

  @override
  String get addImageOrKeepImageless =>
      'Add an image or keep this event imageless';

  @override
  String get addLabel => 'Add';

  @override
  String get addRequiredFieldsBeforePublish =>
      'Add a title, a location and a valid time range before publishing.';

  @override
  String get addSpeaker => 'Add speaker';

  @override
  String get addTimeSlot => 'Add time slot';

  @override
  String get addTitleLocationToContinue =>
      'Add an event title and location to continue.';

  @override
  String get addToCalendarButton => 'Add to Calendar';

  @override
  String get addingEllipsis => 'Adding…';

  @override
  String get adminDashboardTitle => 'Admin Dashboard';

  @override
  String get agenda => 'Agenda';

  @override
  String get allowAccessButton => 'Allow Access';

  @override
  String get allowCalendarAccessTitle => 'Allow Calendar Access';

  @override
  String get alreadyHaveAccount => 'I already have one';

  @override
  String get assignClubRoleLabel => 'Assign club role';

  @override
  String get attendedBadge => 'ATTENDED';

  @override
  String attendedCount(int n) {
    return '$n attended';
  }

  @override
  String get attendees => 'Attendees';

  @override
  String attendingCount(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n attending',
      one: '1 attending',
    );
    return '$_temp0';
  }

  @override
  String attendingViewRsvps(int count) {
    return '$count attending · View RSVPs';
  }

  @override
  String get back => 'Back';

  @override
  String get backTooltip => 'Back';

  @override
  String becauseYouFollowClub(String club) {
    return 'Because you follow $club';
  }

  @override
  String get bestForYouThisWeek => 'Best for You This Week';

  @override
  String get boardMemberFallbackTitle => 'Board Member';

  @override
  String get boardMemberLabel => 'Board Member';

  @override
  String get boardMembersPublicHint =>
      'Followers added here are shown publicly in the Board tab.';

  @override
  String bothInClub(String club) {
    return 'Both in $club';
  }

  @override
  String get byContinuingAcknowledge => 'By continuing you acknowledge our';

  @override
  String get calEventTypeClass => 'Class';

  @override
  String get calEventTypeDeadline => 'Deadline';

  @override
  String get calEventTypeEvent => 'Event';

  @override
  String get calEventTypePersonal => 'Personal';

  @override
  String get calendarAccessDeniedBody =>
      'Calendar access was denied. To add events, please enable it in:\n\nSettings → Privacy & Security → Calendars';

  @override
  String get calendarAccessDeniedTitle => 'Calendar Access Denied';

  @override
  String get calendarAccessRequestBody =>
      'My Clubs would like to save this event to your Calendar app.\n\nYour calendar is only used to add events you choose.';

  @override
  String get calendarAdd => 'Add';

  @override
  String get calendarAddEventButton => '+ Add an event';

  @override
  String get calendarAddFailedGeneric => 'Failed to add event to calendar.';

  @override
  String get calendarAddToPhone => 'Add to phone';

  @override
  String get calendarAddedSuccess => 'Event added to calendar!';

  @override
  String get calendarAddedToCalendarButton => '✓ Added to Calendar';

  @override
  String get calendarAddedToCalendarSnackbar => 'Event added to calendar';

  @override
  String get calendarAddedToPhone => 'Added to phone';

  @override
  String get calendarAlreadyAdded => 'Added to calendar';

  @override
  String get calendarAppleAddFailed => 'Failed to add event to Apple Calendar.';

  @override
  String get calendarDeleteEventButton => 'Delete event';

  @override
  String get calendarDeniedBody =>
      'To sync events to your phone, please allow calendar access in:\n\nSettings → Privacy & Security → Calendars';

  @override
  String get calendarEditEvent => 'Edit event';

  @override
  String get calendarFilterRsvpd => 'RSVP\'d';

  @override
  String calendarItemsCount(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n items',
      one: '$n item',
    );
    return '$_temp0';
  }

  @override
  String calendarItemsThisMonth(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n items this month',
      one: '$n item this month',
    );
    return '$_temp0';
  }

  @override
  String get calendarNewEvent => 'New event';

  @override
  String get calendarNoWritableCalendar =>
      'No writable calendar found on this device.';

  @override
  String get calendarNothingScheduled => 'Nothing scheduled.';

  @override
  String get calendarPermissionCheckFailed =>
      'Unable to check calendar permissions.';

  @override
  String get calendarPrePermissionBody =>
      'To save this event to your phone\'s Calendar app, we need permission to access your calendar.\n\nYour calendar data is only used to add events you choose.';

  @override
  String calendarPreviewLabel(String type) {
    return '$type · Preview';
  }

  @override
  String get calendarRsvpdBadge => 'RSVP\'D';

  @override
  String get calendarYoursTapToEdit => 'Yours · tap to edit';

  @override
  String get campusEmailLabel => 'Campus email';

  @override
  String get campusEventFallback => 'Campus event';

  @override
  String get campusFallbackLocation => 'Campus';

  @override
  String get campusPostFallback => 'Campus post';

  @override
  String campusTodaySummary(String summary) {
    return 'Campus today: $summary';
  }

  @override
  String get categoryAcademic => 'Academic';

  @override
  String get categoryArts => 'Arts';

  @override
  String get categoryBusiness => 'Business';

  @override
  String get categoryCareer => 'Career';

  @override
  String get categoryEngineering => 'Engineering';

  @override
  String get categoryMusic => 'Music';

  @override
  String get categorySocial => 'Social';

  @override
  String get categorySocialImpact => 'Social Impact';

  @override
  String get categorySports => 'Sports';

  @override
  String get categoryTech => 'Tech';

  @override
  String get categoryWellness => 'Wellness';

  @override
  String get changeEventPhoto => 'Change photo';

  @override
  String get changeLabel => 'Change';

  @override
  String get changePhotoButton => 'Change photo';

  @override
  String get checkBackSoonEvents => 'Check back soon for new events.';

  @override
  String get checkYourInboxTitle => 'Check your inbox.';

  @override
  String get choose6DigitPinHint =>
      'Choose a 6-digit PIN — numbers only, no letters or symbols.';

  @override
  String get chooseFromLibraryOption => 'Choose from library';

  @override
  String get chooseYourLanguage => 'Choose your language';

  @override
  String get chooseYourLook => 'Choose your look';

  @override
  String get clearSearchTooltip => 'Clear search';

  @override
  String get clubAdminSignIn => 'Club admin sign in';

  @override
  String get clubAdminsAddMembersHint =>
      'Club admins can add members from Manage board members.';

  @override
  String get clubLeaderboard => 'Club Leaderboard';

  @override
  String get clubMembershipLabel => 'Club membership';

  @override
  String clubMentionedYouInPost(String club) {
    return '$club mentioned you in a post';
  }

  @override
  String get clubNameAppearsAcrossApp =>
      'This appears across the app wherever your club is shown.';

  @override
  String get clubPhotoRemovedLocallyDeleteFailed =>
      'Club photo removed locally, but remote delete failed.';

  @override
  String clubPostedNewEvent(String club, String event) {
    return '$club posted a new event: $event';
  }

  @override
  String clubRoleSemanticLabel(String role) {
    return 'Club role: $role';
  }

  @override
  String clubSharedNewPost(String club) {
    return '$club shared a new post';
  }

  @override
  String clubsCountLabel(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n clubs',
      one: '1 club',
    );
    return '$_temp0';
  }

  @override
  String clubsCountTitle(int count) {
    return 'CLUBS · $count';
  }

  @override
  String clubsInCommonCount(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n clubs in common',
      one: '$n club in common',
    );
    return '$_temp0';
  }

  @override
  String get clubsPickedForYou => 'Clubs picked for you';

  @override
  String get collabBadge => 'Collab';

  @override
  String get collabsTab => 'Collabs';

  @override
  String get completeRequiredFields => 'Please complete the required fields.';

  @override
  String confirmRemovalBody(String name, String clubName) {
    return 'This will permanently remove $name from the board of $clubName. Continue?';
  }

  @override
  String get confirmRemovalTitle => 'Confirm Removal';

  @override
  String confirmRemoveBoardMemberBody(String name) {
    return 'Are you sure you want to remove $name from the board?';
  }

  @override
  String get continueButton => 'Continue';

  @override
  String continueWithTheme(String theme) {
    return 'Continue with $theme';
  }

  @override
  String get couldNotDeleteEventSupabase =>
      'Could not delete event from Supabase.';

  @override
  String get couldNotDeletePostSupabase =>
      'Could not delete post from Supabase.';

  @override
  String get couldNotLoadConnections => 'Could not load connections.';

  @override
  String get couldNotLoadInterests =>
      'Could not load interests. Please try again.';

  @override
  String get couldNotLoadPeople => 'Could not load people from profiles.';

  @override
  String get couldNotLoadProfileOptions =>
      'Could not load profile options from Supabase.';

  @override
  String get couldNotLoadProfileOptionsRetry =>
      'Could not load profile options. Please try again.';

  @override
  String couldNotOpenLinkedIn(String name) {
    return 'Couldn\'t open $name\'s LinkedIn';
  }

  @override
  String get couldNotOpenPhotoCropper => 'Could not open photo cropper.';

  @override
  String get couldNotOpenPrivacyPolicy => 'Could not open the Privacy Policy.';

  @override
  String get couldNotOpenRegistrationForm =>
      'Couldn\'t open the registration form';

  @override
  String get couldNotReachSignupServer =>
      'Could not reach the signup server. Please try again.';

  @override
  String get couldNotRemoveClubMember => 'Could not remove this club member.';

  @override
  String get couldNotSaveChanges => 'Could not save changes.';

  @override
  String get couldNotSaveEventSupabase => 'Could not save event to Supabase.';

  @override
  String get couldNotSaveProfileSupabase =>
      'Could not save profile to Supabase';

  @override
  String get couldNotUpdateBoardRole => 'Could not update board member role.';

  @override
  String get couldNotUpdateClubDescription =>
      'Could not update club description.';

  @override
  String get couldNotUpdateClubFollow => 'Could not update club follow.';

  @override
  String get couldNotUpdateClubName => 'Could not update club name.';

  @override
  String get couldNotUpdateFollow =>
      'Could not update follow. Please try again.';

  @override
  String get couldNotUpdateName => 'Could not update name.';

  @override
  String get couldNotUploadClubPhoto => 'Could not upload club photo.';

  @override
  String get createAccount => 'Create account';

  @override
  String get createPasswordTitle => 'Create a password.';

  @override
  String get createSheetTitle => 'Create';

  @override
  String get createSomethingInspiring => 'Create something inspiring';

  @override
  String get cropPhoto => 'Crop Photo';

  @override
  String get cropPhotoTitle => 'Crop Photo';

  @override
  String currentBoardMembersHeader(int n) {
    return 'Current Board Members ($n)';
  }

  @override
  String get dark => 'Dark';

  @override
  String get dateLabel => 'Date';

  @override
  String daysAgo(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '${n}d ago',
      one: '1d ago',
    );
    return '$_temp0';
  }

  @override
  String daysAgoLong(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days ago',
      one: '$n day ago',
    );
    return '$_temp0';
  }

  @override
  String daysAgoShort(int n) {
    return '${n}d ago';
  }

  @override
  String daysAgoSuffix(int n) {
    return '${n}d ago';
  }

  @override
  String daysCount(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String daysShort(int n) {
    return '${n}d';
  }

  @override
  String get deleteEventButton => 'Delete Event';

  @override
  String get deleteEventFromClubMsg =>
      'This event will be permanently removed from your club.';

  @override
  String get deleteEventMenuItem => 'Delete event';

  @override
  String deleteEventPermanentWarning(String title) {
    return '\"$title\" and all RSVP data will be permanently removed. This cannot be undone.';
  }

  @override
  String get deletePostAction => 'Delete post';

  @override
  String get deletePostFeedBody =>
      'This post will be removed from the home feed.';

  @override
  String get deletePostFromClubMsg =>
      'This post will be permanently removed from your club.';

  @override
  String get deletePostMenuItem => 'Delete post';

  @override
  String get deleteThisEventConfirm => 'Delete this event?';

  @override
  String descriptionAppearsOnClubProfile(String clubName) {
    return 'This appears on $clubName’s profile across the app.';
  }

  @override
  String get descriptionLabel => 'Description';

  @override
  String get didntGetCode => 'Didn\'t get it?';

  @override
  String get discoverClubDescriptionFallback =>
      'Discover what this club is all about.';

  @override
  String get done => 'Done';

  @override
  String get doubleMajorLabel => 'Double major';

  @override
  String get dowFri => 'Fri';

  @override
  String get dowMon => 'Mon';

  @override
  String get dowSat => 'Sat';

  @override
  String get dowSun => 'Sun';

  @override
  String get dowThu => 'Thu';

  @override
  String get dowTue => 'Tue';

  @override
  String get dowWed => 'Wed';

  @override
  String get edit => 'Edit';

  @override
  String get editClubRoleLabel => 'Edit club role';

  @override
  String get editEventButton => 'Edit Event';

  @override
  String get editEventTitle => 'Edit Event';

  @override
  String get endMustBeAfterStartShort => 'End must be after start';

  @override
  String get endTimeAfterStartTime => 'End time must be after the start time.';

  @override
  String get endsLabel => 'Ends';

  @override
  String get enterEmailAndPassword => 'Please enter your email and password';

  @override
  String get enterFullSixDigitCode => 'Enter the full 6-digit code.';

  @override
  String get eventDescriptionHint => 'Tell people what this event is about...';

  @override
  String get eventFallbackTitle => 'Event';

  @override
  String eventInDays(int days) {
    return 'In ${days}d';
  }

  @override
  String get eventLabel => 'Event';

  @override
  String get eventLinkCopied => 'Event link copied to clipboard';

  @override
  String get eventReminderChannelDescription =>
      'Reminders for events you RSVP to';

  @override
  String get eventReminderChannelName => 'Event reminders';

  @override
  String get eventReminderTitle => 'Event reminder';

  @override
  String eventStartsInOneHour(String title) {
    return '$title starts in 1 hour';
  }

  @override
  String eventStartsTomorrow(String title) {
    return '$title starts tomorrow';
  }

  @override
  String get eventStepBasics => 'Basics';

  @override
  String get eventStepDetails => 'Details';

  @override
  String get eventStepReview => 'Review';

  @override
  String get eventStepWhen => 'When';

  @override
  String get eventTitleHint => 'e.g. Spring Hackathon';

  @override
  String get eventTitleLabel => 'Event Title';

  @override
  String get eventTitlePlaceholder => 'Event title';

  @override
  String get eventTitlePreviewPlaceholder => 'Event title preview';

  @override
  String get eventViewersTitle => 'Event Viewers';

  @override
  String eventsCount(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n events',
      one: '1 event',
    );
    return '$_temp0';
  }

  @override
  String eventsCountLabel(int count) {
    return 'Events ($count)';
  }

  @override
  String get externalSignupBadge => 'External sign-up';

  @override
  String get externalSignupLinkSubtitle =>
      'Attendees register on your form (Google Form, Eventbrite…)';

  @override
  String get externalSignupLinkTitle => 'External sign-up link';

  @override
  String get fallbackNameGreeting => 'there';

  @override
  String get feedPreviewHint => 'This is how it will appear in the Home Feed.';

  @override
  String filterQueryLabel(String query) {
    return '· \"$query\"';
  }

  @override
  String get findClubsAction => 'Find clubs';

  @override
  String get finishSetupButton => 'Finish setup';

  @override
  String get followAll => 'Follow all';

  @override
  String get followRequestAccepted => 'Your follow request was accepted.';

  @override
  String followRequestMessage(String name) {
    return '$name wants to follow you.';
  }

  @override
  String get followToSeePosts => 'Follow to see their posts.';

  @override
  String get followedClubsTitle => 'Followed clubs';

  @override
  String followersAndRsvpsSummary(int followers, int rsvps) {
    return '$followers followers · $rsvps RSVPs';
  }

  @override
  String followersCountHeader(int n) {
    return 'Followers ($n)';
  }

  @override
  String get followersLoadError => 'Followers could not be loaded.';

  @override
  String get followingCheckLabel => 'Following ✓';

  @override
  String followingClubsCount(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Following $n clubs',
      one: 'Following 1 club',
    );
    return '$_temp0';
  }

  @override
  String get followingFilterLabel => 'following';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get fullNameLabel => 'Full name';

  @override
  String goingCount(int n) {
    return '$n going';
  }

  @override
  String get gotIt => 'Got it';

  @override
  String get guestName => 'Guest';

  @override
  String get happeningNow => 'Happening now';

  @override
  String get happeningNowBadge => 'HAPPENING NOW';

  @override
  String get happeningNowHeader => 'Happening Now';

  @override
  String get happeningNowInline => 'Happening now';

  @override
  String get happeningNowLabel => 'HAPPENING NOW';

  @override
  String get heroCampusLine1 => 'Your campus,';

  @override
  String get heroCampusLine2 => 'in your pocket.';

  @override
  String get heroSubtext =>
      'Class schedules, dining, events, and the people who make Koç University home.';

  @override
  String get highlight => 'Highlight';

  @override
  String get hostedBy => 'HOSTED BY';

  @override
  String hoursAgo(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '${n}h ago',
      one: '1h ago',
    );
    return '$_temp0';
  }

  @override
  String hoursAgoSuffix(int n) {
    return '${n}h ago';
  }

  @override
  String hoursShort(int n) {
    return '${n}h';
  }

  @override
  String inDaysCount(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'In $n days',
      one: 'In 1 day',
    );
    return '$_temp0';
  }

  @override
  String inNDays(int days) {
    return 'In $days days';
  }

  @override
  String get incorrectEmailOrPassword => 'Incorrect email or password';

  @override
  String get insightsTitle => 'Insights';

  @override
  String interestMatchCount(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n interest matches',
      one: '1 interest match',
    );
    return '$_temp0';
  }

  @override
  String get justNow => 'Just now';

  @override
  String get justNowShort => 'now';

  @override
  String get kuStudentLabel => 'KU student';

  @override
  String get lessLabel => 'less';

  @override
  String get letsGoArrow => 'Let\'s go →';

  @override
  String get light => 'Light';

  @override
  String likesCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n likes',
      one: '1 like',
    );
    return '$_temp0';
  }

  @override
  String get linkedinOptionalLabel => 'LinkedIn (optional)';

  @override
  String liveNowCount(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n live now',
      one: '1 live now',
    );
    return '$_temp0';
  }

  @override
  String get liveNowFilterLabel => 'live now';

  @override
  String liveNowFollowingClub(String club) {
    return 'Live now · you follow $club';
  }

  @override
  String get liveNowOnCampus => 'Live now on campus';

  @override
  String get loadingConnections => 'Loading connections...';

  @override
  String get loadingMajors => 'Loading majors...';

  @override
  String get loadingMembers => 'Loading members...';

  @override
  String get locationHint => 'Write the event location';

  @override
  String get locationLabel => 'Location';

  @override
  String get locationOptionalLabel => 'Location (optional)';

  @override
  String get logIn => 'Log in';

  @override
  String get majorFieldLabel => 'Major';

  @override
  String get majorLabel => 'Major';

  @override
  String get managingBadge => 'MANAGING';

  @override
  String matchesYourInterest(String tag) {
    return 'Matches your $tag interest';
  }

  @override
  String memberCountLabel(int n) {
    return '$n members';
  }

  @override
  String get memberProfilesLoadError => 'Member profiles could not be loaded.';

  @override
  String get memberRoleDefault => 'Member';

  @override
  String get memberRoleFallback => 'Member';

  @override
  String get memberRoleLabel => 'Member';

  @override
  String get members => 'Members';

  @override
  String membersCategoryLabel(num count, String category) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0 · $category';
  }

  @override
  String membersCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String membersCountLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get membersLabel => 'Members';

  @override
  String membersMatchInterests(int count) {
    return '$count members · matches your interests';
  }

  @override
  String get mentionTypeClub => 'Club';

  @override
  String get mentionTypeStudent => 'Student';

  @override
  String minorIn(String majors) {
    return 'Minor in $majors';
  }

  @override
  String get minorLabel => 'Minor';

  @override
  String minutesAgo(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '${n}m ago',
      one: '1m ago',
    );
    return '$_temp0';
  }

  @override
  String minutesAgoSuffix(int n) {
    return '${n}m ago';
  }

  @override
  String minutesShort(int n) {
    return '${n}m';
  }

  @override
  String monthAbbr(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      '1': 'JAN',
      '2': 'FEB',
      '3': 'MAR',
      '4': 'APR',
      '5': 'MAY',
      '6': 'JUN',
      '7': 'JUL',
      '8': 'AUG',
      '9': 'SEP',
      '10': 'OCT',
      '11': 'NOV',
      '12': 'DEC',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get monthApr => 'Apr';

  @override
  String get monthApril => 'April';

  @override
  String get monthAug => 'Aug';

  @override
  String get monthAugust => 'August';

  @override
  String get monthDec => 'Dec';

  @override
  String get monthDecember => 'December';

  @override
  String get monthFeb => 'Feb';

  @override
  String get monthFebruary => 'February';

  @override
  String get monthJan => 'Jan';

  @override
  String get monthJanuary => 'January';

  @override
  String get monthJul => 'Jul';

  @override
  String get monthJuly => 'July';

  @override
  String get monthJun => 'Jun';

  @override
  String get monthJune => 'June';

  @override
  String get monthMar => 'Mar';

  @override
  String get monthMarch => 'March';

  @override
  String get monthMay => 'May';

  @override
  String get monthNov => 'Nov';

  @override
  String get monthNovember => 'November';

  @override
  String get monthOct => 'Oct';

  @override
  String get monthOctober => 'October';

  @override
  String get monthSep => 'Sep';

  @override
  String get monthSeptember => 'September';

  @override
  String get moreLabel => 'more';

  @override
  String mutualBadgeCount(String mutualLabel) {
    return '$mutualLabel mutuals';
  }

  @override
  String mutualFriendCountLabel(String mutualLabel) {
    return 'Followed by $mutualLabel people you follow';
  }

  @override
  String mutualFriendNamed(String name) {
    return 'Followed by $name';
  }

  @override
  String mutualFriendNamedPlus(String name, int extra) {
    return 'Followed by $name + $extra more';
  }

  @override
  String get myCalendarTitle => 'My Calendar';

  @override
  String get myProfileTitle => 'My Profile';

  @override
  String get newEventTitle => 'New Event';

  @override
  String get newLabel => 'New';

  @override
  String get newPostTitle => 'New Post';

  @override
  String get newThisWeek => 'NEW THIS WEEK';

  @override
  String get next => 'Next';

  @override
  String get nextArrow => 'Next →';

  @override
  String get nextMonthLabel => '· next month';

  @override
  String get noBioYet => 'No bio yet.';

  @override
  String get noClubsFound => 'No clubs found.';

  @override
  String get noClubsYetShort => 'No clubs yet.';

  @override
  String get noCollaborationsYet =>
      'No collaborations yet.\nPosts that tag this club with @ will appear here.';

  @override
  String get noEventImageSelected => 'No event image selected';

  @override
  String get noFollowedClubsYet => 'No followed clubs yet.';

  @override
  String get noLikesYet => 'No likes yet';

  @override
  String get noLiveEventNow => 'No event is live at the moment.';

  @override
  String get noMatchesFoundDot => 'No matches found.';

  @override
  String get noMatchingMajor => 'No matching major';

  @override
  String get noMembersToShowYet => 'No members to show yet.';

  @override
  String get noNewClubsToSuggest =>
      'No new clubs to suggest — you\'re already well-connected!';

  @override
  String get noPastEventsToShow => 'No past events to show.';

  @override
  String get noRepeatedNumbersSideBySide => 'No same numbers side by side';

  @override
  String get noRsvpsYet => 'No RSVPs yet.';

  @override
  String get noSavedEventsYet => 'No saved events yet';

  @override
  String get noSavedPostsYet => 'No saved posts yet';

  @override
  String get noSequentialNumbersSideBySide =>
      'No sequential numbers side by side';

  @override
  String get noTitleSet => 'No title set';

  @override
  String get noViewsYet => 'No views yet';

  @override
  String get notComing => 'Not Coming';

  @override
  String get notNow => 'Not Now';

  @override
  String get nothingHereRightNow => 'Nothing here right now.';

  @override
  String nowFollowingPerson(String name) {
    return 'You are now following $name.';
  }

  @override
  String get nowSegmentLabel => 'Now';

  @override
  String get officialClubLabel => 'Official Club';

  @override
  String get oneMutualBadge => '1 mutual';

  @override
  String get oneMutualFriend => 'Followed by 1 person you follow';

  @override
  String get onlyKuAddressesAccepted =>
      'Only @ku.edu.tr addresses are accepted.';

  @override
  String get onlyKuEmailInfoText =>
      'Only @ku.edu.tr addresses are accepted. Personal emails won\'t work.';

  @override
  String get onlyOwningClubCanDelete =>
      'Only the club that owns this post can delete it.';

  @override
  String get onlyPosterCanViewRsvps => 'Only the event poster can view RSVPs.';

  @override
  String get openSettingsButton => 'Open Settings';

  @override
  String get optional => 'Optional';

  @override
  String get partnerClubsHeader => 'Partner Clubs';

  @override
  String get passwordFieldLabel => 'Password';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordRulesError =>
      'Use 6 numbers with no repeated or sequential numbers side by side.';

  @override
  String get pastBadge => 'PAST';

  @override
  String peopleCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n people',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String get peopleYouFollowGoing => 'People you follow are going';

  @override
  String percentFull(int pct) {
    return '$pct% full';
  }

  @override
  String get photoAdded => 'Photo added';

  @override
  String get photoLabel => 'Photo';

  @override
  String get photoRemovedLocallyDeleteFailed =>
      'Photo removed locally, but remote delete failed.';

  @override
  String get photoSavedLocallyUploadFailed =>
      'Photo saved locally, but upload failed.';

  @override
  String get pickAppearanceHint =>
      'Pick the appearance that feels right. Tap to preview — you can always change it later in Settings.';

  @override
  String get pickAsManyInterests =>
      'Pick as many as you like. We\'ll surface what matters to you.';

  @override
  String pickAtLeastNInterests(int min) {
    return 'Pick at least $min to continue.';
  }

  @override
  String get pickFewMatchHint =>
      'Pick a few — we\'ll match you with clubs, events, and people. ';

  @override
  String get pickLanguageHint =>
      'Pick the language for the app. You can always change it later in Settings.';

  @override
  String get pinToTop => 'Pin to top';

  @override
  String get pleaseEnterFirstLastName =>
      'Please enter your first and last name.';

  @override
  String get pleaseEnterFullName => 'Please enter your full name.';

  @override
  String get pleaseEnterUniversityEmail =>
      'Please enter your university email.';

  @override
  String get pleasePickMajorFromList => 'Please pick a major from the list.';

  @override
  String get pleaseSelectMajor => 'Please select your major.';

  @override
  String get pleaseSelectYear => 'Please select your year.';

  @override
  String get popularOnCampus => 'Popular on campus';

  @override
  String get postDeletedConfirmation => 'Post deleted';

  @override
  String get postLikes => 'Post likes';

  @override
  String get postLinkCopied => 'Post link copied to clipboard';

  @override
  String get postViewersTitle => 'Post Viewers';

  @override
  String get postViews => 'Post views';

  @override
  String postingAsClub(String clubName) {
    return 'Posting as $clubName';
  }

  @override
  String get postingAsLabel => 'Posting as';

  @override
  String postsCountLabel(int count) {
    return 'Posts ($count)';
  }

  @override
  String get postsFeaturingClub => 'Posts featuring this club';

  @override
  String get presidentSecretaryHint => 'e.g. President, Secretary…';

  @override
  String get prioritiseEventsSchedule =>
      'We\'ll prioritise events that fit your schedule.';

  @override
  String profileLinkCopied(String name) {
    return '$name\'s profile link copied to clipboard';
  }

  @override
  String get profileUpdated => 'Profile updated';

  @override
  String get programme => 'Programme';

  @override
  String get programmeLabel => 'Programme';

  @override
  String get programmeSectionSubtitle => 'Add a timetable for your event';

  @override
  String get publishErrorGenericEvent =>
      'Could not publish event. Check Supabase settings.';

  @override
  String get publishErrorMigrationEvent =>
      'Could not publish event. Run the latest events SQL migration.';

  @override
  String get publishErrorRlsPolicyEvent =>
      'Could not publish event. Check events RLS policies for this club account.';

  @override
  String get publishErrorStorageEvent =>
      'Could not upload event image. Check the event-images bucket policies.';

  @override
  String get publishEventButton => 'Publish Event';

  @override
  String get quickSetupSteps => 'Quick setup — just 4 steps';

  @override
  String get readyToPost => 'Ready to post?';

  @override
  String get recapLabel => 'Recap';

  @override
  String registeredCount(int n) {
    return '$n registered';
  }

  @override
  String get registration => 'Registration';

  @override
  String get registrationLabel => 'Registration';

  @override
  String get registrationSectionSubtitle =>
      'Send attendees to your own sign-up form';

  @override
  String get remindMeLabel => 'Remind me';

  @override
  String get remindedLabel => 'Remind ✓';

  @override
  String get reminderRemoved => 'Reminder removed';

  @override
  String get reminderSetMsg =>
      'Reminder set — we\'ll alert you before it starts';

  @override
  String get removeBoardMemberTitle => 'Remove Board Member';

  @override
  String get removeFromBoardLabel => 'Remove from board';

  @override
  String get removeFromClubLabel => 'Remove from club';

  @override
  String get removeFromSaved => 'Remove from saved';

  @override
  String get removeLabel => 'Remove';

  @override
  String get removeRoleLabel => 'Remove role';

  @override
  String removedFromBoard(String name) {
    return '$name removed from the board.';
  }

  @override
  String get removedFromSaved => 'Removed from saved';

  @override
  String get requested => 'Requested';

  @override
  String get requestedLabel => 'Requested';

  @override
  String get resendCodeButton => 'Resend code';

  @override
  String resendInTime(String time) {
    return 'Resend in $time';
  }

  @override
  String resultsCountLabel(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n results',
      one: '1 result',
    );
    return '$_temp0';
  }

  @override
  String get reviewSectionSubtitle => 'Here\'s how your event will appear';

  @override
  String get roleDeptHint => 'e.g. History';

  @override
  String get roleOrDepartmentLabel => 'Role / department';

  @override
  String rsvpdAt(String timestamp) {
    return 'RSVP\'d $timestamp';
  }

  @override
  String get rsvpsBadge => 'RSVPs';

  @override
  String get rsvpsLabel => 'RSVPs';

  @override
  String get saveChangesButton => 'Save Changes';

  @override
  String get savedPostsStudentsOnly =>
      'Saved posts are only available for students.';

  @override
  String get savedPostsTooltip => 'Saved posts';

  @override
  String get savedTitle => 'Saved';

  @override
  String get savedToEvents => 'Saved to your events';

  @override
  String get savingEllipsis => 'Saving...';

  @override
  String get searchFollowersHint => 'Search followers by name...';

  @override
  String get searchMajorsHint => 'Search majors';

  @override
  String get searchYourMajor => 'Search your major...';

  @override
  String seatsTaken(int taken, int capacity) {
    return '$taken of $capacity seats taken';
  }

  @override
  String get selectClubHint => 'Select club';

  @override
  String get selectDoubleMajorHint => 'Select a double major';

  @override
  String get selectMinorHint => 'Select a minor';

  @override
  String selectedOfMinCount(int selected, int min) {
    return '($selected of $min min.)';
  }

  @override
  String get sendCodeToConfirmKocStudent =>
      'We\'ll send a code to confirm you\'re a Koç student.';

  @override
  String get sessionTitleRequiredHint => 'Session title (required)';

  @override
  String get setPasswordButton => 'Set password';

  @override
  String setTitleForMember(String name) {
    return 'Set title for $name';
  }

  @override
  String get setTitleTooltip => 'Set title';

  @override
  String get setUp => 'Set up';

  @override
  String get shareProfileTooltip => 'Share profile';

  @override
  String get shareUpdateWithFollowers => 'Share an update with your followers';

  @override
  String sharesCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n shares',
      one: '1 share',
    );
    return '$_temp0';
  }

  @override
  String showEventsForSelectedDates(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Show events for $n selected dates',
      one: 'Show events for 1 selected date',
    );
    return '$_temp0';
  }

  @override
  String get showFullCaptionSemantic => 'Show full caption';

  @override
  String get showLessCaptionSemantic => 'Show less caption';

  @override
  String get showsOnCampusProfile => 'This shows up on your campus profile.';

  @override
  String get signUp => 'Sign up';

  @override
  String signUpOnClubForm(String url) {
    return 'Sign up on the club\'s form · $url';
  }

  @override
  String get signupRequestFailed => 'Signup request failed.';

  @override
  String get signupServerNotConfigured =>
      'Supabase is not configured. Start the app with SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY.';

  @override
  String get signupUrlLabel => 'Sign-up URL';

  @override
  String get skipSetup => 'Skip setup';

  @override
  String get skipTour => 'Skip tour';

  @override
  String get speakerNameHint => 'e.g. Prof. Elif Yıldız';

  @override
  String get speakerNameLabel => 'Speaker name';

  @override
  String get speakers => 'Speakers';

  @override
  String get speakersLabel => 'Speakers';

  @override
  String get speakersSectionSubtitle =>
      'Optional — add speaker name, role & LinkedIn';

  @override
  String get startExploring => 'Start exploring';

  @override
  String get startsLabel => 'Starts';

  @override
  String stepProgressLabel(int current, int total, String title) {
    return 'Step $current of $total · $title';
  }

  @override
  String get studentFallbackName => 'A student';

  @override
  String get studentIdLabel => 'STUDENT ID';

  @override
  String get studentPasswordMustBe6Digits =>
      'Student password must be exactly 6 digits.';

  @override
  String get studentPasswordRule =>
      'Use 6 numbers with no repeated or sequential numbers side by side.';

  @override
  String get studentProfileTitle => 'Student Profile';

  @override
  String get students => 'Students';

  @override
  String studentsAreMembersCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count students are members',
      one: '$count student is a member',
    );
    return '$_temp0';
  }

  @override
  String get subtitleSpeakerOptionalHint => 'Subtitle / speaker (optional)';

  @override
  String get suggestClubsFitField =>
      'We\'ll suggest clubs that fit your field.';

  @override
  String get tags => 'Tags';

  @override
  String get tagsLabel => 'Tags';

  @override
  String get tagsSectionSubtitle => 'Create your own tags for discovery';

  @override
  String get takePhotoOption => 'Take a photo';

  @override
  String get tapBookmarkEventHint =>
      'Tap the bookmark icon on any event to keep it here.';

  @override
  String get tapBookmarkPostHint =>
      'Tap the bookmark icon on any post to keep it here.';

  @override
  String get tapPublishEventHint =>
      'Tap Publish Event to share this event with your followers.';

  @override
  String get tapSaveChangesHint => 'Tap Save Changes to update this event.';

  @override
  String get tapToPickFromCameraOrLibrary =>
      'Tap to pick from camera or library';

  @override
  String get tapToPickPhotoHint => 'Tap to pick from camera or library';

  @override
  String get tellUsAboutYouTitle => 'Tell us about you.';

  @override
  String get tellUsInterests =>
      'Tell us your interests and we\'ll personalise this for you.';

  @override
  String get templateLabel => 'Template';

  @override
  String thisWeekEventsCount(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n this week',
      one: '1 this week',
    );
    return '$_temp0';
  }

  @override
  String get time => 'Time';

  @override
  String timeAgoDays(int days) {
    return '${days}d ago';
  }

  @override
  String timeAgoHours(int hours) {
    return '${hours}h ago';
  }

  @override
  String timeAgoInDays(int days) {
    return 'in ${days}d';
  }

  @override
  String timeAgoInHours(int hours) {
    return 'in ${hours}h';
  }

  @override
  String get timeAgoJustNow => 'just now';

  @override
  String timeAgoMinutes(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String get timeAgoSoon => 'soon';

  @override
  String get titleFieldLabel => 'Title';

  @override
  String todayAtTime(String time) {
    return 'Today · $time';
  }

  @override
  String todayEventsCount(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n today',
      one: '1 today',
    );
    return '$_temp0';
  }

  @override
  String get topPosts => 'Top posts';

  @override
  String totalCount(int n) {
    return '$n total';
  }

  @override
  String get tune => 'Tune';

  @override
  String get tutorialDescAlertsClub =>
      'New followers and event activity collect here. Tap an alert to open it, or clear them all with this button.';

  @override
  String tutorialDescAppearanceReplay(String replayLabel) {
    return 'The gear opens Settings — appearance and “$replayLabel” whenever you want this tour again.';
  }

  @override
  String get tutorialDescBoardAppearanceReplay =>
      'The gear opens Settings — add or remove board members, switch appearance, and replay this tour whenever you want.';

  @override
  String get tutorialDescClubProfile =>
      'This is your club’s public profile. Switch tabs to manage posts and events — tap the ⋯ menu on any of yours to pin or delete it, or tap an event’s attendee count to see who’s coming.';

  @override
  String get tutorialDescExploreOwnPace =>
      'That’s the tour. It won’t pop up again automatically — replay it anytime from Profile → Settings.';

  @override
  String get tutorialDescFeedYourWay =>
      'Switch between Following and All to control what you see. Like, RSVP, save, and share right from each post.';

  @override
  String get tutorialDescFindPeopleClubs =>
      'Search students by name or major, and clubs by name. Use the tabs above to switch between People and Clubs.';

  @override
  String get tutorialDescFiveSections =>
      'This bar stays with you everywhere: Home, Events, Search, Alerts, and Profile. The active one turns red.';

  @override
  String get tutorialDescFourSections =>
      'Home, Events, Alerts, and Profile stay with you everywhere. The center button replaces Search — it’s reserved for posting.';

  @override
  String get tutorialDescInsights =>
      'Track views, likes, and top posts so you know what your followers respond to.';

  @override
  String get tutorialDescPostNewEvent =>
      'Tap the center button anytime to open the event form — title, time, location, and audience.';

  @override
  String get tutorialDescQuickTextUpdates =>
      'This composer posts a quick update to your club’s followers — no need for the full event form for a text-only post.';

  @override
  String get tutorialDescRsvpOneTap =>
      'Tap RSVP to mark you’re going — it turns to “Going” and can flow into your calendar. Search and filter the agenda up top.';

  @override
  String get tutorialDescRunClub =>
      'A quick tour of the tools you get as a club admin — we’ll point to the real buttons as we go.';

  @override
  String get tutorialDescStayInLoopStudent =>
      'Follows, club posts, and event changes collect here. Tap an alert to open it, filter with the chips, or clear them all with this button.';

  @override
  String get tutorialDescThisIsYou =>
      'Tap your photo, name, or bio to edit them so classmates recognize you. Your clubs, RSVPs, and stats live here too.';

  @override
  String get tutorialDescWelcome =>
      'A quick, tappable tour of the app — we’ll point to the real buttons as we go.';

  @override
  String get tutorialEyebrowCreate => 'Create';

  @override
  String get tutorialEyebrowGettingAround => 'Getting around';

  @override
  String get tutorialEyebrowInsights => 'Insights';

  @override
  String get tutorialEyebrowWelcome => 'Welcome';

  @override
  String get tutorialEyebrowYourClub => 'Your club';

  @override
  String get tutorialEyebrowYoureSet => 'You’re set';

  @override
  String get tutorialTipActiveSectionRed => 'The active section turns red.';

  @override
  String get tutorialTipAddPhotoBiggerPost =>
      'Add a photo for a bigger, more visible post.';

  @override
  String get tutorialTipAllMixes => 'All mixes in campus recommendations.';

  @override
  String get tutorialTipBadgeMeansNew =>
      'A badge on the bar means something’s new.';

  @override
  String get tutorialTipBadgesFlag => 'Badges flag new activity.';

  @override
  String get tutorialTipBoardListsMembers =>
      'Board lists your club’s board members and titles.';

  @override
  String get tutorialTipBoardManagementSettings =>
      'Board management lives under your club’s section in Settings.';

  @override
  String get tutorialTipCollabsJointEvents =>
      'Collabs shows joint events with other clubs.';

  @override
  String get tutorialTipEventShowsUpRightAway =>
      'Your event shows up in Events for everyone right away.';

  @override
  String get tutorialTipFilterByDate =>
      'Filter by date, audience, or what’s live now.';

  @override
  String get tutorialTipFollowJoin =>
      'Follow people and join clubs from the results.';

  @override
  String get tutorialTipFollowersFollowing =>
      'Tap Followers / Following to see who’s who.';

  @override
  String get tutorialTipFollowingShows =>
      'Following shows only clubs you follow.';

  @override
  String get tutorialTipFollowsRsvpsSaves =>
      'Your follows, RSVPs, and saves personalize the app.';

  @override
  String get tutorialTipHomeFeed => 'Home is your personalized feed.';

  @override
  String get tutorialTipOpenEventDetails => 'Open any event for full details.';

  @override
  String get tutorialTipOpenProfileBeforeFollow =>
      'Open a profile before you follow.';

  @override
  String get tutorialTipOpeningClearsBadge =>
      'Opening this tab clears the badge.';

  @override
  String get tutorialTipSkipTour => 'Skip tour is always in the top-right.';

  @override
  String get tutorialTipSwitchLightDark =>
      'Switch between light and dark mode here.';

  @override
  String get tutorialTipTapNext => 'Tap Next, or tap anywhere, to advance.';

  @override
  String get tutorialTipUpNextEvent => 'Your “Up next” event is one tap away.';

  @override
  String get tutorialTipUseBack => 'Use Back to revisit a step.';

  @override
  String get tutorialTitleAppearanceReplay => 'Appearance & replay';

  @override
  String get tutorialTitleBoardAppearanceReplay => 'Board, appearance & replay';

  @override
  String get tutorialTitleExploreOwnPace => 'Explore at your own pace';

  @override
  String get tutorialTitleFeedYourWay => 'Your feed, your way';

  @override
  String get tutorialTitleFindPeopleClubs => 'Find people & clubs';

  @override
  String get tutorialTitleFiveSections => 'Your five sections';

  @override
  String get tutorialTitleFourSections => 'Your four sections';

  @override
  String get tutorialTitlePostNewEvent => 'Post a new event';

  @override
  String get tutorialTitlePostsEventsCollabsBoard =>
      'Posts, Events, Collabs, Board';

  @override
  String get tutorialTitleQuickTextUpdates => 'Quick text updates';

  @override
  String get tutorialTitleRsvpOneTap => 'RSVP in one tap';

  @override
  String get tutorialTitleRunClubFromHere => 'Run your club from here';

  @override
  String get tutorialTitleRunClubOwnPace => 'Run your club at your own pace';

  @override
  String get tutorialTitleSeeWhatsLanding => 'See what’s landing';

  @override
  String get tutorialTitleStayInLoop => 'Stay in the loop';

  @override
  String get tutorialTitleThisIsYou => 'This is you';

  @override
  String get tutorialTitleYourCampus => 'Your campus, in one place';

  @override
  String get typeAtToTagHint => 'Type @ to tag a club or student';

  @override
  String get typeLabel => 'Type';

  @override
  String unfollowedPerson(String name) {
    return 'You unfollowed $name.';
  }

  @override
  String get universityEmailLabel => 'University email';

  @override
  String get universityYearLabel => 'University year';

  @override
  String get unknownUser => 'Unknown User';

  @override
  String unopenedEventsCount(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n unopened events',
      one: '1 unopened event',
    );
    return '$_temp0';
  }

  @override
  String get unpinFromTop => 'Unpin from top';

  @override
  String get untitledLabel => 'Untitled';

  @override
  String get upcomingBadge => 'UPCOMING';

  @override
  String get upcomingSegmentLabel => 'Upcoming';

  @override
  String get updateYourCommunity => 'Update your community';

  @override
  String get verifyButton => 'Verify';

  @override
  String get view => 'View';

  @override
  String get viewChevron => 'View ›';

  @override
  String get viewLabel => 'View';

  @override
  String get viewProfileLabel => 'View profile';

  @override
  String viewsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n views',
      one: '1 view',
    );
    return '$_temp0';
  }

  @override
  String get weSentCodeToPrefix => 'We sent a 6-digit code to\n';

  @override
  String weeksAgo(int n) {
    return '${n}w ago';
  }

  @override
  String weeksShort(int n) {
    return '${n}w';
  }

  @override
  String get welcomeBackCampusHighlight => 'campus';

  @override
  String get welcomeBackToYourPrefix => 'Welcome back to\nyour ';

  @override
  String get welcomeToKoc => 'WELCOME TO KOÇ';

  @override
  String get whatAreYouInto => 'What are you into?';

  @override
  String get whatsHappeningHint => 'What\'s happening?';

  @override
  String get whatsYourMajor => 'What\'s your major?';

  @override
  String get whatsYourScene => 'What\'s your scene?';

  @override
  String get whatsYourSchoolEmail => 'What\'s your\nschool email?';

  @override
  String whenClubPostsHint(String clubName) {
    return 'When $clubName posts, it\'ll show up here.';
  }

  @override
  String get whenDoYouHaveTime => 'When do you usually have time?';

  @override
  String get whenSectionSubtitle => 'Set when your event starts and ends';

  @override
  String get whereHint => 'Where?';

  @override
  String get writeForClubMembersHint =>
      'Write something for your club members…';

  @override
  String get yesRemoveLabel => 'Yes, Remove';

  @override
  String get youMayKnowThemKuStudent => 'You may know them · KU student';

  @override
  String get youMightLike => 'You Might Like';

  @override
  String get yourClubFallback => 'Your club';

  @override
  String get yourEmailFallback => 'your email';

  @override
  String get yourKuDay => 'Your KU Day';

  @override
  String get youreGoing => 'You\'re going';

  @override
  String get signInToContinueSubtitle =>
      'Sign in to pick up where you left off.';

  @override
  String get kocUniversityWordmark => 'KOÇ UNIVERSITY';

  @override
  String get usernameHint => 'yourname';

  @override
  String get newToKocUniversity => 'New to Koç University?';

  @override
  String get runningAClub => 'Running a club?';

  @override
  String get fullNameExampleHint => 'e.g. Ali Yılmaz';

  @override
  String get couldNotUseCamera =>
      'Could not use the camera. Check camera access and try again.';

  @override
  String youreInName(String name) {
    return 'You\'re in,\n$name.';
  }

  @override
  String get markAllRead => 'Mark all read';

  @override
  String get clubRolePresident => 'President';

  @override
  String get clubRoleVicePresident => 'Vice President';

  @override
  String get clubRoleFounder => 'Founder';

  @override
  String get clubRoleCoFounder => 'Co-Founder';

  @override
  String get clubRoleSecretary => 'Secretary';

  @override
  String get clubRoleTreasurer => 'Treasurer';

  @override
  String get clubRoleCoordinator => 'Coordinator';

  @override
  String get clubRoleChair => 'Chair';

  @override
  String get clubRoleViceChair => 'Vice Chair';

  @override
  String get clubRoleTeamLead => 'Team Lead';

  @override
  String get followRequests => 'Follow requests';

  @override
  String plusOthersCount(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '+ $n others',
      one: '+ 1 other',
    );
    return '$_temp0';
  }

  @override
  String get notifGroupNew => 'NEW';

  @override
  String get notifGroupToday => 'TODAY';

  @override
  String get notifGroupThisWeek => 'THIS WEEK';

  @override
  String get notifGroupThisMonth => 'THIS MONTH';

  @override
  String get notifGroupEarlier => 'EARLIER';

  @override
  String get updatedJustNow => 'Updated just now';

  @override
  String get notificationsAutoCleared =>
      'Notifications older than 30 days are cleared automatically';
}
