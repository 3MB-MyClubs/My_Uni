import 'locale_service.dart';
import 'presence_status.dart';

class S {
  S._();
  static String _t(String en, String tr) =>
      localeService.languageCode == 'tr' ? tr : en;

  // ── Feed
  static String get goodMorning => _t('Good morning', 'Günaydın');
  static String get goodAfternoon =>
      _t('Good afternoon', 'İyi öğleden sonralar');
  static String get goodEvening => _t('Good evening', 'İyi akşamlar');
  static String get stillUp => _t('Still up', 'Hâlâ uyanık mısın');
  static String get thisWeek => _t('THIS WEEK', 'BU HAFTA');
  static String get eventsOnCampus =>
      _t('Events on campus', 'Kampüsteki etkinlikler');
  static String get campusHappening => _t(
    "Here's what's happening on campus.",
    'Kampüste neler oluyor, göz at.',
  );
  static String get membersHappening => _t(
    "Here's what your members are up to.",
    'Üyelerin neler yapıyor, göz at.',
  );
  static String get seeAll => _t('See all', 'Hepsini gör');
  static String get fromYourClubs => _t('FROM YOUR CLUBS', 'KULÜPLERİNDEN');
  static String get clubFeed => _t('CLUB FEED', 'KULÜp AKIŞI');
  static String get following => _t('Following', 'Takip');
  static String get all => _t('All', 'Tümü');
  static String get forYou => _t('For You', 'Senin İçin');
  static String get latest => _t('Latest', 'Son Gönderiler');
  static String get nothingHere => _t('Nothing here yet', 'Henüz bir şey yok');
  static String get followClubs => _t(
    'Follow clubs to see their posts\nand events in your feed',
    'Gönderilerini görmek için\nkulüp takip et',
  );
  static String get endOfFeed =>
      _t("That's it for today 😀", 'Bugünlük bu kadar 😀');
  static String get exploreClubs =>
      _t('Explore All Clubs', 'Tüm Kulüpleri Keşfet');
  static String get peopleMightKnow =>
      _t('People You Might Know', 'Tanıyor Olabileceğin Kişiler');
  static String get suggestedForYou =>
      _t('Suggested for you', 'Senin için önerilenler');
  static String get followBack => _t('Follow back', 'Geri takip et');
  static String get sharePostToChat =>
      _t('Share post to a chat', 'Gönderiyi sohbette paylaş');
  static String get postShared => _t('Post shared', 'Gönderi paylaşıldı');
  static String get noStudentChatsYet => _t(
    'Start a student chat before sharing a post.',
    'Gönderi paylaşmadan önce bir öğrenci sohbeti başlat.',
  );
  static String get sharedPost => _t('Shared post', 'Paylaşılan gönderi');
  static String get clubMightLike =>
      _t('Club You Might Like', 'Beğenebileceğin Kulüp');
  static String get today => _t('Today', 'Bugün');
  static String get tomorrow => _t('Tomorrow', 'Yarın');
  static String likedBy(String name) => _t('Liked by $name', '$name beğendi');
  static String likedByOthers(String name, int count) => _t(
    'Liked by $name and $count ${count == 1 ? 'other' : 'others'}',
    '$name ve $count diğer kişi beğendi',
  );

  // ── Explore
  static String get explore => _t('Explore', 'Keşfet');
  static String get discoverClubs => _t('Discover Clubs', 'Kulüpleri Keşfet');
  static String get findPeople => _t('Find People', 'Kişileri Bul');
  static String get searchClubs => _t('Search…', 'Ara…');
  static String get searchPeople => _t('Search people…', 'Kişi ara…');
  static String get allClubs => _t('All clubs', 'Tüm kulüpler');
  static String get exploreContentTab => _t('Events', 'Etkinlikler');
  static String get searchEventsPosts => _t('Search events…', 'Etkinlik ara…');
  static String get upcomingEvents =>
      _t('Upcoming events', 'Yaklaşan etkinlikler');
  static String get noContentMatch =>
      _t('No matches found', 'Sonuç bulunamadı');
  static String get noClubsMatch => _t('No clubs match', 'Eşleşen kulüp yok');
  static String get tryDifferentSearch =>
      _t('Try a different search term', 'Farklı bir arama terimi dene');
  static String get studentProfile => _t('Student profile', 'Öğrenci profili');
  static String get joined => _t('Joined ✓', 'Katıldı ✓');
  static String get join => _t('Join', 'Katıl');
  static String get follow => _t('Follow', 'Takip Et');
  static String get noOneMatches => _t('No one found', 'Kimse bulunamadı');
  static String get tryNameSearch =>
      _t('Try a name, surname, or email', 'İsim, soyisim veya e-posta dene');
  static String get filterByMajor =>
      _t('Filter by major', 'Bölüme göre filtrele');
  static String get clearMajorFilter =>
      _t('Clear major filter', 'Bölüm filtresini temizle');
  static String get searchMajors => _t('Search majors', 'Bölüm ara');
  static String get noMatchingMajor =>
      _t('No matching major', 'Eşleşen bölüm yok');
  static String get clearSearch => _t('Clear search', 'Aramayı temizle');
  static String get done => _t('Done', 'Bitti');
  static String peopleResultCount(int count) =>
      _t(count == 1 ? '1 result' : '$count results', '$count sonuç');
  static String get noPeopleInSelectedMajor =>
      _t('No students found in this major', 'Bu bölümde öğrenci bulunamadı');
  static String get tryAnotherMajorOrName => _t(
    'Try another major or change the name search',
    'Başka bir bölüm seç veya isim aramasını değiştir',
  );

  // ── This Week
  static String get discoverEvents =>
      _t('Discover events', 'Etkinlikleri Keşfet');
  static String get searchEvents =>
      _t('Search events, clubs, topics', 'Etkinlik, kulüp, konu ara');
  static String get anyDate => _t('Any date', 'Herhangi bir tarih');
  static String get past => _t('Past', 'Geçmiş');
  static String get live => _t('Live', 'Canlı');
  static String get allEvents => _t('All events', 'Tüm etkinlikler');
  static String get everythingOnCampus =>
      _t('Everything happening on campus', 'Kampüste olan her şey');
  static String get followingOnly =>
      _t('Only clubs you follow', 'Sadece takip ettiğin kulüpler');
  static String get showEventsFrom =>
      _t('Show events from', 'Şunlardan etkinlikleri göster');
  static String get pickDate => _t('Pick a date', 'Tarih seç');
  static String get clear => _t('Clear', 'Temizle');
  static String get showAllDates =>
      _t('Show all dates', 'Tüm tarihleri göster');
  static String get noEventsFound =>
      _t('No events found', 'Etkinlik bulunamadı');
  static String get tryDifferentKeyword => _t(
    'Try a different keyword or clear your filters.',
    'Farklı bir anahtar kelime deneyin veya filtrelerinizi temizleyin.',
  );
  static String get nothingScheduled => _t(
    'Nothing scheduled here yet — check another date.',
    'Henüz planlanmış bir şey yok — başka bir tarih deneyin.',
  );
  static String get checkBackLater => _t(
    'Nothing on the calendar right now — check back soon!',
    'Şu anda takvimde bir şey yok — yakında tekrar bak!',
  );
  static String get resetFilters => _t('Reset filters', 'Filtreleri Sıfırla');
  static String get newEvents => _t('New events', 'Yeni Etkinlikler');
  static String get allCaughtUp => _t('All caught up', 'Hepsi Görüldü');
  static String get newEventsHint => _t(
    'Newly created events will appear here until you open their details.',
    'Yeni etkinlikler, detaylarını açana kadar burada görünür.',
  );
  static String get going => _t('Going', 'Gidiyorum');
  static String get rsvp => _t('RSVP', 'Kayıt Ol');
  static String get ended => _t('Ended', 'Bitti');

