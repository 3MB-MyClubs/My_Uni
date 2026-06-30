import 'locale_service.dart';

class S {
  S._();
  static String _t(String en, String tr) =>
      localeService.languageCode == 'tr' ? tr : en;

  // ── Feed
  static String get goodMorning     => _t('Good morning',   'Günaydın');
  static String get goodAfternoon   => _t('Good afternoon', 'İyi öğleden sonralar');
  static String get goodEvening     => _t('Good evening',   'İyi akşamlar');
  static String get stillUp         => _t('Still up',       'Hâlâ uyanık mısın');
  static String get thisWeek        => _t('THIS WEEK',      'BU HAFTA');
  static String get seeAll          => _t('See all',        'Hepsini gör');
  static String get fromYourClubs   => _t('FROM YOUR CLUBS', 'KULÜPLERİNDEN');
  static String get clubFeed        => _t('CLUB FEED',      'KULÜp AKIŞI');
  static String get following       => _t('Following',      'Takip');
  static String get all             => _t('All',            'Tümü');
  static String get latest          => _t('Latest',         'Son Gönderiler');
  static String get nothingHere     => _t('Nothing here yet', 'Henüz bir şey yok');
  static String get followClubs     => _t(
    'Follow clubs to see their posts\nand events in your feed',
    'Gönderilerini görmek için\nkulüp takip et',
  );
  static String get exploreClubs    => _t('Explore All Clubs',      'Tüm Kulüpleri Keşfet');
  static String get peopleMightKnow => _t('People You Might Know',  'Tanıyor Olabileceğin Kişiler');
  static String get clubMightLike   => _t('Club You Might Like',    'Beğenebileceğin Kulüp');
  static String get today           => _t('Today',    'Bugün');
  static String get tomorrow        => _t('Tomorrow', 'Yarın');

  // ── Explore
  static String get explore        => _t('Explore',               'Keşfet');
  static String get discoverClubs  => _t('Discover Clubs',        'Kulüpleri Keşfet');
  static String get findPeople     => _t('Find People',           'Kişileri Bul');
  static String get searchClubs    => _t('Search clubs…',         'Kulüp ara…');
  static String get searchPeople   => _t('Search by name or surname…', 'İsim veya soyisim ile ara…');
  static String get allClubs       => _t('All clubs',             'Tüm kulüpler');
  static String get noClubsMatch   => _t('No clubs match',        'Eşleşen kulüp yok');
  static String get tryDifferentSearch => _t('Try a different search term', 'Farklı bir arama terimi dene');
  static String get studentProfile => _t('Student profile',       'Öğrenci profili');
  static String get joined         => _t('Joined ✓',              'Katıldı ✓');
  static String get join           => _t('Join',                  'Katıl');
  static String get follow         => _t('Follow',                'Takip Et');
  static String get noOneMatches   => _t('No one found',          'Kimse bulunamadı');
  static String get tryNameSearch  => _t('Try a name, surname, or email', 'İsim, soyisim veya e-posta dene');

  // ── This Week
  static String get discoverEvents   => _t('Discover events',         'Etkinlikleri Keşfet');
  static String get searchEvents     => _t('Search events, clubs, topics', 'Etkinlik, kulüp, konu ara');
  static String get anyDate          => _t('Any date',                'Herhangi bir tarih');
  static String get past             => _t('Past',                    'Geçmiş');
  static String get live             => _t('Live',                    'Canlı');
  static String get allEvents        => _t('All events',              'Tüm etkinlikler');
  static String get everythingOnCampus => _t('Everything happening on campus', 'Kampüste olan her şey');
  static String get followingOnly    => _t('Only clubs you follow',   'Sadece takip ettiğin kulüpler');
  static String get showEventsFrom   => _t('Show events from',        'Şunlardan etkinlikleri göster');
  static String get pickDate         => _t('Pick a date',             'Tarih seç');
  static String get clear            => _t('Clear',                   'Temizle');
  static String get showAllDates     => _t('Show all dates',          'Tüm tarihleri göster');
  static String get noEventsFound    => _t('No events found',         'Etkinlik bulunamadı');
  static String get tryDifferentKeyword => _t('Try a different keyword or clear your filters.', 'Farklı bir anahtar kelime deneyin veya filtrelerinizi temizleyin.');
  static String get nothingScheduled => _t('Nothing scheduled here yet — check another date.', 'Henüz planlanmış bir şey yok — başka bir tarih deneyin.');
  static String get resetFilters     => _t('Reset filters',           'Filtreleri Sıfırla');
  static String get newEvents        => _t('New events',              'Yeni Etkinlikler');
  static String get allCaughtUp      => _t('All caught up',           'Hepsi Görüldü');
  static String get newEventsHint    => _t('Newly created events will appear here until you open their details.', 'Yeni etkinlikler, detaylarını açana kadar burada görünür.');
  static String get going            => _t('Going',                   'Gidiyorum');
  static String get rsvp             => _t('RSVP',                    'Kayıt Ol');
  static String get ended            => _t('Ended',                   'Bitti');

