import 'locale_service.dart';

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
  static String get clubMightLike =>
      _t('Club You Might Like', 'Beğenebileceğin Kulüp');
  static String get today => _t('Today', 'Bugün');
  static String get tomorrow => _t('Tomorrow', 'Yarın');

  // ── Explore
  static String get explore => _t('Explore', 'Keşfet');
  static String get discoverClubs => _t('Discover Clubs', 'Kulüpleri Keşfet');
  static String get findPeople => _t('Find People', 'Kişileri Bul');
  static String get searchClubs => _t('Search…', 'Ara…');
  static String get searchPeople => _t('Search…', 'Ara…');
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
      _t('Replay App Tutorial', 'Uygulamayı Yeniden Gez');
  static String get replayTutorialSubtitle => _t(
    'Take the guided tour of every area again — anytime',
    'Uygulamanın her alanını istediğin zaman yeniden gez',
  );

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
  static String get upcomingEventsHint => _t(
    "What's on across campus — next month.",
    'Kampüste neler var — önümüzdeki ay.',
  );

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
  static String get graduate => _t('Graduate', 'Lisansüstü');
}