  // ── Notifications
  static String get notifications => _t('Notifications', 'Bildirimler');
  static String get filterYou => _t('You', 'Sen');
  static String get filterEvents => _t('Events', 'Etkinlikler');
  static String get filterClubs => _t('Clubs', 'Kulüpler');
  static String get newSection => _t('New', 'Yeni');
  static String get earlier => _t('Earlier', 'Daha Önce');
  static String get accept => _t('Accept', 'Kabul Et');
  static String get decline => _t('Decline', 'Reddet');
  static String get nothingHereNotif => _t('Nothing here', 'Henüz bir şey yok');

  // ── Event Pass / check-in
  static String get eventPass => _t('Event Pass', 'Etkinlik Kartı');
  static String get eventPassHint => _t(
    'Show this code at the door to check in.',
    'Girişte bu kodu göstererek yoklamaya katıl.',
  );
  static String get showMyPass => _t('Show my pass', 'Kartımı göster');
  static String get scanCheckins => _t('Scan check-ins', 'Yoklama tara');
  static String get scanInvalidPass =>
      _t('Not a valid Event Pass', 'Geçersiz Etkinlik Kartı');
  static String get scanWrongEvent =>
      _t('Pass belongs to another event', 'Kart başka bir etkinliğe ait');
  static String get scanAlreadyIn =>
      _t('already checked in', 'zaten giriş yaptı');
  static String get scanNotAdmitted => _t('Not admitted', 'Alınmadı');
  static String get scanNoRsvpTitle => _t('No RSVP found', 'RSVP bulunamadı');
  static String scanNoRsvpBody(String name) => _t(
    "$name didn't RSVP to this event. Admit anyway?",
    '$name bu etkinliğe RSVP yapmamış. Yine de alınsın mı?',
  );
  static String get scanAdmitAnyway => _t('Admit anyway', 'Yine de al');
  static String checkedInCounter(int checked, int total) =>
      _t('$checked / $total checked in', '$checked / $total giriş yaptı');
  static String get checkedIn => _t('Checked in', 'Giriş yaptı');

  // ── Polls & announcements
  static String get addPoll => _t('Add poll', 'Anket ekle');
  static String get pollQuestionHint => _t('Ask a question…', 'Bir soru sor…');
  static String pollOptionHint(int n) => _t('Option $n', 'Seçenek $n');
  static String pollVotes(int n) => _t(n == 1 ? '1 vote' : '$n votes', '$n oy');
  static String get announcement => _t('Announcement', 'Duyuru');
  static String get markAsAnnouncement =>
      _t('Post as announcement', 'Duyuru olarak paylaş');

  // ── Comments
  static String get comments => _t('Comments', 'Yorumlar');
  static String get addComment => _t('Add a comment…', 'Yorum ekle…');
  static String get noCommentsYet => _t(
    'No comments yet. Be the first!',
    'Henüz yorum yok. İlk yorumu sen yap!',
  );
  static String get deleteComment => _t('Delete comment', 'Yorumu sil');
  static String get reportComment => _t('Report comment', 'Yorumu bildir');
  static String get whyReportComment => _t(
    'Why are you reporting this comment?',
    'Bu yorumu neden bildiriyorsun?',
  );
  static String get commentReported => _t(
    'Comment reported and removed from your feed.',
    'Yorum bildirildi ve akışından kaldırıldı.',
  );
  static String get commentHiddenOffline => _t(
    'Comment hidden. We will send the report when you are back online.',
    'Yorum gizlendi. Çevrimiçi olduğunda bildirim gönderilecek.',
  );
  static String get commentDeleted => _t('Comment deleted', 'Yorum silindi');
  static String get commentDeleteFailed => _t(
    'Comment could not be deleted. Please try again.',
    'Yorum silinemedi. Lütfen tekrar dene.',
  );
  static String get commentFailed => _t(
    'Comment could not be posted. Please try again.',
    'Yorum gönderilemedi. Lütfen tekrar dene.',
  );
  static String commentsWithCount(int count) =>
      _t('Comments · $count', 'Yorumlar · $count');
  static String get commentsStudentsOnly => _t(
    'Sign in with a student account to join the conversation.',
    'Sohbete katılmak için öğrenci hesabınla giriş yap.',
  );

  // ── Messages
  static String get deleteMessage => _t('Delete message', 'Mesajı sil');
  static String get deleteMessageMsg => _t(
    'This message will be permanently removed.',
    'Bu mesaj kalıcı olarak kaldırılacak.',
  );

  // ── Profile
  static String get posts => _t('Posts', 'Gönderiler');
  static String get clubs => _t('Clubs', 'Kulüpler');
  static String get followers => _t('Followers', 'Takipçiler');
  static String get myClubs => _t('My Clubs', 'Kulüplerim');
  static String get myContent => _t('My Content', 'İçeriklerim');
  static String get boardMembers => _t('Board Members', 'Yönetim Kurulu');
  static String get board => _t('Board', 'Yönetim');
  static String get cancel => _t('Cancel', 'İptal');
  static String get save => _t('Save', 'Kaydet');
  static String get delete => _t('Delete', 'Sil');
  static String get superAdmin => _t('Super Admin', 'Süper Yönetici');
  static String get clubAdmin => _t('Club Admin', 'Kulüp Yöneticisi');
  static String get addMajorYear => _t('Add major & year', 'Bölüm ve yıl ekle');
  static String get addBio => _t('Add a bio…', 'Biyografi ekle…');
  static String get noClubsYet => _t(
    "You haven't followed any clubs yet.",
    'Henüz bir kulüp takip etmediniz.',
  );
  static String get exploreClubsHint => _t(
    'Explore clubs and follow the ones you like.',
    'Kulüpleri keşfet ve beğendiklerini takip et.',
  );
  static String get noBoardMembers =>
      _t('No board members yet.', 'Henüz yönetim üyesi yok.');
  static String get approvedHere => _t(
    'Approved requests will appear here.',
    'Onaylanan istekler burada görünür.',
  );
  static String get noPostsYet => _t('No posts yet.', 'Henüz gönderi yok.');
  static String get noEventsYet => _t('No events yet.', 'Henüz etkinlik yok.');
  static String get noFollowersYet =>
      _t('No followers yet.', 'Henüz takipçi yok.');
  static String get notFollowingAnyone =>
      _t('Not following anyone yet.', 'Henüz kimseyi takip etmiyor.');
  static String get changePhoto =>
      _t('Change Profile Photo', 'Profil Fotoğrafını Değiştir');
  static String get takePhoto => _t('Take a Photo', 'Fotoğraf Çek');
  static String get useCamera =>
      _t('Use your camera right now', 'Kameranı hemen kullan');
  static String get chooseFromLib =>
      _t('Choose from Library', 'Kütüphaneden Seç');
  static String get pickFromLib =>
      _t('Pick from your photo library', 'Fotoğraf kütüphanenizden seçin');
  static String get removePhoto => _t('Remove photo', 'Fotoğrafı Kaldır');
  static String get majorYearLabel => _t('Major & Year', 'Bölüm & Yıl');
  static String get selectMajor => _t('Select your major', 'Bölümünü seç');
  static String get selectMajorHint => _t('Select major', 'Bölüm seç');
  static String get yearLabel => _t('Year', 'Yıl');
  static String get bioLabel => _t('Bio', 'Biyografi');
  static String get bioHint =>
      _t('Tell people a little about yourself', 'Kendinizi kısaca tanıtın');
  static String get useThisPhoto =>
      _t('Use this photo?', 'Bu fotoğrafı kullan?');
  static String get usePhoto => _t('Use Photo', 'Fotoğrafı Kullan');
  static String get deletePost => _t('Delete post?', 'Gönderi silinsin mi?');
  static String get deletePostMsg => _t(
    'This post will be permanently removed.',
    'Bu gönderi kalıcı olarak kaldırılacak.',
  );
  static String get deleteEvent => _t('Delete event?', 'Etkinlik silinsin mi?');
  static String get deleteEventMsg => _t(
    'This event will be permanently removed.',
    'Bu etkinlik kalıcı olarak kaldırılacak.',
  );
  static String get majorNotAdded => _t('Major not added', 'Bölüm eklenmedi');
  static String get yearNotAdded => _t('Year not added', 'Yıl eklenmedi');
  static String get addBioIntro => _t(
    'Add a bio to introduce yourself.',
    'Kendinizi tanıtmak için biyografi ekleyin.',
  );