  // ── Notifications
  static String get notifications    => _t('Notifications',       'Bildirimler');
  static String get filterYou        => _t('You',                 'Sen');
  static String get filterEvents     => _t('Events',              'Etkinlikler');
  static String get filterClubs      => _t('Clubs',               'Kulüpler');
  static String get newSection       => _t('New',                 'Yeni');
  static String get earlier          => _t('Earlier',             'Daha Önce');
  static String get accept           => _t('Accept',              'Kabul Et');
  static String get decline          => _t('Decline',             'Reddet');
  static String get nothingHereNotif => _t('Nothing here',        'Henüz bir şey yok');

  // ── Profile
  static String get posts            => _t('Posts',               'Gönderiler');
  static String get clubs            => _t('Clubs',               'Kulüpler');
  static String get followers        => _t('Followers',           'Takipçiler');
  static String get myClubs          => _t('My Clubs',            'Kulüplerim');
  static String get myContent        => _t('My Content',          'İçeriklerim');
  static String get boardMembers     => _t('Board Members',       'Yönetim Kurulu');
  static String get board            => _t('Board',               'Yönetim');
  static String get cancel           => _t('Cancel',              'İptal');
  static String get save             => _t('Save',                'Kaydet');
  static String get delete           => _t('Delete',              'Sil');
  static String get superAdmin       => _t('Super Admin',         'Süper Yönetici');
  static String get clubAdmin        => _t('Club Admin',          'Kulüp Yöneticisi');
  static String get addMajorYear     => _t('Add major & year',    'Bölüm ve yıl ekle');
  static String get addBio           => _t('Add a bio…',          'Biyografi ekle…');
  static String get noClubsYet       => _t("You haven't followed any clubs yet.", 'Henüz bir kulüp takip etmediniz.');
  static String get exploreClubsHint => _t('Explore clubs and follow the ones you like.', 'Kulüpleri keşfet ve beğendiklerini takip et.');
  static String get noBoardMembers   => _t('No board members yet.', 'Henüz yönetim üyesi yok.');
  static String get approvedHere     => _t('Approved requests will appear here.', 'Onaylanan istekler burada görünür.');
  static String get noPostsYet       => _t('No posts yet.',       'Henüz gönderi yok.');
  static String get noEventsYet      => _t('No events yet.',      'Henüz etkinlik yok.');
  static String get noFollowersYet   => _t('No followers yet.',   'Henüz takipçi yok.');
  static String get notFollowingAnyone => _t('Not following anyone yet.', 'Henüz kimseyi takip etmiyor.');
  static String get changePhoto      => _t('Change Profile Photo', 'Profil Fotoğrafını Değiştir');
  static String get takePhoto        => _t('Take a Photo',        'Fotoğraf Çek');
  static String get useCamera        => _t('Use your camera right now', 'Kameranı hemen kullan');
  static String get chooseFromLib    => _t('Choose from Library', 'Kütüphaneden Seç');
  static String get pickFromLib      => _t('Pick from your photo library', 'Fotoğraf kütüphanenizden seçin');
  static String get removePhoto      => _t('Remove photo',        'Fotoğrafı Kaldır');
  static String get majorYearLabel   => _t('Major & Year',        'Bölüm & Yıl');
  static String get selectMajor      => _t('Select your major',   'Bölümünü seç');
  static String get selectMajorHint  => _t('Select major',        'Bölüm seç');
  static String get yearLabel        => _t('Year',                'Yıl');
  static String get bioLabel         => _t('Bio',                 'Biyografi');
  static String get bioHint          => _t('Tell people a little about yourself', 'Kendinizi kısaca tanıtın');
  static String get useThisPhoto     => _t('Use this photo?',     'Bu fotoğrafı kullan?');
  static String get usePhoto         => _t('Use Photo',           'Fotoğrafı Kullan');
  static String get deletePost       => _t('Delete post?',        'Gönderi silinsin mi?');
  static String get deletePostMsg    => _t('This post will be permanently removed.', 'Bu gönderi kalıcı olarak kaldırılacak.');
  static String get deleteEvent      => _t('Delete event?',       'Etkinlik silinsin mi?');
  static String get deleteEventMsg   => _t('This event will be permanently removed.', 'Bu etkinlik kalıcı olarak kaldırılacak.');
  static String get majorNotAdded    => _t('Major not added',     'Bölüm eklenmedi');
  static String get yearNotAdded     => _t('Year not added',      'Yıl eklenmedi');
  static String get addBioIntro      => _t('Add a bio to introduce yourself.', 'Kendinizi tanıtmak için biyografi ekleyin.');

  // ── Bottom nav
  static String get home    => _t('Home',    'Ana Sayfa');
  static String get events  => _t('Events',  'Etkinlikler');
  static String get search  => _t('Search',  'Ara');
  static String get alerts  => _t('Alerts',  'Bildirimler');
  static String get profile => _t('Profile', 'Profil');
  static String get admin   => _t('Admin',   'Yönetici');

