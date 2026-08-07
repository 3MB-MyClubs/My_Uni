// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get goodMorning => 'Günaydın';

  @override
  String get goodAfternoon => 'İyi öğleden sonralar';

  @override
  String get goodEvening => 'İyi akşamlar';

  @override
  String get stillUp => 'Hâlâ uyanık mısın';

  @override
  String get thisWeek => 'BU HAFTA';

  @override
  String get eventsOnCampus => 'Kampüsteki etkinlikler';

  @override
  String get campusHappening => 'Kampüste neler oluyor, göz at.';

  @override
  String get membersHappening => 'Üyelerin neler yapıyor, göz at.';

  @override
  String get seeAll => 'Hepsini gör';

  @override
  String get bringYourFriends => 'Arkadaşlarını da getir';

  @override
  String get invite => 'Davet et';

  @override
  String get invited => 'Davet edildi';

  @override
  String get shareEventAction => 'Etkinliği paylaş';

  @override
  String get shareThisEvent => 'Bu etkinliği paylaş';

  @override
  String get qrCodeAction => 'QR kodu';

  @override
  String get searchPeopleOnCampus => 'Kampüsteki kişileri ara';

  @override
  String get sentAction => 'Gönderildi';

  @override
  String inviteFriendsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arkadaşını davet et',
      one: '1 arkadaşını davet et',
      zero: 'Arkadaşlarını davet et',
    );
    return '$_temp0';
  }

  @override
  String eventInvitesSentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count davet gönderildi',
      one: 'Davet gönderildi',
    );
    return '$_temp0';
  }

  @override
  String get noPeopleMatchSearch => 'Aramanla eşleşen kişi bulunamadı.';

  @override
  String get scanToOpenEvent => 'Etkinliği açmak için tara';

  @override
  String followedPeopleAttending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Takip ettiğin $count kişi katılıyor',
      zero: 'Takip ettiklerinden henüz katılan yok',
    );
    return '$_temp0';
  }

  @override
  String eventInviteSent(String name) {
    return '$name davet edildi.';
  }

  @override
  String mutualClubsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ortak kulüp',
    );
    return '$_temp0';
  }

  @override
  String get fromYourClubs => 'KULÜPLERİNDEN';

  @override
  String get clubFeed => 'KULÜp AKIŞI';

  @override
  String get following => 'Takip';

  @override
  String get all => 'Tümü';

  @override
  String get latest => 'Son Gönderiler';

  @override
  String get nothingHere => 'Henüz bir şey yok';

  @override
  String get followClubs => 'Gönderilerini görmek için\nkulüp takip et';

  @override
  String get endOfFeed => 'Bugünlük bu kadar 😀';

  @override
  String get exploreClubs => 'Tüm Kulüpleri Keşfet';

  @override
  String get peopleMightKnow => 'Tanıyor Olabileceğin Kişiler';

  @override
  String get suggestedForYou => 'Senin için önerilenler';

  @override
  String get followBack => 'Geri takip et';

  @override
  String get clubMightLike => 'Beğenebileceğin Kulüp';

  @override
  String get today => 'Bugün';

  @override
  String get tomorrow => 'Yarın';

  @override
  String get explore => 'Keşfet';

  @override
  String get discoverClubs => 'Kulüpleri Keşfet';

  @override
  String get findPeople => 'Kişileri Bul';

  @override
  String get searchClubs => 'Ara…';

  @override
  String get searchPeople => 'Ara…';

  @override
  String get allClubs => 'Tüm kulüpler';

  @override
  String get exploreContentTab => 'Etkinlikler';

  @override
  String get searchEventsPosts => 'Etkinlik ara…';

  @override
  String get upcomingEvents => 'Yaklaşan etkinlikler';

  @override
  String get noContentMatch => 'Sonuç bulunamadı';

  @override
  String get noClubsMatch => 'Eşleşen kulüp yok';

  @override
  String get tryDifferentSearch => 'Farklı bir arama terimi dene';

  @override
  String get studentProfile => 'Öğrenci profili';

  @override
  String get joined => 'Katıldı ✓';

  @override
  String get join => 'Katıl';

  @override
  String get follow => 'Takip Et';

  @override
  String get noOneMatches => 'Kimse bulunamadı';

  @override
  String get tryNameSearch => 'İsim, soyisim veya e-posta dene';

  @override
  String get discoverEvents => 'Etkinlikleri Keşfet';

  @override
  String get searchEvents => 'Etkinlik, kulüp, konu ara';

  @override
  String get anyDate => 'Herhangi bir tarih';

  @override
  String get past => 'Geçmiş';

  @override
  String get live => 'Canlı';

  @override
  String get allEvents => 'Tüm etkinlikler';

  @override
  String get allPosts => 'Tüm gönderiler';

  @override
  String get overview => 'Genel bakış';

  @override
  String get everythingOnCampus => 'Kampüste olan her şey';

  @override
  String get followingOnly => 'Sadece takip ettiğin kulüpler';

  @override
  String get showEventsFrom => 'Şunlardan etkinlikleri göster';

  @override
  String get pickDate => 'Tarih seç';

  @override
  String get clear => 'Temizle';

  @override
  String get showAllDates => 'Tüm tarihleri göster';

  @override
  String get noEventsFound => 'Etkinlik bulunamadı';

  @override
  String get tryDifferentKeyword =>
      'Farklı bir anahtar kelime deneyin veya filtrelerinizi temizleyin.';

  @override
  String get nothingScheduled =>
      'Henüz planlanmış bir şey yok — başka bir tarih deneyin.';

  @override
  String get checkBackLater =>
      'Şu anda takvimde bir şey yok — yakında tekrar bak!';

  @override
  String get resetFilters => 'Filtreleri Sıfırla';

  @override
  String get newEvents => 'Yeni Etkinlikler';

  @override
  String get allCaughtUp => 'Hepsi Görüldü';

  @override
  String get newEventsHint =>
      'Yeni etkinlikler, detaylarını açana kadar burada görünür.';

  @override
  String get going => 'Gidiyorum';

  @override
  String get rsvp => 'Hadi Gidelim';

  @override
  String get ended => 'Bitti';

  @override
  String get notifications => 'Bildirimler';

  @override
  String get filterYou => 'Sen';

  @override
  String get filterEvents => 'Etkinlikler';

  @override
  String get filterClubs => 'Kulüpler';

  @override
  String get newSection => 'Yeni';

  @override
  String get earlier => 'Daha Önce';

  @override
  String get accept => 'Kabul Et';

  @override
  String get decline => 'Reddet';

  @override
  String get nothingHereNotif => 'Henüz bir şey yok';

  @override
  String get eventPass => 'Etkinlik Kartı';

  @override
  String get eventPassHint => 'Girişte bu kodu göstererek yoklamaya katıl.';

  @override
  String get showMyPass => 'Kartımı göster';

  @override
  String get scanCheckins => 'Yoklama tara';

  @override
  String get scanInvalidPass => 'Geçersiz Etkinlik Kartı';

  @override
  String get scanWrongEvent => 'Kart başka bir etkinliğe ait';

  @override
  String get scanAlreadyIn => 'zaten giriş yaptı';

  @override
  String get scanNotAdmitted => 'Alınmadı';

  @override
  String get scanNoRsvpTitle => 'RSVP bulunamadı';

  @override
  String scanNoRsvpBody(String name) {
    return '$name bu etkinliğe RSVP yapmamış. Yine de alınsın mı?';
  }

  @override
  String get scanAdmitAnyway => 'Yine de al';

  @override
  String checkedInCounter(int checked, int total) {
    return '$checked / $total giriş yaptı';
  }

  @override
  String get checkedIn => 'Giriş yaptı';

  @override
  String get addPoll => 'Anket ekle';

  @override
  String get pollQuestionHint => 'Bir soru sor…';

  @override
  String pollOptionHint(int n) {
    return 'Seçenek $n';
  }

  @override
  String pollVotes(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n oy',
    );
    return '$_temp0';
  }

  @override
  String get announcement => 'Duyuru';

  @override
  String get markAsAnnouncement => 'Duyuru olarak paylaş';

  @override
  String get comments => 'Yorumlar';

  @override
  String get addComment => 'Yorum ekle…';

  @override
  String get noCommentsYet => 'Henüz yorum yok. İlk yorumu sen yap!';

  @override
  String get deleteComment => 'Yorumu sil';

  @override
  String get posts => 'Gönderiler';

  @override
  String get clubs => 'Kulüpler';

  @override
  String get followers => 'Takipçiler';

  @override
  String get myClubs => 'Kulüplerim';

  @override
  String get myContent => 'İçeriklerim';

  @override
  String get boardMembers => 'Yönetim Kurulu';

  @override
  String get board => 'Yönetim';

  @override
  String get cancel => 'İptal';

  @override
  String get save => 'Kaydet';

  @override
  String get delete => 'Sil';

  @override
  String get superAdmin => 'Süper Yönetici';

  @override
  String get clubAdmin => 'Kulüp Yöneticisi';

  @override
  String get addMajorYear => 'Bölüm ve yıl ekle';

  @override
  String get addBio => 'Biyografi ekle…';

  @override
  String get noClubsYet => 'Henüz bir kulüp takip etmediniz.';

  @override
  String get exploreClubsHint => 'Kulüpleri keşfet ve beğendiklerini takip et.';

  @override
  String get noBoardMembers => 'Henüz yönetim üyesi yok.';

  @override
  String get approvedHere => 'Onaylanan istekler burada görünür.';

  @override
  String get noPostsYet => 'Henüz gönderi yok.';

  @override
  String get noEventsYet => 'Henüz etkinlik yok.';

  @override
  String get noFollowersYet => 'Henüz takipçi yok.';

  @override
  String get notFollowingAnyone => 'Henüz kimseyi takip etmiyor.';

  @override
  String get changePhoto => 'Profil Fotoğrafını Değiştir';

  @override
  String get takePhoto => 'Fotoğraf Çek';

  @override
  String get useCamera => 'Kameranı hemen kullan';

  @override
  String get chooseFromLib => 'Kütüphaneden Seç';

  @override
  String get pickFromLib => 'Fotoğraf kütüphanenizden seçin';

  @override
  String get removePhoto => 'Fotoğrafı Kaldır';

  @override
  String get majorYearLabel => 'Bölüm & Yıl';

  @override
  String get selectMajor => 'Bölümünü seç';

  @override
  String get selectMajorHint => 'Bölüm seç';

  @override
  String get yearLabel => 'Yıl';

  @override
  String get bioLabel => 'Biyografi';

  @override
  String get bioHint => 'Kendinizi kısaca tanıtın';

  @override
  String get useThisPhoto => 'Bu fotoğrafı kullan?';

  @override
  String get usePhoto => 'Fotoğrafı Kullan';

  @override
  String get deletePost => 'Gönderi silinsin mi?';

  @override
  String get deletePostMsg => 'Bu gönderi kalıcı olarak kaldırılacak.';

  @override
  String get deleteEvent => 'Etkinlik silinsin mi?';

  @override
  String get deleteEventMsg => 'Bu etkinlik kalıcı olarak kaldırılacak.';

  @override
  String get eventDeletedConfirmation => 'Etkinlik silindi';

  @override
  String get majorNotAdded => 'Bölüm eklenmedi';

  @override
  String get yearNotAdded => 'Yıl eklenmedi';

  @override
  String get addBioIntro => 'Kendinizi tanıtmak için biyografi ekleyin.';

  @override
  String get home => 'Ana Sayfa';

  @override
  String get events => 'Etkinlikler';

  @override
  String get search => 'Ara';

  @override
  String get alerts => 'Bildirimler';

  @override
  String get profile => 'Profil';

  @override
  String get admin => 'Yönetici';

  @override
  String get settings => 'Ayarlar';

  @override
  String get language => 'Dil';

  @override
  String get appearance => 'Görünüm';

  @override
  String get darkMode => 'Karanlık Mod';

  @override
  String get lightMode => 'Aydınlık Mod';

  @override
  String get switchToDark => 'Karanlık temaya geç';

  @override
  String get switchToLight => 'Aydınlık temaya geç';

  @override
  String get help => 'Yardım';

  @override
  String get supportAndLegal => 'Destek ve Yasal';

  @override
  String get supportCenter => 'Destek Merkezi';

  @override
  String get supportCenterSubtitle => 'Yardım, sık sorulanlar ve iletişim';

  @override
  String get privacyPolicy => 'Gizlilik Politikası';

  @override
  String get privacyPolicySubtitle => 'ClubUp verilerinizi nasıl işler';

  @override
  String get termsOfUse => 'Kullanım Koşulları';

  @override
  String get termsOfUseSubtitle => 'Topluluk kuralları ve güvenlik uygulaması';

  @override
  String get deleteAccount => 'Hesabı Sil';

  @override
  String get deleteAccountSubtitle =>
      'Hesap ve verilerin kalıcı olarak silinmesini iste';

  @override
  String get couldNotOpenPage => 'Bu sayfa açılamadı.';

  @override
  String get account => 'Hesap';

  @override
  String get logOut => 'Çıkış Yap';

  @override
  String get confirmLogoutTitle => 'Çıkış yapılsın mı?';

  @override
  String get confirmLogoutMessage =>
      'Hesabınızdan çıkış yapmak istediğinizden emin misiniz?';

  @override
  String get editProfile => 'Profili Düzenle';

  @override
  String get editProfileSubtitle => 'Fotoğraf, biyografi, bölüm & yıl';

  @override
  String get changeMyName => 'Adımı Değiştir';

  @override
  String get changeNameSubtitle => 'Öğrenci profilinde görünen adı seç.';

  @override
  String get displayName => 'Görünen ad';

  @override
  String get nameTaken => 'Bu isim zaten alınmış.';

  @override
  String get useRealName => 'Gerçek Adı Kullan';

  @override
  String get saveName => 'Adı Kaydet';

  @override
  String get notSetConfigure => 'Ayarlanmadı — yapılandırmak için dokun';

  @override
  String get replayTutorial => 'Uygulamayı Yeniden Gez';

  @override
  String get replayTutorialSubtitle =>
      'Uygulamanın her alanını istediğin zaman yeniden gez';

  @override
  String get safetyHero => 'Güvenli bir kampüs topluluğu hepimizle başlar';

  @override
  String get safetyIntro =>
      'Hesap oluşturmadan veya giriş yapmadan önce lütfen Kullanım Koşullarını inceleyip kabul et.';

  @override
  String get communitySafetyTerms => 'TOPLULUK GÜVENLİĞİ KOŞULLARI';

  @override
  String get zeroTolerance => 'Sıfır tolerans';

  @override
  String get zeroToleranceBody =>
      'Sakıncalı içeriklere, tacize, tehditlere, nefrete, cinsel sömürüye, dolandırıcılığa ve kötü niyetli kullanıcılara izin verilmez.';

  @override
  String get reportHarmfulContent => 'Zararlı içeriği bildir';

  @override
  String get reportHarmfulContentBody =>
      'Gönderi ve profillerdeki bildirme seçeneğini kullan. ClubUp bildirimleri 24 saat içinde inceler ve ihlaller için işlem yapar.';

  @override
  String get blockAbusiveUsers => 'Kötü niyetli kullanıcıları engelle';

  @override
  String get blockAbusiveUsersBody =>
      'Engelleme, hesabı ClubUp’a bildirir ve kullanıcıyı ve içeriğini deneyiminden hemen kaldırır.';

  @override
  String get enforcement => 'Yaptırım';

  @override
  String get enforcementBody =>
      'ClubUp ihlalli içeriği kaldırabilir ve sorumlu hesabı askıya alabilir veya kalıcı olarak hizmetten çıkarabilir.';

  @override
  String get readFullTerms => 'Kullanım Koşullarının tamamını oku';

  @override
  String get agreeToSafetyTerms =>
      'Kullanım Koşullarını ve Topluluk Güvenliği Koşullarını kabul ediyorum.';

  @override
  String get agreeAndContinue => 'Kabul et ve devam et';

  @override
  String get iAccept => 'Kabul Ediyorum';

  @override
  String get updatedTermsTitle => 'Kullanım Koşullarımızı güncelledik';

  @override
  String get updatedTermsMessage =>
      'ClubUp\'ı kullanmaya devam etmek için lütfen güncellenen koşulları inceleyip kabul et.';

  @override
  String get termsAcceptanceSaveFailed =>
      'Kabulün kaydedilemedi. Hesabın hâlâ kilitli. Bağlantını kontrol edip tekrar dene.';

  @override
  String get termsVerificationFailed =>
      'Bu hesabın kabul ettiği Kullanım Koşulları sürümünü doğrulayamadık. Doğrulama başarılı olana veya güncel koşulları kabul edene kadar erişim kilitli kalır.';

  @override
  String get retry => 'Tekrar dene';

  @override
  String get termsReviewSummary =>
      'Bu koşullar ClubUp kullanım kurallarını ve kampüs topluluğunu nasıl güvende tuttuğumuzu açıklar.';

  @override
  String get termsEffectiveMetadata =>
      'Yürürlük: 18 Temmuz 2026  •  Son güncelleme: 18 Temmuz 2026  •  İşleten: 3MB MyClubs';

  @override
  String get termsZeroToleranceNotice =>
      'ClubUp, sakıncalı içeriklere ve kötü niyetli kullanıcılara karşı sıfır tolerans uygular.';

  @override
  String get termsAgreementTitle => '1. Koşulların kabulü';

  @override
  String get termsAgreementBody =>
      'Hesap oluşturarak, giriş yaparak veya ClubUp\'ı kullanarak bu Kullanım Koşullarını ve Gizlilik Politikamızı kabul edersin. Kabul etmiyorsan hizmeti kullanma. Uygulama içi sözleşme kayıt sırasında ve güncellenen koşullar yeniden kabul gerektirdiğinde sunulur.';

  @override
  String get termsEligibilityTitle => '2. Uygunluk ve hesaplar';

  @override
  String get termsEligibilityBody =>
      'ClubUp, desteklenen üniversite topluluğunun uygun üyeleri içindir. Doğru bilgi ver, giriş bilgilerini koru, başka bir kişiyi taklit etme ve hesabını paylaşma. Hesabınla gerçekleştirilen faaliyetlerden sorumlusun.';

  @override
  String get termsSafetyTitle => '3. Topluluk güvenliği ve yasak davranışlar';

  @override
  String get termsSafetyBody =>
      'Şunları paylaşamaz, gönderemez, teşvik edemez veya yapamazsın:\n\n• Taciz, zorbalık, takip, tehdit, yıldırma veya hedefli kötüye kullanım.\n• Korunan bir niteliğe dayalı nefret söylemi veya ayrımcılık.\n• Çıplaklık, cinsel sömürü, rıza dışı cinsel içerik veya çocukların cinsel istismarına ilişkin herhangi bir materyal.\n• Şiddet, kendine zarar vermeyi teşvik, tehlikeli davranış veya ciddi zarar tehdidi.\n• Dolandırıcılık, spam, kötü amaçlı bağlantı, yasa dışı faaliyet veya aldatıcı kimliğe bürünme.\n• Gizliliği, fikrî mülkiyeti, hukuku ya da başka bir kişinin haklarını ihlal eden içerik.\n• Denetimden kaçma, bildirim yapanlardan intikam alma veya askıya alınan bir kullanıcının geri dönmesine yardım etme.';

  @override
  String get termsContentTitle => '4. İçeriğin';

  @override
  String get termsContentBody =>
      'Gönderdiğin içerikten sen sorumlusun. ClubUp\'a yalnızca hizmeti işletmek için gereken barındırma, görüntüleme, işleme ve denetleme iznini verirsin. Paylaşma iznin olmayan materyalleri yükleme.';

  @override
  String get termsReportingTitle => '5. Bildirim ve engelleme';

  @override
  String get termsReportingBody =>
      'Sakıncalı materyalleri bildirmek için uygulamadaki Gönderiyi bildir veya Kullanıcıyı bildir seçeneklerini kullan. Kullanıcıyı engelle ve bildir seçeneği ClubUp\'ı bilgilendirir ve kullanıcıyı ve içeriğini deneyiminden hemen kaldırır. Acil güvenlik endişeleri için dev3mb@gmail.com adresine yaz.\n\nUygulama içi güvenlik bildirimlerini 24 saat içinde inceleriz.';

  @override
  String get termsEnforcementTitle => '6. Yaptırım';

  @override
  String get termsEnforcementBody =>
      'İçerik veya davranış bu koşulları ihlal ettiğinde ClubUp; içeriği kaldırma, özellikleri kısıtlama, kanıtları koruma, hesabı askıya alma ve ihlalli içeriği sağlayan kullanıcıyı kalıcı olarak hizmetten çıkarma dâhil uygun işlemleri yapar. Ciddi veya tekrarlanan ihlaller gerektiğinde üniversiteye ya da yetkili makamlara bildirilebilir.';

  @override
  String get termsServiceTitle => '7. Hizmet';

  @override
  String get termsServiceBody =>
      'ClubUp özellikleri değiştirebilir, askıya alabilir veya sonlandırabilir ve kesintisiz kullanılabilirliği garanti etmez. ClubUp bir öğrenci topluluğu ürünüdür ve Koç Üniversitesinin resmî bir hizmeti değildir.';

  @override
  String get termsChangesTitle => '8. Değişiklikler ve iletişim';

  @override
  String get termsChangesBody =>
      'Bu koşulları güncelleyebilir ve güncel tarihi burada yayımlarız. Önemli bir güncelleme uygulama içinde yeniden kabul gerektirebilir. Sorular ve güvenlik endişeleri için dev3mb@gmail.com adresine yaz veya ClubUp Destek sayfasını kullan.';

  @override
  String get couldNotOpenThisPage => 'Bu sayfa açılamadı.';

  @override
  String get whyReportPost => 'Bu gönderiyi neden bildiriyorsun?';

  @override
  String get whyReportUser => 'Bu kullanıcıyı neden bildiriyorsun?';

  @override
  String get whyBlockUser => 'Bu kullanıcıyı neden engelliyorsun?';

  @override
  String get chooseReportReason =>
      'Sorunu en iyi açıklayan nedeni seç. Bildirimler 24 saat içinde incelenir.';

  @override
  String moderationReasonLabel(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'harassment': 'Taciz veya zorbalık',
      'hate_or_discrimination': 'Nefret veya ayrımcılık',
      'sexual_content': 'Cinsel veya açık içerik',
      'violence_or_danger': 'Şiddet veya tehlikeli davranış',
      'spam_or_scam': 'Spam veya dolandırıcılık',
      'other': 'Başka bir neden',
    });
    return '$_temp0';
  }

  @override
  String moderationReasonDetail(String value) {
    String _temp0 = intl.Intl.selectLogic(value, {
      'harassment':
          'Bir kişiyi veya grubu hedef alır, tehdit eder ya da kötüye kullanır.',
      'hate_or_discrimination':
          'İnsanlara korunan bir özellikleri nedeniyle saldırır.',
      'sexual_content': 'İstenmeyen çıplaklık veya cinsel materyal içerir.',
      'violence_or_danger':
          'Zarar tehdidi içerir veya tehlikeli davranışı teşvik eder.',
      'spam_or_scam':
          'İnsanları yanıltır veya sürekli istenmeyen içerik paylaşır.',
      'other': 'ClubUp Kullanım Koşullarının başka bir ihlali.',
    });
    return '$_temp0';
  }

  @override
  String get reportPost => 'Gönderiyi bildir';

  @override
  String get reportUser => 'Kullanıcıyı bildir';

  @override
  String get reportUserSubtitle =>
      'Bu profili incelenmesi için ClubUp’a gönder.';

  @override
  String get blockAndReportUser => 'Kullanıcıyı engelle ve bildir';

  @override
  String get blockAndReportSubtitle =>
      'Bu kullanıcıyı hemen gizle ve ClubUp’a bildir.';

  @override
  String blockUserQuestion(String name) {
    return '$name engellensin mi?';
  }

  @override
  String get blockUserExplanation =>
      'Profili ve içeriği deneyiminden hemen kaldırılacak. ClubUp ayrıca bir güvenlik bildirimi alacak.';

  @override
  String get userReported =>
      'Kullanıcı bildirildi. Ekibimiz 24 saat içinde inceleyecek.';

  @override
  String get reportSendFailed => 'Bildirim gönderilemedi. Lütfen tekrar dene.';

  @override
  String get userBlockedAndReported => 'Kullanıcı engellendi ve bildirildi.';

  @override
  String get userBlockedOffline =>
      'Kullanıcı bu cihazda engellendi. Bildirim gönderilemedi; çevrimiçi olduğunda tekrar dene.';

  @override
  String get postReportedAndRemoved =>
      'Gönderi bildirildi ve akışından kaldırıldı.';

  @override
  String get postHiddenOffline =>
      'Gönderi gizlendi. Bildirim gönderilemedi; çevrimiçi olduğunda tekrar dene.';

  @override
  String get safetyOptions => 'Güvenlik seçenekleri';

  @override
  String get contentSafetyRejected =>
      'Bu içerik ClubUp Topluluk Güvenliği Koşullarını ihlal edebileceği için yayımlanamaz.';

  @override
  String get profileSection => 'Profil';

  @override
  String get clubSection => 'Kulüp';

  @override
  String get clubName => 'Kulüp Adı';

  @override
  String get clubNameLabel => 'Kulüp adı';

  @override
  String get clubPhoto => 'Kulüp Fotoğrafı';

  @override
  String get changeClubPhoto => 'Kulüp Fotoğrafını Değiştir';

  @override
  String get tapToChangeLogo => 'Kulüp logonuzu değiştirmek için dokun';

  @override
  String get clubCategories => 'Kulüp Kategorileri';

  @override
  String get chooseTagsHint =>
      'Öğrencilerin kulübünüzü keşfetmesine yardımcı olacak etiketler seçin.';

  @override
  String get customTags => 'Özel etiketler';

  @override
  String get customTagsHint => 'Tasarım, Oyun, Kültür';

  @override
  String get separateWithCommas => 'Özel etiketleri virgülle ayırın';

  @override
  String get saveCategories => 'Kategorileri Kaydet';

  @override
  String get addDiscoveryTags => 'Keşif etiketleri ekle';

  @override
  String get clubDescription => 'Kulüp Açıklaması';

  @override
  String get clubDescriptionHint => 'Bu kulüp ne hakkında?';

  @override
  String get manageBoardMembers => 'Yönetim Kurulunu Yönet';

  @override
  String get manageBoardSubtitle =>
      'Yönetim üyelerini ve rolleri ekle veya kaldır';

  @override
  String get post => 'Gönder';

  @override
  String get addPhoto => 'Fotoğraf ekle';

  @override
  String get whatsHappeningAtClub => 'Kulübünde neler oluyor?';

  @override
  String get tapForDetails => 'Detaylar için dokun';

  @override
  String get pastEventsHint => 'Son 7 gün içinde biten etkinlikler.';

  @override
  String get upcomingEventsHint => 'Kampüste neler var — önümüzdeki ay.';

  @override
  String get yesterday => 'Dün';

  @override
  String noNotificationsFor(String label) {
    return '${label}bildirim yok şu an. Bir şey olduğunda haber veririz.';
  }

  @override
  String get profilesWillAppear =>
      'Kullanıcılar kaydolduktan sonra profiller burada görünecek';

  @override
  String get graduate => 'Lisansüstü';

  @override
  String get addedToBothCalendars => 'Her iki takvime de eklendi';

  @override
  String get enableCalendarAccessHint =>
      'Gidiyorsun! Telefonuna da senkronlamak için Ayarlar\'dan takvim erişimini aç.';

  @override
  String get publishErrorRlsPolicy =>
      'Gönderi yayımlanamadı. Bu kulüp hesabı için club_posts RLS politikalarını kontrol et.';

  @override
  String get publishErrorMigration =>
      'Gönderi yayımlanamadı. En son club_posts SQL migrasyonunu çalıştır.';

  @override
  String get publishErrorStorage =>
      'Fotoğraf yüklenemedi. post-images bucket politikalarını kontrol et.';

  @override
  String get publishErrorGeneric =>
      'Gönderi yayımlanamadı. Supabase ayarlarını kontrol et.';

  @override
  String get confirm => 'Onayla';

  @override
  String get liveNowLabel => 'CANLI';

  @override
  String get clubFallbackName => 'Kulüp';

  @override
  String get clubEmailPasscodeRequired => 'Kulüp e-postası ve şifre gerekli';

  @override
  String get passcodeMustBe8Digits => 'Şifre tam olarak 8 haneli olmalı';

  @override
  String get invalidClubCredentials => 'Geçersiz kulüp e-postası veya şifresi';

  @override
  String get clubNotLinked => 'Bu giriş bir kulübe bağlı değil';

  @override
  String get linkedClubNotFound => 'Bağlı kulüp bulunamadı';

  @override
  String get clubLoginNotReady =>
      'Kulüp girişi hazır değil. Supabase\'te club_auth_accounts tablosunu kontrol et.';

  @override
  String get clubAdminLoginTitle => 'Kulüp Yönetici Girişi';

  @override
  String get clubAdminLoginSubtitle =>
      'Kulübünü yönetmek için kulüp e-postanı ve 8 haneli şifreni gir.';

  @override
  String get platformAdminLoginTitle => 'Platform Yöneticisi Girişi';

  @override
  String get platformAdminLoginSubtitle =>
      'ClubUp platform yöneticisine ayrılmış kısıtlı erişim.';

  @override
  String get adminEmailLabel => 'Yönetici e-postası';

  @override
  String get adminCredentialsRequired =>
      'Yönetici e-postası ve şifresi gerekli';

  @override
  String get invalidAdminCredentials =>
      'Geçersiz yönetici e-postası veya şifresi';

  @override
  String get notPlatformAdmin => 'Bu bilgiler platform yöneticisine atanmamış';

  @override
  String get clubEmailLabel => 'Kulüp E-postası';

  @override
  String get eightDigitPasscodeLabel => '8 haneli şifre';

  @override
  String get eightDigitsHint => '8 hane';

  @override
  String get forgotPasscode => 'Şifreni mi unuttun?';

  @override
  String get signInAsAdmin => 'Yönetici Olarak Giriş Yap';

  @override
  String get supabaseNotConfigured => 'Supabase yapılandırılmadı.';

  @override
  String get passwordResetRequestFailed =>
      'Şifre sıfırlama isteği başarısız oldu.';

  @override
  String get couldNotReachResetServer =>
      'Şifre sıfırlama sunucusuna ulaşılamadı. Lütfen tekrar dene.';

  @override
  String resetCredentialTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'passcode': 'Şifreyi Sıfırla',
      'other': 'Şifreyi Sıfırla',
    });
    return '$_temp0';
  }

  @override
  String get checkYourEmailTitle => 'E-postanı kontrol et';

  @override
  String createNewCredentialTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'passcode': 'Yeni şifre oluştur',
      'other': 'Yeni şifre oluştur',
    });
    return '$_temp0';
  }

  @override
  String credentialUpdatedTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'passcode': 'Şifre güncellendi',
      'other': 'Şifre güncellendi',
    });
    return '$_temp0';
  }

  @override
  String get enterKuEmailSubtitle => 'Hesabın için KU e-postanı gir.';

  @override
  String get enterAccountEmailSubtitle => 'Hesabın için e-posta adresini gir.';

  @override
  String enterCodeSubtitle(String email) {
    return '$email adresine gönderilen tek kullanımlık kodu gir.';
  }

  @override
  String newCredentialSubtitle(String kind, int length) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'passcode': '$length haneli, sadece rakamlardan oluşan bir şifre kullan.',
      'other': '$length haneli, sadece rakamlardan oluşan bir şifre kullan.',
    });
    return '$_temp0';
  }

  @override
  String credentialUpdatedSubtitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'passcode': 'Artık yeni şifrenle giriş yapabilirsin.',
      'other': 'Artık yeni şifrenle giriş yapabilirsin.',
    });
    return '$_temp0';
  }

  @override
  String get sendCodeButton => 'Kod gönder';

  @override
  String get verifyCodeButton => 'Kodu doğrula';

  @override
  String updateCredentialButton(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'passcode': 'Şifreyi güncelle',
      'other': 'Şifreyi güncelle',
    });
    return '$_temp0';
  }

  @override
  String get backToSignIn => 'Girişe dön';

  @override
  String get kuEmailLabel => 'KU E-postası';

  @override
  String get oneTimeCodeLabel => 'Tek kullanımlık kod';

  @override
  String get enterSixDigitCodeHint => '6 haneli kodu gir';

  @override
  String get sendingEllipsis => 'Gönderiliyor...';

  @override
  String get sendNewCode => 'Yeni kod gönder';

  @override
  String newCredentialLabel(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'passcode': 'Yeni şifre',
      'other': 'Yeni şifre',
    });
    return '$_temp0';
  }

  @override
  String digitPinHint(int length) {
    return '$length haneli PIN';
  }

  @override
  String confirmCredentialLabel(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'passcode': 'Şifreyi onayla',
      'other': 'Şifreyi onayla',
    });
    return '$_temp0';
  }

  @override
  String reenterDigitPinHint(int length) {
    return '$length haneli PIN\'i tekrar gir';
  }

  @override
  String exactlyNDigits(int length) {
    return 'Tam olarak $length hane';
  }

  @override
  String get numbersOnly => 'Sadece rakam';

  @override
  String get pleaseEnterKuEmail => 'Lütfen KU e-postanı gir.';

  @override
  String get useKuEmailAddress =>
      '@ku.edu.tr uzantılı e-posta adresini kullan.';

  @override
  String get useValidEmailAddress => 'Geçerli bir e-posta adresi gir.';

  @override
  String get newCodeSent => 'Yeni kod gönderildi.';

  @override
  String get enterSixDigitCode => '6 haneli kodu gir.';

  @override
  String credentialMustBeNDigits(String kind, int length) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'passcode': 'Şifre tam olarak $length haneli olmalı.',
      'other': 'Şifre tam olarak $length haneli olmalı.',
    });
    return '$_temp0';
  }

  @override
  String credentialNumbersOnly(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'passcode': 'Şifre sadece rakam içermeli.',
      'other': 'Şifre sadece rakam içermeli.',
    });
    return '$_temp0';
  }

  @override
  String get passwordsDoNotMatch => 'Şifreler eşleşmiyor.';

  @override
  String get aboutThisEvent => 'Bu etkinlik hakkında';

  @override
  String get accountReadyRedirecting =>
      'Hesabın hazır.\nGiriş ekranına yönlendiriliyorsun.';

  @override
  String actorCommentedOnYourPost(String actor) {
    return '$actor gönderine yorum yaptı';
  }

  @override
  String actorLikedYourPost(String actor) {
    return '$actor gönderini beğendi';
  }

  @override
  String actorRsvpdToEvent(String actor, String event) {
    return '$actor $event etkinliğine katılacağını belirtti';
  }

  @override
  String get add => 'Ekle';

  @override
  String get addAPhotoTitle => 'Fotoğraf ekle';

  @override
  String get addCoverPhotoOptional => 'Kapak fotoğrafı ekle (opsiyonel)';

  @override
  String get addCustomTagHint => 'Özel etiket ekle…';

  @override
  String get addEventToCampusCalendar => 'Kampüs takvimine bir etkinlik ekle';

  @override
  String get addFollowerAboveHint =>
      'Yukarıdan bir takipçi ekleyerek Kurul sekmesinde herkese açık göster.';

  @override
  String get addImageOrKeepImageless =>
      'Bir görsel ekle ya da bu etkinliği görselsiz bırak';

  @override
  String get addLabel => 'Ekle';

  @override
  String get addRequiredFieldsBeforePublish =>
      'Yayınlamadan önce bir başlık, konum ve geçerli bir zaman aralığı ekle.';

  @override
  String get addSpeaker => 'Konuşmacı ekle';

  @override
  String get addTimeSlot => 'Zaman dilimi ekle';

  @override
  String get addTitleLocationToContinue =>
      'Devam etmek için bir etkinlik başlığı ve konum ekle.';

  @override
  String get addToCalendarButton => 'Takvime Ekle';

  @override
  String get addingEllipsis => 'Ekleniyor…';

  @override
  String get adminDashboardTitle => 'Yönetici Paneli';

  @override
  String get agenda => 'Gündem';

  @override
  String get allowAccessButton => 'Erişime İzin Ver';

  @override
  String get allowCalendarAccessTitle => 'Takvim Erişimine İzin Ver';

  @override
  String get alreadyHaveAccount => 'Zaten hesabım var';

  @override
  String get assignClubRoleLabel => 'Kulüp rolü ata';

  @override
  String get attendedBadge => 'KATILDI';

  @override
  String attendedCount(int n) {
    return '$n katıldı';
  }

  @override
  String get attendees => 'Katılımcılar';

  @override
  String attendingCount(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n katılıyor',
    );
    return '$_temp0';
  }

  @override
  String attendingViewRsvps(int count) {
    return '$count katılımcı · RSVP\'leri görüntüle';
  }

  @override
  String get back => 'Geri';

  @override
  String get backTooltip => 'Geri';

  @override
  String becauseYouFollowClub(String club) {
    return '$club kulübünü takip ettiğin için';
  }

  @override
  String get bestForYouThisWeek => 'Bu Hafta Senin İçin En İyisi';

  @override
  String get boardMemberFallbackTitle => 'Yönetim Kurulu Üyesi';

  @override
  String get boardMemberLabel => 'Kurul Üyesi';

  @override
  String get boardMembersPublicHint =>
      'Buraya eklenen takipçiler Kurul sekmesinde herkese açık şekilde gösterilir.';

  @override
  String bothInClub(String club) {
    return 'İkiniz de $club kulübündesiniz';
  }

  @override
  String get byContinuingAcknowledge =>
      'Devam ederek şunu kabul etmiş olursun:';

  @override
  String get calEventTypeClass => 'Ders';

  @override
  String get calEventTypeDeadline => 'Son Tarih';

  @override
  String get calEventTypeEvent => 'Etkinlik';

  @override
  String get calEventTypePersonal => 'Kişisel';

  @override
  String get calendarAccessDeniedBody =>
      'Takvim erişimi reddedildi. Etkinlik ekleyebilmek için lütfen şuradan izin ver:\n\nAyarlar → Gizlilik ve Güvenlik → Takvimler';

  @override
  String get calendarAccessDeniedTitle => 'Takvim Erişimi Reddedildi';

  @override
  String get calendarAccessRequestBody =>
      'My Clubs bu etkinliği Takvim uygulamana kaydetmek istiyor.\n\nTakvimin yalnızca seçtiğin etkinlikleri eklemek için kullanılır.';

  @override
  String get calendarAdd => 'Ekle';

  @override
  String get calendarAddEventButton => '+ Etkinlik ekle';

  @override
  String get calendarAddFailedGeneric => 'Etkinlik takvime eklenemedi.';

  @override
  String get calendarAddToPhone => 'Telefona ekle';

  @override
  String get calendarAddedSuccess => 'Etkinlik takvime eklendi!';

  @override
  String get calendarAddedToCalendarButton => '✓ Takvime Eklendi';

  @override
  String get calendarAddedToCalendarSnackbar => 'Etkinlik takvime eklendi';

  @override
  String get calendarAddedToPhone => 'Telefona eklendi';

  @override
  String get calendarAlreadyAdded => 'Takvime eklendi';

  @override
  String get calendarAppleAddFailed => 'Etkinlik Apple Takvimi\'ne eklenemedi.';

  @override
  String get calendarDeleteEventButton => 'Etkinliği sil';

  @override
  String get calendarDeniedBody =>
      'Etkinlikleri telefonuna eşitlemek için lütfen şuradan takvim erişimine izin ver:\n\nAyarlar → Gizlilik ve Güvenlik → Takvimler';

  @override
  String get calendarEditEvent => 'Etkinliği düzenle';

  @override
  String get calendarFilterRsvpd => 'RSVP\'lerim';

  @override
  String calendarItemsCount(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n öğe',
    );
    return '$_temp0';
  }

  @override
  String calendarItemsThisMonth(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Bu ay $n öğe',
    );
    return '$_temp0';
  }

  @override
  String get calendarNewEvent => 'Yeni etkinlik';

  @override
  String get calendarNoWritableCalendar =>
      'Bu cihazda yazılabilir bir takvim bulunamadı.';

  @override
  String get calendarNothingScheduled => 'Planlanmış bir şey yok.';

  @override
  String get calendarPermissionCheckFailed =>
      'Takvim izinleri kontrol edilemedi.';

  @override
  String get calendarPrePermissionBody =>
      'Bu etkinliği telefonundaki Takvim uygulamasına kaydetmek için takvimine erişim iznine ihtiyacımız var.\n\nTakvim verilerin yalnızca seçtiğin etkinlikleri eklemek için kullanılır.';

  @override
  String calendarPreviewLabel(String type) {
    return '$type · Önizleme';
  }

  @override
  String get calendarRsvpdBadge => 'RSVP\'LENDİ';

  @override
  String get calendarYoursTapToEdit => 'Senin · düzenlemek için dokun';

  @override
  String get campusEmailLabel => 'Kampüs e-postası';

  @override
  String get campusEventFallback => 'Kampüs etkinliği';

  @override
  String get campusFallbackLocation => 'Kampüs';

  @override
  String get campusPostFallback => 'Kampüs gönderisi';

  @override
  String campusTodaySummary(String summary) {
    return 'Kampüste bugün: $summary';
  }

  @override
  String get categoryAcademic => 'Akademik';

  @override
  String get categoryArts => 'Sanat';

  @override
  String get categoryBusiness => 'İşletme';

  @override
  String get categoryCareer => 'Kariyer';

  @override
  String get categoryEngineering => 'Mühendislik';

  @override
  String get categoryMusic => 'Müzik';

  @override
  String get categorySocial => 'Sosyal';

  @override
  String get categorySocialImpact => 'Sosyal Etki';

  @override
  String get categorySports => 'Spor';

  @override
  String get categoryTech => 'Teknoloji';

  @override
  String get categoryWellness => 'Sağlıklı Yaşam';

  @override
  String get changeEventPhoto => 'Fotoğrafı değiştir';

  @override
  String get changeLabel => 'Değiştir';

  @override
  String get changePhotoButton => 'Fotoğrafı değiştir';

  @override
  String get checkBackSoonEvents => 'Yeni etkinlikler için yakında tekrar bak.';

  @override
  String get checkYourInboxTitle => 'Gelen kutunu kontrol et.';

  @override
  String get choose6DigitPinHint =>
      '6 haneli bir PIN seç — sadece rakam, harf ya da sembol kullanma.';

  @override
  String get chooseFromLibraryOption => 'Kütüphaneden seç';

  @override
  String get chooseYourLanguage => 'Dilini seç';

  @override
  String get chooseYourLook => 'Görünümünü seç';

  @override
  String get clearSearchTooltip => 'Aramayı temizle';

  @override
  String get clubAdminSignIn => 'Kulüp yöneticisi girişi';

  @override
  String get clubAdminsAddMembersHint =>
      'Kulüp yöneticileri, Kurul üyelerini yönet üzerinden üye ekleyebilir.';

  @override
  String get clubLeaderboard => 'Kulüp Sıralaması';

  @override
  String get clubMembershipLabel => 'Kulüp üyeliği';

  @override
  String clubMentionedYouInPost(String club) {
    return '$club seni bir gönderide etiketledi';
  }

  @override
  String get clubNameAppearsAcrossApp =>
      'Bu ad, kulübünün gösterildiği her yerde uygulama genelinde görünür.';

  @override
  String get clubPhotoRemovedLocallyDeleteFailed =>
      'Kulüp fotoğrafı cihazdan kaldırıldı ama sunucudan silinemedi.';

  @override
  String clubPostedNewEvent(String club, String event) {
    return '$club yeni bir etkinlik paylaştı: $event';
  }

  @override
  String clubRoleSemanticLabel(String role) {
    return 'Kulüp rolü: $role';
  }

  @override
  String clubSharedNewPost(String club) {
    return '$club yeni bir gönderi paylaştı';
  }

  @override
  String clubsCountLabel(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n kulüp',
    );
    return '$_temp0';
  }

  @override
  String clubsCountTitle(int count) {
    return 'KULÜPLER · $count';
  }

  @override
  String clubsInCommonCount(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n ortak kulüp',
    );
    return '$_temp0';
  }

  @override
  String get clubsPickedForYou => 'Senin için seçilen kulüpler';

  @override
  String get collabBadge => 'İşbirliği';

  @override
  String get collabsTab => 'İşbirlikleri';

  @override
  String get completeRequiredFields => 'Lütfen zorunlu alanları doldur.';

  @override
  String confirmRemovalBody(String name, String clubName) {
    return 'Bu işlem $name kişisini $clubName kurulundan kalıcı olarak çıkaracak. Devam edilsin mi?';
  }

  @override
  String get confirmRemovalTitle => 'Kaldırmayı Onayla';

  @override
  String confirmRemoveBoardMemberBody(String name) {
    return '$name kişisini kuruldan çıkarmak istediğinden emin misin?';
  }

  @override
  String get continueButton => 'Devam Et';

  @override
  String continueWithTheme(String theme) {
    return '$theme ile devam et';
  }

  @override
  String get couldNotDeleteEventSupabase =>
      'Etkinlik Supabase\'den silinemedi.';

  @override
  String get couldNotDeletePostSupabase => 'Gönderi Supabase\'den silinemedi.';

  @override
  String get couldNotLoadConnections => 'Bağlantılar yüklenemedi.';

  @override
  String get couldNotLoadInterests =>
      'İlgi alanları yüklenemedi. Lütfen tekrar dene.';

  @override
  String get couldNotLoadPeople => 'Kişiler profillerden yüklenemedi.';

  @override
  String get couldNotLoadProfileOptions =>
      'Profil seçenekleri Supabase\'ten yüklenemedi.';

  @override
  String get couldNotLoadProfileOptionsRetry =>
      'Profil seçenekleri yüklenemedi. Lütfen tekrar dene.';

  @override
  String couldNotOpenLinkedIn(String name) {
    return '$name adlı kişinin LinkedIn\'i açılamadı';
  }

  @override
  String get couldNotOpenPhotoCropper => 'Fotoğraf kırpma aracı açılamadı.';

  @override
  String get couldNotOpenPrivacyPolicy => 'Gizlilik Politikası açılamadı.';

  @override
  String get couldNotOpenRegistrationForm => 'Kayıt formu açılamadı';

  @override
  String get couldNotReachSignupServer =>
      'Kayıt sunucusuna ulaşılamadı. Lütfen tekrar dene.';

  @override
  String get couldNotRemoveClubMember => 'Bu kulüp üyesi kaldırılamadı.';

  @override
  String get couldNotSaveChanges => 'Değişiklikler kaydedilemedi.';

  @override
  String get couldNotSaveEventSupabase => 'Etkinlik Supabase\'e kaydedilemedi.';

  @override
  String get couldNotSaveProfileSupabase => 'Profil Supabase\'e kaydedilemedi';

  @override
  String get couldNotUpdateBoardRole => 'Kurul üyesi rolü güncellenemedi.';

  @override
  String get couldNotUpdateClubDescription =>
      'Kulüp açıklaması güncellenemedi.';

  @override
  String get couldNotUpdateClubFollow => 'Kulüp takibi güncellenemedi.';

  @override
  String get couldNotUpdateClubName => 'Kulüp adı güncellenemedi.';

  @override
  String get couldNotUpdateFollow =>
      'Takip durumu güncellenemedi. Lütfen tekrar dene.';

  @override
  String get couldNotUpdateName => 'Ad güncellenemedi.';

  @override
  String get couldNotUploadClubPhoto => 'Kulüp fotoğrafı yüklenemedi.';

  @override
  String get createAccount => 'Hesap oluştur';

  @override
  String get createPasswordTitle => 'Bir şifre oluştur.';

  @override
  String get createSheetTitle => 'Oluştur';

  @override
  String get createSomethingInspiring => 'İlham verici bir şey oluştur';

  @override
  String get cropPhoto => 'Fotoğrafı Kırp';

  @override
  String get cropPhotoTitle => 'Fotoğrafı Kırp';

  @override
  String currentBoardMembersHeader(int n) {
    return 'Mevcut Kurul Üyeleri ($n)';
  }

  @override
  String get dark => 'Karanlık';

  @override
  String get dateLabel => 'Tarih';

  @override
  String daysAgo(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '${n}g önce',
    );
    return '$_temp0';
  }

  @override
  String daysAgoLong(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n gün önce',
      one: '$n gün önce',
    );
    return '$_temp0';
  }

  @override
  String daysAgoShort(int n) {
    return '${n}g önce';
  }

  @override
  String daysAgoSuffix(int n) {
    return '$n g önce';
  }

  @override
  String daysCount(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n gün',
    );
    return '$_temp0';
  }

  @override
  String daysShort(int n) {
    return '${n}g';
  }

  @override
  String get deleteEventButton => 'Etkinliği Sil';

  @override
  String get deleteEventFromClubMsg =>
      'Bu etkinlik kulübünden kalıcı olarak kaldırılacak.';

  @override
  String get deleteEventMenuItem => 'Etkinliği sil';

  @override
  String deleteEventPermanentWarning(String title) {
    return '\"$title\" ve tüm RSVP verileri kalıcı olarak kaldırılacak. Bu işlem geri alınamaz.';
  }

  @override
  String get deletePostAction => 'Gönderiyi sil';

  @override
  String get deletePostFeedBody => 'Bu gönderi ana akıştan kaldırılacak.';

  @override
  String get deletePostFromClubMsg =>
      'Bu gönderi kulübünden kalıcı olarak kaldırılacak.';

  @override
  String get deletePostMenuItem => 'Gönderiyi sil';

  @override
  String get deleteThisEventConfirm => 'Bu etkinlik silinsin mi?';

  @override
  String descriptionAppearsOnClubProfile(String clubName) {
    return 'Bu açıklama, $clubName profilinde uygulama genelinde görünür.';
  }

  @override
  String get descriptionLabel => 'Açıklama';

  @override
  String get didntGetCode => 'Kod gelmedi mi?';

  @override
  String get discoverClubDescriptionFallback =>
      'Bu kulübün ne hakkında olduğunu keşfet.';

  @override
  String get done => 'Tamam';

  @override
  String get doubleMajorLabel => 'Çift ana dal';

  @override
  String get dowFri => 'Cum';

  @override
  String get dowMon => 'Pzt';

  @override
  String get dowSat => 'Cmt';

  @override
  String get dowSun => 'Paz';

  @override
  String get dowThu => 'Per';

  @override
  String get dowTue => 'Sal';

  @override
  String get dowWed => 'Çar';

  @override
  String get edit => 'Düzenle';

  @override
  String get editClubRoleLabel => 'Kulüp rolünü düzenle';

  @override
  String get editEventButton => 'Etkinliği Düzenle';

  @override
  String get editEventTitle => 'Etkinliği Düzenle';

  @override
  String get endMustBeAfterStartShort => 'Bitiş, başlangıçtan sonra olmalı';

  @override
  String get endTimeAfterStartTime =>
      'Bitiş saati başlangıç saatinden sonra olmalı.';

  @override
  String get endsLabel => 'Bitiş';

  @override
  String get enterEmailAndPassword => 'Lütfen e-postanı ve şifreni gir';

  @override
  String get enterFullSixDigitCode => '6 haneli kodun tamamını gir.';

  @override
  String get eventDescriptionHint =>
      'Bu etkinliğin ne hakkında olduğunu anlat...';

  @override
  String get eventFallbackTitle => 'Etkinlik';

  @override
  String eventInDays(int days) {
    return '$days gün içinde';
  }

  @override
  String get eventLabel => 'Etkinlik';

  @override
  String get eventLinkCopied => 'Etkinlik bağlantısı panoya kopyalandı';

  @override
  String get eventReminderChannelDescription =>
      'Katılacağını belirttiğin etkinlikler için hatırlatmalar';

  @override
  String get eventReminderChannelName => 'Etkinlik hatırlatmaları';

  @override
  String get eventReminderTitle => 'Etkinlik hatırlatması';

  @override
  String eventStartsInOneHour(String title) {
    return '$title 1 saat içinde başlıyor';
  }

  @override
  String eventStartsTomorrow(String title) {
    return '$title yarın başlıyor';
  }

  @override
  String get eventStepBasics => 'Temel Bilgiler';

  @override
  String get eventStepDetails => 'Detaylar';

  @override
  String get eventStepReview => 'Önizleme';

  @override
  String get eventStepWhen => 'Zaman';

  @override
  String get eventTitleHint => 'örn. Bahar Hackathon\'u';

  @override
  String get eventTitleLabel => 'Etkinlik Başlığı';

  @override
  String get eventTitlePlaceholder => 'Etkinlik başlığı';

  @override
  String get eventTitlePreviewPlaceholder => 'Etkinlik başlığı önizlemesi';

  @override
  String get eventViewersTitle => 'Etkinliği Görüntüleyenler';

  @override
  String eventsCount(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n etkinlik',
    );
    return '$_temp0';
  }

  @override
  String eventsCountLabel(int count) {
    return 'Etkinlikler ($count)';
  }

  @override
  String get externalSignupBadge => 'Harici kayıt';

  @override
  String get externalSignupLinkSubtitle =>
      'Katılımcılar kendi formunda kayıt olur (Google Form, Eventbrite…)';

  @override
  String get externalSignupLinkTitle => 'Harici kayıt bağlantısı';

  @override
  String get fallbackNameGreeting => 'arkadaşım';

  @override
  String get feedPreviewHint => 'Ana Akış\'ta böyle görünecek.';

  @override
  String filterQueryLabel(String query) {
    return '· \"$query\"';
  }

  @override
  String get findClubsAction => 'Kulüp bul';

  @override
  String get finishSetupButton => 'Kurulumu tamamla';

  @override
  String get followAll => 'Tümünü takip et';

  @override
  String get followRequestAccepted => 'Takip isteğin kabul edildi.';

  @override
  String followRequestMessage(String name) {
    return '$name seni takip etmek istiyor.';
  }

  @override
  String get followToSeePosts => 'Gönderilerini görmek için takip et.';

  @override
  String get followedClubsTitle => 'Takip edilen kulüpler';

  @override
  String followersAndRsvpsSummary(int followers, int rsvps) {
    return '$followers takipçi · $rsvps RSVP';
  }

  @override
  String followersCountHeader(int n) {
    return 'Takipçiler ($n)';
  }

  @override
  String get followersLoadError => 'Takipçiler yüklenemedi.';

  @override
  String get followingCheckLabel => 'Takip Ediliyor ✓';

  @override
  String followingClubsCount(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n kulübü takip ediyorsun',
      one: '1 kulübü takip ediyorsun',
    );
    return '$_temp0';
  }

  @override
  String get followingFilterLabel => 'takip edilenler';

  @override
  String get forgotPassword => 'Şifreni mi unuttun?';

  @override
  String get fullNameLabel => 'Ad Soyad';

  @override
  String goingCount(int n) {
    return '$n katılacak';
  }

  @override
  String get gotIt => 'Anladım';

  @override
  String get guestName => 'Misafir';

  @override
  String get happeningNow => 'Şu anda gerçekleşiyor';

  @override
  String get happeningNowBadge => 'ŞU ANDA GERÇEKLEŞİYOR';

  @override
  String get happeningNowHeader => 'Şu An Oluyor';

  @override
  String get happeningNowInline => 'Şu an oluyor';

  @override
  String get happeningNowLabel => 'ŞU AN CANLI';

  @override
  String get heroCampusLine1 => 'Kampüsün,';

  @override
  String get heroCampusLine2 => 'cebinde.';

  @override
  String get heroSubtext =>
      'Ders programları, yemekhane, etkinlikler ve Koç Üniversitesi\'ni ev yapan insanlar.';

  @override
  String get highlight => 'Öne çıkar';

  @override
  String get hostedBy => 'DÜZENLEYEN';

  @override
  String hoursAgo(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '${n}sa önce',
    );
    return '$_temp0';
  }

  @override
  String hoursAgoSuffix(int n) {
    return '$n sa önce';
  }

  @override
  String hoursShort(int n) {
    return '${n}sa';
  }

  @override
  String inDaysCount(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n gün sonra',
    );
    return '$_temp0';
  }

  @override
  String inNDays(int days) {
    return '$days gün içinde';
  }

  @override
  String get incorrectEmailOrPassword => 'E-posta veya şifre hatalı';

  @override
  String insightsAcrossEvents(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count etkinlikte',
      zero: 'henüz etkinlik yok',
    );
    return '$_temp0';
  }

  @override
  String insightsAcrossPosts(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gönderide',
      zero: 'henüz gönderi yok',
    );
    return '$_temp0';
  }

  @override
  String get insightsAdminBadge => 'YÖNETİCİ';

  @override
  String get insightsAdminOnlyNote =>
      'Yalnızca kulüp yöneticisi olarak sana görünür.';

  @override
  String get insightsAllTime => 'tüm zamanlar';

  @override
  String get insightsEarlyDaysNote =>
      'Henüz başlangıç — buradaki her şey kulübü kurduğun günden itibaren sayılıyor, yani bu sayılar yalnızca artar.';

  @override
  String get insightsEntrySubtitle =>
      'Takipçiler, katılımlar ve gönderi performansı';

  @override
  String insightsSince(String date) {
    return '$date TARİHİNDEN BERİ';
  }

  @override
  String get insightsTitle => 'İstatistikler';

  @override
  String get insightsTopPostsByViews => 'tüm zamanlar, görüntülemeye göre';

  @override
  String interestMatchCount(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n ilgi alanı eşleşmesi',
      one: '1 ilgi alanı eşleşmesi',
    );
    return '$_temp0';
  }

  @override
  String get justNow => 'Az önce';

  @override
  String get justNowShort => 'az önce';

  @override
  String get kuStudentLabel => 'KU öğrencisi';

  @override
  String get lessLabel => 'gizle';

  @override
  String get letsGoArrow => 'Hadi başlayalım →';

  @override
  String get light => 'Aydınlık';

  @override
  String likesCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n beğeni',
    );
    return '$_temp0';
  }

  @override
  String get linkedinOptionalLabel => 'LinkedIn (isteğe bağlı)';

  @override
  String liveNowCount(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n canlı',
      one: '1 canlı',
    );
    return '$_temp0';
  }

  @override
  String get liveNowFilterLabel => 'şu anda canlı';

  @override
  String liveNowFollowingClub(String club) {
    return 'Şu an canlı · $club kulübünü takip ediyorsun';
  }

  @override
  String get liveNowOnCampus => 'Kampüste şu an canlı';

  @override
  String get loadingConnections => 'Bağlantılar yükleniyor...';

  @override
  String get loadingMajors => 'Bölümler yükleniyor...';

  @override
  String get loadingMembers => 'Üyeler yükleniyor...';

  @override
  String get locationHint => 'Etkinlik konumunu yaz';

  @override
  String get locationLabel => 'Konum';

  @override
  String get locationOptionalLabel => 'Konum (opsiyonel)';

  @override
  String get logIn => 'Giriş yap';

  @override
  String get majorFieldLabel => 'Bölüm';

  @override
  String get majorLabel => 'Bölüm';

  @override
  String get managingBadge => 'YÖNETİLİYOR';

  @override
  String matchesYourInterest(String tag) {
    return '$tag ilgi alanınla eşleşiyor';
  }

  @override
  String memberCountLabel(int n) {
    return '$n üye';
  }

  @override
  String get memberProfilesLoadError => 'Üye profilleri yüklenemedi.';

  @override
  String get memberRoleDefault => 'Üye';

  @override
  String get memberRoleFallback => 'Üye';

  @override
  String get memberRoleLabel => 'Üye';

  @override
  String get members => 'Üyeler';

  @override
  String membersCategoryLabel(num count, String category) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count üye',
    );
    return '$_temp0 · $category';
  }

  @override
  String membersCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count üye',
    );
    return '$_temp0';
  }

  @override
  String membersCountLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count üye',
      one: '1 üye',
    );
    return '$_temp0';
  }

  @override
  String get membersLabel => 'Üyeler';

  @override
  String membersMatchInterests(int count) {
    return '$count üye · ilgi alanlarınla eşleşiyor';
  }

  @override
  String get mentionTypeClub => 'Kulüp';

  @override
  String get mentionTypeStudent => 'Öğrenci';

  @override
  String minorIn(String majors) {
    return 'Yandal: $majors';
  }

  @override
  String get minorLabel => 'Yan dal';

  @override
  String minutesAgo(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '${n}dk önce',
    );
    return '$_temp0';
  }

  @override
  String minutesAgoSuffix(int n) {
    return '$n dk önce';
  }

  @override
  String minutesShort(int n) {
    return '${n}dk';
  }

  @override
  String monthAbbr(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      '1': 'OCA',
      '2': 'ŞUB',
      '3': 'MAR',
      '4': 'NİS',
      '5': 'MAY',
      '6': 'HAZ',
      '7': 'TEM',
      '8': 'AĞU',
      '9': 'EYL',
      '10': 'EKİ',
      '11': 'KAS',
      '12': 'ARA',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get monthApr => 'Nis';

  @override
  String get monthApril => 'Nisan';

  @override
  String get monthAug => 'Ağu';

  @override
  String get monthAugust => 'Ağustos';

  @override
  String get monthDec => 'Ara';

  @override
  String get monthDecember => 'Aralık';

  @override
  String get monthFeb => 'Şub';

  @override
  String get monthFebruary => 'Şubat';

  @override
  String get monthJan => 'Oca';

  @override
  String get monthJanuary => 'Ocak';

  @override
  String get monthJul => 'Tem';

  @override
  String get monthJuly => 'Temmuz';

  @override
  String get monthJun => 'Haz';

  @override
  String get monthJune => 'Haziran';

  @override
  String get monthMar => 'Mar';

  @override
  String get monthMarch => 'Mart';

  @override
  String get monthMay => 'May';

  @override
  String get monthNov => 'Kas';

  @override
  String get monthNovember => 'Kasım';

  @override
  String get monthOct => 'Eki';

  @override
  String get monthOctober => 'Ekim';

  @override
  String get monthSep => 'Eyl';

  @override
  String get monthSeptember => 'Eylül';

  @override
  String get moreLabel => 'devamı';

  @override
  String mutualBadgeCount(String mutualLabel) {
    return '$mutualLabel ortak';
  }

  @override
  String mutualFriendCountLabel(String mutualLabel) {
    return 'Takip ettiklerinden $mutualLabel kişi takip ediyor';
  }

  @override
  String mutualFriendNamed(String name) {
    return '$name takip ediyor';
  }

  @override
  String mutualFriendNamedPlus(String name, int extra) {
    return '$name ve $extra kişi daha takip ediyor';
  }

  @override
  String get myCalendarTitle => 'Takvimim';

  @override
  String get myProfileTitle => 'Profilim';

  @override
  String get newEventTitle => 'Yeni Etkinlik';

  @override
  String get newLabel => 'Yeni';

  @override
  String get newPostTitle => 'Yeni Gönderi';

  @override
  String get newThisWeek => 'BU HAFTA YENİ';

  @override
  String get next => 'İleri';

  @override
  String get nextArrow => 'İleri →';

  @override
  String get nextMonthLabel => '· önümüzdeki ay';

  @override
  String get noBioYet => 'Henüz biyografi yok.';

  @override
  String get noClubsFound => 'Kulüp bulunamadı.';

  @override
  String get noClubsYetShort => 'Henüz kulüp yok.';

  @override
  String get noCollaborationsYet =>
      'Henüz işbirliği yok.\n@ ile bu kulübü etiketleyen gönderiler burada görünecek.';

  @override
  String get noEventImageSelected => 'Etkinlik görseli seçilmedi';

  @override
  String get noFollowedClubsYet => 'Henüz takip edilen kulüp yok.';

  @override
  String get noLikesYet => 'Henüz beğeni yok';

  @override
  String get noLiveEventNow => 'Şu anda canlı bir etkinlik yok.';

  @override
  String get noMatchesFoundDot => 'Eşleşme bulunamadı.';

  @override
  String get noMatchingMajor => 'Eşleşen bölüm yok';

  @override
  String get noMembersToShowYet => 'Henüz gösterilecek üye yok.';

  @override
  String get noNewClubsToSuggest =>
      'Önerecek yeni kulüp yok — zaten bağlantıların güçlü!';

  @override
  String get noPastEventsToShow => 'Gösterilecek geçmiş etkinlik yok.';

  @override
  String get noRepeatedNumbersSideBySide => 'Yan yana aynı rakamlar olmasın';

  @override
  String get noRsvpsYet => 'Henüz RSVP yok.';

  @override
  String get noSavedEventsYet => 'Henüz kaydedilmiş etkinlik yok';

  @override
  String get noSavedPostsYet => 'Henüz kaydedilmiş gönderi yok';

  @override
  String get noSequentialNumbersSideBySide =>
      'Yan yana ardışık rakamlar olmasın';

  @override
  String get noTitleSet => 'Unvan belirlenmedi';

  @override
  String get noViewsYet => 'Henüz görüntülenme yok';

  @override
  String get notComing => 'Gelmiyorum';

  @override
  String get notNow => 'Şimdi Değil';

  @override
  String get nothingHereRightNow => 'Şu anda burada bir şey yok.';

  @override
  String nowFollowingPerson(String name) {
    return 'Artık $name adlı kişiyi takip ediyorsun.';
  }

  @override
  String get nowSegmentLabel => 'Şimdi';

  @override
  String get officialClubLabel => 'Resmi Kulüp';

  @override
  String get oneMutualBadge => '1 ortak';

  @override
  String get oneMutualFriend => 'Takip ettiğin 1 kişi takip ediyor';

  @override
  String get onlyKuAddressesAccepted =>
      'Sadece @ku.edu.tr adresleri kabul edilir.';

  @override
  String get onlyKuEmailInfoText =>
      'Sadece @ku.edu.tr adresleri kabul edilir. Kişisel e-postalar çalışmaz.';

  @override
  String get onlyOwningClubCanDelete =>
      'Bu gönderiyi yalnızca sahibi olan kulüp silebilir.';

  @override
  String get onlyPosterCanViewRsvps =>
      'RSVP\'leri yalnızca etkinliği paylaşan görebilir.';

  @override
  String get openSettingsButton => 'Ayarları Aç';

  @override
  String get optional => 'İsteğe bağlı';

  @override
  String get partnerClubsHeader => 'Ortak Kulüpler';

  @override
  String get passwordFieldLabel => 'Şifre';

  @override
  String get passwordLabel => 'Şifre';

  @override
  String get passwordRulesError =>
      '6 rakam kullan; yan yana tekrar eden veya ardışık rakamlar olmasın.';

  @override
  String get pastBadge => 'GEÇMİŞ';

  @override
  String peopleCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n kişi',
    );
    return '$_temp0';
  }

  @override
  String get peopleYouFollowGoing => 'Takip ettiklerin katılıyor';

  @override
  String percentFull(int pct) {
    return '%$pct dolu';
  }

  @override
  String get photoAdded => 'Fotoğraf eklendi';

  @override
  String get photoLabel => 'Fotoğraf';

  @override
  String get photoRemovedLocallyDeleteFailed =>
      'Fotoğraf cihazdan kaldırıldı ama sunucudan silinemedi.';

  @override
  String get photoSavedLocallyUploadFailed =>
      'Fotoğraf cihazına kaydedildi ama yükleme başarısız oldu.';

  @override
  String get pickAppearanceHint =>
      'Sana uygun görünümü seç. Önizlemek için dokun — istediğin zaman Ayarlar\'dan değiştirebilirsin.';

  @override
  String get pickAsManyInterests =>
      'İstediğin kadar seç. Senin için önemli olanları öne çıkaralım.';

  @override
  String pickAtLeastNInterests(int min) {
    return 'Devam etmek için en az $min tane seç.';
  }

  @override
  String get pickFewMatchHint =>
      'Birkaç tane seç — seni kulüplerle, etkinliklerle ve kişilerle eşleştirelim. ';

  @override
  String get pickLanguageHint =>
      'Uygulama için dil seç. İstediğin zaman Ayarlar\'dan değiştirebilirsin.';

  @override
  String get pinToTop => 'Üste sabitle';

  @override
  String get pleaseEnterFirstLastName => 'Lütfen adını ve soyadını gir.';

  @override
  String get pleaseEnterFullName => 'Lütfen adını gir.';

  @override
  String get pleaseEnterUniversityEmail => 'Lütfen üniversite e-postanı gir.';

  @override
  String get pleasePickMajorFromList => 'Lütfen listeden bir bölüm seç.';

  @override
  String get pleaseSelectMajor => 'Lütfen bölümünü seç.';

  @override
  String get pleaseSelectYear => 'Lütfen yılını seç.';

  @override
  String get popularOnCampus => 'Kampüste popüler';

  @override
  String get postDeletedConfirmation => 'Gönderi silindi';

  @override
  String get postLikes => 'Gönderi beğenileri';

  @override
  String get postLinkCopied => 'Gönderi bağlantısı panoya kopyalandı';

  @override
  String get postViewersTitle => 'Gönderiyi Görüntüleyenler';

  @override
  String get postViews => 'Gönderi görüntülenmeleri';

  @override
  String postingAsClub(String clubName) {
    return '$clubName olarak paylaşıyorsun';
  }

  @override
  String get postingAsLabel => 'Şu olarak paylaşıyorsun';

  @override
  String postsCountLabel(int count) {
    return 'Gönderiler ($count)';
  }

  @override
  String get postsFeaturingClub => 'Bu kulübü etiketleyen gönderiler';

  @override
  String get presidentSecretaryHint => 'örn. Başkan, Sekreter…';

  @override
  String get prioritiseEventsSchedule =>
      'Programına uyan etkinlikleri öne çıkaralım.';

  @override
  String profileLinkCopied(String name) {
    return '$name adlı kullanıcının profil bağlantısı panoya kopyalandı';
  }

  @override
  String get profileUpdated => 'Profil güncellendi';

  @override
  String get programme => 'Program';

  @override
  String get programmeLabel => 'Program';

  @override
  String get programmeSectionSubtitle => 'Etkinliğin için bir program ekle';

  @override
  String get publishErrorGenericEvent =>
      'Etkinlik yayınlanamadı. Supabase ayarlarını kontrol et.';

  @override
  String get publishErrorMigrationEvent =>
      'Etkinlik yayınlanamadı. En son events SQL migration\'ını çalıştır.';

  @override
  String get publishErrorRlsPolicyEvent =>
      'Etkinlik yayınlanamadı. Bu kulüp hesabı için events RLS politikalarını kontrol et.';

  @override
  String get publishErrorStorageEvent =>
      'Etkinlik görseli yüklenemedi. event-images bucket politikalarını kontrol et.';

  @override
  String get publishEventButton => 'Etkinliği Yayınla';

  @override
  String get quickSetupSteps => 'Hızlı kurulum — sadece 4 adım';

  @override
  String get readyToPost => 'Paylaşmaya hazır mısın?';

  @override
  String get recapLabel => 'Özet';

  @override
  String registeredCount(int n) {
    return '$n kayıtlı';
  }

  @override
  String get registration => 'Kayıt';

  @override
  String get registrationLabel => 'Kayıt';

  @override
  String get registrationSectionSubtitle =>
      'Katılımcıları kendi kayıt formuna yönlendir';

  @override
  String get remindMeLabel => 'Hatırlat';

  @override
  String get remindedLabel => 'Hatırlatıldı ✓';

  @override
  String get reminderRemoved => 'Hatırlatıcı kaldırıldı';

  @override
  String get reminderSetMsg =>
      'Hatırlatıcı ayarlandı — başlamadan önce sana haber vereceğiz';

  @override
  String get removeBoardMemberTitle => 'Kurul Üyesini Kaldır';

  @override
  String get removeFromBoardLabel => 'Kuruldan çıkar';

  @override
  String get removeFromClubLabel => 'Kulüpten çıkar';

  @override
  String get removeFromSaved => 'Kaydedilenlerden kaldır';

  @override
  String get removeLabel => 'Kaldır';

  @override
  String get removeRoleLabel => 'Rolü kaldır';

  @override
  String removedFromBoard(String name) {
    return '$name kuruldan çıkarıldı.';
  }

  @override
  String get removedFromSaved => 'Kaydedilenlerden kaldırıldı';

  @override
  String get requested => 'İstek Gönderildi';

  @override
  String get requestedLabel => 'İstek Gönderildi';

  @override
  String get resendCodeButton => 'Kodu tekrar gönder';

  @override
  String resendInTime(String time) {
    return '$time sonra tekrar gönder';
  }

  @override
  String resultsCountLabel(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n sonuç',
    );
    return '$_temp0';
  }

  @override
  String get reviewSectionSubtitle => 'Etkinliğin böyle görünecek';

  @override
  String get roleDeptHint => 'örn. Tarih';

  @override
  String get roleOrDepartmentLabel => 'Rol / bölüm';

  @override
  String rsvpdAt(String timestamp) {
    return '$timestamp tarihinde kayıt oldu';
  }

  @override
  String get rsvpsBadge => 'Kayıtlar';

  @override
  String get rsvpsLabel => 'RSVP\'ler';

  @override
  String get saveChangesButton => 'Değişiklikleri Kaydet';

  @override
  String get savedPostsStudentsOnly =>
      'Kaydedilen gönderiler yalnızca öğrenciler için kullanılabilir.';

  @override
  String get savedPostsTooltip => 'Kaydedilen gönderiler';

  @override
  String get savedTitle => 'Kaydedilenler';

  @override
  String get savedToEvents => 'Etkinliklerine kaydedildi';

  @override
  String get savingEllipsis => 'Kaydediliyor...';

  @override
  String get searchFollowersHint => 'Takipçileri isimle ara...';

  @override
  String get searchMajorsHint => 'Bölüm ara';

  @override
  String get searchYourMajor => 'Bölümünü ara...';

  @override
  String seatsTaken(int taken, int capacity) {
    return '$capacity koltuktan $taken tanesi doldu';
  }

  @override
  String get selectClubHint => 'Kulüp seç';

  @override
  String get selectDoubleMajorHint => 'Bir çift ana dal seç';

  @override
  String get selectMinorHint => 'Bir yan dal seç';

  @override
  String selectedOfMinCount(int selected, int min) {
    return '(en az $min — $selected seçildi)';
  }

  @override
  String get sendCodeToConfirmKocStudent =>
      'Koç öğrencisi olduğunu doğrulamak için bir kod göndereceğiz.';

  @override
  String get sessionTitleRequiredHint => 'Oturum başlığı (zorunlu)';

  @override
  String get setPasswordButton => 'Şifreyi belirle';

  @override
  String setTitleForMember(String name) {
    return '$name için unvan belirle';
  }

  @override
  String get setTitleTooltip => 'Unvan belirle';

  @override
  String get setUp => 'Ayarla';

  @override
  String get shareProfileTooltip => 'Profili paylaş';

  @override
  String get shareUpdateWithFollowers => 'Takipçilerinle bir güncelleme paylaş';

  @override
  String sharesCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n paylaşım',
    );
    return '$_temp0';
  }

  @override
  String showEventsForSelectedDates(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n seçili tarih için etkinlikleri göster',
    );
    return '$_temp0';
  }

  @override
  String get showFullCaptionSemantic => 'Tüm açıklamayı göster';

  @override
  String get showLessCaptionSemantic => 'Açıklamayı daralt';

  @override
  String get showsOnCampusProfile => 'Bu, kampüs profilinde görünür.';

  @override
  String get signUp => 'Kayıt ol';

  @override
  String signUpOnClubForm(String url) {
    return 'Kulübün formundan kaydol · $url';
  }

  @override
  String get signupRequestFailed => 'Kayıt isteği başarısız oldu.';

  @override
  String get signupServerNotConfigured =>
      'Supabase yapılandırılmadı. Uygulamayı SUPABASE_URL ve SUPABASE_PUBLISHABLE_KEY ile başlat.';

  @override
  String get signupUrlLabel => 'Kayıt URL\'si';

  @override
  String get skipSetup => 'Kurulumu atla';

  @override
  String get skipTour => 'Turu atla';

  @override
  String get speakerNameHint => 'örn. Prof. Elif Yıldız';

  @override
  String get speakerNameLabel => 'Konuşmacı adı';

  @override
  String get speakers => 'Konuşmacılar';

  @override
  String get speakersLabel => 'Konuşmacılar';

  @override
  String get speakersSectionSubtitle =>
      'İsteğe bağlı — konuşmacı adı, rolü ve LinkedIn\'ini ekle';

  @override
  String get startExploring => 'Keşfetmeye başla';

  @override
  String get startsLabel => 'Başlangıç';

  @override
  String stepProgressLabel(int current, int total, String title) {
    return 'Adım $current/$total · $title';
  }

  @override
  String get studentFallbackName => 'Bir öğrenci';

  @override
  String get studentIdLabel => 'ÖĞRENCİ KİMLİĞİ';

  @override
  String get studentPasswordMustBe6Digits =>
      'Öğrenci şifresi tam olarak 6 haneli olmalı.';

  @override
  String get studentPasswordRule =>
      'Yan yana tekrar eden veya sıralı olmayan 6 rakam kullan.';

  @override
  String get studentProfileTitle => 'Öğrenci Profili';

  @override
  String get students => 'Öğrenciler';

  @override
  String studentsAreMembersCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count öğrenci üye',
    );
    return '$_temp0';
  }

  @override
  String get subtitleSpeakerOptionalHint =>
      'Alt başlık / konuşmacı (isteğe bağlı)';

  @override
  String get suggestClubsFitField => 'Alanına uygun kulüpler önerelim.';

  @override
  String get tags => 'Etiketler';

  @override
  String get tagsLabel => 'Etiketler';

  @override
  String get tagsSectionSubtitle =>
      'Keşfedilmen için kendi etiketlerini oluştur';

  @override
  String get takePhotoOption => 'Fotoğraf çek';

  @override
  String get tapBookmarkEventHint =>
      'Burada tutmak için herhangi bir etkinlikteki yer imi simgesine dokun.';

  @override
  String get tapBookmarkPostHint =>
      'Burada tutmak için herhangi bir gönderideki yer imi simgesine dokun.';

  @override
  String get tapPublishEventHint =>
      'Bu etkinliği takipçilerinle paylaşmak için Etkinliği Yayınla\'ya dokun.';

  @override
  String get tapSaveChangesHint =>
      'Bu etkinliği güncellemek için Değişiklikleri Kaydet\'e dokun.';

  @override
  String get tapToPickFromCameraOrLibrary =>
      'Kameradan veya kütüphaneden seçmek için dokun';

  @override
  String get tapToPickPhotoHint =>
      'Kameradan veya kütüphaneden seçmek için dokun';

  @override
  String get tellUsAboutYouTitle => 'Bize kendinden bahset.';

  @override
  String get tellUsInterests =>
      'İlgi alanlarını söyle, senin için kişiselleştirelim.';

  @override
  String get templateLabel => 'Şablon';

  @override
  String thisWeekEventsCount(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n bu hafta',
      one: '1 bu hafta',
    );
    return '$_temp0';
  }

  @override
  String get time => 'Saat';

  @override
  String timeAgoDays(int days) {
    return '$days gün önce';
  }

  @override
  String timeAgoHours(int hours) {
    return '$hours sa önce';
  }

  @override
  String timeAgoInDays(int days) {
    return '$days gün sonra';
  }

  @override
  String timeAgoInHours(int hours) {
    return '$hours saat sonra';
  }

  @override
  String get timeAgoJustNow => 'az önce';

  @override
  String timeAgoMinutes(int minutes) {
    return '$minutes dk önce';
  }

  @override
  String get timeAgoSoon => 'yakında';

  @override
  String get titleFieldLabel => 'Başlık';

  @override
  String todayAtTime(String time) {
    return 'Bugün · $time';
  }

  @override
  String todayEventsCount(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n bugün',
      one: '1 bugün',
    );
    return '$_temp0';
  }

  @override
  String get topPosts => 'En popüler gönderiler';

  @override
  String totalCount(int n) {
    return '$n toplam';
  }

  @override
  String get tune => 'Ayarla';

  @override
  String get tutorialDescAlertsClub =>
      'Yeni takipçiler ve etkinlik hareketleri burada toplanır. Bir bildirime dokunarak aç ya da bu butonla hepsini temizle.';

  @override
  String tutorialDescAppearanceReplay(String replayLabel) {
    return 'Dişli simgesi Ayarlar\'ı açar — görünüm ayarları ve bu turu tekrar izlemek istediğinde “$replayLabel” burada.';
  }

  @override
  String get tutorialDescBoardAppearanceReplay =>
      'Dişli simgesi Ayarlar\'ı açar — yönetim kurulu üyesi ekle veya kaldır, görünümü değiştir ve bu turu istediğin zaman tekrar izle.';

  @override
  String get tutorialDescClubProfile =>
      'Bu, kulübünün herkese açık profili. Gönderileri ve etkinlikleri yönetmek için sekmeler arasında geçiş yap — kendi gönderilerinden birini sabitlemek veya silmek için ⋯ menüsüne dokun, ya da kimlerin geleceğini görmek için bir etkinliğin katılımcı sayısına dokun.';

  @override
  String get tutorialDescExploreOwnPace =>
      'Tur burada bitti. Bir daha otomatik olarak açılmayacak — istediğin zaman Profil → Ayarlar\'dan tekrar izleyebilirsin.';

  @override
  String get tutorialDescFeedYourWay =>
      'Ne göreceğini kontrol etmek için Takip Edilenler ve Tümü arasında geçiş yap. Her gönderiden doğrudan beğen, kayıt ol, kaydet ve paylaş.';

  @override
  String get tutorialDescFindPeopleClubs =>
      'Öğrencileri isme veya bölüme göre, kulüpleri de isme göre ara. Kişiler ve Kulüpler arasında geçiş yapmak için üstteki sekmeleri kullan.';

  @override
  String get tutorialDescFiveSections =>
      'Bu çubuk her yerde seninle: Ana Sayfa, Etkinlikler, Ara, Bildirimler ve Profil. Aktif olan kırmızıya döner.';

  @override
  String get tutorialDescFourSections =>
      'Ana Sayfa, Etkinlikler, Bildirimler ve Profil her yerde seninle. Ortadaki buton Ara\'nın yerini alır — paylaşım yapmak için ayrılmıştır.';

  @override
  String get tutorialDescInsights =>
      'Takipçilerinin neye ilgi gösterdiğini bilmek için görüntülenmeleri, beğenileri ve en iyi gönderileri takip et.';

  @override
  String get tutorialDescPostNewEvent =>
      'Etkinlik formunu açmak için istediğin zaman ortadaki butona dokun — başlık, saat, konum ve kitle.';

  @override
  String get tutorialDescQuickTextUpdates =>
      'Bu düzenleyici, kulübünün takipçilerine hızlı bir güncelleme paylaşır — sadece metin içeren bir gönderi için tüm etkinlik formuna gerek yok.';

  @override
  String get tutorialDescRsvpOneTap =>
      'Katılacağını belirtmek için Kayıt Ol\'a dokun — buton “Gidiyorum”a döner ve takvimine eklenebilir. Üstteki arama ve filtrelerle programı düzenle.';

  @override
  String get tutorialDescRunClub =>
      'Kulüp yöneticisi olarak sahip olduğun araçların hızlı bir turu — ilerledikçe sana gerçek butonları göstereceğiz.';

  @override
  String get tutorialDescStayInLoopStudent =>
      'Takipler, kulüp gönderileri ve etkinlik değişiklikleri burada toplanır. Bir bildirime dokunarak aç, çiplerle filtrele ya da bu butonla hepsini temizle.';

  @override
  String get tutorialDescThisIsYou =>
      'Sınıf arkadaşların seni tanısın diye fotoğrafına, adına veya biyografine dokunarak düzenle. Kulüplerin, kayıtların ve istatistiklerin de burada.';

  @override
  String get tutorialDescWelcome =>
      'Uygulamada hızlı, dokunmatik bir tur — ilerledikçe sana gerçek butonları göstereceğiz.';

  @override
  String get tutorialEyebrowCreate => 'Oluştur';

  @override
  String get tutorialEyebrowGettingAround => 'Gezinme';

  @override
  String get tutorialEyebrowInsights => 'İstatistikler';

  @override
  String get tutorialEyebrowWelcome => 'Hoş geldin';

  @override
  String get tutorialEyebrowYourClub => 'Kulübün';

  @override
  String get tutorialEyebrowYoureSet => 'Hazırsın';

  @override
  String get tutorialTipActiveSectionRed => 'Aktif bölüm kırmızıya döner.';

  @override
  String get tutorialTipAddPhotoBiggerPost =>
      'Daha büyük ve daha görünür bir gönderi için fotoğraf ekle.';

  @override
  String get tutorialTipAllMixes => 'Tümü, kampüs önerilerini de karıştırır.';

  @override
  String get tutorialTipBadgeMeansNew =>
      'Çubuktaki bir rozet yeni bir şey olduğu anlamına gelir.';

  @override
  String get tutorialTipBadgesFlag => 'Rozetler yeni etkinlikleri işaret eder.';

  @override
  String get tutorialTipBoardListsMembers =>
      'Yönetim, kulübünün yönetim kurulu üyelerini ve unvanlarını listeler.';

  @override
  String get tutorialTipBoardManagementSettings =>
      'Yönetim kurulu yönetimi, Ayarlar\'da kulübünün bölümü altında bulunur.';

  @override
  String get tutorialTipCollabsJointEvents =>
      'İş Birlikleri, diğer kulüplerle ortak etkinlikleri gösterir.';

  @override
  String get tutorialTipEventShowsUpRightAway =>
      'Etkinliğin, herkes için hemen Etkinlikler\'de görünür.';

  @override
  String get tutorialTipFilterByDate =>
      'Tarihe, kitleye veya şu an canlı olana göre filtrele.';

  @override
  String get tutorialTipFollowJoin =>
      'Sonuçlardan kişileri takip et ve kulüplere katıl.';

  @override
  String get tutorialTipFollowersFollowing =>
      'Kimin kim olduğunu görmek için Takipçiler / Takip Edilenler\'e dokun.';

  @override
  String get tutorialTipFollowingShows =>
      'Takip Edilenler sadece takip ettiğin kulüpleri gösterir.';

  @override
  String get tutorialTipFollowsRsvpsSaves =>
      'Takiplerin, kayıtların ve kaydettiklerin uygulamayı senin için kişiselleştirir.';

  @override
  String get tutorialTipHomeFeed =>
      'Ana Sayfa senin kişiselleştirilmiş akışın.';

  @override
  String get tutorialTipOpenEventDetails =>
      'Tüm ayrıntılar için herhangi bir etkinliği aç.';

  @override
  String get tutorialTipOpenProfileBeforeFollow =>
      'Takip etmeden önce profili aç.';

  @override
  String get tutorialTipOpeningClearsBadge =>
      'Bu sekmeyi açmak rozeti temizler.';

  @override
  String get tutorialTipSkipTour => 'Turu atla seçeneği her zaman sağ üstte.';

  @override
  String get tutorialTipSwitchLightDark =>
      'Burada aydınlık ve karanlık mod arasında geçiş yap.';

  @override
  String get tutorialTipTapNext =>
      'İlerlemek için İleri\'ye ya da herhangi bir yere dokun.';

  @override
  String get tutorialTipUpNextEvent =>
      '“Sıradaki” etkinliğin bir dokunuş uzağında.';

  @override
  String get tutorialTipUseBack =>
      'Bir adımı tekrar görmek için Geri\'yi kullan.';

  @override
  String get tutorialTitleAppearanceReplay => 'Görünüm ve turu tekrar izle';

  @override
  String get tutorialTitleBoardAppearanceReplay =>
      'Yönetim kurulu, görünüm ve turu tekrar izle';

  @override
  String get tutorialTitleExploreOwnPace => 'Kendi hızında keşfet';

  @override
  String get tutorialTitleFeedYourWay => 'Akışın, senin tarzında';

  @override
  String get tutorialTitleFindPeopleClubs => 'Kişileri ve kulüpleri bul';

  @override
  String get tutorialTitleFiveSections => 'Beş bölümün';

  @override
  String get tutorialTitleFourSections => 'Dört bölümün';

  @override
  String get tutorialTitlePostNewEvent => 'Yeni bir etkinlik paylaş';

  @override
  String get tutorialTitlePostsEventsCollabsBoard =>
      'Gönderiler, Etkinlikler, İş Birlikleri, Yönetim';

  @override
  String get tutorialTitleQuickTextUpdates => 'Hızlı metin güncellemeleri';

  @override
  String get tutorialTitleRsvpOneTap => 'Tek dokunuşla kayıt ol';

  @override
  String get tutorialTitleRunClubFromHere => 'Kulübünü buradan yönet';

  @override
  String get tutorialTitleRunClubOwnPace => 'Kulübünü kendi hızında yönet';

  @override
  String get tutorialTitleSeeWhatsLanding => 'Neyin ilgi gördüğünü gör';

  @override
  String get tutorialTitleStayInLoop => 'Her şeyden haberdar ol';

  @override
  String get tutorialTitleThisIsYou => 'İşte sen';

  @override
  String get tutorialTitleYourCampus => 'Kampüsün, tek bir yerde';

  @override
  String get typeAtToTagHint =>
      'Bir kulübü veya öğrenciyi etiketlemek için @ yaz';

  @override
  String get typeLabel => 'Tür';

  @override
  String unfollowedPerson(String name) {
    return '$name adlı kişiyi takipten çıkardın.';
  }

  @override
  String get universityEmailLabel => 'Üniversite e-postası';

  @override
  String get universityYearLabel => 'Üniversite yılı';

  @override
  String get unknownUser => 'Bilinmeyen Kullanıcı';

  @override
  String unopenedEventsCount(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n okunmamış etkinlik',
    );
    return '$_temp0';
  }

  @override
  String get unpinFromTop => 'Üstten kaldır';

  @override
  String get untitledLabel => 'Başlıksız';

  @override
  String get upcomingBadge => 'YAKLAŞAN';

  @override
  String get upcomingSegmentLabel => 'Yaklaşan';

  @override
  String get updateYourCommunity => 'Topluluğunu güncelle';

  @override
  String get verifyButton => 'Doğrula';

  @override
  String get view => 'Görüntüle';

  @override
  String get viewChevron => 'Görüntüle ›';

  @override
  String get viewLabel => 'Görüntüle';

  @override
  String get viewProfileLabel => 'Profili görüntüle';

  @override
  String viewsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n görüntülenme',
    );
    return '$_temp0';
  }

  @override
  String get weSentCodeToPrefix => '6 haneli kod şu adrese gönderildi:\n';

  @override
  String weeksAgo(int n) {
    return '${n}hf önce';
  }

  @override
  String weeksShort(int n) {
    return '${n}hf';
  }

  @override
  String get welcomeBackCampusHighlight => 'kampüsüne';

  @override
  String get welcomeBackToYourPrefix => 'Tekrar hoş geldin\n';

  @override
  String get welcomeToKoc => 'KOÇ\'A HOŞ GELDİN';

  @override
  String get whatAreYouInto => 'Neyle ilgileniyorsun?';

  @override
  String get whatsHappeningHint => 'Ne oluyor?';

  @override
  String get whatsYourMajor => 'Bölümün ne?';

  @override
  String get whatsYourScene => 'Senin tarzın ne?';

  @override
  String get whatsYourSchoolEmail => 'Okul e-postan\nnedir?';

  @override
  String whenClubPostsHint(String clubName) {
    return '$clubName paylaşım yaptığında burada görünecek.';
  }

  @override
  String get whenDoYouHaveTime => 'Genellikle ne zaman vaktin oluyor?';

  @override
  String get whenSectionSubtitle =>
      'Etkinliğinin başlangıç ve bitiş zamanını ayarla';

  @override
  String get whereHint => 'Nerede?';

  @override
  String get writeForClubMembersHint => 'Kulüp üyelerin için bir şeyler yaz…';

  @override
  String get yesRemoveLabel => 'Evet, Kaldır';

  @override
  String get youMayKnowThemKuStudent =>
      'Onları tanıyor olabilirsin · KU öğrencisi';

  @override
  String get youMightLike => 'Beğenebilirsin';

  @override
  String get yourClubFallback => 'Kulübün';

  @override
  String get yourEmailFallback => 'e-postan';

  @override
  String get yourKuDay => 'Senin KU Günün';

  @override
  String get youreGoing => 'Katılıyorsun';

  @override
  String get signInToContinueSubtitle =>
      'Kaldığın yerden devam etmek için giriş yap.';

  @override
  String get kocUniversityWordmark => 'KOÇ ÜNİVERSİTESİ';

  @override
  String get usernameHint => 'adınız';

  @override
  String get newToKocUniversity => 'Koç Üniversitesi\'nde yeni misin?';

  @override
  String get runningAClub => 'Bir kulüp mü yönetiyorsun?';

  @override
  String get fullNameExampleHint => 'örn. Ali Yılmaz';

  @override
  String get couldNotUseCamera =>
      'Kamera kullanılamadı. Kamera erişimini kontrol edip tekrar dene.';

  @override
  String youreInName(String name) {
    return 'Aramıza katıldın,\n$name.';
  }

  @override
  String get markAllRead => 'Tümünü okundu işaretle';

  @override
  String get clubRolePresident => 'Başkan';

  @override
  String get clubRoleVicePresident => 'Başkan Yardımcısı';

  @override
  String get clubRoleFounder => 'Kurucu';

  @override
  String get clubRoleCoFounder => 'Eş Kurucu';

  @override
  String get clubRoleSecretary => 'Sekreter';

  @override
  String get clubRoleTreasurer => 'Sayman';

  @override
  String get clubRoleCoordinator => 'Koordinatör';

  @override
  String get clubRoleChair => 'Başkan';

  @override
  String get clubRoleViceChair => 'Başkan Vekili';

  @override
  String get clubRoleTeamLead => 'Ekip Lideri';

  @override
  String get followRequests => 'Takip istekleri';

  @override
  String plusOthersCount(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '+ $n kişi daha',
      one: '+ 1 kişi daha',
    );
    return '$_temp0';
  }

  @override
  String get notifGroupNew => 'YENİ';

  @override
  String get notifGroupToday => 'BUGÜN';

  @override
  String get notifGroupThisWeek => 'BU HAFTA';

  @override
  String get notifGroupThisMonth => 'BU AY';

  @override
  String get notifGroupEarlier => 'DAHA ÖNCE';

  @override
  String get updatedJustNow => 'Az önce güncellendi';

  @override
  String get notificationsAutoCleared =>
      '30 günden eski bildirimler otomatik olarak temizlenir';

  @override
  String get updateRequiredTitle => 'Güncelleme gerekli';

  @override
  String get updateRequiredMessage =>
      'Uygulamayı kullanmaya devam etmek için ClubUp\'ı güncelleyin.';

  @override
  String get updateRequiredButton => 'Şimdi güncelle';

  @override
  String get updateRequiredRetry => 'Tekrar kontrol et';

  @override
  String get updateRequiredStoreError =>
      'Uygulama mağazası açılamadı. ClubUp\'ı mağazadan güncelledikten sonra tekrar deneyin.';

  @override
  String get eventsAndActivities => 'Etkinlikler ve aktiviteler';

  @override
  String get activityTitle => 'Aktivite';

  @override
  String get activityOwnerSubtitle => 'Herkese açık profilinde görünür';

  @override
  String activityVisitorSubtitle(String name) {
    return '$name adlı kişinin kampüs etkinlik geçmişi';
  }

  @override
  String activityOtherTitle(String name) {
    return '$name adlı kişinin aktivitesi';
  }

  @override
  String activitySeeAllCount(int count) {
    return '$count etkinliğin tümü';
  }

  @override
  String get activityViewFullHistory => 'Tüm geçmişi gör';

  @override
  String get activityFilterAll => 'Tümü';

  @override
  String get activityFilterUpcoming => 'Yaklaşan';

  @override
  String get activityFilterPast => 'Geçmiş';

  @override
  String activityGoingSection(int count) {
    return 'Gidiyor · $count';
  }

  @override
  String activityPastSection(int count) {
    return 'Katıldı · $count';
  }

  @override
  String get activityGoingBadge => 'Gidiyor';

  @override
  String get activityLiveBadge => 'Şu anda';

  @override
  String get activityAttendedBadge => 'Katıldı';

  @override
  String get activityUnconfirmedBadge => 'Okutulmadı';

  @override
  String get activityStatAttended => 'Katıldı';

  @override
  String get activityStatUpcoming => 'Yaklaşan';

  @override
  String get activityStatClubs => 'Kulüp';

  @override
  String get activityCheckinFootnote => 'Katılım, etkinlik girişinde onaylanır';

  @override
  String activityEventCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count etkinlik',
      one: '1 etkinlik',
      zero: 'Etkinlik yok',
    );
    return '$_temp0';
  }

  @override
  String activityAcademicYear(String label) {
    return '$label akademik yılı';
  }

  @override
  String get activityEmptyTitle => 'Henüz etkinlik yok';

  @override
  String get activityEmptyBody =>
      'Bir kampüs etkinliğine katılacağını belirt; gideceğin ve katıldığın her şeyin kaydı burada birikir.';

  @override
  String activityEmptyBodyVisitor(String name) {
    return '$name henüz hiçbir kampüs etkinliğine katılmadı.';
  }

  @override
  String get activityBrowseEvents => 'Bu haftanın etkinliklerine göz at';

  @override
  String get activityNoUpcoming => 'Yaklaşan bir şey yok';

  @override
  String get activityNoUpcomingBody =>
      'Katılacağını belirttiğin etkinlikler, gerçekleşmeden önce burada görünür.';

  @override
  String get activityNoPast => 'Henüz geçmiş yok';

  @override
  String get activityNoPastBody =>
      'Etkinlikler sona erdiğinde geçmişine eklenir.';

  @override
  String activityShareSummary(String name, int attended, int upcoming) {
    return '$name · ClubUp\'ta $attended etkinliğe katıldı, $upcoming etkinliği yaklaşıyor';
  }

  @override
  String get activitySummaryCopied => 'Aktivite özeti kopyalandı';

  @override
  String get activityShareTooltip => 'Aktiviteyi paylaş';
}