  // ── Bottom nav
  static String get home => _t('Home', 'Ana Sayfa');
  static String get events => _t('Events', 'Etkinlikler');
  static String get search => _t('Search', 'Ara');
  static String get alerts => _t('Alerts', 'Bildirimler');
  static String get profile => _t('Profile', 'Profil');
  static String get admin => _t('Admin', 'Yönetici');

  // ── Settings
  static String get settings => _t('Settings', 'Ayarlar');
  static String get language => _t('Language', 'Dil');
  static String get appearance => _t('Appearance', 'Görünüm');
  static String get darkMode => _t('Dark Mode', 'Karanlık Mod');
  static String get lightMode => _t('Light Mode', 'Aydınlık Mod');
  static String get switchToDark =>
      _t('Switch to dark theme', 'Karanlık temaya geç');
  static String get switchToLight =>
      _t('Switch to light theme', 'Aydınlık temaya geç');
  static String get help => _t('Help', 'Yardım');
  static String get supportAndLegal => _t('Support & Legal', 'Destek ve Yasal');
  static String get supportCenter => _t('Support Center', 'Destek Merkezi');
  static String get supportCenterSubtitle =>
      _t('Help, FAQs & contact', 'Yardım, sık sorulanlar ve iletişim');
  static String get privacyPolicy =>
      _t('Privacy Policy', 'Gizlilik Politikası');
  static String get privacyPolicySubtitle =>
      _t('How ClubUp handles your data', 'ClubUp verilerinizi nasıl işler');
  static String get termsOfUse => _t('Terms of Use', 'Kullanım Koşulları');
  static String get termsOfUseSubtitle => _t(
    'Community rules & safety enforcement',
    'Topluluk kuralları ve güvenlik uygulaması',
  );
  static String get deleteAccount => _t('Delete Account', 'Hesabı Sil');
  static String get deleteAccountSubtitle => _t(
    'Request permanent account & data deletion',
    'Hesap ve verilerin kalıcı olarak silinmesini iste',
  );
  static String get couldNotOpenPage =>
      _t('Could not open this page.', 'Bu sayfa açılamadı.');
  static String get account => _t('Account', 'Hesap');
  static String get logOut => _t('Log Out', 'Çıkış Yap');
  static String get editProfile => _t('Edit Profile', 'Profili Düzenle');
  static String get editProfileSubtitle =>
      _t('Photo, bio, major & year', 'Fotoğraf, biyografi, bölüm & yıl');
  static String get changeMyName => _t('Change My Name', 'Adımı Değiştir');
  static String get changeNameSubtitle => _t(
    'Choose the name people see on your student profile.',
    'Öğrenci profilinde görünen adı seç.',
  );
  static String get displayName => _t('Display name', 'Görünen ad');
  static String get nameTaken =>
      _t('That name is already taken.', 'Bu isim zaten alınmış.');
  static String get useRealName => _t('Use Real Name', 'Gerçek Adı Kullan');
  static String get saveName => _t('Save Name', 'Adı Kaydet');
  static String get notSetConfigure => _t(
    'Not set — tap to configure',
    'Ayarlanmadı — yapılandırmak için dokun',
  );
  static String get replayTutorial =>
      _t('Replay the tour', 'Turu yeniden izle');
  static String get replayTutorialSubtitle =>
      _t('Take the campus tour again', 'Kampüs turunu yeniden yap');

  // ── Onboarding intro (first-run carousel)
  static String get onboardingIntroDiscoverTitle =>
      _t('Discover campus life', 'Kampüs hayatını keşfet');
  static String get onboardingIntroDiscoverSubtitle => _t(
    "See what's happening across campus, all in one feed.",
    'Kampüste neler olduğunu tek bir akışta gör.',
  );
  static String get onboardingIntroCalendarTitle =>
      _t('RSVP in a tap', 'Tek dokunuşla LCV ver');
  static String get onboardingIntroCalendarSubtitle => _t(
    "Say you're going and events land on your calendar automatically.",
    'Gidiyorum de, etkinlikler takvimine otomatik eklensin.',
  );
  static String get onboardingIntroClubsTitle =>
      _t('Follow your clubs', 'Kulüplerini takip et');
  static String get onboardingIntroClubsSubtitle => _t(
    'Never miss an update from the clubs you love.',
    'Sevdiğin kulüplerden hiçbir güncellemeyi kaçırma.',
  );
  static String get onboardingIntroReadyTitle =>
      _t('Ready to dive in?', 'Başlamaya hazır mısın?');
  static String get onboardingIntroReadySubtitle => _t(
    'Join your campus community and make it yours.',
    'Kampüs topluluğuna katıl ve burayı kendine ait kıl.',
  );
  static String get onboardingIntroSkip => _t('Skip', 'Atla');
  static String get onboardingIntroGetStarted => _t('Get started', 'Başla');
  static String get onboardingIntroLogIn => _t('Log in', 'Giriş yap');

  // ── Onboarding — welcome (Act 1)
  static String get onboardingWelcomeEyebrow =>
      _t('YOUR CAMPUS, YOUR PEOPLE', 'KAMPÜSÜN, İNSANLARIN');
  static String onboardingWelcomeTitle(String firstName) => firstName.isEmpty
      ? _t('Hey! 👋', 'Selam! 👋')
      : _t('Hey $firstName! 👋', 'Selam $firstName! 👋');
  static String get onboardingWelcomeBody => _t(
    'Welcome to ClubUp — this is where campus life happens. '
        'Want a quick tour? Takes about a minute.',
    "ClubUp'a hoş geldin — kampüs hayatı burada dönüyor. "
        'Hızlı bir tur ister misin? Bir dakikanı alır.',
  );
  static String get onboardingShowMeAround =>
      _t('Show me around', 'Bana etrafı göster');
  static String get onboardingExploreOnMyOwn =>
      _t("I'll explore on my own", 'Kendim keşfederim');