  // ── Settings
  static String get settings              => _t('Settings',                        'Ayarlar');
  static String get language              => _t('Language',                        'Dil');
  static String get appearance            => _t('Appearance',                      'Görünüm');
  static String get darkMode              => _t('Dark Mode',                       'Karanlık Mod');
  static String get lightMode             => _t('Light Mode',                      'Aydınlık Mod');
  static String get switchToDark          => _t('Switch to dark theme',            'Karanlık temaya geç');
  static String get switchToLight         => _t('Switch to light theme',           'Aydınlık temaya geç');
  static String get help                  => _t('Help',                            'Yardım');
  static String get account               => _t('Account',                         'Hesap');
  static String get logOut                => _t('Log Out',                         'Çıkış Yap');
  static String get editProfile           => _t('Edit Profile',                    'Profili Düzenle');
  static String get editProfileSubtitle   => _t('Photo, bio, major, year & interests', 'Fotoğraf, biyografi, bölüm, yıl & ilgi alanları');
  static String get changeMyName          => _t('Change My Name',                  'Adımı Değiştir');
  static String get changeNameSubtitle    => _t('Choose the name people see on your student profile.', 'Öğrenci profilinde görünen adı seç.');
  static String get displayName           => _t('Display name',                    'Görünen ad');
  static String get nameTaken             => _t('That name is already taken.',     'Bu isim zaten alınmış.');
  static String get useRealName           => _t('Use Real Name',                   'Gerçek Adı Kullan');
  static String get saveName              => _t('Save Name',                       'Adı Kaydet');
  static String get preferences           => _t('Preferences',                     'Tercihler');
  static String get myPreferences         => _t('My Preferences',                  'Tercihlerim');
  static String get notSetConfigure       => _t('Not set — tap to configure',      'Ayarlanmadı — yapılandırmak için dokun');
  static String get replayTutorial        => _t('Replay App Tutorial',             'Uygulamayı Yeniden Gez');
  static String get replayTutorialSubtitle => _t('Take the guided tour of every area again — anytime', 'Uygulamanın her alanını istediğin zaman yeniden gez');
  static String get profileSection        => _t('Profile',                         'Profil');

  // ── Settings — Club admin
  static String get clubSection          => _t('Club',                             'Kulüp');
  static String get clubName             => _t('Club Name',                        'Kulüp Adı');
  static String get clubNameLabel        => _t('Club name',                        'Kulüp adı');
  static String get clubPhoto            => _t('Club Photo',                       'Kulüp Fotoğrafı');
  static String get changeClubPhoto      => _t('Change Club Photo',                'Kulüp Fotoğrafını Değiştir');
  static String get tapToChangeLogo      => _t('Tap to change your club logo',     'Kulüp logonuzu değiştirmek için dokun');
  static String get clubCategories       => _t('Club Categories',                  'Kulüp Kategorileri');
  static String get chooseTagsHint       => _t('Choose tags that help students discover your club.', 'Öğrencilerin kulübünüzü keşfetmesine yardımcı olacak etiketler seçin.');
  static String get customTags           => _t('Custom tags',                      'Özel etiketler');
  static String get customTagsHint       => _t('Design, Gaming, Culture',          'Tasarım, Oyun, Kültür');
  static String get separateWithCommas   => _t('Separate custom tags with commas', 'Özel etiketleri virgülle ayırın');
  static String get saveCategories       => _t('Save Categories',                  'Kategorileri Kaydet');
  static String get addDiscoveryTags     => _t('Add discovery tags',               'Keşif etiketleri ekle');
  static String get clubDescription      => _t('Club Description',                 'Kulüp Açıklaması');
  static String get clubDescriptionHint  => _t('What is this club about?',         'Bu kulüp ne hakkında?');
  static String get manageBoardMembers   => _t('Manage Board Members',             'Yönetim Kurulunu Yönet');
  static String get manageBoardSubtitle  => _t('Add or remove board members & roles', 'Yönetim üyelerini ve rolleri ekle veya kaldır');

  // ── Feed composer
  static String get post                 => _t('Post',                             'Gönder');
  static String get addPhoto             => _t('Add photo',                        'Fotoğraf ekle');
  static String get whatsHappeningAtClub => _t("What's happening at your club?",   'Kulübünde neler oluyor?');
  static String get tapForDetails        => _t('Tap for details',                  'Detaylar için dokun');

  // ── This Week
  static String get pastEventsHint       => _t('Events that finished during the last 7 days.', 'Son 7 gün içinde biten etkinlikler.');
  static String get upcomingEventsHint   => _t("What's on across campus — next 3 weeks.", 'Kampüste neler var — önümüzdeki 3 hafta.');

  // ── Notifications
  static String get yesterday            => _t('Yesterday',                        'Dün');
  static String noNotificationsFor(String label) =>
      _t('No ${label}notifications right now. We\'ll let you know when something happens.',
         '${label}bildirim yok şu an. Bir şey olduğunda haber veririz.');

  // ── Explore
  static String get profilesWillAppear   => _t('Profiles will appear here after users sign up', 'Kullanıcılar kaydolduktan sonra profiller burada görünecek');

  // ── Profile
  static String get graduate             => _t('Graduate',                         'Lisansüstü');
}
