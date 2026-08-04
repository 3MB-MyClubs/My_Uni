import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get goodEvening;

  /// No description provided for @stillUp.
  ///
  /// In en, this message translates to:
  /// **'Still up'**
  String get stillUp;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'THIS WEEK'**
  String get thisWeek;

  /// No description provided for @eventsOnCampus.
  ///
  /// In en, this message translates to:
  /// **'Events on campus'**
  String get eventsOnCampus;

  /// No description provided for @campusHappening.
  ///
  /// In en, this message translates to:
  /// **'Here\'s what\'s happening on campus.'**
  String get campusHappening;

  /// No description provided for @membersHappening.
  ///
  /// In en, this message translates to:
  /// **'Here\'s what your members are up to.'**
  String get membersHappening;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @fromYourClubs.
  ///
  /// In en, this message translates to:
  /// **'FROM YOUR CLUBS'**
  String get fromYourClubs;

  /// No description provided for @clubFeed.
  ///
  /// In en, this message translates to:
  /// **'CLUB FEED'**
  String get clubFeed;

  /// No description provided for @following.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get following;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @latest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get latest;

  /// No description provided for @nothingHere.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get nothingHere;

  /// No description provided for @followClubs.
  ///
  /// In en, this message translates to:
  /// **'Follow clubs to see their posts\nand events in your feed'**
  String get followClubs;

  /// No description provided for @endOfFeed.
  ///
  /// In en, this message translates to:
  /// **'That\'s it for today 😀'**
  String get endOfFeed;

  /// No description provided for @exploreClubs.
  ///
  /// In en, this message translates to:
  /// **'Explore All Clubs'**
  String get exploreClubs;

  /// No description provided for @peopleMightKnow.
  ///
  /// In en, this message translates to:
  /// **'People You Might Know'**
  String get peopleMightKnow;

  /// No description provided for @suggestedForYou.
  ///
  /// In en, this message translates to:
  /// **'Suggested for you'**
  String get suggestedForYou;

  /// No description provided for @followBack.
  ///
  /// In en, this message translates to:
  /// **'Follow back'**
  String get followBack;

  /// No description provided for @clubMightLike.
  ///
  /// In en, this message translates to:
  /// **'Club You Might Like'**
  String get clubMightLike;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @explore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get explore;

  /// No description provided for @discoverClubs.
  ///
  /// In en, this message translates to:
  /// **'Discover Clubs'**
  String get discoverClubs;

  /// No description provided for @findPeople.
  ///
  /// In en, this message translates to:
  /// **'Find People'**
  String get findPeople;

  /// No description provided for @searchClubs.
  ///
  /// In en, this message translates to:
  /// **'Search…'**
  String get searchClubs;

  /// No description provided for @searchPeople.
  ///
  /// In en, this message translates to:
  /// **'Search…'**
  String get searchPeople;

  /// No description provided for @allClubs.
  ///
  /// In en, this message translates to:
  /// **'All clubs'**
  String get allClubs;

  /// No description provided for @exploreContentTab.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get exploreContentTab;

  /// No description provided for @searchEventsPosts.
  ///
  /// In en, this message translates to:
  /// **'Search events…'**
  String get searchEventsPosts;

  /// No description provided for @upcomingEvents.
  ///
  /// In en, this message translates to:
  /// **'Upcoming events'**
  String get upcomingEvents;

  /// No description provided for @noContentMatch.
  ///
  /// In en, this message translates to:
  /// **'No matches found'**
  String get noContentMatch;

  /// No description provided for @noClubsMatch.
  ///
  /// In en, this message translates to:
  /// **'No clubs match'**
  String get noClubsMatch;

  /// No description provided for @tryDifferentSearch.
  ///
  /// In en, this message translates to:
  /// **'Try a different search term'**
  String get tryDifferentSearch;

  /// No description provided for @studentProfile.
  ///
  /// In en, this message translates to:
  /// **'Student profile'**
  String get studentProfile;

  /// No description provided for @joined.
  ///
  /// In en, this message translates to:
  /// **'Joined ✓'**
  String get joined;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @follow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get follow;

  /// No description provided for @noOneMatches.
  ///
  /// In en, this message translates to:
  /// **'No one found'**
  String get noOneMatches;

  /// No description provided for @tryNameSearch.
  ///
  /// In en, this message translates to:
  /// **'Try a name, surname, or email'**
  String get tryNameSearch;

  /// No description provided for @discoverEvents.
  ///
  /// In en, this message translates to:
  /// **'Discover events'**
  String get discoverEvents;

  /// No description provided for @searchEvents.
  ///
  /// In en, this message translates to:
  /// **'Search events, clubs, topics'**
  String get searchEvents;

  /// No description provided for @anyDate.
  ///
  /// In en, this message translates to:
  /// **'Any date'**
  String get anyDate;

  /// No description provided for @past.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get past;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get live;

  /// No description provided for @allEvents.
  ///
  /// In en, this message translates to:
  /// **'All events'**
  String get allEvents;

  /// No description provided for @allPosts.
  ///
  /// In en, this message translates to:
  /// **'All posts'**
  String get allPosts;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @everythingOnCampus.
  ///
  /// In en, this message translates to:
  /// **'Everything happening on campus'**
  String get everythingOnCampus;

  /// No description provided for @followingOnly.
  ///
  /// In en, this message translates to:
  /// **'Only clubs you follow'**
  String get followingOnly;

  /// No description provided for @showEventsFrom.
  ///
  /// In en, this message translates to:
  /// **'Show events from'**
  String get showEventsFrom;

  /// No description provided for @pickDate.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get pickDate;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @showAllDates.
  ///
  /// In en, this message translates to:
  /// **'Show all dates'**
  String get showAllDates;

  /// No description provided for @noEventsFound.
  ///
  /// In en, this message translates to:
  /// **'No events found'**
  String get noEventsFound;

  /// No description provided for @tryDifferentKeyword.
  ///
  /// In en, this message translates to:
  /// **'Try a different keyword or clear your filters.'**
  String get tryDifferentKeyword;

  /// No description provided for @nothingScheduled.
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled here yet — check another date.'**
  String get nothingScheduled;

  /// No description provided for @checkBackLater.
  ///
  /// In en, this message translates to:
  /// **'Nothing on the calendar right now — check back soon!'**
  String get checkBackLater;

  /// No description provided for @resetFilters.
  ///
  /// In en, this message translates to:
  /// **'Reset filters'**
  String get resetFilters;

  /// No description provided for @newEvents.
  ///
  /// In en, this message translates to:
  /// **'New events'**
  String get newEvents;

  /// No description provided for @allCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'All caught up'**
  String get allCaughtUp;

  /// No description provided for @newEventsHint.
  ///
  /// In en, this message translates to:
  /// **'Newly created events will appear here until you open their details.'**
  String get newEventsHint;

  /// No description provided for @going.
  ///
  /// In en, this message translates to:
  /// **'Going'**
  String get going;

  /// No description provided for @rsvp.
  ///
  /// In en, this message translates to:
  /// **'Let\'s Go'**
  String get rsvp;

  /// No description provided for @ended.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get ended;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @filterYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get filterYou;

  /// No description provided for @filterEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get filterEvents;

  /// No description provided for @filterClubs.
  ///
  /// In en, this message translates to:
  /// **'Clubs'**
  String get filterClubs;

  /// No description provided for @newSection.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newSection;

  /// No description provided for @earlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get earlier;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @nothingHereNotif.
  ///
  /// In en, this message translates to:
  /// **'Nothing here'**
  String get nothingHereNotif;

  /// No description provided for @eventPass.
  ///
  /// In en, this message translates to:
  /// **'Event Pass'**
  String get eventPass;

  /// No description provided for @eventPassHint.
  ///
  /// In en, this message translates to:
  /// **'Show this code at the door to check in.'**
  String get eventPassHint;

  /// No description provided for @showMyPass.
  ///
  /// In en, this message translates to:
  /// **'Show my pass'**
  String get showMyPass;

  /// No description provided for @scanCheckins.
  ///
  /// In en, this message translates to:
  /// **'Scan check-ins'**
  String get scanCheckins;

  /// No description provided for @scanInvalidPass.
  ///
  /// In en, this message translates to:
  /// **'Not a valid Event Pass'**
  String get scanInvalidPass;

  /// No description provided for @scanWrongEvent.
  ///
  /// In en, this message translates to:
  /// **'Pass belongs to another event'**
  String get scanWrongEvent;

  /// No description provided for @scanAlreadyIn.
  ///
  /// In en, this message translates to:
  /// **'already checked in'**
  String get scanAlreadyIn;

  /// No description provided for @scanNotAdmitted.
  ///
  /// In en, this message translates to:
  /// **'Not admitted'**
  String get scanNotAdmitted;

  /// No description provided for @scanNoRsvpTitle.
  ///
  /// In en, this message translates to:
  /// **'No RSVP found'**
  String get scanNoRsvpTitle;

  /// No description provided for @scanNoRsvpBody.
  ///
  /// In en, this message translates to:
  /// **'{name} didn\'t RSVP to this event. Admit anyway?'**
  String scanNoRsvpBody(String name);

  /// No description provided for @scanAdmitAnyway.
  ///
  /// In en, this message translates to:
  /// **'Admit anyway'**
  String get scanAdmitAnyway;

  /// No description provided for @checkedInCounter.
  ///
  /// In en, this message translates to:
  /// **'{checked} / {total} checked in'**
  String checkedInCounter(int checked, int total);

  /// No description provided for @checkedIn.
  ///
  /// In en, this message translates to:
  /// **'Checked in'**
  String get checkedIn;

  /// No description provided for @addPoll.
  ///
  /// In en, this message translates to:
  /// **'Add poll'**
  String get addPoll;

  /// No description provided for @pollQuestionHint.
  ///
  /// In en, this message translates to:
  /// **'Ask a question…'**
  String get pollQuestionHint;

  /// No description provided for @pollOptionHint.
  ///
  /// In en, this message translates to:
  /// **'Option {n}'**
  String pollOptionHint(int n);

  /// No description provided for @pollVotes.
  ///
  /// In en, this message translates to:
  /// **'{n,plural, one{1 vote} other{{n} votes}}'**
  String pollVotes(num n);

  /// No description provided for @announcement.
  ///
  /// In en, this message translates to:
  /// **'Announcement'**
  String get announcement;

  /// No description provided for @markAsAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'Post as announcement'**
  String get markAsAnnouncement;

  /// No description provided for @comments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get comments;

  /// No description provided for @addComment.
  ///
  /// In en, this message translates to:
  /// **'Add a comment…'**
  String get addComment;

  /// No description provided for @noCommentsYet.
  ///
  /// In en, this message translates to:
  /// **'No comments yet. Be the first!'**
  String get noCommentsYet;

  /// No description provided for @deleteComment.
  ///
  /// In en, this message translates to:
  /// **'Delete comment'**
  String get deleteComment;

  /// No description provided for @posts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get posts;

  /// No description provided for @clubs.
  ///
  /// In en, this message translates to:
  /// **'Clubs'**
  String get clubs;

  /// No description provided for @followers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get followers;

  /// No description provided for @myClubs.
  ///
  /// In en, this message translates to:
  /// **'My Clubs'**
  String get myClubs;

  /// No description provided for @myContent.
  ///
  /// In en, this message translates to:
  /// **'My Content'**
  String get myContent;

  /// No description provided for @boardMembers.
  ///
  /// In en, this message translates to:
  /// **'Board Members'**
  String get boardMembers;

  /// No description provided for @board.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get board;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @superAdmin.
  ///
  /// In en, this message translates to:
  /// **'Super Admin'**
  String get superAdmin;

  /// No description provided for @clubAdmin.
  ///
  /// In en, this message translates to:
  /// **'Club Admin'**
  String get clubAdmin;

  /// No description provided for @addMajorYear.
  ///
  /// In en, this message translates to:
  /// **'Add major & year'**
  String get addMajorYear;

  /// No description provided for @addBio.
  ///
  /// In en, this message translates to:
  /// **'Add a bio…'**
  String get addBio;

  /// No description provided for @noClubsYet.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t followed any clubs yet.'**
  String get noClubsYet;

  /// No description provided for @exploreClubsHint.
  ///
  /// In en, this message translates to:
  /// **'Explore clubs and follow the ones you like.'**
  String get exploreClubsHint;

  /// No description provided for @noBoardMembers.
  ///
  /// In en, this message translates to:
  /// **'No board members yet.'**
  String get noBoardMembers;

  /// No description provided for @approvedHere.
  ///
  /// In en, this message translates to:
  /// **'Approved requests will appear here.'**
  String get approvedHere;

  /// No description provided for @noPostsYet.
  ///
  /// In en, this message translates to:
  /// **'No posts yet.'**
  String get noPostsYet;

  /// No description provided for @noEventsYet.
  ///
  /// In en, this message translates to:
  /// **'No events yet.'**
  String get noEventsYet;

  /// No description provided for @noFollowersYet.
  ///
  /// In en, this message translates to:
  /// **'No followers yet.'**
  String get noFollowersYet;

  /// No description provided for @notFollowingAnyone.
  ///
  /// In en, this message translates to:
  /// **'Not following anyone yet.'**
  String get notFollowingAnyone;

  /// No description provided for @changePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change Profile Photo'**
  String get changePhoto;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a Photo'**
  String get takePhoto;

  /// No description provided for @useCamera.
  ///
  /// In en, this message translates to:
  /// **'Use your camera right now'**
  String get useCamera;

  /// No description provided for @chooseFromLib.
  ///
  /// In en, this message translates to:
  /// **'Choose from Library'**
  String get chooseFromLib;

  /// No description provided for @pickFromLib.
  ///
  /// In en, this message translates to:
  /// **'Pick from your photo library'**
  String get pickFromLib;

  /// No description provided for @removePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get removePhoto;

  /// No description provided for @majorYearLabel.
  ///
  /// In en, this message translates to:
  /// **'Major & Year'**
  String get majorYearLabel;

  /// No description provided for @selectMajor.
  ///
  /// In en, this message translates to:
  /// **'Select your major'**
  String get selectMajor;

  /// No description provided for @selectMajorHint.
  ///
  /// In en, this message translates to:
  /// **'Select major'**
  String get selectMajorHint;

  /// No description provided for @yearLabel.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get yearLabel;

  /// No description provided for @bioLabel.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get bioLabel;

  /// No description provided for @bioHint.
  ///
  /// In en, this message translates to:
  /// **'Tell people a little about yourself'**
  String get bioHint;

  /// No description provided for @useThisPhoto.
  ///
  /// In en, this message translates to:
  /// **'Use this photo?'**
  String get useThisPhoto;

  /// No description provided for @usePhoto.
  ///
  /// In en, this message translates to:
  /// **'Use Photo'**
  String get usePhoto;

  /// No description provided for @deletePost.
  ///
  /// In en, this message translates to:
  /// **'Delete post?'**
  String get deletePost;

  /// No description provided for @deletePostMsg.
  ///
  /// In en, this message translates to:
  /// **'This post will be permanently removed.'**
  String get deletePostMsg;

  /// No description provided for @deleteEvent.
  ///
  /// In en, this message translates to:
  /// **'Delete event?'**
  String get deleteEvent;

  /// No description provided for @deleteEventMsg.
  ///
  /// In en, this message translates to:
  /// **'This event will be permanently removed.'**
  String get deleteEventMsg;

  /// No description provided for @eventDeletedConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Event deleted'**
  String get eventDeletedConfirmation;

  /// No description provided for @majorNotAdded.
  ///
  /// In en, this message translates to:
  /// **'Major not added'**
  String get majorNotAdded;

  /// No description provided for @yearNotAdded.
  ///
  /// In en, this message translates to:
  /// **'Year not added'**
  String get yearNotAdded;

  /// No description provided for @addBioIntro.
  ///
  /// In en, this message translates to:
  /// **'Add a bio to introduce yourself.'**
  String get addBioIntro;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @events.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get events;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @alerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alerts;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// No description provided for @switchToDark.
  ///
  /// In en, this message translates to:
  /// **'Switch to dark theme'**
  String get switchToDark;

  /// No description provided for @switchToLight.
  ///
  /// In en, this message translates to:
  /// **'Switch to light theme'**
  String get switchToLight;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @supportAndLegal.
  ///
  /// In en, this message translates to:
  /// **'Support & Legal'**
  String get supportAndLegal;

  /// No description provided for @supportCenter.
  ///
  /// In en, this message translates to:
  /// **'Support Center'**
  String get supportCenter;

  /// No description provided for @supportCenterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Help, FAQs & contact'**
  String get supportCenterSubtitle;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @privacyPolicySubtitle.
  ///
  /// In en, this message translates to:
  /// **'How ClubUp handles your data'**
  String get privacyPolicySubtitle;

  /// No description provided for @termsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get termsOfUse;

  /// No description provided for @termsOfUseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Community rules & safety enforcement'**
  String get termsOfUseSubtitle;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Request permanent account & data deletion'**
  String get deleteAccountSubtitle;

  /// No description provided for @couldNotOpenPage.
  ///
  /// In en, this message translates to:
  /// **'Could not open this page.'**
  String get couldNotOpenPage;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOut;

  /// No description provided for @confirmLogoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get confirmLogoutTitle;

  /// No description provided for @confirmLogoutMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out of your account?'**
  String get confirmLogoutMessage;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @editProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Photo, bio, major & year'**
  String get editProfileSubtitle;

  /// No description provided for @changeMyName.
  ///
  /// In en, this message translates to:
  /// **'Change My Name'**
  String get changeMyName;

  /// No description provided for @changeNameSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the name people see on your student profile.'**
  String get changeNameSubtitle;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @nameTaken.
  ///
  /// In en, this message translates to:
  /// **'That name is already taken.'**
  String get nameTaken;

  /// No description provided for @useRealName.
  ///
  /// In en, this message translates to:
  /// **'Use Real Name'**
  String get useRealName;

  /// No description provided for @saveName.
  ///
  /// In en, this message translates to:
  /// **'Save Name'**
  String get saveName;

  /// No description provided for @notSetConfigure.
  ///
  /// In en, this message translates to:
  /// **'Not set — tap to configure'**
  String get notSetConfigure;

  /// No description provided for @replayTutorial.
  ///
  /// In en, this message translates to:
  /// **'Replay App Tutorial'**
  String get replayTutorial;

  /// No description provided for @replayTutorialSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Take the guided tour of every area again — anytime'**
  String get replayTutorialSubtitle;

  /// No description provided for @safetyHero.
  ///
  /// In en, this message translates to:
  /// **'A safe campus community starts with everyone'**
  String get safetyHero;

  /// No description provided for @safetyIntro.
  ///
  /// In en, this message translates to:
  /// **'Please review and accept the Terms of Use before creating an account or signing in.'**
  String get safetyIntro;

  /// No description provided for @communitySafetyTerms.
  ///
  /// In en, this message translates to:
  /// **'COMMUNITY SAFETY TERMS'**
  String get communitySafetyTerms;

  /// No description provided for @zeroTolerance.
  ///
  /// In en, this message translates to:
  /// **'Zero tolerance'**
  String get zeroTolerance;

  /// No description provided for @zeroToleranceBody.
  ///
  /// In en, this message translates to:
  /// **'Objectionable content, harassment, threats, hate, sexual exploitation, scams, and abusive users are not allowed.'**
  String get zeroToleranceBody;

  /// No description provided for @reportHarmfulContent.
  ///
  /// In en, this message translates to:
  /// **'Report harmful content'**
  String get reportHarmfulContent;

  /// No description provided for @reportHarmfulContentBody.
  ///
  /// In en, this message translates to:
  /// **'Use the report option on posts and profiles. ClubUp reviews reports and acts on violations within 24 hours.'**
  String get reportHarmfulContentBody;

  /// No description provided for @blockAbusiveUsers.
  ///
  /// In en, this message translates to:
  /// **'Block abusive users'**
  String get blockAbusiveUsers;

  /// No description provided for @blockAbusiveUsersBody.
  ///
  /// In en, this message translates to:
  /// **'Blocking reports the account to ClubUp and immediately removes that user and their content from your experience.'**
  String get blockAbusiveUsersBody;

  /// No description provided for @enforcement.
  ///
  /// In en, this message translates to:
  /// **'Enforcement'**
  String get enforcement;

  /// No description provided for @enforcementBody.
  ///
  /// In en, this message translates to:
  /// **'ClubUp may remove violating content and suspend or permanently eject the responsible account.'**
  String get enforcementBody;

  /// No description provided for @readFullTerms.
  ///
  /// In en, this message translates to:
  /// **'Read full Terms of Use'**
  String get readFullTerms;

  /// No description provided for @agreeToSafetyTerms.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Terms of Use and Community Safety Terms.'**
  String get agreeToSafetyTerms;

  /// No description provided for @agreeAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Agree and continue'**
  String get agreeAndContinue;

  /// No description provided for @couldNotOpenThisPage.
  ///
  /// In en, this message translates to:
  /// **'Could not open this page.'**
  String get couldNotOpenThisPage;

  /// No description provided for @whyReportPost.
  ///
  /// In en, this message translates to:
  /// **'Why are you reporting this post?'**
  String get whyReportPost;

  /// No description provided for @whyReportUser.
  ///
  /// In en, this message translates to:
  /// **'Why are you reporting this user?'**
  String get whyReportUser;

  /// No description provided for @whyBlockUser.
  ///
  /// In en, this message translates to:
  /// **'Why are you blocking this user?'**
  String get whyBlockUser;

  /// No description provided for @chooseReportReason.
  ///
  /// In en, this message translates to:
  /// **'Choose the reason that best describes the issue. Reports are reviewed within 24 hours.'**
  String get chooseReportReason;

  /// No description provided for @moderationReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'{value, select, harassment{Harassment or bullying} hate_or_discrimination{Hate or discrimination} sexual_content{Sexual or explicit content} violence_or_danger{Violence or dangerous behavior} spam_or_scam{Spam or scam} other{Something else}}'**
  String moderationReasonLabel(String value);

  /// No description provided for @moderationReasonDetail.
  ///
  /// In en, this message translates to:
  /// **'{value, select, harassment{Targets, threatens, or abuses a person or group.} hate_or_discrimination{Attacks people based on a protected characteristic.} sexual_content{Contains unwanted nudity or sexual material.} violence_or_danger{Threatens harm or promotes dangerous conduct.} spam_or_scam{Misleads people or repeatedly posts unwanted material.} other{Another violation of the ClubUp Terms of Use.}}'**
  String moderationReasonDetail(String value);

  /// No description provided for @reportPost.
  ///
  /// In en, this message translates to:
  /// **'Report post'**
  String get reportPost;

  /// No description provided for @reportUser.
  ///
  /// In en, this message translates to:
  /// **'Report user'**
  String get reportUser;

  /// No description provided for @reportUserSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send this profile to ClubUp for review.'**
  String get reportUserSubtitle;

  /// No description provided for @blockAndReportUser.
  ///
  /// In en, this message translates to:
  /// **'Block and report user'**
  String get blockAndReportUser;

  /// No description provided for @blockAndReportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Immediately hide this user and notify ClubUp.'**
  String get blockAndReportSubtitle;

  /// No description provided for @blockUserQuestion.
  ///
  /// In en, this message translates to:
  /// **'Block {name}?'**
  String blockUserQuestion(String name);

  /// No description provided for @blockUserExplanation.
  ///
  /// In en, this message translates to:
  /// **'Their profile and content will be removed from your experience immediately. ClubUp will also receive a safety report.'**
  String get blockUserExplanation;

  /// No description provided for @userReported.
  ///
  /// In en, this message translates to:
  /// **'User reported. Our team will review it within 24 hours.'**
  String get userReported;

  /// No description provided for @reportSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send the report. Please try again.'**
  String get reportSendFailed;

  /// No description provided for @userBlockedAndReported.
  ///
  /// In en, this message translates to:
  /// **'User blocked and reported.'**
  String get userBlockedAndReported;

  /// No description provided for @userBlockedOffline.
  ///
  /// In en, this message translates to:
  /// **'User blocked on this device. The report could not be sent; please try again when online.'**
  String get userBlockedOffline;

  /// No description provided for @postReportedAndRemoved.
  ///
  /// In en, this message translates to:
  /// **'Post reported and removed from your feed.'**
  String get postReportedAndRemoved;

  /// No description provided for @postHiddenOffline.
  ///
  /// In en, this message translates to:
  /// **'Post hidden. The report could not be sent; please try again when online.'**
  String get postHiddenOffline;

  /// No description provided for @safetyOptions.
  ///
  /// In en, this message translates to:
  /// **'Safety options'**
  String get safetyOptions;

  /// No description provided for @contentSafetyRejected.
  ///
  /// In en, this message translates to:
  /// **'This content cannot be published because it may violate the ClubUp Community Safety Terms.'**
  String get contentSafetyRejected;

  /// No description provided for @profileSection.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileSection;

  /// No description provided for @clubSection.
  ///
  /// In en, this message translates to:
  /// **'Club'**
  String get clubSection;

  /// No description provided for @clubName.
  ///
  /// In en, this message translates to:
  /// **'Club Name'**
  String get clubName;

  /// No description provided for @clubNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Club name'**
  String get clubNameLabel;

  /// No description provided for @clubPhoto.
  ///
  /// In en, this message translates to:
  /// **'Club Photo'**
  String get clubPhoto;

  /// No description provided for @changeClubPhoto.
  ///
  /// In en, this message translates to:
  /// **'Change Club Photo'**
  String get changeClubPhoto;

  /// No description provided for @tapToChangeLogo.
  ///
  /// In en, this message translates to:
  /// **'Tap to change your club logo'**
  String get tapToChangeLogo;

  /// No description provided for @clubCategories.
  ///
  /// In en, this message translates to:
  /// **'Club Categories'**
  String get clubCategories;

  /// No description provided for @chooseTagsHint.
  ///
  /// In en, this message translates to:
  /// **'Choose tags that help students discover your club.'**
  String get chooseTagsHint;

  /// No description provided for @customTags.
  ///
  /// In en, this message translates to:
  /// **'Custom tags'**
  String get customTags;

  /// No description provided for @customTagsHint.
  ///
  /// In en, this message translates to:
  /// **'Design, Gaming, Culture'**
  String get customTagsHint;

  /// No description provided for @separateWithCommas.
  ///
  /// In en, this message translates to:
  /// **'Separate custom tags with commas'**
  String get separateWithCommas;

  /// No description provided for @saveCategories.
  ///
  /// In en, this message translates to:
  /// **'Save Categories'**
  String get saveCategories;

  /// No description provided for @addDiscoveryTags.
  ///
  /// In en, this message translates to:
  /// **'Add discovery tags'**
  String get addDiscoveryTags;

  /// No description provided for @clubDescription.
  ///
  /// In en, this message translates to:
  /// **'Club Description'**
  String get clubDescription;

  /// No description provided for @clubDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'What is this club about?'**
  String get clubDescriptionHint;

  /// No description provided for @manageBoardMembers.
  ///
  /// In en, this message translates to:
  /// **'Manage Board Members'**
  String get manageBoardMembers;

  /// No description provided for @manageBoardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add or remove board members & roles'**
  String get manageBoardSubtitle;

  /// No description provided for @post.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get post;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get addPhoto;

  /// No description provided for @whatsHappeningAtClub.
  ///
  /// In en, this message translates to:
  /// **'What\'s happening at your club?'**
  String get whatsHappeningAtClub;

  /// No description provided for @tapForDetails.
  ///
  /// In en, this message translates to:
  /// **'Tap for details'**
  String get tapForDetails;

  /// No description provided for @pastEventsHint.
  ///
  /// In en, this message translates to:
  /// **'Events that finished during the last 7 days.'**
  String get pastEventsHint;

  /// No description provided for @upcomingEventsHint.
  ///
  /// In en, this message translates to:
  /// **'What\'s on across campus — next month.'**
  String get upcomingEventsHint;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @noNotificationsFor.
  ///
  /// In en, this message translates to:
  /// **'No {label}notifications right now. We\'ll let you know when something happens.'**
  String noNotificationsFor(String label);

  /// No description provided for @profilesWillAppear.
  ///
  /// In en, this message translates to:
  /// **'Profiles will appear here after users sign up'**
  String get profilesWillAppear;

  /// No description provided for @graduate.
  ///
  /// In en, this message translates to:
  /// **'Graduate'**
  String get graduate;

  /// No description provided for @addedToBothCalendars.
  ///
  /// In en, this message translates to:
  /// **'Added to both calendars'**
  String get addedToBothCalendars;

  /// No description provided for @enableCalendarAccessHint.
  ///
  /// In en, this message translates to:
  /// **'You\'re going! Enable calendar access in Settings to also sync to your phone.'**
  String get enableCalendarAccessHint;

  /// No description provided for @publishErrorRlsPolicy.
  ///
  /// In en, this message translates to:
  /// **'Could not publish post. Check club_posts RLS policies for this club account.'**
  String get publishErrorRlsPolicy;

  /// No description provided for @publishErrorMigration.
  ///
  /// In en, this message translates to:
  /// **'Could not publish post. Run the latest club_posts SQL migration.'**
  String get publishErrorMigration;

  /// No description provided for @publishErrorStorage.
  ///
  /// In en, this message translates to:
  /// **'Could not upload photo. Check the post-images bucket policies.'**
  String get publishErrorStorage;

  /// No description provided for @publishErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Could not publish post. Check Supabase settings.'**
  String get publishErrorGeneric;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @liveNowLabel.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get liveNowLabel;

  /// No description provided for @clubFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Club'**
  String get clubFallbackName;

  /// No description provided for @clubEmailPasscodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Club email and passcode are required'**
  String get clubEmailPasscodeRequired;

  /// No description provided for @passcodeMustBe8Digits.
  ///
  /// In en, this message translates to:
  /// **'Passcode must be exactly 8 digits'**
  String get passcodeMustBe8Digits;

  /// No description provided for @invalidClubCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid club email or passcode'**
  String get invalidClubCredentials;

  /// No description provided for @clubNotLinked.
  ///
  /// In en, this message translates to:
  /// **'This login is not linked to a club'**
  String get clubNotLinked;

  /// No description provided for @linkedClubNotFound.
  ///
  /// In en, this message translates to:
  /// **'Linked club was not found'**
  String get linkedClubNotFound;

  /// No description provided for @clubLoginNotReady.
  ///
  /// In en, this message translates to:
  /// **'Club login is not ready. Check club_auth_accounts in Supabase.'**
  String get clubLoginNotReady;

  /// No description provided for @clubAdminLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Club Admin Login'**
  String get clubAdminLoginTitle;

  /// No description provided for @clubAdminLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the club email and 8 digit passcode to manage your club.'**
  String get clubAdminLoginSubtitle;

  /// No description provided for @platformAdminLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Platform Admin Login'**
  String get platformAdminLoginTitle;

  /// No description provided for @platformAdminLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restricted access for the ClubUp platform administrator.'**
  String get platformAdminLoginSubtitle;

  /// No description provided for @adminEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Admin email'**
  String get adminEmailLabel;

  /// No description provided for @adminCredentialsRequired.
  ///
  /// In en, this message translates to:
  /// **'Admin email and passcode are required'**
  String get adminCredentialsRequired;

  /// No description provided for @invalidAdminCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid admin email or passcode'**
  String get invalidAdminCredentials;

  /// No description provided for @notPlatformAdmin.
  ///
  /// In en, this message translates to:
  /// **'These credentials are not assigned to the platform administrator'**
  String get notPlatformAdmin;

  /// No description provided for @clubEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Club Email'**
  String get clubEmailLabel;

  /// No description provided for @eightDigitPasscodeLabel.
  ///
  /// In en, this message translates to:
  /// **'8 digit passcode'**
  String get eightDigitPasscodeLabel;

  /// No description provided for @eightDigitsHint.
  ///
  /// In en, this message translates to:
  /// **'8 digits'**
  String get eightDigitsHint;

  /// No description provided for @forgotPasscode.
  ///
  /// In en, this message translates to:
  /// **'Forgot passcode?'**
  String get forgotPasscode;

  /// No description provided for @signInAsAdmin.
  ///
  /// In en, this message translates to:
  /// **'Sign In as Admin'**
  String get signInAsAdmin;

  /// No description provided for @supabaseNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Supabase is not configured.'**
  String get supabaseNotConfigured;

  /// No description provided for @passwordResetRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Password reset request failed.'**
  String get passwordResetRequestFailed;

  /// No description provided for @couldNotReachResetServer.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the password reset server. Please try again.'**
  String get couldNotReachResetServer;

  /// No description provided for @resetCredentialTitle.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, passcode{Reset passcode} other{Reset password}}'**
  String resetCredentialTitle(String kind);

  /// No description provided for @checkYourEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get checkYourEmailTitle;

  /// No description provided for @createNewCredentialTitle.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, passcode{Create new passcode} other{Create new password}}'**
  String createNewCredentialTitle(String kind);

  /// No description provided for @credentialUpdatedTitle.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, passcode{Passcode updated} other{Password updated}}'**
  String credentialUpdatedTitle(String kind);

  /// No description provided for @enterKuEmailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the KU email for your account.'**
  String get enterKuEmailSubtitle;

  /// No description provided for @enterAccountEmailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the email for your account.'**
  String get enterAccountEmailSubtitle;

  /// No description provided for @enterCodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the one-time code sent to {email}.'**
  String enterCodeSubtitle(String email);

  /// No description provided for @newCredentialSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, passcode{Use a {length}-digit numbers-only passcode for future sign-ins.} other{Use a {length}-digit numbers-only password for future sign-ins.}}'**
  String newCredentialSubtitle(String kind, int length);

  /// No description provided for @credentialUpdatedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, passcode{You can now sign in with your new passcode.} other{You can now sign in with your new password.}}'**
  String credentialUpdatedSubtitle(String kind);

  /// No description provided for @sendCodeButton.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get sendCodeButton;

  /// No description provided for @verifyCodeButton.
  ///
  /// In en, this message translates to:
  /// **'Verify code'**
  String get verifyCodeButton;

  /// No description provided for @updateCredentialButton.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, passcode{Update passcode} other{Update password}}'**
  String updateCredentialButton(String kind);

  /// No description provided for @backToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get backToSignIn;

  /// No description provided for @kuEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'KU Email'**
  String get kuEmailLabel;

  /// No description provided for @oneTimeCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'One-time code'**
  String get oneTimeCodeLabel;

  /// No description provided for @enterSixDigitCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter 6-digit code'**
  String get enterSixDigitCodeHint;

  /// No description provided for @sendingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get sendingEllipsis;

  /// No description provided for @sendNewCode.
  ///
  /// In en, this message translates to:
  /// **'Send a new code'**
  String get sendNewCode;

  /// No description provided for @newCredentialLabel.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, passcode{New passcode} other{New password}}'**
  String newCredentialLabel(String kind);

  /// No description provided for @digitPinHint.
  ///
  /// In en, this message translates to:
  /// **'{length}-digit PIN'**
  String digitPinHint(int length);

  /// No description provided for @confirmCredentialLabel.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, passcode{Confirm passcode} other{Confirm password}}'**
  String confirmCredentialLabel(String kind);

  /// No description provided for @reenterDigitPinHint.
  ///
  /// In en, this message translates to:
  /// **'Re-enter {length}-digit PIN'**
  String reenterDigitPinHint(int length);

  /// No description provided for @exactlyNDigits.
  ///
  /// In en, this message translates to:
  /// **'Exactly {length} digits'**
  String exactlyNDigits(int length);

  /// No description provided for @numbersOnly.
  ///
  /// In en, this message translates to:
  /// **'Numbers only'**
  String get numbersOnly;

  /// No description provided for @pleaseEnterKuEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your KU email.'**
  String get pleaseEnterKuEmail;

  /// No description provided for @useKuEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Use your @ku.edu.tr email address.'**
  String get useKuEmailAddress;

  /// No description provided for @useValidEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get useValidEmailAddress;

  /// No description provided for @newCodeSent.
  ///
  /// In en, this message translates to:
  /// **'New code sent.'**
  String get newCodeSent;

  /// No description provided for @enterSixDigitCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code.'**
  String get enterSixDigitCode;

  /// No description provided for @credentialMustBeNDigits.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, passcode{Passcode must be exactly {length} digits.} other{Password must be exactly {length} digits.}}'**
  String credentialMustBeNDigits(String kind, int length);

  /// No description provided for @credentialNumbersOnly.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, passcode{Passcode must contain numbers only.} other{Password must contain numbers only.}}'**
  String credentialNumbersOnly(String kind);

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get passwordsDoNotMatch;

  /// No description provided for @aboutThisEvent.
  ///
  /// In en, this message translates to:
  /// **'About this event'**
  String get aboutThisEvent;

  /// No description provided for @accountReadyRedirecting.
  ///
  /// In en, this message translates to:
  /// **'Your account is ready.\nRedirecting you to sign in.'**
  String get accountReadyRedirecting;

  /// No description provided for @actorCommentedOnYourPost.
  ///
  /// In en, this message translates to:
  /// **'{actor} commented on your post'**
  String actorCommentedOnYourPost(String actor);

  /// No description provided for @actorLikedYourPost.
  ///
  /// In en, this message translates to:
  /// **'{actor} liked your post'**
  String actorLikedYourPost(String actor);

  /// No description provided for @actorRsvpdToEvent.
  ///
  /// In en, this message translates to:
  /// **'{actor} RSVP\'d to {event}'**
  String actorRsvpdToEvent(String actor, String event);

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @addAPhotoTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get addAPhotoTitle;

  /// No description provided for @addCoverPhotoOptional.
  ///
  /// In en, this message translates to:
  /// **'Add cover photo (optional)'**
  String get addCoverPhotoOptional;

  /// No description provided for @addCustomTagHint.
  ///
  /// In en, this message translates to:
  /// **'Add custom tag…'**
  String get addCustomTagHint;

  /// No description provided for @addEventToCampusCalendar.
  ///
  /// In en, this message translates to:
  /// **'Add an event to the campus calendar'**
  String get addEventToCampusCalendar;

  /// No description provided for @addFollowerAboveHint.
  ///
  /// In en, this message translates to:
  /// **'Add a follower above to show them publicly on the Board tab.'**
  String get addFollowerAboveHint;

  /// No description provided for @addImageOrKeepImageless.
  ///
  /// In en, this message translates to:
  /// **'Add an image or keep this event imageless'**
  String get addImageOrKeepImageless;

  /// No description provided for @addLabel.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addLabel;

  /// No description provided for @addRequiredFieldsBeforePublish.
  ///
  /// In en, this message translates to:
  /// **'Add a title, a location and a valid time range before publishing.'**
  String get addRequiredFieldsBeforePublish;

  /// No description provided for @addSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Add speaker'**
  String get addSpeaker;

  /// No description provided for @addTimeSlot.
  ///
  /// In en, this message translates to:
  /// **'Add time slot'**
  String get addTimeSlot;

  /// No description provided for @addTitleLocationToContinue.
  ///
  /// In en, this message translates to:
  /// **'Add an event title and location to continue.'**
  String get addTitleLocationToContinue;

  /// No description provided for @addToCalendarButton.
  ///
  /// In en, this message translates to:
  /// **'Add to Calendar'**
  String get addToCalendarButton;

  /// No description provided for @addingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Adding…'**
  String get addingEllipsis;

  /// No description provided for @adminDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin Dashboard'**
  String get adminDashboardTitle;

  /// No description provided for @agenda.
  ///
  /// In en, this message translates to:
  /// **'Agenda'**
  String get agenda;

  /// No description provided for @allowAccessButton.
  ///
  /// In en, this message translates to:
  /// **'Allow Access'**
  String get allowAccessButton;

  /// No description provided for @allowCalendarAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow Calendar Access'**
  String get allowCalendarAccessTitle;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'I already have one'**
  String get alreadyHaveAccount;

  /// No description provided for @assignClubRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Assign club role'**
  String get assignClubRoleLabel;

  /// No description provided for @attendedBadge.
  ///
  /// In en, this message translates to:
  /// **'ATTENDED'**
  String get attendedBadge;

  /// No description provided for @attendedCount.
  ///
  /// In en, this message translates to:
  /// **'{n} attended'**
  String attendedCount(int n);

  /// No description provided for @attendees.
  ///
  /// In en, this message translates to:
  /// **'Attendees'**
  String get attendees;

  /// No description provided for @attendingCount.
  ///
  /// In en, this message translates to:
  /// **'{n,plural, one{1 attending} other{{n} attending}}'**
  String attendingCount(num n);

  /// No description provided for @attendingViewRsvps.
  ///
  /// In en, this message translates to:
  /// **'{count} attending · View RSVPs'**
  String attendingViewRsvps(int count);

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @backTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backTooltip;

  /// No description provided for @becauseYouFollowClub.
  ///
  /// In en, this message translates to:
  /// **'Because you follow {club}'**
  String becauseYouFollowClub(String club);

  /// No description provided for @bestForYouThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Best for You This Week'**
  String get bestForYouThisWeek;

  /// No description provided for @boardMemberFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Board Member'**
  String get boardMemberFallbackTitle;

  /// No description provided for @boardMemberLabel.
  ///
  /// In en, this message translates to:
  /// **'Board Member'**
  String get boardMemberLabel;

  /// No description provided for @boardMembersPublicHint.
  ///
  /// In en, this message translates to:
  /// **'Followers added here are shown publicly in the Board tab.'**
  String get boardMembersPublicHint;

  /// No description provided for @bothInClub.
  ///
  /// In en, this message translates to:
  /// **'Both in {club}'**
  String bothInClub(String club);

  /// No description provided for @byContinuingAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'By continuing you acknowledge our'**
  String get byContinuingAcknowledge;

  /// No description provided for @calEventTypeClass.
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get calEventTypeClass;

  /// No description provided for @calEventTypeDeadline.
  ///
  /// In en, this message translates to:
  /// **'Deadline'**
  String get calEventTypeDeadline;

  /// No description provided for @calEventTypeEvent.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get calEventTypeEvent;

  /// No description provided for @calEventTypePersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get calEventTypePersonal;

  /// No description provided for @calendarAccessDeniedBody.
  ///
  /// In en, this message translates to:
  /// **'Calendar access was denied. To add events, please enable it in:\n\nSettings → Privacy & Security → Calendars'**
  String get calendarAccessDeniedBody;

  /// No description provided for @calendarAccessDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar Access Denied'**
  String get calendarAccessDeniedTitle;

  /// No description provided for @calendarAccessRequestBody.
  ///
  /// In en, this message translates to:
  /// **'My Clubs would like to save this event to your Calendar app.\n\nYour calendar is only used to add events you choose.'**
  String get calendarAccessRequestBody;

  /// No description provided for @calendarAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get calendarAdd;

  /// No description provided for @calendarAddEventButton.
  ///
  /// In en, this message translates to:
  /// **'+ Add an event'**
  String get calendarAddEventButton;

  /// No description provided for @calendarAddFailedGeneric.
  ///
  /// In en, this message translates to:
  /// **'Failed to add event to calendar.'**
  String get calendarAddFailedGeneric;

  /// No description provided for @calendarAddToPhone.
  ///
  /// In en, this message translates to:
  /// **'Add to phone'**
  String get calendarAddToPhone;

  /// No description provided for @calendarAddedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Event added to calendar!'**
  String get calendarAddedSuccess;

  /// No description provided for @calendarAddedToCalendarButton.
  ///
  /// In en, this message translates to:
  /// **'✓ Added to Calendar'**
  String get calendarAddedToCalendarButton;

  /// No description provided for @calendarAddedToCalendarSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Event added to calendar'**
  String get calendarAddedToCalendarSnackbar;

  /// No description provided for @calendarAddedToPhone.
  ///
  /// In en, this message translates to:
  /// **'Added to phone'**
  String get calendarAddedToPhone;

  /// No description provided for @calendarAlreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'Added to calendar'**
  String get calendarAlreadyAdded;

  /// No description provided for @calendarAppleAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add event to Apple Calendar.'**
  String get calendarAppleAddFailed;

  /// No description provided for @calendarDeleteEventButton.
  ///
  /// In en, this message translates to:
  /// **'Delete event'**
  String get calendarDeleteEventButton;

  /// No description provided for @calendarDeniedBody.
  ///
  /// In en, this message translates to:
  /// **'To sync events to your phone, please allow calendar access in:\n\nSettings → Privacy & Security → Calendars'**
  String get calendarDeniedBody;

  /// No description provided for @calendarEditEvent.
  ///
  /// In en, this message translates to:
  /// **'Edit event'**
  String get calendarEditEvent;

  /// No description provided for @calendarFilterRsvpd.
  ///
  /// In en, this message translates to:
  /// **'RSVP\'d'**
  String get calendarFilterRsvpd;

  /// No description provided for @calendarItemsCount.
  ///
  /// In en, this message translates to:
  /// **'{n,plural, one{{n} item} other{{n} items}}'**
  String calendarItemsCount(num n);

  /// No description provided for @calendarItemsThisMonth.
  ///
  /// In en, this message translates to:
  /// **'{n,plural, one{{n} item this month} other{{n} items this month}}'**
  String calendarItemsThisMonth(num n);

  /// No description provided for @calendarNewEvent.
  ///
  /// In en, this message translates to:
  /// **'New event'**
  String get calendarNewEvent;

  /// No description provided for @calendarNoWritableCalendar.
  ///
  /// In en, this message translates to:
  /// **'No writable calendar found on this device.'**
  String get calendarNoWritableCalendar;

  /// No description provided for @calendarNothingScheduled.
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled.'**
  String get calendarNothingScheduled;

  /// No description provided for @calendarPermissionCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to check calendar permissions.'**
  String get calendarPermissionCheckFailed;

  /// No description provided for @calendarPrePermissionBody.
  ///
  /// In en, this message translates to:
  /// **'To save this event to your phone\'s Calendar app, we need permission to access your calendar.\n\nYour calendar data is only used to add events you choose.'**
  String get calendarPrePermissionBody;

  /// No description provided for @calendarPreviewLabel.
  ///
  /// In en, this message translates to:
  /// **'{type} · Preview'**
  String calendarPreviewLabel(String type);

  /// No description provided for @calendarRsvpdBadge.
  ///
  /// In en, this message translates to:
  /// **'RSVP\'D'**
  String get calendarRsvpdBadge;

  /// No description provided for @calendarYoursTapToEdit.
  ///
  /// In en, this message translates to:
  /// **'Yours · tap to edit'**
  String get calendarYoursTapToEdit;

  /// No description provided for @campusEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Campus email'**
  String get campusEmailLabel;

  /// No description provided for @campusEventFallback.
  ///
  /// In en, this message translates to:
  /// **'Campus event'**
  String get campusEventFallback;

  /// No description provided for @campusFallbackLocation.
  ///
  /// In en, this message translates to:
  /// **'Campus'**
  String get campusFallbackLocation;

  /// No description provided for @campusPostFallback.
  ///
  /// In en, this message translates to:
  /// **'Campus post'**
  String get campusPostFallback;

  /// No description provided for @campusTodaySummary.
  ///
  /// In en, this message translates to:
  /// **'Campus today: {summary}'**
  String campusTodaySummary(String summary);

  /// No description provided for @categoryAcademic.
  ///
  /// In en, this message translates to:
  /// **'Academic'**
  String get categoryAcademic;

  /// No description provided for @categoryArts.
  ///
  /// In en, this message translates to:
  /// **'Arts'**
  String get categoryArts;

  /// No description provided for @categoryBusiness.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get categoryBusiness;

  /// No description provided for @categoryCareer.
  ///
  /// In en, this message translates to:
  /// **'Career'**
  String get categoryCareer;

  /// No description provided for @categoryEngineering.
  ///
  /// In en, this message translates to:
  /// **'Engineering'**
  String get categoryEngineering;

  /// No description provided for @categoryMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get categoryMusic;

  /// No description provided for @categorySocial.
  ///
  /// In en, this message translates to:
  /// **'Social'**
  String get categorySocial;

  /// No description provided for @categorySocialImpact.
  ///
  /// In en, this message translates to:
  /// **'Social Impact'**
  String get categorySocialImpact;

  /// No description provided for @categorySports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get categorySports;

  /// No description provided for @categoryTech.
  ///
  /// In en, this message translates to:
  /// **'Tech'**
  String get categoryTech;

  /// No description provided for @categoryWellness.
  ///
  /// In en, this message translates to:
  /// **'Wellness'**
  String get categoryWellness;

  /// No description provided for @changeEventPhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get changeEventPhoto;

  /// No description provided for @changeLabel.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get changeLabel;

  /// No description provided for @changePhotoButton.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get changePhotoButton;

  /// No description provided for @checkBackSoonEvents.
  ///
  /// In en, this message translates to:
  /// **'Check back soon for new events.'**
  String get checkBackSoonEvents;

  /// No description provided for @checkYourInboxTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your inbox.'**
  String get checkYourInboxTitle;

  /// No description provided for @choose6DigitPinHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a 6-digit PIN — numbers only, no letters or symbols.'**
  String get choose6DigitPinHint;

  /// No description provided for @chooseFromLibraryOption.
  ///
  /// In en, this message translates to:
  /// **'Choose from library'**
  String get chooseFromLibraryOption;

  /// No description provided for @chooseYourLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get chooseYourLanguage;

  /// No description provided for @chooseYourLook.
  ///
  /// In en, this message translates to:
  /// **'Choose your look'**
  String get chooseYourLook;

  /// No description provided for @clearSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearchTooltip;

  /// No description provided for @clubAdminSignIn.
  ///
  /// In en, this message translates to:
  /// **'Club admin sign in'**
  String get clubAdminSignIn;

  /// No description provided for @clubAdminsAddMembersHint.
  ///
  /// In en, this message translates to:
  /// **'Club admins can add members from Manage board members.'**
  String get clubAdminsAddMembersHint;

  /// No description provided for @clubLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Club Leaderboard'**
  String get clubLeaderboard;

  /// No description provided for @clubMembershipLabel.
  ///
  /// In en, this message translates to:
  /// **'Club membership'**
  String get clubMembershipLabel;

  /// No description provided for @clubMentionedYouInPost.
  ///
  /// In en, this message translates to:
  /// **'{club} mentioned you in a post'**
  String clubMentionedYouInPost(String club);

  /// No description provided for @clubNameAppearsAcrossApp.
  ///
  /// In en, this message translates to:
  /// **'This appears across the app wherever your club is shown.'**
  String get clubNameAppearsAcrossApp;

  /// No description provided for @clubPhotoRemovedLocallyDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Club photo removed locally, but remote delete failed.'**
  String get clubPhotoRemovedLocallyDeleteFailed;

  /// No description provided for @clubPostedNewEvent.
  ///
  /// In en, this message translates to:
  /// **'{club} posted a new event: {event}'**
  String clubPostedNewEvent(String club, String event);

  /// No description provided for @clubRoleSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Club role: {role}'**
  String clubRoleSemanticLabel(String role);

  /// No description provided for @clubSharedNewPost.
  ///
  /// In en, this message translates to:
  /// **'{club} shared a new post'**
  String clubSharedNewPost(String club);

  /// No description provided for @clubsCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{n,plural, one{1 club} other{{n} clubs}}'**
  String clubsCountLabel(num n);

  /// No description provided for @clubsCountTitle.
  ///
  /// In en, this message translates to:
  /// **'CLUBS · {count}'**
  String clubsCountTitle(int count);

  /// No description provided for @clubsInCommonCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, one{{n} club in common} other{{n} clubs in common}}'**
  String clubsInCommonCount(num n);

  /// No description provided for @clubsPickedForYou.
  ///
  /// In en, this message translates to:
  /// **'Clubs picked for you'**
  String get clubsPickedForYou;

  /// No description provided for @collabBadge.
  ///
  /// In en, this message translates to:
  /// **'Collab'**
  String get collabBadge;

  /// No description provided for @collabsTab.
  ///
  /// In en, this message translates to:
  /// **'Collabs'**
  String get collabsTab;

  /// No description provided for @completeRequiredFields.
  ///
  /// In en, this message translates to:
  /// **'Please complete the required fields.'**
  String get completeRequiredFields;

  /// No description provided for @confirmRemovalBody.
  ///
  /// In en, this message translates to:
  /// **'This will permanently remove {name} from the board of {clubName}. Continue?'**
  String confirmRemovalBody(String name, String clubName);

  /// No description provided for @confirmRemovalTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Removal'**
  String get confirmRemovalTitle;

  /// No description provided for @confirmRemoveBoardMemberBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove {name} from the board?'**
  String confirmRemoveBoardMemberBody(String name);

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @continueWithTheme.
  ///
  /// In en, this message translates to:
  /// **'Continue with {theme}'**
  String continueWithTheme(String theme);

  /// No description provided for @couldNotDeleteEventSupabase.
  ///
  /// In en, this message translates to:
  /// **'Could not delete event from Supabase.'**
  String get couldNotDeleteEventSupabase;

  /// No description provided for @couldNotDeletePostSupabase.
  ///
  /// In en, this message translates to:
  /// **'Could not delete post from Supabase.'**
  String get couldNotDeletePostSupabase;

  /// No description provided for @couldNotLoadConnections.
  ///
  /// In en, this message translates to:
  /// **'Could not load connections.'**
  String get couldNotLoadConnections;

  /// No description provided for @couldNotLoadInterests.
  ///
  /// In en, this message translates to:
  /// **'Could not load interests. Please try again.'**
  String get couldNotLoadInterests;

  /// No description provided for @couldNotLoadPeople.
  ///
  /// In en, this message translates to:
  /// **'Could not load people from profiles.'**
  String get couldNotLoadPeople;

  /// No description provided for @couldNotLoadProfileOptions.
  ///
  /// In en, this message translates to:
  /// **'Could not load profile options from Supabase.'**
  String get couldNotLoadProfileOptions;

  /// No description provided for @couldNotLoadProfileOptionsRetry.
  ///
  /// In en, this message translates to:
  /// **'Could not load profile options. Please try again.'**
  String get couldNotLoadProfileOptionsRetry;

  /// No description provided for @couldNotOpenLinkedIn.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open {name}\'s LinkedIn'**
  String couldNotOpenLinkedIn(String name);

  /// No description provided for @couldNotOpenPhotoCropper.
  ///
  /// In en, this message translates to:
  /// **'Could not open photo cropper.'**
  String get couldNotOpenPhotoCropper;

  /// No description provided for @couldNotOpenPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Could not open the Privacy Policy.'**
  String get couldNotOpenPrivacyPolicy;

  /// No description provided for @couldNotOpenRegistrationForm.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the registration form'**
  String get couldNotOpenRegistrationForm;

  /// No description provided for @couldNotReachSignupServer.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the signup server. Please try again.'**
  String get couldNotReachSignupServer;

  /// No description provided for @couldNotRemoveClubMember.
  ///
  /// In en, this message translates to:
  /// **'Could not remove this club member.'**
  String get couldNotRemoveClubMember;

  /// No description provided for @couldNotSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Could not save changes.'**
  String get couldNotSaveChanges;

  /// No description provided for @couldNotSaveEventSupabase.
  ///
  /// In en, this message translates to:
  /// **'Could not save event to Supabase.'**
  String get couldNotSaveEventSupabase;

  /// No description provided for @couldNotSaveProfileSupabase.
  ///
  /// In en, this message translates to:
  /// **'Could not save profile to Supabase'**
  String get couldNotSaveProfileSupabase;

  /// No description provided for @couldNotUpdateBoardRole.
  ///
  /// In en, this message translates to:
  /// **'Could not update board member role.'**
  String get couldNotUpdateBoardRole;

  /// No description provided for @couldNotUpdateClubDescription.
  ///
  /// In en, this message translates to:
  /// **'Could not update club description.'**
  String get couldNotUpdateClubDescription;

  /// No description provided for @couldNotUpdateClubFollow.
  ///
  /// In en, this message translates to:
  /// **'Could not update club follow.'**
  String get couldNotUpdateClubFollow;

  /// No description provided for @couldNotUpdateClubName.
  ///
  /// In en, this message translates to:
  /// **'Could not update club name.'**
  String get couldNotUpdateClubName;

  /// No description provided for @couldNotUpdateFollow.
  ///
  /// In en, this message translates to:
  /// **'Could not update follow. Please try again.'**
  String get couldNotUpdateFollow;

  /// No description provided for @couldNotUpdateName.
  ///
  /// In en, this message translates to:
  /// **'Could not update name.'**
  String get couldNotUpdateName;

  /// No description provided for @couldNotUploadClubPhoto.
  ///
  /// In en, this message translates to:
  /// **'Could not upload club photo.'**
  String get couldNotUploadClubPhoto;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @createPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a password.'**
  String get createPasswordTitle;

  /// No description provided for @createSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createSheetTitle;

  /// No description provided for @createSomethingInspiring.
  ///
  /// In en, this message translates to:
  /// **'Create something inspiring'**
  String get createSomethingInspiring;

  /// No description provided for @cropPhoto.
  ///
  /// In en, this message translates to:
  /// **'Crop Photo'**
  String get cropPhoto;

  /// No description provided for @cropPhotoTitle.
  ///
  /// In en, this message translates to:
  /// **'Crop Photo'**
  String get cropPhotoTitle;

  /// No description provided for @currentBoardMembersHeader.
  ///
  /// In en, this message translates to:
  /// **'Current Board Members ({n})'**
  String currentBoardMembersHeader(int n);

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{n,plural, one{1d ago} other{{n}d ago}}'**
  String daysAgo(num n);

  /// No description provided for @daysAgoLong.
  ///
  /// In en, this message translates to:
  /// **'{n,plural, one{{n} day ago} other{{n} days ago}}'**
  String daysAgoLong(int n);

  /// No description provided for @daysAgoShort.
  ///
  /// In en, this message translates to:
  /// **'{n}d ago'**
  String daysAgoShort(int n);

  /// No description provided for @daysAgoSuffix.
  ///
  /// In en, this message translates to:
  /// **'{n}d ago'**
  String daysAgoSuffix(int n);

  /// No description provided for @daysCount.
  ///
  /// In en, this message translates to:
  /// **'{n,plural, one{1 day} other{{n} days}}'**
  String daysCount(num n);

  /// No description provided for @daysShort.
  ///
  /// In en, this message translates to:
  /// **'{n}d'**
  String daysShort(int n);

  /// No description provided for @deleteEventButton.
  ///
  /// In en, this message translates to:
  /// **'Delete Event'**
  String get deleteEventButton;

  /// No description provided for @deleteEventFromClubMsg.
  ///
  /// In en, this message translates to:
  /// **'This event will be permanently removed from your club.'**
  String get deleteEventFromClubMsg;

  /// No description provided for @deleteEventMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Delete event'**
  String get deleteEventMenuItem;

  /// No description provided for @deleteEventPermanentWarning.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" and all RSVP data will be permanently removed. This cannot be undone.'**
  String deleteEventPermanentWarning(String title);

  /// No description provided for @deletePostAction.
  ///
  /// In en, this message translates to:
  /// **'Delete post'**
  String get deletePostAction;

  /// No description provided for @deletePostFeedBody.
  ///
  /// In en, this message translates to:
  /// **'This post will be removed from the home feed.'**
  String get deletePostFeedBody;

  /// No description provided for @deletePostFromClubMsg.
  ///
  /// In en, this message translates to:
  /// **'This post will be permanently removed from your club.'**
  String get deletePostFromClubMsg;

  /// No description provided for @deletePostMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Delete post'**
  String get deletePostMenuItem;

  /// No description provided for @deleteThisEventConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this event?'**
  String get deleteThisEventConfirm;

  /// No description provided for @descriptionAppearsOnClubProfile.
  ///
  /// In en, this message translates to:
  /// **'This appears on {clubName}’s profile across the app.'**
  String descriptionAppearsOnClubProfile(String clubName);

  /// No description provided for @descriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get descriptionLabel;

  /// No description provided for @didntGetCode.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t get it?'**
  String get didntGetCode;

  /// No description provided for @discoverClubDescriptionFallback.
  ///
  /// In en, this message translates to:
  /// **'Discover what this club is all about.'**
  String get discoverClubDescriptionFallback;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @doubleMajorLabel.
  ///
  /// In en, this message translates to:
  /// **'Double major'**
  String get doubleMajorLabel;

  /// No description provided for @dowFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get dowFri;

  /// No description provided for @dowMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get dowMon;

  /// No description provided for @dowSat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get dowSat;

  /// No description provided for @dowSun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get dowSun;

  /// No description provided for @dowThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get dowThu;

  /// No description provided for @dowTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get dowTue;

  /// No description provided for @dowWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get dowWed;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @editClubRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit club role'**
  String get editClubRoleLabel;

  /// No description provided for @editEventButton.
  ///
  /// In en, this message translates to:
  /// **'Edit Event'**
  String get editEventButton;

  /// No description provided for @editEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Event'**
  String get editEventTitle;

  /// No description provided for @endMustBeAfterStartShort.
  ///
  /// In en, this message translates to:
  /// **'End must be after start'**
  String get endMustBeAfterStartShort;

  /// No description provided for @endTimeAfterStartTime.
  ///
  /// In en, this message translates to:
  /// **'End time must be after the start time.'**
  String get endTimeAfterStartTime;

  /// No description provided for @endsLabel.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get endsLabel;

  /// No description provided for @enterEmailAndPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email and password'**
  String get enterEmailAndPassword;

  /// No description provided for @enterFullSixDigitCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the full 6-digit code.'**
  String get enterFullSixDigitCode;

  /// No description provided for @eventDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Tell people what this event is about...'**
  String get eventDescriptionHint;

  /// No description provided for @eventFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get eventFallbackTitle;

  /// No description provided for @eventInDays.
  ///
  /// In en, this message translates to:
  /// **'In {days}d'**
  String eventInDays(int days);

  /// No description provided for @eventLabel.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get eventLabel;

  /// No description provided for @eventLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Event link copied to clipboard'**
  String get eventLinkCopied;

  /// No description provided for @eventReminderChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Reminders for events you RSVP to'**
  String get eventReminderChannelDescription;

  /// No description provided for @eventReminderChannelName.
  ///
  /// In en, this message translates to:
  /// **'Event reminders'**
  String get eventReminderChannelName;

  /// No description provided for @eventReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Event reminder'**
  String get eventReminderTitle;

  /// No description provided for @eventStartsInOneHour.
  ///
  /// In en, this message translates to:
  /// **'{title} starts in 1 hour'**
  String eventStartsInOneHour(String title);

  /// No description provided for @eventStartsTomorrow.
  ///
  /// In en, this message translates to:
  /// **'{title} starts tomorrow'**
  String eventStartsTomorrow(String title);

  /// No description provided for @eventStepBasics.
  ///
  /// In en, this message translates to:
  /// **'Basics'**
  String get eventStepBasics;

  /// No description provided for @eventStepDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get eventStepDetails;

  /// No description provided for @eventStepReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get eventStepReview;

  /// No description provided for @eventStepWhen.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get eventStepWhen;

  /// No description provided for @eventTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Spring Hackathon'**
  String get eventTitleHint;

  /// No description provided for @eventTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Event Title'**
  String get eventTitleLabel;

  /// No description provided for @eventTitlePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Event title'**
  String get eventTitlePlaceholder;

  /// No description provided for @eventTitlePreviewPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Event title preview'**
  String get eventTitlePreviewPlaceholder;

  /// No description provided for @eventViewersTitle.
  ///
  /// In en, this message translates to:
  /// **'Event Viewers'**
  String get eventViewersTitle;

  /// No description provided for @eventsCount.
  ///
  /// In en, this message translates to:
  /// **'{n,plural, one{1 event} other{{n} events}}'**
  String eventsCount(num n);

  /// No description provided for @eventsCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Events ({count})'**
  String eventsCountLabel(int count);

  /// No description provided for @externalSignupBadge.
  ///
  /// In en, this message translates to:
  /// **'External sign-up'**
  String get externalSignupBadge;

  /// No description provided for @externalSignupLinkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Attendees register on your form (Google Form, Eventbrite…)'**
  String get externalSignupLinkSubtitle;

  /// No description provided for @externalSignupLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'External sign-up link'**
  String get externalSignupLinkTitle;

  /// No description provided for @fallbackNameGreeting.
  ///
  /// In en, this message translates to:
  /// **'there'**
  String get fallbackNameGreeting;

  /// No description provided for @feedPreviewHint.
  ///
  /// In en, this message translates to:
  /// **'This is how it will appear in the Home Feed.'**
  String get feedPreviewHint;

  /// No description provided for @filterQueryLabel.
  ///
  /// In en, this message translates to:
  /// **'· \"{query}\"'**
  String filterQueryLabel(String query);

  /// No description provided for @findClubsAction.
  ///
  /// In en, this message translates to:
  /// **'Find clubs'**
  String get findClubsAction;

  /// No description provided for @finishSetupButton.
  ///
  /// In en, this message translates to:
  /// **'Finish setup'**
  String get finishSetupButton;

  /// No description provided for @followAll.
  ///
  /// In en, this message translates to:
  /// **'Follow all'**
  String get followAll;

  /// No description provided for @followRequestAccepted.
  ///
  /// In en, this message translates to:
  /// **'Your follow request was accepted.'**
  String get followRequestAccepted;

  /// No description provided for @followRequestMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} wants to follow you.'**
  String followRequestMessage(String name);

  /// No description provided for @followToSeePosts.
  ///
  /// In en, this message translates to:
  /// **'Follow to see their posts.'**
  String get followToSeePosts;

  /// No description provided for @followedClubsTitle.
  ///
  /// In en, this message translates to:
  /// **'Followed clubs'**
  String get followedClubsTitle;

  /// No description provided for @followersAndRsvpsSummary.
  ///
  /// In en, this message translates to:
  /// **'{followers} followers · {rsvps} RSVPs'**
  String followersAndRsvpsSummary(int followers, int rsvps);

  /// No description provided for @followersCountHeader.
  ///
  /// In en, this message translates to:
  /// **'Followers ({n})'**
  String followersCountHeader(int n);

  /// No description provided for @followersLoadError.
  ///
  /// In en, this message translates to:
  /// **'Followers could not be loaded.'**
  String get followersLoadError;

  /// No description provided for @followingCheckLabel.
  ///
  /// In en, this message translates to:
  /// **'Following ✓'**
  String get followingCheckLabel;

  /// No description provided for @followingClubsCount.
  ///
  /// In en, this message translates to:
  /// **'{n,plural, one{Following 1 club} other{Following {n} clubs}}'**
  String followingClubsCount(num n);

  /// No description provided for @followingFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'following'**
  String get followingFilterLabel;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @fullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullNameLabel;

  /// No description provided for @goingCount.
  ///
  /// In en, this message translates to:
  /// **'{n} going'**
  String goingCount(int n);

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @guestName.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get guestName;

  /// No description provided for @happeningNow.
  ///
  /// In en, this message translates to:
  /// **'Happening now'**
  String get happeningNow;

  /// No description provided for @happeningNowBadge.
  ///
  /// In en, this message translates to:
  /// **'HAPPENING NOW'**
  String get happeningNowBadge;

  /// No description provided for @happeningNowHeader.
  ///
  /// In en, this message translates to:
  /// **'Happening Now'**
  String get happeningNowHeader;

  /// No description provided for @happeningNowInline.
  ///
  /// In en, this message translates to:
  /// **'Happening now'**
  String get happeningNowInline;

  /// No description provided for @happeningNowLabel.
  ///
  /// In en, this message translates to:
  /// **'HAPPENING NOW'**
  String get happeningNowLabel;

  /// No description provided for @heroCampusLine1.
  ///
  /// In en, this message translates to:
  /// **'Your campus,'**
  String get heroCampusLine1;

  /// No description provided for @heroCampusLine2.
  ///
  /// In en, this message translates to:
  /// **'in your pocket.'**
  String get heroCampusLine2;

  /// No description provided for @heroSubtext.
  ///
  /// In en, this message translates to:
  /// **'Class schedules, dining, events, and the people who make Koç University home.'**
  String get heroSubtext;

  /// No description provided for @highlight.
  ///
  /// In en, this message translates to:
  /// **'Highlight'**
  String get highlight;

  /// No description provided for @hostedBy.
  ///
  /// In en, this message translates to:
  /// **'HOSTED BY'**
  String get hostedBy;

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{n,plural, one{1h ago} other{{n}h ago}}'**
  String hoursAgo(num n);

  /// No description provided for @hoursAgoSuffix.
  ///
  /// In en, this message translates to:
  /// **'{n}h ago'**
  String hoursAgoSuffix(int n);

  /// No description provided for @hoursShort.
  ///
  /// In en, this message translates to:
  /// **'{n}h'**
  String hoursShort(int n);

  /// No description provided for @inDaysCount.
  ///
  /// In en, this message translates to:
  /// **'{n,plural, one{In 1 day} other{In {n} days}}'**
  String inDaysCount(num n);

  /// No description provided for @inNDays.
  ///
  /// In en, this message translates to:
  /// **'In {days} days'**
  String inNDays(int days);

  /// No description provided for @incorrectEmailOrPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password'**
  String get incorrectEmailOrPassword;

  /// No description provided for @insightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insightsTitle;

  /// No description provided for @interestMatchCount.
  ///
  /// In en, this message translates to:
  /// **'{n,plural, one{1 interest match} other{{n} interest matches}}'**
  String interestMatchCount(num n);

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @justNowShort.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get justNowShort;

  /// No description provided for @kuStudentLabel.
  ///
  /// In en, this message translates to:
  /// **'KU student'**
  String get kuStudentLabel;

  /// No description provided for @lessLabel.
  ///
  /// In en, this message translates to:
  /// **'less'**
  String get lessLabel;

  /// No description provided for @letsGoArrow.
  ///
  /// In en, this message translates to:
  /// **'Let\'s go →'**
  String get letsGoArrow;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @likesCount.
  ///
  /// In en, this message translates to:
  /// **'{n,plural, one{1 like} other{{n} likes}}'**
  String likesCount(int n);

  /// No description provided for @linkedinOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'LinkedIn (optional)'**
  String get linkedinOptionalLabel;

  /// No description provided for @liveNowCount.
  ///
  /// In en, this message translates to:
  /// **'{n,plural, one{1 live now} other{{n} live now}}'**
  String liveNowCount(num n);

  /// No description provided for @liveNowFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'live now'**
  String get liveNowFilterLabel;

  /// No description provided for @liveNowFollowingClub.
  ///
  /// In en, this message translates to:
  /// **'Live now · you follow {club}'**
  String liveNowFollowingClub(String club);

  /// No description provided for @liveNowOnCampus.
  ///
  /// In en, this message translates to:
  /// **'Live now on campus'**
  String get liveNowOnCampus;

  /// No description provided for @loadingConnections.
  ///
  /// In en, this message translates to:
  /// **'Loading connections...'**
  String get loadingConnections;

  /// No description provided for @loadingMajors.
  ///
  /// In en, this message translates to:
  /// **'Loading majors...'**
  String get loadingMajors;

  /// No description provided for @loadingMembers.
  ///
  /// In en, this message translates to:
  /// **'Loading members...'**
  String get loadingMembers;

  /// No description provided for @locationHint.
  ///
  /// In en, this message translates to:
  /// **'Write the event location'**
  String get locationHint;

  /// No description provided for @locationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationLabel;

  /// No description provided for @locationOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Location (optional)'**
  String get locationOptionalLabel;

  /// No description provided for @logIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get logIn;

  /// No description provided for @majorFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Major'**
  String get majorFieldLabel;

  /// No description provided for @majorLabel.
  ///
  /// In en, this message translates to:
  /// **'Major'**
  String get majorLabel;

  /// No description provided for @managingBadge.
  ///
  /// In en, this message translates to:
  /// **'MANAGING'**
  String get managingBadge;

  /// No description provided for @matchesYourInterest.
  ///
  /// In en, this message translates to:
  /// **'Matches your {tag} interest'**
  String matchesYourInterest(String tag);

  /// No description provided for @memberCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{n} members'**
  String memberCountLabel(int n);

  /// No description provided for @memberProfilesLoadError.
  ///
  /// In en, this message translates to:
  /// **'Member profiles could not be loaded.'**
  String get memberProfilesLoadError;

  /// No description provided for @memberRoleDefault.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get memberRoleDefault;

  /// No description provided for @memberRoleFallback.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get memberRoleFallback;

  /// No description provided for @memberRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get memberRoleLabel;

  /// No description provided for @members.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get members;

  /// No description provided for @membersCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'{count,plural, one{1 member} other{{count} members}} · {category}'**
  String membersCategoryLabel(num count, String category);

  /// No description provided for @membersCount.
  ///
  /// In en, this message translates to:
  /// **'{count,plural, one{1 member} other{{count} members}}'**
  String membersCount(num count);

  /// No description provided for @membersCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count,plural, one{1 member} other{{count} members}}'**
  String membersCountLabel(num count);

  /// No description provided for @membersLabel.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get membersLabel;

  /// No description provided for @membersMatchInterests.
  ///
  /// In en, this message translates to:
  /// **'{count} members · matches your interests'**
  String membersMatchInterests(int count);

  /// No description provided for @mentionTypeClub.
  ///
  /// In en, this message translates to:
  /// **'Club'**
  String get mentionTypeClub;

  /// No description provided for @mentionTypeStudent.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get mentionTypeStudent;

  /// No description provided for @minorIn.
  ///
  /// In en, this message translates to:
  /// **'Minor in {majors}'**
  String minorIn(String majors);

  /// No description provided for @minorLabel.
  ///
  /// In en, this message translates to:
  /// **'Minor'**
  String get minorLabel;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{n,plural, one{1m ago} other{{n}m ago}}'**
  String minutesAgo(num n);

  /// No description provided for @minutesAgoSuffix.
  ///
  /// In en, this message translates to:
  /// **'{n}m ago'**
  String minutesAgoSuffix(int n);

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'{n}m'**
  String minutesShort(int n);

  /// No description provided for @monthAbbr.
  ///
  /// In en, this message translates to:
  /// **'{month, select, 1{JAN} 2{FEB} 3{MAR} 4{APR} 5{MAY} 6{JUN} 7{JUL} 8{AUG} 9{SEP} 10{OCT} 11{NOV} 12{DEC} other{}}'**
  String monthAbbr(String month);

  /// No description provided for @monthApr.
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get monthApr;

  /// No description provided for @monthApril.
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get monthApril;

  /// No description provided for @monthAug.
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get monthAug;

  /// No description provided for @monthAugust.
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get monthAugust;

  /// No description provided for @monthDec.
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get monthDec;

  /// No description provided for @monthDecember.
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get monthDecember;

  /// No description provided for @monthFeb.
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get monthFeb;

  /// No description provided for @monthFebruary.
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get monthFebruary;

  /// No description provided for @monthJan.
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get monthJan;

  /// No description provided for @monthJanuary.
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get monthJanuary;

  /// No description provided for @monthJul.
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get monthJul;

  /// No description provided for @monthJuly.
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get monthJuly;

  /// No description provided for @monthJun.
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get monthJun;

  /// No description provided for @monthJune.
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get monthJune;

  /// No description provided for @monthMar.
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get monthMar;

  /// No description provided for @monthMarch.
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get monthMarch;

  /// No description provided for @monthMay.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get monthMay;

  /// No description provided for @monthNov.
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get monthNov;

  /// No description provided for @monthNovember.
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get monthNovember;

  /// No description provided for @monthOct.
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get monthOct;

  /// No description provided for @monthOctober.
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get monthOctober;

  /// No description provided for @monthSep.
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get monthSep;

  /// No description provided for @monthSeptember.
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get monthSeptember;

  /// No description provided for @moreLabel.
  ///
  /// In en, this message translates to:
  /// **'more'**
  String get moreLabel;

  /// No description provided for @mutualBadgeCount.
  ///
  /// In en, this message translates to:
  /// **'{mutualLabel} mutuals'**
  String mutualBadgeCount(String mutualLabel);

  /// No description provided for @mutualFriendCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Followed by {mutualLabel} people you follow'**
  String mutualFriendCountLabel(String mutualLabel);

  /// No description provided for @mutualFriendNamed.
  ///
  /// In en, this message translates to:
  /// **'Followed by {name}'**
  String mutualFriendNamed(String name);

  /// No description provided for @mutualFriendNamedPlus.
  ///
  /// In en, this message translates to:
  /// **'Followed by {name} + {extra} more'**
  String mutualFriendNamedPlus(String name, int extra);

  /// No description provided for @myCalendarTitle.
  ///
  /// In en, this message translates to:
  /// **'My Calendar'**
  String get myCalendarTitle;

  /// No description provided for @myProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get myProfileTitle;

  /// No description provided for @newEventTitle.
  ///
  /// In en, this message translates to:
  /// **'New Event'**
  String get newEventTitle;

  /// No description provided for @newLabel.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newLabel;

  /// No description provided for @newPostTitle.
  ///
  /// In en, this message translates to:
  /// **'New Post'**
  String get newPostTitle;

  /// No description provided for @newThisWeek.
  ///
  /// In en, this message translates to:
  /// **'NEW THIS WEEK'**
  String get newThisWeek;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @nextArrow.
  ///
  /// In en, this message translates to:
  /// **'Next →'**
  String get nextArrow;

  /// No description provided for @nextMonthLabel.
  ///
  /// In en, this message translates to:
  /// **'· next month'**
  String get nextMonthLabel;

  /// No description provided for @noBioYet.
  ///
  /// In en, this message translates to:
  /// **'No bio yet.'**
  String get noBioYet;

  /// No description provided for @noClubsFound.
  ///
  /// In en, this message translates to:
  /// **'No clubs found.'**
  String get noClubsFound;

  /// No description provided for @noClubsYetShort.
  ///
  /// In en, this message translates to:
  /// **'No clubs yet.'**
  String get noClubsYetShort;

  /// No description provided for @noCollaborationsYet.
  ///
  /// In en, this message translates to:
  /// **'No collaborations yet.\nPosts that tag this club with @ will appear here.'**
  String get noCollaborationsYet;

  /// No description provided for @noEventImageSelected.
  ///
  /// In en, this message translates to:
  /// **'No event image selected'**
  String get noEventImageSelected;

  /// No description provided for @noFollowedClubsYet.
  ///
  /// In en, this message translates to:
  /// **'No followed clubs yet.'**
  String get noFollowedClubsYet;

  /// No description provided for @noLikesYet.
  ///
  /// In en, this message translates to:
  /// **'No likes yet'**
  String get noLikesYet;

  /// No description provided for @noLiveEventNow.
  ///
  /// In en, this message translates to:
  /// **'No event is live at the moment.'**
  String get noLiveEventNow;

  /// No description provided for @noMatchesFoundDot.
  ///
  /// In en, this message translates to:
  /// **'No matches found.'**
  String get noMatchesFoundDot;

  /// No description provided for @noMatchingMajor.
  ///
  /// In en, this message translates to:
  /// **'No matching major'**
  String get noMatchingMajor;

  /// No description provided for @noMembersToShowYet.
  ///
  /// In en, this message translates to:
  /// **'No members to show yet.'**
  String get noMembersToShowYet;

  /// No description provided for @noNewClubsToSuggest.
  ///
  /// In en, this message translates to:
  /// **'No new clubs to suggest — you\'re already well-connected!'**
  String get noNewClubsToSuggest;

  /// No description provided for @noPastEventsToShow.
  ///
  /// In en, this message translates to:
  /// **'No past events to show.'**
  String get noPastEventsToShow;

  /// No description provided for @noRepeatedNumbersSideBySide.
  ///
  /// In en, this message translates to:
  /// **'No same numbers side by side'**
  String get noRepeatedNumbersSideBySide;

  /// No description provided for @noRsvpsYet.
  ///
  /// In en, this message translates to:
  /// **'No RSVPs yet.'**
  String get noRsvpsYet;

  /// No description provided for @noSavedEventsYet.
  ///
  /// In en, this message translates to:
  /// **'No saved events yet'**
  String get noSavedEventsYet;

  /// No description provided for @noSavedPostsYet.
  ///
  /// In en, this message translates to:
  /// **'No saved posts yet'**
  String get noSavedPostsYet;

  /// No description provided for @noSequentialNumbersSideBySide.
  ///
  /// In en, this message translates to:
  /// **'No sequential numbers side by side'**
  String get noSequentialNumbersSideBySide;

  /// No description provided for @noTitleSet.
  ///
  /// In en, this message translates to:
  /// **'No title set'**
  String get noTitleSet;

  /// No description provided for @noViewsYet.
  ///
  /// In en, this message translates to:
  /// **'No views yet'**
  String get noViewsYet;

  /// No description provided for @notComing.
  ///
  /// In en, this message translates to:
  /// **'Not Coming'**
  String get notComing;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not Now'**
  String get notNow;

  /// No description provided for @nothingHereRightNow.
  ///
  /// In en, this message translates to:
  /// **'Nothing here right now.'**
  String get nothingHereRightNow;

  /// No description provided for @nowFollowingPerson.
  ///
  /// In en, this message translates to:
  /// **'You are now following {name}.'**
  String nowFollowingPerson(String name);

  /// No description provided for @nowSegmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get nowSegmentLabel;

  /// No description provided for @officialClubLabel.
  ///
  /// In en, this message translates to:
  /// **'Official Club'**
  String get officialClubLabel;

  /// No description provided for @oneMutualBadge.
  ///
  /// In en, this message translates to:
  /// **'1 mutual'**
  String get oneMutualBadge;

  /// No description provided for @oneMutualFriend.
  ///
  /// In en, this message translates to:
  /// **'Followed by 1 person you follow'**
  String get oneMutualFriend;

  /// No description provided for @onlyKuAddressesAccepted.
  ///
  /// In en, this message translates to:
  /// **'Only @ku.edu.tr addresses are accepted.'**
  String get onlyKuAddressesAccepted;

  /// No description provided for @onlyKuEmailInfoText.
  ///
  /// In en, this message translates to:
  /// **'Only @ku.edu.tr addresses are accepted. Personal emails won\'t work.'**
  String get onlyKuEmailInfoText;

  /// No description provided for @onlyOwningClubCanDelete.
  ///
  /// In en, this message translates to:
  /// **'Only the club that owns this post can delete it.'**
  String get onlyOwningClubCanDelete;

  /// No description provided for @onlyPosterCanViewRsvps.
  ///
  /// In en, this message translates to:
  /// **'Only the event poster can view RSVPs.'**
  String get onlyPosterCanViewRsvps;

  /// No description provided for @openSettingsButton.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettingsButton;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @partnerClubsHeader.
  ///
  /// In en, this message translates to:
  /// **'Partner Clubs'**
  String get partnerClubsHeader;

  /// No description provided for @passwordFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordFieldLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @passwordRulesError.
  ///
  /// In en, this message translates to:
  /// **'Use 6 numbers with no repeated or sequential numbers side by side.'**
  String get passwordRulesError;

  /// No description provided for @pastBadge.
  ///
  /// In en, this message translates to:
  /// **'PAST'**
  String get pastBadge;

  /// No description provided for @peopleCount.
  ///
  /// In en, this message translates to:
  /// **'{n,plural, one{1 person} other{{n} people}}'**
  String peopleCount(int n);

  /// No description provided for @peopleYouFollowGoing.
  ///
  /// In en, this message translates to:
  /// **'People you follow are going'**
  String get peopleYouFollowGoing;

  /// No description provided for @percentFull.
  ///
  /// In en, this message translates to:
  /// **'{pct}% full'**
  String percentFull(int pct);

  /// No description provided for @photoAdded.
  ///
  /// In en, this message translates to:
  /// **'Photo added'**
  String get photoAdded;

  /// No description provided for @photoLabel.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photoLabel;

  /// No description provided for @photoRemovedLocallyDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Photo removed locally, but remote delete failed.'**
  String get photoRemovedLocallyDeleteFailed;

  /// No description provided for @photoSavedLocallyUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Photo saved locally, but upload failed.'**
  String get photoSavedLocallyUploadFailed;

  /// No description provided for @pickAppearanceHint.
  ///
  /// In en, this message translates to:
  /// **'Pick the appearance that feels right. Tap to preview — you can always change it later in Settings.'**
  String get pickAppearanceHint;

  /// No description provided for @pickAsManyInterests.
  ///
  /// In en, this message translates to:
  /// **'Pick as many as you like. We\'ll surface what matters to you.'**
  String get pickAsManyInterests;

  /// No description provided for @pickAtLeastNInterests.
  ///
  /// In en, this message translates to:
  /// **'Pick at least {min} to continue.'**
  String pickAtLeastNInterests(int min);

  /// No description provided for @pickFewMatchHint.
  ///
  /// In en, this message translates to:
  /// **'Pick a few — we\'ll match you with clubs, events, and people. '**
  String get pickFewMatchHint;

  /// No description provided for @pickLanguageHint.
  ///
  /// In en, this message translates to:
  /// **'Pick the language for the app. You can always change it later in Settings.'**
  String get pickLanguageHint;

  /// No description provided for @pinToTop.
  ///
  /// In en, this message translates to:
  /// **'Pin to top'**
  String get pinToTop;

  /// No description provided for @pleaseEnterFirstLastName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your first and last name.'**
  String get pleaseEnterFirstLastName;

  /// No description provided for @pleaseEnterFullName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your full name.'**
  String get pleaseEnterFullName;

  /// No description provided for @pleaseEnterUniversityEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your university email.'**
  String get pleaseEnterUniversityEmail;

  /// No description provided for @pleasePickMajorFromList.
  ///
  /// In en, this message translates to:
  /// **'Please pick a major from the list.'**
  String get pleasePickMajorFromList;

  /// No description provided for @pleaseSelectMajor.
  ///
  /// In en, this message translates to:
  /// **'Please select your major.'**
  String get pleaseSelectMajor;

  /// No description provided for @pleaseSelectYear.
  ///
  /// In en, this message translates to:
  /// **'Please select your year.'**
  String get pleaseSelectYear;

  /// No description provided for @popularOnCampus.
  ///
  /// In en, this message translates to:
  /// **'Popular on campus'**
  String get popularOnCampus;

  /// No description provided for @postDeletedConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Post deleted'**
  String get postDeletedConfirmation;

  /// No description provided for @postLikes.
  ///
  /// In en, this message translates to:
  /// **'Post likes'**
  String get postLikes;

  /// No description provided for @postLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Post link copied to clipboard'**
  String get postLinkCopied;

  /// No description provided for @postViewersTitle.
  ///
  /// In en, this message translates to:
  /// **'Post Viewers'**
  String get postViewersTitle;

  /// No description provided for @postViews.
  ///
  /// In en, this message translates to:
  /// **'Post views'**
  String get postViews;

  /// No description provided for @postingAsClub.
  ///
  /// In en, this message translates to:
  /// **'Posting as {clubName}'**
  String postingAsClub(String clubName);

  /// No description provided for @postingAsLabel.
  ///
  /// In en, this message translates to:
  /// **'Posting as'**
  String get postingAsLabel;

  /// No description provided for @postsCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Posts ({count})'**
  String postsCountLabel(int count);

  /// No description provided for @postsFeaturingClub.
  ///
  /// In en, this message translates to:
  /// **'Posts featuring this club'**
  String get postsFeaturingClub;

  /// No description provided for @presidentSecretaryHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. President, Secretary…'**
  String get presidentSecretaryHint;

  /// No description provided for @prioritiseEventsSchedule.
  ///
  /// In en, this message translates to:
  /// **'We\'ll prioritise events that fit your schedule.'**
  String get prioritiseEventsSchedule;

  /// No description provided for @profileLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s profile link copied to clipboard'**
  String profileLinkCopied(String name);

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileUpdated;

  /// No description provided for @programme.
  ///
  /// In en, this message translates to:
  /// **'Programme'**
  String get programme;

  /// No description provided for @programmeLabel.
  ///
  /// In en, this message translates to:
  /// **'Programme'**
  String get programmeLabel;

  /// No description provided for @programmeSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add a timetable for your event'**
  String get programmeSectionSubtitle;

  /// No description provided for @publishErrorGenericEvent.
  ///
  /// In en, this message translates to:
  /// **'Could not publish event. Check Supabase settings.'**
  String get publishErrorGenericEvent;

  /// No description provided for @publishErrorMigrationEvent.
  ///
  /// In en, this message translates to:
  /// **'Could not publish event. Run the latest events SQL migration.'**
  String get publishErrorMigrationEvent;

  /// No description provided for @publishErrorRlsPolicyEvent.
  ///
  /// In en, this message translates to:
  /// **'Could not publish event. Check events RLS policies for this club account.'**
  String get publishErrorRlsPolicyEvent;

  /// No description provided for @publishErrorStorageEvent.
  ///
  /// In en, this message translates to:
  /// **'Could not upload event image. Check the event-images bucket policies.'**
  String get publishErrorStorageEvent;

  /// No description provided for @publishEventButton.
  ///
  /// In en, this message translates to:
  /// **'Publish Event'**
  String get publishEventButton;

  /// No description provided for @quickSetupSteps.
  ///
  /// In en, this message translates to:
  /// **'Quick setup — just 4 steps'**
  String get quickSetupSteps;

  /// No description provided for @readyToPost.
  ///
  /// In en, this message translates to:
  /// **'Ready to post?'**
  String get readyToPost;

  /// No description provided for @recapLabel.
  ///
  /// In en, this message translates to:
  /// **'Recap'**
  String get recapLabel;

  /// No description provided for @registeredCount.
  ///
  /// In en, this message translates to:
  /// **'{n} registered'**
  String registeredCount(int n);

  /// No description provided for @registration.
  ///
  /// In en, this message translates to:
  /// **'Registration'**
  String get registration;

  /// No description provided for @registrationLabel.
  ///
  /// In en, this message translates to:
  /// **'Registration'**
  String get registrationLabel;

  /// No description provided for @registrationSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send attendees to your own sign-up form'**
  String get registrationSectionSubtitle;

  /// No description provided for @remindMeLabel.
  ///
  /// In en, this message translates to:
  /// **'Remind me'**
  String get remindMeLabel;

  /// No description provided for @remindedLabel.
  ///
  /// In en, this message translates to:
  /// **'Remind ✓'**
  String get remindedLabel;

  /// No description provided for @reminderRemoved.
  ///
  /// In en, this message translates to:
  /// **'Reminder removed'**
  String get reminderRemoved;

  /// No description provided for @reminderSetMsg.
  ///
  /// In en, this message translates to:
  /// **'Reminder set — we\'ll alert you before it starts'**
  String get reminderSetMsg;

  /// No description provided for @removeBoardMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Board Member'**
  String get removeBoardMemberTitle;

  /// No description provided for @removeFromBoardLabel.
  ///
  /// In en, this message translates to:
  /// **'Remove from board'**
  String get removeFromBoardLabel;

  /// No description provided for @removeFromClubLabel.
  ///
  /// In en, this message translates to:
  /// **'Remove from club'**
  String get removeFromClubLabel;

  /// No description provided for @removeFromSaved.
  ///
  /// In en, this message translates to:
  /// **'Remove from saved'**
  String get removeFromSaved;

  /// No description provided for @removeLabel.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeLabel;

  /// No description provided for @removeRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Remove role'**
  String get removeRoleLabel;

  /// No description provided for @removedFromBoard.
  ///
  /// In en, this message translates to:
  /// **'{name} removed from the board.'**
  String removedFromBoard(String name);

  /// No description provided for @removedFromSaved.
  ///
  /// In en, this message translates to:
  /// **'Removed from saved'**
  String get removedFromSaved;

  /// No description provided for @requested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get requested;

  /// No description provided for @requestedLabel.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get requestedLabel;

  /// No description provided for @resendCodeButton.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resendCodeButton;

  /// No description provided for @resendInTime.
  ///
  /// In en, this message translates to:
  /// **'Resend in {time}'**
  String resendInTime(String time);

  /// No description provided for @resultsCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{n,plural, one{1 result} other{{n} results}}'**
  String resultsCountLabel(num n);

  /// No description provided for @reviewSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Here\'s how your event will appear'**
  String get reviewSectionSubtitle;

  /// No description provided for @roleDeptHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. History'**
  String get roleDeptHint;

  /// No description provided for @roleOrDepartmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Role / department'**
  String get roleOrDepartmentLabel;

  /// No description provided for @rsvpdAt.
  ///
  /// In en, this message translates to:
  /// **'RSVP\'d {timestamp}'**
  String rsvpdAt(String timestamp);

  /// No description provided for @rsvpsBadge.
  ///
  /// In en, this message translates to:
  /// **'RSVPs'**
  String get rsvpsBadge;

  /// No description provided for @rsvpsLabel.
  ///
  /// In en, this message translates to:
  /// **'RSVPs'**
  String get rsvpsLabel;

  /// No description provided for @saveChangesButton.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChangesButton;

  /// No description provided for @savedPostsStudentsOnly.
  ///
  /// In en, this message translates to:
  /// **'Saved posts are only available for students.'**
  String get savedPostsStudentsOnly;

  /// No description provided for @savedPostsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Saved posts'**
  String get savedPostsTooltip;

  /// No description provided for @savedTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get savedTitle;

  /// No description provided for @savedToEvents.
  ///
  /// In en, this message translates to:
  /// **'Saved to your events'**
  String get savedToEvents;

  /// No description provided for @savingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get savingEllipsis;

  /// No description provided for @searchFollowersHint.
  ///
  /// In en, this message translates to:
  /// **'Search followers by name...'**
  String get searchFollowersHint;

  /// No description provided for @searchMajorsHint.
  ///
  /// In en, this message translates to:
  /// **'Search majors'**
  String get searchMajorsHint;

  /// No description provided for @searchYourMajor.
  ///
  /// In en, this message translates to:
  /// **'Search your major...'**
  String get searchYourMajor;

  /// No description provided for @seatsTaken.
  ///
  /// In en, this message translates to:
  /// **'{taken} of {capacity} seats taken'**
  String seatsTaken(int taken, int capacity);

  /// No description provided for @selectClubHint.
  ///
  /// In en, this message translates to:
  /// **'Select club'**
  String get selectClubHint;

  /// No description provided for @selectDoubleMajorHint.
  ///
  /// In en, this message translates to:
  /// **'Select a double major'**
  String get selectDoubleMajorHint;

  /// No description provided for @selectMinorHint.
  ///
  /// In en, this message translates to:
  /// **'Select a minor'**
  String get selectMinorHint;

  /// No description provided for @selectedOfMinCount.
  ///
  /// In en, this message translates to:
  /// **'({selected} of {min} min.)'**
  String selectedOfMinCount(int selected, int min);

  /// No description provided for @sendCodeToConfirmKocStudent.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send a code to confirm you\'re a Koç student.'**
  String get sendCodeToConfirmKocStudent;

  /// No description provided for @sessionTitleRequiredHint.
  ///
  /// In en, this message translates to:
  /// **'Session title (required)'**
  String get sessionTitleRequiredHint;

  /// No description provided for @setPasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Set password'**
  String get setPasswordButton;

  /// No description provided for @setTitleForMember.
  ///
  /// In en, this message translates to:
  /// **'Set title for {name}'**
  String setTitleForMember(String name);

  /// No description provided for @setTitleTooltip.
  ///
  /// In en, this message translates to:
  /// **'Set title'**
  String get setTitleTooltip;

  /// No description provided for @setUp.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get setUp;

  /// No description provided for @shareProfileTooltip.
  ///
  /// In en, this message translates to:
  /// **'Share profile'**
  String get shareProfileTooltip;

  /// No description provided for @shareUpdateWithFollowers.
  ///
  /// In en, this message translates to:
  /// **'Share an update with your followers'**
  String get shareUpdateWithFollowers;

  /// No description provided for @sharesCount.
  ///
  /// In en, this message translates to:
  /// **'{n,plural, one{1 share} other{{n} shares}}'**
  String sharesCount(int n);

  /// No description provided for @showEventsForSelectedDates.
  ///
  /// In en, this message translates to:
  /// **'{n,plural, one{Show events for 1 selected date} other{Show events for {n} selected dates}}'**
  String showEventsForSelectedDates(num n);

  /// No description provided for @showFullCaptionSemantic.
  ///
  /// In en, this message translates to:
  /// **'Show full caption'**
  String get showFullCaptionSemantic;

  /// No description provided for @showLessCaptionSemantic.
  ///
  /// In en, this message translates to:
  /// **'Show less caption'**
  String get showLessCaptionSemantic;

  /// No description provided for @showsOnCampusProfile.
  ///
  /// In en, this message translates to:
  /// **'This shows up on your campus profile.'**
  String get showsOnCampusProfile;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUp;

  /// No description provided for @signUpOnClubForm.
  ///
  /// In en, this message translates to:
  /// **'Sign up on the club\'s form · {url}'**
  String signUpOnClubForm(String url);

  /// No description provided for @signupRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Signup request failed.'**
  String get signupRequestFailed;

  /// No description provided for @signupServerNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Supabase is not configured. Start the app with SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY.'**
  String get signupServerNotConfigured;

  /// No description provided for @signupUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Sign-up URL'**
  String get signupUrlLabel;

  /// No description provided for @skipSetup.
  ///
  /// In en, this message translates to:
  /// **'Skip setup'**
  String get skipSetup;

  /// No description provided for @skipTour.
  ///
  /// In en, this message translates to:
  /// **'Skip tour'**
  String get skipTour;

  /// No description provided for @speakerNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Prof. Elif Yıldız'**
  String get speakerNameHint;

  /// No description provided for @speakerNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Speaker name'**
  String get speakerNameLabel;

  /// No description provided for @speakers.
  ///
  /// In en, this message translates to:
  /// **'Speakers'**
  String get speakers;

  /// No description provided for @speakersLabel.
  ///
  /// In en, this message translates to:
  /// **'Speakers'**
  String get speakersLabel;

  /// No description provided for @speakersSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Optional — add speaker name, role & LinkedIn'**
  String get speakersSectionSubtitle;

  /// No description provided for @startExploring.
  ///
  /// In en, this message translates to:
  /// **'Start exploring'**
  String get startExploring;

  /// No description provided for @startsLabel.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get startsLabel;

  /// No description provided for @stepProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total} · {title}'**
  String stepProgressLabel(int current, int total, String title);

  /// No description provided for @studentFallbackName.
  ///
  /// In en, this message translates to:
  /// **'A student'**
  String get studentFallbackName;

  /// No description provided for @studentIdLabel.
  ///
  /// In en, this message translates to:
  /// **'STUDENT ID'**
  String get studentIdLabel;

  /// No description provided for @studentPasswordMustBe6Digits.
  ///
  /// In en, this message translates to:
  /// **'Student password must be exactly 6 digits.'**
  String get studentPasswordMustBe6Digits;

  /// No description provided for @studentPasswordRule.
  ///
  /// In en, this message translates to:
  /// **'Use 6 numbers with no repeated or sequential numbers side by side.'**
  String get studentPasswordRule;

  /// No description provided for @studentProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Student Profile'**
  String get studentProfileTitle;

  /// No description provided for @students.
  ///
  /// In en, this message translates to:
  /// **'Students'**
  String get students;

  /// No description provided for @studentsAreMembersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} student is a member} other{{count} students are members}}'**
  String studentsAreMembersCount(num count);

  /// No description provided for @subtitleSpeakerOptionalHint.
  ///
  /// In en, this message translates to:
  /// **'Subtitle / speaker (optional)'**
  String get subtitleSpeakerOptionalHint;

  /// No description provided for @suggestClubsFitField.
  ///
  /// In en, this message translates to:
  /// **'We\'ll suggest clubs that fit your field.'**
  String get suggestClubsFitField;

  /// No description provided for @tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tags;

  /// No description provided for @tagsLabel.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tagsLabel;

  /// No description provided for @tagsSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create your own tags for discovery'**
  String get tagsSectionSubtitle;

  /// No description provided for @takePhotoOption.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get takePhotoOption;

  /// No description provided for @tapBookmarkEventHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the bookmark icon on any event to keep it here.'**
  String get tapBookmarkEventHint;

  /// No description provided for @tapBookmarkPostHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the bookmark icon on any post to keep it here.'**
  String get tapBookmarkPostHint;

  /// No description provided for @tapPublishEventHint.
  ///
  /// In en, this message translates to:
  /// **'Tap Publish Event to share this event with your followers.'**
  String get tapPublishEventHint;

  /// No description provided for @tapSaveChangesHint.
  ///
  /// In en, this message translates to:
  /// **'Tap Save Changes to update this event.'**
  String get tapSaveChangesHint;

  /// No description provided for @tapToPickFromCameraOrLibrary.
  ///
  /// In en, this message translates to:
  /// **'Tap to pick from camera or library'**
  String get tapToPickFromCameraOrLibrary;

  /// No description provided for @tapToPickPhotoHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to pick from camera or library'**
  String get tapToPickPhotoHint;

  /// No description provided for @tellUsAboutYouTitle.
  ///
  /// In en, this message translates to:
  /// **'Tell us about you.'**
  String get tellUsAboutYouTitle;

  /// No description provided for @tellUsInterests.
  ///
  /// In en, this message translates to:
  /// **'Tell us your interests and we\'ll personalise this for you.'**
  String get tellUsInterests;

  /// No description provided for @templateLabel.
  ///
  /// In en, this message translates to:
  /// **'Template'**
  String get templateLabel;

  /// No description provided for @thisWeekEventsCount.
  ///
  /// In en, this message translates to:
  /// **'{n,plural, one{1 this week} other{{n} this week}}'**
  String thisWeekEventsCount(num n);

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @timeAgoDays.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String timeAgoDays(int days);

  /// No description provided for @timeAgoHours.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String timeAgoHours(int hours);

  /// No description provided for @timeAgoInDays.
  ///
  /// In en, this message translates to:
  /// **'in {days}d'**
  String timeAgoInDays(int days);

  /// No description provided for @timeAgoInHours.
  ///
  /// In en, this message translates to:
  /// **'in {hours}h'**
  String timeAgoInHours(int hours);

  /// No description provided for @timeAgoJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeAgoJustNow;

  /// No description provided for @timeAgoMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String timeAgoMinutes(int minutes);

  /// No description provided for @timeAgoSoon.
  ///
  /// In en, this message translates to:
  /// **'soon'**
  String get timeAgoSoon;

  /// No description provided for @titleFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get titleFieldLabel;

  /// No description provided for @todayAtTime.
  ///
  /// In en, this message translates to:
  /// **'Today · {time}'**
  String todayAtTime(String time);

  /// No description provided for @todayEventsCount.
  ///
  /// In en, this message translates to:
  /// **'{n,plural, one{1 today} other{{n} today}}'**
  String todayEventsCount(num n);

  /// No description provided for @topPosts.
  ///
  /// In en, this message translates to:
  /// **'Top posts'**
  String get topPosts;

  /// No description provided for @totalCount.
  ///
  /// In en, this message translates to:
  /// **'{n} total'**
  String totalCount(int n);

  /// No description provided for @tune.
  ///
  /// In en, this message translates to:
  /// **'Tune'**
  String get tune;

  /// No description provided for @tutorialDescAlertsClub.
  ///
  /// In en, this message translates to:
  /// **'New followers and event activity collect here. Tap an alert to open it, or clear them all with this button.'**
  String get tutorialDescAlertsClub;

  /// No description provided for @tutorialDescAppearanceReplay.
  ///
  /// In en, this message translates to:
  /// **'The gear opens Settings — appearance and “{replayLabel}” whenever you want this tour again.'**
  String tutorialDescAppearanceReplay(String replayLabel);

  /// No description provided for @tutorialDescBoardAppearanceReplay.
  ///
  /// In en, this message translates to:
  /// **'The gear opens Settings — add or remove board members, switch appearance, and replay this tour whenever you want.'**
  String get tutorialDescBoardAppearanceReplay;

  /// No description provided for @tutorialDescClubProfile.
  ///
  /// In en, this message translates to:
  /// **'This is your club’s public profile. Switch tabs to manage posts and events — tap the ⋯ menu on any of yours to pin or delete it, or tap an event’s attendee count to see who’s coming.'**
  String get tutorialDescClubProfile;

  /// No description provided for @tutorialDescExploreOwnPace.
  ///
  /// In en, this message translates to:
  /// **'That’s the tour. It won’t pop up again automatically — replay it anytime from Profile → Settings.'**
  String get tutorialDescExploreOwnPace;

  /// No description provided for @tutorialDescFeedYourWay.
  ///
  /// In en, this message translates to:
  /// **'Switch between Following and All to control what you see. Like, RSVP, save, and share right from each post.'**
  String get tutorialDescFeedYourWay;

  /// No description provided for @tutorialDescFindPeopleClubs.
  ///
  /// In en, this message translates to:
  /// **'Search students by name or major, and clubs by name. Use the tabs above to switch between People and Clubs.'**
  String get tutorialDescFindPeopleClubs;

  /// No description provided for @tutorialDescFiveSections.
  ///
  /// In en, this message translates to:
  /// **'This bar stays with you everywhere: Home, Events, Search, Alerts, and Profile. The active one turns red.'**
  String get tutorialDescFiveSections;

  /// No description provided for @tutorialDescFourSections.
  ///
  /// In en, this message translates to:
  /// **'Home, Events, Alerts, and Profile stay with you everywhere. The center button replaces Search — it’s reserved for posting.'**
  String get tutorialDescFourSections;

  /// No description provided for @tutorialDescInsights.
  ///
  /// In en, this message translates to:
  /// **'Track views, likes, and top posts so you know what your followers respond to.'**
  String get tutorialDescInsights;

  /// No description provided for @tutorialDescPostNewEvent.
  ///
  /// In en, this message translates to:
  /// **'Tap the center button anytime to open the event form — title, time, location, and audience.'**
  String get tutorialDescPostNewEvent;

  /// No description provided for @tutorialDescQuickTextUpdates.
  ///
  /// In en, this message translates to:
  /// **'This composer posts a quick update to your club’s followers — no need for the full event form for a text-only post.'**
  String get tutorialDescQuickTextUpdates;

  /// No description provided for @tutorialDescRsvpOneTap.
  ///
  /// In en, this message translates to:
  /// **'Tap RSVP to mark you’re going — it turns to “Going” and can flow into your calendar. Search and filter the agenda up top.'**
  String get tutorialDescRsvpOneTap;

  /// No description provided for @tutorialDescRunClub.
  ///
  /// In en, this message translates to:
  /// **'A quick tour of the tools you get as a club admin — we’ll point to the real buttons as we go.'**
  String get tutorialDescRunClub;

  /// No description provided for @tutorialDescStayInLoopStudent.
  ///
  /// In en, this message translates to:
  /// **'Follows, club posts, and event changes collect here. Tap an alert to open it, filter with the chips, or clear them all with this button.'**
  String get tutorialDescStayInLoopStudent;

  /// No description provided for @tutorialDescThisIsYou.
  ///
  /// In en, this message translates to:
  /// **'Tap your photo, name, or bio to edit them so classmates recognize you. Your clubs, RSVPs, and stats live here too.'**
  String get tutorialDescThisIsYou;

  /// No description provided for @tutorialDescWelcome.
  ///
  /// In en, this message translates to:
  /// **'A quick, tappable tour of the app — we’ll point to the real buttons as we go.'**
  String get tutorialDescWelcome;

  /// No description provided for @tutorialEyebrowCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get tutorialEyebrowCreate;

  /// No description provided for @tutorialEyebrowGettingAround.
  ///
  /// In en, this message translates to:
  /// **'Getting around'**
  String get tutorialEyebrowGettingAround;

  /// No description provided for @tutorialEyebrowInsights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get tutorialEyebrowInsights;

  /// No description provided for @tutorialEyebrowWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get tutorialEyebrowWelcome;

  /// No description provided for @tutorialEyebrowYourClub.
  ///
  /// In en, this message translates to:
  /// **'Your club'**
  String get tutorialEyebrowYourClub;

  /// No description provided for @tutorialEyebrowYoureSet.
  ///
  /// In en, this message translates to:
  /// **'You’re set'**
  String get tutorialEyebrowYoureSet;

  /// No description provided for @tutorialTipActiveSectionRed.
  ///
  /// In en, this message translates to:
  /// **'The active section turns red.'**
  String get tutorialTipActiveSectionRed;

  /// No description provided for @tutorialTipAddPhotoBiggerPost.
  ///
  /// In en, this message translates to:
  /// **'Add a photo for a bigger, more visible post.'**
  String get tutorialTipAddPhotoBiggerPost;

  /// No description provided for @tutorialTipAllMixes.
  ///
  /// In en, this message translates to:
  /// **'All mixes in campus recommendations.'**
  String get tutorialTipAllMixes;

  /// No description provided for @tutorialTipBadgeMeansNew.
  ///
  /// In en, this message translates to:
  /// **'A badge on the bar means something’s new.'**
  String get tutorialTipBadgeMeansNew;

  /// No description provided for @tutorialTipBadgesFlag.
  ///
  /// In en, this message translates to:
  /// **'Badges flag new activity.'**
  String get tutorialTipBadgesFlag;

  /// No description provided for @tutorialTipBoardListsMembers.
  ///
  /// In en, this message translates to:
  /// **'Board lists your club’s board members and titles.'**
  String get tutorialTipBoardListsMembers;

  /// No description provided for @tutorialTipBoardManagementSettings.
  ///
  /// In en, this message translates to:
  /// **'Board management lives under your club’s section in Settings.'**
  String get tutorialTipBoardManagementSettings;

  /// No description provided for @tutorialTipCollabsJointEvents.
  ///
  /// In en, this message translates to:
  /// **'Collabs shows joint events with other clubs.'**
  String get tutorialTipCollabsJointEvents;

  /// No description provided for @tutorialTipEventShowsUpRightAway.
  ///
  /// In en, this message translates to:
  /// **'Your event shows up in Events for everyone right away.'**
  String get tutorialTipEventShowsUpRightAway;

  /// No description provided for @tutorialTipFilterByDate.
  ///
  /// In en, this message translates to:
  /// **'Filter by date, audience, or what’s live now.'**
  String get tutorialTipFilterByDate;

  /// No description provided for @tutorialTipFollowJoin.
  ///
  /// In en, this message translates to:
  /// **'Follow people and join clubs from the results.'**
  String get tutorialTipFollowJoin;

  /// No description provided for @tutorialTipFollowersFollowing.
  ///
  /// In en, this message translates to:
  /// **'Tap Followers / Following to see who’s who.'**
  String get tutorialTipFollowersFollowing;

  /// No description provided for @tutorialTipFollowingShows.
  ///
  /// In en, this message translates to:
  /// **'Following shows only clubs you follow.'**
  String get tutorialTipFollowingShows;

  /// No description provided for @tutorialTipFollowsRsvpsSaves.
  ///
  /// In en, this message translates to:
  /// **'Your follows, RSVPs, and saves personalize the app.'**
  String get tutorialTipFollowsRsvpsSaves;

  /// No description provided for @tutorialTipHomeFeed.
  ///
  /// In en, this message translates to:
  /// **'Home is your personalized feed.'**
  String get tutorialTipHomeFeed;

  /// No description provided for @tutorialTipOpenEventDetails.
  ///
  /// In en, this message translates to:
  /// **'Open any event for full details.'**
  String get tutorialTipOpenEventDetails;

  /// No description provided for @tutorialTipOpenProfileBeforeFollow.
  ///
  /// In en, this message translates to:
  /// **'Open a profile before you follow.'**
  String get tutorialTipOpenProfileBeforeFollow;

  /// No description provided for @tutorialTipOpeningClearsBadge.
  ///
  /// In en, this message translates to:
  /// **'Opening this tab clears the badge.'**
  String get tutorialTipOpeningClearsBadge;

  /// No description provided for @tutorialTipSkipTour.
  ///
  /// In en, this message translates to:
  /// **'Skip tour is always in the top-right.'**
  String get tutorialTipSkipTour;

  /// No description provided for @tutorialTipSwitchLightDark.
  ///
  /// In en, this message translates to:
  /// **'Switch between light and dark mode here.'**
  String get tutorialTipSwitchLightDark;

  /// No description provided for @tutorialTipTapNext.
  ///
  /// In en, this message translates to:
  /// **'Tap Next, or tap anywhere, to advance.'**
  String get tutorialTipTapNext;

  /// No description provided for @tutorialTipUpNextEvent.
  ///
  /// In en, this message translates to:
  /// **'Your “Up next” event is one tap away.'**
  String get tutorialTipUpNextEvent;

  /// No description provided for @tutorialTipUseBack.
  ///
  /// In en, this message translates to:
  /// **'Use Back to revisit a step.'**
  String get tutorialTipUseBack;

  /// No description provided for @tutorialTitleAppearanceReplay.
  ///
  /// In en, this message translates to:
  /// **'Appearance & replay'**
  String get tutorialTitleAppearanceReplay;

  /// No description provided for @tutorialTitleBoardAppearanceReplay.
  ///
  /// In en, this message translates to:
  /// **'Board, appearance & replay'**
  String get tutorialTitleBoardAppearanceReplay;

  /// No description provided for @tutorialTitleExploreOwnPace.
  ///
  /// In en, this message translates to:
  /// **'Explore at your own pace'**
  String get tutorialTitleExploreOwnPace;

  /// No description provided for @tutorialTitleFeedYourWay.
  ///
  /// In en, this message translates to:
  /// **'Your feed, your way'**
  String get tutorialTitleFeedYourWay;

  /// No description provided for @tutorialTitleFindPeopleClubs.
  ///
  /// In en, this message translates to:
  /// **'Find people & clubs'**
  String get tutorialTitleFindPeopleClubs;

  /// No description provided for @tutorialTitleFiveSections.
  ///
  /// In en, this message translates to:
  /// **'Your five sections'**
  String get tutorialTitleFiveSections;

  /// No description provided for @tutorialTitleFourSections.
  ///
  /// In en, this message translates to:
  /// **'Your four sections'**
  String get tutorialTitleFourSections;

  /// No description provided for @tutorialTitlePostNewEvent.
  ///
  /// In en, this message translates to:
  /// **'Post a new event'**
  String get tutorialTitlePostNewEvent;

  /// No description provided for @tutorialTitlePostsEventsCollabsBoard.
  ///
  /// In en, this message translates to:
  /// **'Posts, Events, Collabs, Board'**
  String get tutorialTitlePostsEventsCollabsBoard;

  /// No description provided for @tutorialTitleQuickTextUpdates.
  ///
  /// In en, this message translates to:
  /// **'Quick text updates'**
  String get tutorialTitleQuickTextUpdates;

  /// No description provided for @tutorialTitleRsvpOneTap.
  ///
  /// In en, this message translates to:
  /// **'RSVP in one tap'**
  String get tutorialTitleRsvpOneTap;

  /// No description provided for @tutorialTitleRunClubFromHere.
  ///
  /// In en, this message translates to:
  /// **'Run your club from here'**
  String get tutorialTitleRunClubFromHere;

  /// No description provided for @tutorialTitleRunClubOwnPace.
  ///
  /// In en, this message translates to:
  /// **'Run your club at your own pace'**
  String get tutorialTitleRunClubOwnPace;

  /// No description provided for @tutorialTitleSeeWhatsLanding.
  ///
  /// In en, this message translates to:
  /// **'See what’s landing'**
  String get tutorialTitleSeeWhatsLanding;

  /// No description provided for @tutorialTitleStayInLoop.
  ///
  /// In en, this message translates to:
  /// **'Stay in the loop'**
  String get tutorialTitleStayInLoop;

  /// No description provided for @tutorialTitleThisIsYou.
  ///
  /// In en, this message translates to:
  /// **'This is you'**
  String get tutorialTitleThisIsYou;

  /// No description provided for @tutorialTitleYourCampus.
  ///
  /// In en, this message translates to:
  /// **'Your campus, in one place'**
  String get tutorialTitleYourCampus;

  /// No description provided for @typeAtToTagHint.
  ///
  /// In en, this message translates to:
  /// **'Type @ to tag a club or student'**
  String get typeAtToTagHint;

  /// No description provided for @typeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get typeLabel;

  /// No description provided for @unfollowedPerson.
  ///
  /// In en, this message translates to:
  /// **'You unfollowed {name}.'**
  String unfollowedPerson(String name);

  /// No description provided for @universityEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'University email'**
  String get universityEmailLabel;

  /// No description provided for @universityYearLabel.
  ///
  /// In en, this message translates to:
  /// **'University year'**
  String get universityYearLabel;

  /// No description provided for @unknownUser.
  ///
  /// In en, this message translates to:
  /// **'Unknown User'**
  String get unknownUser;

  /// No description provided for @unopenedEventsCount.
  ///
  /// In en, this message translates to:
  /// **'{n,plural, one{1 unopened event} other{{n} unopened events}}'**
  String unopenedEventsCount(num n);

  /// No description provided for @unpinFromTop.
  ///
  /// In en, this message translates to:
  /// **'Unpin from top'**
  String get unpinFromTop;

  /// No description provided for @untitledLabel.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitledLabel;

  /// No description provided for @upcomingBadge.
  ///
  /// In en, this message translates to:
  /// **'UPCOMING'**
  String get upcomingBadge;

  /// No description provided for @upcomingSegmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcomingSegmentLabel;

  /// No description provided for @updateYourCommunity.
  ///
  /// In en, this message translates to:
  /// **'Update your community'**
  String get updateYourCommunity;

  /// No description provided for @verifyButton.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verifyButton;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @viewChevron.
  ///
  /// In en, this message translates to:
  /// **'View ›'**
  String get viewChevron;

  /// No description provided for @viewLabel.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get viewLabel;

  /// No description provided for @viewProfileLabel.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get viewProfileLabel;

  /// No description provided for @viewsCount.
  ///
  /// In en, this message translates to:
  /// **'{n,plural, one{1 view} other{{n} views}}'**
  String viewsCount(int n);

  /// No description provided for @weSentCodeToPrefix.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to\n'**
  String get weSentCodeToPrefix;

  /// No description provided for @weeksAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}w ago'**
  String weeksAgo(int n);

  /// No description provided for @weeksShort.
  ///
  /// In en, this message translates to:
  /// **'{n}w'**
  String weeksShort(int n);

  /// No description provided for @welcomeBackCampusHighlight.
  ///
  /// In en, this message translates to:
  /// **'campus'**
  String get welcomeBackCampusHighlight;

  /// No description provided for @welcomeBackToYourPrefix.
  ///
  /// In en, this message translates to:
  /// **'Welcome back to\nyour '**
  String get welcomeBackToYourPrefix;

  /// No description provided for @welcomeToKoc.
  ///
  /// In en, this message translates to:
  /// **'WELCOME TO KOÇ'**
  String get welcomeToKoc;

  /// No description provided for @whatAreYouInto.
  ///
  /// In en, this message translates to:
  /// **'What are you into?'**
  String get whatAreYouInto;

  /// No description provided for @whatsHappeningHint.
  ///
  /// In en, this message translates to:
  /// **'What\'s happening?'**
  String get whatsHappeningHint;

  /// No description provided for @whatsYourMajor.
  ///
  /// In en, this message translates to:
  /// **'What\'s your major?'**
  String get whatsYourMajor;

  /// No description provided for @whatsYourScene.
  ///
  /// In en, this message translates to:
  /// **'What\'s your scene?'**
  String get whatsYourScene;

  /// No description provided for @whatsYourSchoolEmail.
  ///
  /// In en, this message translates to:
  /// **'What\'s your\nschool email?'**
  String get whatsYourSchoolEmail;

  /// No description provided for @whenClubPostsHint.
  ///
  /// In en, this message translates to:
  /// **'When {clubName} posts, it\'ll show up here.'**
  String whenClubPostsHint(String clubName);

  /// No description provided for @whenDoYouHaveTime.
  ///
  /// In en, this message translates to:
  /// **'When do you usually have time?'**
  String get whenDoYouHaveTime;

  /// No description provided for @whenSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set when your event starts and ends'**
  String get whenSectionSubtitle;

  /// No description provided for @whereHint.
  ///
  /// In en, this message translates to:
  /// **'Where?'**
  String get whereHint;

  /// No description provided for @writeForClubMembersHint.
  ///
  /// In en, this message translates to:
  /// **'Write something for your club members…'**
  String get writeForClubMembersHint;

  /// No description provided for @yesRemoveLabel.
  ///
  /// In en, this message translates to:
  /// **'Yes, Remove'**
  String get yesRemoveLabel;

  /// No description provided for @youMayKnowThemKuStudent.
  ///
  /// In en, this message translates to:
  /// **'You may know them · KU student'**
  String get youMayKnowThemKuStudent;

  /// No description provided for @youMightLike.
  ///
  /// In en, this message translates to:
  /// **'You Might Like'**
  String get youMightLike;

  /// No description provided for @yourClubFallback.
  ///
  /// In en, this message translates to:
  /// **'Your club'**
  String get yourClubFallback;

  /// No description provided for @yourEmailFallback.
  ///
  /// In en, this message translates to:
  /// **'your email'**
  String get yourEmailFallback;

  /// No description provided for @yourKuDay.
  ///
  /// In en, this message translates to:
  /// **'Your KU Day'**
  String get yourKuDay;

  /// No description provided for @youreGoing.
  ///
  /// In en, this message translates to:
  /// **'You\'re going'**
  String get youreGoing;

  /// No description provided for @signInToContinueSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to pick up where you left off.'**
  String get signInToContinueSubtitle;

  /// No description provided for @kocUniversityWordmark.
  ///
  /// In en, this message translates to:
  /// **'KOÇ UNIVERSITY'**
  String get kocUniversityWordmark;

  /// No description provided for @usernameHint.
  ///
  /// In en, this message translates to:
  /// **'yourname'**
  String get usernameHint;

  /// No description provided for @newToKocUniversity.
  ///
  /// In en, this message translates to:
  /// **'New to Koç University?'**
  String get newToKocUniversity;

  /// No description provided for @runningAClub.
  ///
  /// In en, this message translates to:
  /// **'Running a club?'**
  String get runningAClub;

  /// No description provided for @fullNameExampleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Ali Yılmaz'**
  String get fullNameExampleHint;

  /// No description provided for @couldNotUseCamera.
  ///
  /// In en, this message translates to:
  /// **'Could not use the camera. Check camera access and try again.'**
  String get couldNotUseCamera;

  /// No description provided for @youreInName.
  ///
  /// In en, this message translates to:
  /// **'You\'re in,\n{name}.'**
  String youreInName(String name);

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllRead;

  /// No description provided for @clubRolePresident.
  ///
  /// In en, this message translates to:
  /// **'President'**
  String get clubRolePresident;

  /// No description provided for @clubRoleVicePresident.
  ///
  /// In en, this message translates to:
  /// **'Vice President'**
  String get clubRoleVicePresident;

  /// No description provided for @clubRoleFounder.
  ///
  /// In en, this message translates to:
  /// **'Founder'**
  String get clubRoleFounder;

  /// No description provided for @clubRoleCoFounder.
  ///
  /// In en, this message translates to:
  /// **'Co-Founder'**
  String get clubRoleCoFounder;

  /// No description provided for @clubRoleSecretary.
  ///
  /// In en, this message translates to:
  /// **'Secretary'**
  String get clubRoleSecretary;

  /// No description provided for @clubRoleTreasurer.
  ///
  /// In en, this message translates to:
  /// **'Treasurer'**
  String get clubRoleTreasurer;

  /// No description provided for @clubRoleCoordinator.
  ///
  /// In en, this message translates to:
  /// **'Coordinator'**
  String get clubRoleCoordinator;

  /// No description provided for @clubRoleChair.
  ///
  /// In en, this message translates to:
  /// **'Chair'**
  String get clubRoleChair;

  /// No description provided for @clubRoleViceChair.
  ///
  /// In en, this message translates to:
  /// **'Vice Chair'**
  String get clubRoleViceChair;

  /// No description provided for @clubRoleTeamLead.
  ///
  /// In en, this message translates to:
  /// **'Team Lead'**
  String get clubRoleTeamLead;

  /// No description provided for @followRequests.
  ///
  /// In en, this message translates to:
  /// **'Follow requests'**
  String get followRequests;

  /// No description provided for @plusOthersCount.
  ///
  /// In en, this message translates to:
  /// **'{n,plural, one{+ 1 other} other{+ {n} others}}'**
  String plusOthersCount(num n);

  /// No description provided for @notifGroupNew.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get notifGroupNew;

  /// No description provided for @notifGroupToday.
  ///
  /// In en, this message translates to:
  /// **'TODAY'**
  String get notifGroupToday;

  /// No description provided for @notifGroupThisWeek.
  ///
  /// In en, this message translates to:
  /// **'THIS WEEK'**
  String get notifGroupThisWeek;

  /// No description provided for @notifGroupThisMonth.
  ///
  /// In en, this message translates to:
  /// **'THIS MONTH'**
  String get notifGroupThisMonth;

  /// No description provided for @notifGroupEarlier.
  ///
  /// In en, this message translates to:
  /// **'EARLIER'**
  String get notifGroupEarlier;

  /// No description provided for @updatedJustNow.
  ///
  /// In en, this message translates to:
  /// **'Updated just now'**
  String get updatedJustNow;

  /// No description provided for @notificationsAutoCleared.
  ///
  /// In en, this message translates to:
  /// **'Notifications older than 30 days are cleared automatically'**
  String get notificationsAutoCleared;

  /// No description provided for @updateRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get updateRequiredTitle;

  /// No description provided for @updateRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Please update ClubUp to continue using the app.'**
  String get updateRequiredMessage;

  /// No description provided for @updateRequiredButton.
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get updateRequiredButton;

  /// No description provided for @updateRequiredRetry.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get updateRequiredRetry;

  /// No description provided for @updateRequiredStoreError.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t open the app store. Please update ClubUp there, then try again.'**
  String get updateRequiredStoreError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