  // ── Onboarding — tour chrome (Act 2)
  static String get onboardingNext => _t('Next', 'İleri');
  static String get onboardingBack => _t('Back', 'Geri');
  static String get onboardingFinish => _t('Finish', 'Bitir');
  static String get onboardingSkipTour => _t('Skip tour', 'Turu atla');
  static String onboardingStepLabel(int current, int total) =>
      _t('Step $current of $total', '$total adımın $current. adımı');
  static String get onboardingTapHint => _t(
    'Tip: tapping the glowing spot works too',
    'İpucu: parlayan yere dokunmak da olur',
  );

  // ── Onboarding — student tour guide lines
  static String get onboardingStudentHome => _t(
    'This is your feed. Everything from clubs you follow lands here — '
        'plus events and people you might like.',
    'Burası senin akışın. Takip ettiğin kulüplerden her şey buraya düşer — '
        'bir de hoşuna gidebilecek etkinlikler ve kişiler.',
  );
  static String get onboardingStudentFeedToggle => _t(
    'Following shows the clubs you picked; For You mixes in things '
        "we think you'll like. Flip between them anytime.",
    'Takip Edilenler seçtiğin kulüpleri gösterir; Sana Özel ise '
        'seveceğini düşündüklerimizi karıştırır. İstediğin zaman geçiş yap.',
  );
  static String get onboardingStudentRsvp => _t(
    'Campus events, all in one place. See something fun? '
        "Hit RSVP and it's on your list.",
    'Kampüs etkinlikleri, hepsi tek yerde. Eğlenceli bir şey mi gördün? '
        'LCV ver, listene eklensin.',
  );
  static String get onboardingStudentExplore => _t(
    'Looking for your people? Search clubs, events and students here — '
        'this is how you find your crowd.',
    'İnsanlarını mı arıyorsun? Kulüpleri, etkinlikleri ve öğrencileri '
        'buradan ara — çevreni böyle bulursun.',
  );
  static String get onboardingStudentCompose => _t(
    "DM friends, or jump into a club's community chat. "
        'This button starts a new conversation.',
    'Arkadaşlarına yaz ya da bir kulübün topluluk sohbetine katıl. '
        'Bu düğme yeni bir sohbet başlatır.',
  );
  static String get onboardingStudentProfile => _t(
    "And this one's yours. Add a bio, your major and year — "
        'make it feel like you.',
    'Burası da senin. Bir biyografi, bölümünü ve sınıfını ekle — '
        'burayı kendin gibi hissettir.',
  );

  // ── Onboarding — club-admin tour guide lines
  static String get onboardingClubComposer => _t(
    "This is your club's feed. Got news? Share an update right from here.",
    'Burası kulübünün akışı. Haber mi var? Güncellemeyi doğrudan '
        'buradan paylaş.',
  );
  static String get onboardingClubCreateEvent => _t(
    'The + button creates events — date, cover photo, schedule, '
        'speakers, the works.',
    '+ düğmesi etkinlik oluşturur — tarih, kapak fotoğrafı, program, '
        'konuşmacılar, hepsi.',
  );
  static String get onboardingClubProfileTabs => _t(
    "Your club's public home: posts, events and your board, "
        'all in one place.',
    'Kulübünün herkese açık yüzü: gönderiler, etkinlikler '
        've yönetim kurulu, hepsi bir arada.',
  );
  static String get onboardingClubChats => _t(
    'Your community chat lives here — members can talk to each other, '
        'and to you.',
    'Topluluk sohbetin burada — üyeler birbirleriyle ve seninle '
        'konuşabilir.',
  );
  static String get onboardingClubModeration => _t(
    'Review reports and manage profile or club access from the moderation area.',
    'Bildirimleri incele ve profil ya da kulüp erişimini moderasyon alanından yönet.',
  );
  static String get onboardingClubSettings => _t(
    'Name, photo, categories, board members — manage all of it '
        'from settings.',
    'İsim, fotoğraf, kategoriler, yönetim kurulu — hepsini ayarlardan '
        'yönet.',
  );

  // ── Onboarding — finish (Act 3)
  static String get onboardingFinishTitle =>
      _t("That's the tour! 🎉", 'Tur bitti! 🎉');
  static String get onboardingFinishBody => _t(
    "Here's how to make this place yours — three small things to get "
        'you started.',
    'Burayı kendine ait kılmanın yolu — başlaman için üç küçük adım.',
  );
  static String get onboardingFinishBodyClub => _t(
    "You're all set. Go post something — your members are waiting.",
    'Her şey hazır. Hadi bir şeyler paylaş — üyelerin bekliyor.',
  );
  static String get onboardingLetsGo => _t("Let's go", 'Hadi başlayalım');

  // ── Onboarding — starter checklist
  static String get checklistTitle => _t('Get started', 'Başlarken');
  static String get checklistSubtitle => _t(
    'Three small steps to make ClubUp yours',
    "ClubUp'ı sana ait kılacak üç küçük adım",
  );
  static String get checklistFollowClub =>
      _t('Follow a club you like', 'Beğendiğin bir kulübü takip et');
  static String get checklistFollowClubAction =>
      _t('Explore clubs', 'Kulüpleri keşfet');
  static String get checklistRsvpEvent =>
      _t('RSVP to an event', 'Bir etkinliğe LCV ver');
  static String get checklistRsvpEventAction =>
      _t('See events', 'Etkinliklere bak');
  static String get checklistSayHi =>
      _t('Say hi to someone', 'Birine selam ver');
  static String get checklistSayHiAction => _t('Open chats', 'Sohbetleri aç');
  static String get checklistDismiss => _t('Hide', 'Gizle');
  static String get checklistAllDone =>
      _t("You're all set! 🎉", 'Hepsi tamam! 🎉');

  // ── Community safety & moderation
  static String get safetyHero => _t(
    'A safe campus community starts with everyone',
    'Güvenli bir kampüs topluluğu hepimizle başlar',
  );
  static String get safetyIntro => _t(
    'Please review and accept the Terms of Use before creating an account or signing in.',
    'Hesap oluşturmadan veya giriş yapmadan önce lütfen Kullanım Koşullarını inceleyip kabul et.',
  );
  static String get communitySafetyTerms =>
      _t('COMMUNITY SAFETY TERMS', 'TOPLULUK GÜVENLİĞİ KOŞULLARI');
  static String get zeroTolerance => _t('Zero tolerance', 'Sıfır tolerans');
  static String get zeroToleranceBody => _t(
    'Objectionable content, harassment, threats, hate, sexual exploitation, scams, and abusive users are not allowed.',
    'Sakıncalı içeriklere, tacize, tehditlere, nefrete, cinsel sömürüye, dolandırıcılığa ve kötü niyetli kullanıcılara izin verilmez.',
  );
  static String get reportHarmfulContent =>
      _t('Report harmful content', 'Zararlı içeriği bildir');
  static String get reportHarmfulContentBody => _t(
    'Use the report option on posts and profiles. ClubUp reviews reports and acts on violations within 24 hours.',
    'Gönderi ve profillerdeki bildirme seçeneğini kullan. ClubUp bildirimleri 24 saat içinde inceler ve ihlaller için işlem yapar.',
  );
  static String get blockAbusiveUsers =>
      _t('Block abusive users', 'Kötü niyetli kullanıcıları engelle');
  static String get blockAbusiveUsersBody => _t(
    'Blocking reports the account to ClubUp and immediately removes that user and their content from your experience.',
    'Engelleme, hesabı ClubUp’a bildirir ve kullanıcıyı ve içeriğini deneyiminden hemen kaldırır.',
  );
  static String get enforcement => _t('Enforcement', 'Yaptırım');
  static String get enforcementBody => _t(
    'ClubUp may remove violating content and suspend or permanently eject the responsible account.',
    'ClubUp ihlalli içeriği kaldırabilir ve sorumlu hesabı askıya alabilir veya kalıcı olarak hizmetten çıkarabilir.',
  );
  static String get readFullTerms =>
      _t('Read full Terms of Use', 'Kullanım Koşullarının tamamını oku');
  static String get agreeToSafetyTerms => _t(
    'I agree to the Terms of Use and Community Safety Terms.',
    'Kullanım Koşullarını ve Topluluk Güvenliği Koşullarını kabul ediyorum.',
  );
  static String get agreeAndContinue =>
      _t('Agree and continue', 'Kabul et ve devam et');
  static String get couldNotOpenThisPage =>
      _t('Could not open this page.', 'Bu sayfa açılamadı.');
  static String get whyReportPost => _t(
    'Why are you reporting this post?',
    'Bu gönderiyi neden bildiriyorsun?',
  );
  static String get whyReportUser => _t(
    'Why are you reporting this user?',
    'Bu kullanıcıyı neden bildiriyorsun?',
  );
  static String get whyBlockUser => _t(
    'Why are you blocking this user?',
    'Bu kullanıcıyı neden engelliyorsun?',
  );
  static String get chooseReportReason => _t(
    'Choose the reason that best describes the issue. Reports are reviewed within 24 hours.',
    'Sorunu en iyi açıklayan nedeni seç. Bildirimler 24 saat içinde incelenir.',
  );
  static String moderationReasonLabel(String value) => switch (value) {
    'harassment' => _t('Harassment or bullying', 'Taciz veya zorbalık'),
    'hate_or_discrimination' => _t(
      'Hate or discrimination',
      'Nefret veya ayrımcılık',
    ),
    'sexual_content' => _t(
      'Sexual or explicit content',
      'Cinsel veya açık içerik',
    ),
    'violence_or_danger' => _t(
      'Violence or dangerous behavior',
      'Şiddet veya tehlikeli davranış',
    ),
    'spam_or_scam' => _t('Spam or scam', 'Spam veya dolandırıcılık'),
    _ => _t('Something else', 'Başka bir neden'),
  };
  static String moderationReasonDetail(String value) => switch (value) {
    'harassment' => _t(
      'Targets, threatens, or abuses a person or group.',
      'Bir kişiyi veya grubu hedef alır, tehdit eder ya da kötüye kullanır.',
    ),
    'hate_or_discrimination' => _t(
      'Attacks people based on a protected characteristic.',
      'İnsanlara korunan bir özellikleri nedeniyle saldırır.',
    ),
    'sexual_content' => _t(
      'Contains unwanted nudity or sexual material.',
      'İstenmeyen çıplaklık veya cinsel materyal içerir.',
    ),
    'violence_or_danger' => _t(
      'Threatens harm or promotes dangerous conduct.',
      'Zarar tehdidi içerir veya tehlikeli davranışı teşvik eder.',
    ),
    'spam_or_scam' => _t(
      'Misleads people or repeatedly posts unwanted material.',
      'İnsanları yanıltır veya sürekli istenmeyen içerik paylaşır.',
    ),
    _ => _t(
      'Another violation of the ClubUp Terms of Use.',
      'ClubUp Kullanım Koşullarının başka bir ihlali.',
    ),
  };
  static String get reportPost => _t('Report post', 'Gönderiyi bildir');
  static String get reportUser => _t('Report user', 'Kullanıcıyı bildir');
  static String get reportUserSubtitle => _t(
    'Send this profile to ClubUp for review.',
    'Bu profili incelenmesi için ClubUp’a gönder.',
  );
  static String get blockAndReportUser =>
      _t('Block and report user', 'Kullanıcıyı engelle ve bildir');
  static String get blockAndReportSubtitle => _t(
    'Immediately hide this user and notify ClubUp.',
    'Bu kullanıcıyı hemen gizle ve ClubUp’a bildir.',
  );
  static String blockUserQuestion(String name) =>
      _t('Block $name?', '$name engellensin mi?');
  static String get blockUserExplanation => _t(
    'Their profile and content will be removed from your experience immediately. ClubUp will also receive a safety report.',
    'Profili ve içeriği deneyiminden hemen kaldırılacak. ClubUp ayrıca bir güvenlik bildirimi alacak.',
  );
  static String get userReported => _t(
    'User reported. Our team will review it within 24 hours.',
    'Kullanıcı bildirildi. Ekibimiz 24 saat içinde inceleyecek.',
  );
  static String get reportSendFailed => _t(
    'Could not send the report. Please try again.',
    'Bildirim gönderilemedi. Lütfen tekrar dene.',
  );
  static String get userBlockedAndReported =>
      _t('User blocked and reported.', 'Kullanıcı engellendi ve bildirildi.');
  static String get userBlockedOffline => _t(
    'User blocked on this device. The report could not be sent; please try again when online.',
    'Kullanıcı bu cihazda engellendi. Bildirim gönderilemedi; çevrimiçi olduğunda tekrar dene.',
  );
  static String get blockedAccounts =>
      _t('Blocked people and clubs', 'Engellenen kişiler ve kulüpler');
  static String get blockedAccountsSubtitle => _t(
    'Review and unblock accounts you have hidden.',
    'Gizlediğin hesapları incele ve engellerini kaldır.',
  );
  static String get people => _t('People', 'Kişiler');
  static String get clubsLabel => _t('Clubs', 'Kulüpler');
  static String get unblock => _t('Unblock', 'Engeli kaldır');
  static String unblockQuestion(String name) =>
      _t('Unblock $name?', '$name için engel kaldırılsın mı?');
  static String get unblockExplanation => _t(
    'Their profile and content will appear in your experience again.',
    'Profili ve içeriği deneyiminde yeniden görünecek.',
  );
  static String get unblockFailed => _t(
    'Could not unblock this account. Please try again.',
    'Bu hesabın engeli kaldırılamadı. Lütfen tekrar dene.',
  );
  static String get noBlockedPeople =>
      _t('You have not blocked anyone.', 'Engellediğin kimse yok.');
  static String get noBlockedClubs =>
      _t('You have not blocked any clubs.', 'Engellediğin kulüp yok.');
  static String get whyBlockClub =>
      _t('Why are you blocking this club?', 'Bu kulübü neden engelliyorsun?');
  static String blockClubQuestion(String name) =>
      _t('Block $name?', '$name engellensin mi?');
  static String get blockAndReportClub =>
      _t('Block and report club', 'Kulübü engelle ve bildir');
  static String get clubBlockedAndReported =>
      _t('Club blocked and reported.', 'Kulüp engellendi ve bildirildi.');
  static String get clubBlockedOffline => _t(
    'Club blocked on this device. The report could not be sent; please try again when online.',
    'Kulüp bu cihazda engellendi. Bildirim gönderilemedi; çevrimiçi olduğunda tekrar dene.',
  );
  static String get postReportedAndRemoved => _t(
    'Post reported and removed from your feed.',
    'Gönderi bildirildi ve akışından kaldırıldı.',
  );
  static String get postHiddenOffline => _t(
    'Post hidden. The report could not be sent; please try again when online.',
    'Gönderi gizlendi. Bildirim gönderilemedi; çevrimiçi olduğunda tekrar dene.',
  );
  static String get safetyOptions =>
      _t('Safety options', 'Güvenlik seçenekleri');

  /// Settings group heading for the blocked-accounts entry.
  static String get privacySection => _t('Privacy', 'Gizlilik');
  static String get moderation => _t('Moderation', 'Moderasyon');
  static String get moderationCenter =>
      _t('ClubUp moderation center', 'ClubUp moderasyon merkezi');
  static String get moderationCenterSubtitle => _t(
    'Review reports and manage login bans on this device.',
    'Bildirimleri incele ve bu cihazdaki giriş yasaklarını yönet.',
  );
  static String get reports => _t('Reports', 'Bildirimler');
  static String get profiles => _t('Profiles', 'Profiller');
  static String get noReports =>
      _t('No reports have been made yet.', 'Henüz bildirim yapılmadı.');
  static String get noProfiles =>
      _t('No profiles are available yet.', 'Henüz profil bulunmuyor.');
  static String get noClubsForModeration =>
      _t('No clubs are available yet.', 'Henüz kulüp bulunmuyor.');
  static String get ban => _t('Ban', 'Yasakla');
  static String get unban => _t('Unban', 'Yasağı kaldır');
  static String get banned => _t('Banned', 'Yasaklandı');
  static String get active => _t('Active', 'Aktif');
  static String get banProfile => _t('Ban profile', 'Profili yasakla');
  static String get unbanProfile =>
      _t('Unban profile', 'Profil yasağını kaldır');
  static String get banClub => _t('Ban club', 'Kulübü yasakla');
  static String get unbanClub => _t('Unban club', 'Kulüp yasağını kaldır');
  static String get banConfirmation => _t(
    'They will no longer be able to log in with their email and password.',
    'E-posta ve şifreleriyle artık giriş yapamayacaklar.',
  );
  static String get unbanConfirmation =>
      _t('They will be able to log in again.', 'Tekrar giriş yapabilecekler.');
  static String get moderationActionFailed => _t(
    'This action is available only to the ClubUp profile.',
    'Bu işlem yalnızca ClubUp profili tarafından kullanılabilir.',
  );
  static String get moderationAccessDenied => _t(
    'Only the ClubUp profile can access this area.',
    'Bu alana yalnızca ClubUp profili erişebilir.',
  );
  static String get reportedBy => _t('Reported by', 'Bildiren');
  static String get reportedContent =>
      _t('Reported content', 'Bildirilen içerik');
  static String get reason => _t('Reason', 'Neden');
  static String get unknownProfile =>
      _t('Unknown profile', 'Bilinmeyen profil');
  static String get unknownClub => _t('Unknown club', 'Bilinmeyen kulüp');
  static String get bannedFromApp => _t(
    'You have been banned from this app.',
    'Bu uygulamadan yasaklandınız.',
  );
  static String get contentSafetyRejected => _t(
    'This content cannot be published because it may violate the ClubUp Community Safety Terms.',
    'Bu içerik ClubUp Topluluk Güvenliği Koşullarını ihlal edebileceği için yayımlanamaz.',
  );
  static String get profileSection => _t('Profile', 'Profil');

  // ── Settings — Club admin
  static String get clubSection => _t('Club', 'Kulüp');
  static String get clubName => _t('Club Name', 'Kulüp Adı');
  static String get clubNameLabel => _t('Club name', 'Kulüp adı');
  static String get clubPhoto => _t('Club Photo', 'Kulüp Fotoğrafı');
  static String get changeClubPhoto =>
      _t('Change Club Photo', 'Kulüp Fotoğrafını Değiştir');
  static String get tapToChangeLogo => _t(
    'Tap to change your club logo',
    'Kulüp logonuzu değiştirmek için dokun',
  );
  static String get clubCategories =>
      _t('Club Categories', 'Kulüp Kategorileri');
  static String get chooseTagsHint => _t(
    'Choose tags that help students discover your club.',
    'Öğrencilerin kulübünüzü keşfetmesine yardımcı olacak etiketler seçin.',
  );
  static String get customTags => _t('Custom tags', 'Özel etiketler');
  static String get customTagsHint =>
      _t('Design, Gaming, Culture', 'Tasarım, Oyun, Kültür');
  static String get separateWithCommas =>
      _t('Separate custom tags with commas', 'Özel etiketleri virgülle ayırın');
  static String get saveCategories =>
      _t('Save Categories', 'Kategorileri Kaydet');
  static String get addDiscoveryTags =>
      _t('Add discovery tags', 'Keşif etiketleri ekle');
  static String get clubDescription =>
      _t('Club Description', 'Kulüp Açıklaması');
  static String get clubDescriptionHint =>
      _t('What is this club about?', 'Bu kulüp ne hakkında?');
  static String get manageBoardMembers =>
      _t('Manage Board Members', 'Yönetim Kurulunu Yönet');
  static String get manageBoardSubtitle => _t(
    'Add or remove board members & roles',
    'Yönetim üyelerini ve rolleri ekle veya kaldır',
  );

  // ── Feed composer
  static String get post => _t('Post', 'Gönder');
  static String get addPhoto => _t('Add photo', 'Fotoğraf ekle');
  static String get whatsHappeningAtClub =>
      _t("What's happening at your club?", 'Kulübünde neler oluyor?');
  static String get tapForDetails =>
      _t('Tap for details', 'Detaylar için dokun');

  // ── This Week
  static String get pastEventsHint => _t(
    'Events that finished during the last 7 days.',
    'Son 7 gün içinde biten etkinlikler.',
  );
  static String get upcomingEventsHint =>
      _t("What's on across campus.", 'Kampüste neler var.');

  // ── Notifications
  static String get yesterday => _t('Yesterday', 'Dün');
  static String noNotificationsFor(String label) => _t(
    'No ${label}notifications right now. We\'ll let you know when something happens.',
    '${label}bildirim yok şu an. Bir şey olduğunda haber veririz.',
  );

  // ── Explore
  static String get profilesWillAppear => _t(
    'Profiles will appear here after users sign up',
    'Kullanıcılar kaydolduktan sonra profiller burada görünecek',
  );

  // ── Profile
  static String get prepYear => _t('Prep', 'Hazırlık');
  static String get graduate => _t('Graduate', 'Lisansüstü');

  // ── Chats
  static String get chats => _t('Chats', 'Sohbetler');
  static String get newChat => _t('New chat', 'Yeni sohbet');
  static String get noChatsYet =>
      _t('No conversations yet', 'Henüz sohbet yok');
  static String get noChatsHint => _t(
    'Message a friend or join a club\nto start chatting.',
    'Sohbete başlamak için bir arkadaşına yaz\nveya bir kulübe katıl.',
  );
  static String get typeMessage => _t('Message…', 'Mesaj…');
  static String get startConversation =>
      _t('Start the conversation', 'Sohbeti başlat');
  static String get joinToChat =>
      _t('Join the club to chat', 'Sohbet için kulübe katıl');
  static String get joinToChatHint => _t(
    'This chat is only for club members.\nFollow the club to join the conversation.',
    'Bu sohbet sadece kulüp üyeleri içindir.\nSohbete katılmak için kulübü takip et.',
  );
  static String get clubChat => _t('Club chat', 'Kulüp sohbeti');
  static String get clubInbox => _t('Club inbox', 'Kulüp gelen kutusu');
  static String get privateClubMessage =>
      _t('Private club message', 'Özel kulüp mesajı');
  static String get messageClub => _t('Message club', 'Kulübe mesaj yaz');
  static String get clubChannelReadOnly => _t(
    'Only board members can post in this channel.',
    'Bu kanalda yalnızca yönetim kurulu üyeleri paylaşım yapabilir.',
  );
  static String get secureChatUnavailable => _t(
    'Messaging is not available yet. Try again shortly.',
    'Mesajlaşma henüz kullanılamıyor. Birazdan tekrar dene.',
  );
  static String chatMembers(int n) => _t('$n members', '$n üye');
  static String communityMembers(int n) =>
      n >= 100 ? _t('100+ Members', '100+ Üye') : _t('$n Members', '$n Üye');
  static String communityOnline(int n) => _t('$n Online', '$n Çevrimiçi');
  static String get message => _t('Message', 'Mesaj');

  /// Sits under the club name on an empty community room. The empty screen
  /// already says there are no messages, so this line only invites.
  static String get sayHello =>
      _t('Say hello to your club', 'Kulübüne merhaba de');
  static String get adminLabel => _t('Admin', 'Yönetici');
  static String get you => _t('You', 'Sen');
  static String get onlineNow => _t('Online now', 'Şimdi çevrimiçi');
  static String onlineMembers(int n) => _t('$n online', '$n çevrimiçi');
  static String get lastSeenRecently =>
      _t('Last seen recently', 'Son görülme az önce');
  static String lastOnlineLabel(DateTime? lastSeenAt, {DateTime? now}) {
    final relative = relativeLastSeen(lastSeenAt, now: now);
    return switch (relative.period) {
      LastSeenPeriod.unknown => lastSeenRecently,
      LastSeenPeriod.justNow => _t(
        'Last online just now',
        'Son çevrimiçi: az önce',
      ),
      LastSeenPeriod.minutes => _t(
        'Last online ${relative.value} min ago',
        'Son çevrimiçi: ${relative.value} dk önce',
      ),
      LastSeenPeriod.hours => _t(
        'Last online ${relative.value} ${relative.value == 1 ? 'hour' : 'hours'} ago',
        'Son çevrimiçi: ${relative.value} saat önce',
      ),
      LastSeenPeriod.days => _t(
        'Last online ${relative.value} ${relative.value == 1 ? 'day' : 'days'} ago',
        'Son çevrimiçi: ${relative.value} gün önce',
      ),
    };
  }

  static String get typing => _t('typing…', 'yazıyor…');
  static String get sent => _t('Sent', 'Gönderildi');
  static String get delivered => _t('Delivered', 'Teslim edildi');
  static String get seen => _t('Seen', 'Görüldü');
  static String get read => _t('Read', 'Okundu');
  static String get messageInfo => _t('Message info', 'Mesaj bilgisi');
  static String get readBy => _t('Read by', 'Okuyanlar');
  static String get deliveredTo => _t('Delivered to', 'Teslim edilenler');
  static String deliveredAt(String time) =>
      _t('Delivered $time', '$time teslim edildi');
  static String readAt(String time) => _t('Read $time', '$time okundu');
  static String get reply => _t('Reply', 'Yanıtla');
  static String replyingTo(String name) =>
      _t('Replying to $name', '$name adlı kişiye yanıt');
  static String get cancelReply => _t('Cancel reply', 'Yanıtı iptal et');
  static String nNew(int n) => _t('$n new', '$n yeni');
  static String get searchStudents => _t('Search students…', 'Öğrenci ara…');
  static String get studentChats => _t('Students', 'Öğrenciler');
  static String get clubChats => _t('Clubs', 'Kulüpler');
  static String get searchClubChats =>
      _t('Search club chats…', 'Kulüp sohbeti ara…');
  static String get noStudentChats =>
      _t('No student conversations yet', 'Henüz öğrenci sohbeti yok');
  static String get noStudentChatsHint => _t(
    'Start a new chat to message another student.',
    'Başka bir öğrenciye yazmak için yeni bir sohbet başlat.',
  );
  static String get noClubChats =>
      _t('No club conversations yet', 'Henüz kulüp sohbeti yok');
  static String get noClubChatsHint => _t(
    'Join a club to access its community chat.',
    'Topluluk sohbetine erişmek için bir kulübe katıl.',
  );
  static String get messagesLabel => _t('Messages', 'Mesajlar');
  static String get viewProfile => _t('View profile', 'Profili gör');

  // ── New student chat (empty thread)
  /// Shown under the name when there is nothing else worth saying about a
  /// brand-new thread. Deliberately short so the empty state stays quiet.
  static String get chatNoMessagesYet =>
      _t('No messages yet', 'Henüz mesaj yok');
  static String chatPeopleCount(int n) => _t('$n people', '$n kişi');
  static String get chatCreatedByYou => _t('created by you', 'sen kurdun');
  static String chatAlsoIn(String clubName) =>
      _t('Also in $clubName', 'Ortak kulüp: $clubName');
  static String chatMutualFriends(int n) => n == 1
      ? _t('1 mutual friend', '1 ortak arkadaş')
      : _t('$n mutual friends', '$n ortak arkadaş');

  static String get attachToMessage => _t('Add to message', 'Mesaja ekle');

  // ── Club community
  static String communityActiveNow(int n) =>
      _t('$n active now', '$n şu an aktif');
  static String get communityMembersButton => _t('Members', 'Üyeler');
  static String communityEventsButton(int n) =>
      _t('Events · $n', 'Etkinlikler · $n');
  static String get communityNotices => _t('Notices', 'Duyurular');

  // ── Club Board + Chat (two lanes of one club room)
  /// The official notice area — the lane a club room lands on.
  static String get clubBoardTab => _t('Board', 'Pano');

  /// The room itself, where every reply lives.
  static String get clubChatTab => _t('Chat', 'Sohbet');
  static String get boardGroupPinned => _t('Pinned', 'Sabitlenen');
  static String boardGroupNew(int n) => _t('New · $n', 'Yeni · $n');
  static String get boardGroupEarlier => _t('Earlier', 'Daha önce');
  static String get boardPostNotice => _t('Post a notice', 'Duyuru paylaş');
  static String get boardOnlyBoardPosts =>
      _t('Only the board posts here', 'Burada yalnızca yönetim paylaşır');
  static String get boardSayItInChat => _t('Say it in chat', 'Sohbette söyle');
  static String get boardReplyInChat => _t('Reply in chat', 'Sohbette yanıtla');
  static String boardRepliesInChat(int n) =>
      _t('$n replies in chat', 'Sohbette $n yanıt');
  static String get boardReplyingToNotice =>
      _t('REPLYING TO NOTICE', 'DUYURUYA YANIT');
  static String get boardEmptyTitle => _t('No notices yet', 'Henüz duyuru yok');
  static String get boardEmptyHintStaff => _t(
    'Post a notice and every member sees it here — replies happen in chat.',
    'Bir duyuru paylaş, tüm üyeler burada görsün — yanıtlar sohbette olur.',
  );
  static String get boardEmptyHintMember => _t(
    "The club's notices will appear here. Until then, the room is in chat.",
    'Kulübün duyuruları burada görünecek. O zamana kadar sohbete geç.',
  );
  static String boardReplyCount(int n) =>
      n == 1 ? _t('1 reply', '1 yanıt') : _t('$n replies', '$n yanıt');
  static String get noticeLabel => _t('NOTICE', 'DUYURU');
  static String get boardExpandNotice => _t('Open notice', 'Duyuruyu aç');
  static String get boardCollapseNotice => _t('Close notice', 'Duyuruyu kapat');
  static String get announcementLabel => _t('ANNOUNCEMENT', 'DUYURU');
  static String get pinnedLabel => _t('Pinned', 'Sabitlendi');
  static String get pinToTop => _t('Pin to top', 'Yukarı sabitle');
  static String get unpin => _t('Unpin', 'Sabitlemeyi kaldır');
  static String get pollLabel => _t('POLL', 'ANKET');
  static String pollCloses(String when) =>
      _t('closes $when', '$when kapanıyor');
  static String get pollClosed => _t('closed', 'kapandı');
  static String get pollVoted => _t('voted', 'oy verdin');
  static String goingCount(int n) => _t('$n going', '$n kişi gidiyor');
  static String leftOffHere(int n) =>
      _t('You left off here · $n new', 'Buradan devam · $n yeni');
  static String typingOne(String name) =>
      _t('$name is typing', '$name yazıyor');
  static String typingMany(String names) =>
      _t('$names are typing', '$names yazıyor');
  static String get jumpToLatest => _t('Jump to latest', 'En sona git');
  static String activeNowGroup(int n) => _t('Active now · $n', 'Aktif · $n');
  static String offlineGroup(int n) => _t('Offline · $n', 'Çevrimdışı · $n');
  static String get activeNowLabel => _t('Active now', 'Şu an aktif');
  static String get offlineLabel => _t('Offline', 'Çevrimdışı');
  static String seenCount(int n) => _t('$n seen', '$n görüntüleme');
  static String get attachMedia =>
      _t('Photos & videos', 'Fotoğraf ve videolar');
  static String get attachPhoto => _t('Photo', 'Fotoğraf');
  static String get attachVideo => _t('Video', 'Video');
  static String get attachFile => _t('File', 'Dosya');
  static String get mediaCaptionHint => _t('Add a caption…', 'Açıklama ekle…');
  static String get mediaSend => _t('Send media', 'Medyayı gönder');
  static String get mediaPreviewRemove => _t('Remove', 'Kaldır');
  static String get mediaPreviewEmpty =>
      _t('No media selected', 'Medya seçilmedi');
  static String mediaPreviewPosition(int current, int total) =>
      _t('$current of $total', '$current / $total');
  static String mediaSelectionRejected(int count) => count == 1
      ? _t(
          '1 item could not be added. Media must be available and smaller than 100 MB.',
          '1 öğe eklenemedi. Medya erişilebilir ve 100 MB\'tan küçük olmalı.',
        )
      : _t(
          '$count items could not be added. Media must be available and smaller than 100 MB.',
          '$count öğe eklenemedi. Medya erişilebilir ve 100 MB\'tan küçük olmalı.',
        );
  static String get mediaSelectionFailed => _t(
    'Could not open your media library. Please try again.',
    'Medya arşivi açılamadı. Lütfen tekrar dene.',
  );
  static String get mediaSendFailed => _t(
    'The media could not be sent. Please try again.',
    'Medya gönderilemedi. Lütfen tekrar dene.',
  );
  static String get attachPoll => _t('Poll', 'Anket');
  static String get attachEvent => _t('Event', 'Etkinlik');
  static String get mentionEveryone => _t('everyone', 'herkes');
  static String get allMembers => _t('All members', 'Tüm üyeler');
  static String get memberRole => _t('Member', 'Üye');
  static String get retryMembers => _t(
    'Could not load members. Try again',
    'Üyeler yüklenemedi. Tekrar dene',
  );
  static String get communityComposerHint => _t("What's up?", 'Neler oluyor?');
  static String get newPollTitle => _t('New poll', 'Yeni anket');
  static String get pollQuestion => _t('Question', 'Soru');
  static String pollOptionLabel(int n) => _t('Option $n', '$n. seçenek');
  static String get addOption => _t('Add option', 'Seçenek ekle');
  static String get pollClosesIn => _t('Closes in', 'Kapanış');
  static String pollHours(int n) => _t('${n}h', '$n sa');
  static String pollDays(int n) => _t('${n}d', '$n gün');
  static String get shareEvent => _t('Share an event', 'Etkinlik paylaş');
  static String get noUpcomingEvents =>
      _t('No upcoming events', 'Yaklaşan etkinlik yok');
  static String get postAsAnnouncement =>
      _t('Post as announcement', 'Duyuru olarak paylaş');
  static String get announcementTitleHint =>
      _t('Announcement headline', 'Duyuru başlığı');
  static String get chatDisplay => _t('Chat display', 'Sohbet görünümü');
  static String get changeChatBackground =>
      _t('Change chat background', 'Sohbet arka planını değiştir');
  static String get chatBackground =>
      _t('Chat background', 'Sohbet arka planı');
  static String get backgroundClassic => _t('Classic', 'Klasik');
  static String get backgroundWarm => _t('Warm', 'Sıcak');
  static String get backgroundOcean => _t('Ocean', 'Okyanus');
  static String get backgroundForest => _t('Forest', 'Orman');
  static String get backgroundMidnight => _t('Midnight', 'Gece');
  static String get messageStyle => _t('Message style', 'Mesaj biçimi');
  static String get styleRows => _t('Rows', 'Satır');
  static String get styleBubbles => _t('Bubbles', 'Balon');
  static String get styleCards => _t('Cards', 'Kart');
  static String get announcementsStyle => _t('Announcements', 'Duyurular');
  static String get emphasisSubtle => _t('Subtle', 'Sade');
  static String get emphasisTinted => _t('Tinted', 'Renkli');
  static String get emphasisBold => _t('Bold', 'Belirgin');
  static String get showRolesBadges =>
      _t('Show roles & badges', 'Rolleri ve rozetleri göster');
  static String get muteCommunity =>
      _t('Mute notifications', 'Bildirimleri sustur');
  static String get unmuteCommunity =>
      _t('Unmute notifications', 'Bildirimleri aç');
  static String get muted => _t('Muted', 'Susturuldu');
  static String get react => _t('React', 'Tepki ver');
  static String get copyText => _t('Copy text', 'Metni kopyala');
  static String get copied => _t('Copied', 'Kopyalandı');
  static String get clubSettings => _t('Club settings', 'Kulüp ayarları');
  static String get openClubProfile =>
      _t('Open club profile', 'Kulüp profilini aç');
  static String get downloadAttachment => _t('Open', 'Aç');
  static String activeAgo(String ago) =>
      _t('Active $ago ago', '$ago önce aktif');

  static const _weekdaysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _weekdaysTr = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  static const _monthsEn = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const _monthsTr = [
    'Oca',
    'Şub',
    'Mar',
    'Nis',
    'May',
    'Haz',
    'Tem',
    'Ağu',
    'Eyl',
    'Eki',
    'Kas',
    'Ara',
  ];

  /// [weekday] follows [DateTime.weekday] (1 = Monday).
  static String weekdayShort(int weekday) =>
      _t(_weekdaysEn[(weekday - 1) % 7], _weekdaysTr[(weekday - 1) % 7]);

  static String monthShort(int month) =>
      _t(_monthsEn[(month - 1) % 12], _monthsTr[(month - 1) % 12]);
}
