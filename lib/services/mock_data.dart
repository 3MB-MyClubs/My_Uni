import '../models/user.dart';
import '../models/club.dart';
import '../models/event.dart';
import '../models/news_post.dart';
import '../models/comment.dart';
import '../models/like.dart';
import '../models/share.dart';
import '../models/subscription.dart';
import '../models/notification.dart';
import '../models/app_admin.dart';
import '../models/message.dart';
import '../models/board_member_request.dart';

// ─── Users ────────────────────────────────────────────────────────────────────

final users = [
  User(id: 'u1',  name: 'Alice Yılmaz',   email: 'alice@ku.edu.tr',      password: 'alice123',  role: 'student', subscribedClubIds: ['c4', 'c13', 'c35'],                    followingUserIds: ['u2', 'u4', 'u5']),
  User(id: 'u2',  name: 'Can Serbester',  email: 'can@ku.edu.tr',        password: 'can123',    role: 'student', subscribedClubIds: ['c4', 'c28', 'c15', 'c36'],              followingUserIds: ['u1', 'u4']),
  User(id: 'u3',  name: 'Emir Karaarslan',email: 'emir@ku.edu.tr',       password: 'emir123',  role: 'student', subscribedClubIds: ['c27', 'c28', 'c29'],                    followingUserIds: ['u1', 'u2', 'u7']),
  User(id: 'u4',  name: 'Deniz Kaya',     email: 'deniz@ku.edu.tr',      password: 'deniz123',  role: 'student', subscribedClubIds: ['c13', 'c15', 'c34'],                    followingUserIds: ['u1', 'u3', 'u8']),
  User(id: 'u5',  name: 'Hakan Tuncay',   email: 'htuncay23@ku.edu.tr',  password: '',          role: 'student', subscribedClubIds: ['c4', 'c22'],                            followingUserIds: ['u1', 'u2', 'u3', 'u4']),
  User(id: 'u6',  name: 'Elif Şahin',     email: 'esahin@ku.edu.tr',     password: 'elif123',   role: 'student', subscribedClubIds: ['c1', 'c3', 'c9', 'c10', 'c34'],         followingUserIds: ['u10', 'u12']),
  User(id: 'u7',  name: 'Murat Özdemir',  email: 'mozdemir@ku.edu.tr',   password: 'murat123',  role: 'student', subscribedClubIds: ['c2', 'c3', 'c25', 'c37', 'c40'],        followingUserIds: ['u3', 'u9', 'u13']),
  User(id: 'u8',  name: 'Selin Yıldız',   email: 'syildiz@ku.edu.tr',    password: 'selin123',  role: 'student', subscribedClubIds: ['c6', 'c12', 'c29', 'c39', 'c41'],       followingUserIds: ['u4', 'u6', 'u14']),
  User(id: 'u9',  name: 'Ahmet Korkmaz',  email: 'akorkmaz@ku.edu.tr',   password: 'ahmet123',  role: 'student', subscribedClubIds: ['c7', 'c8', 'c15', 'c18', 'c32'],        followingUserIds: ['u7', 'u15']),
  User(id: 'u10', name: 'Zeynep Aktaş',   email: 'zaktas@ku.edu.tr',     password: 'zeynep123', role: 'student', subscribedClubIds: ['c3', 'c10', 'c14', 'c17', 'c33'],       followingUserIds: ['u6', 'u11']),
  User(id: 'u11', name: 'Yunuscan Doğan', email: 'ydogan@ku.edu.tr',     password: 'kemal123',  role: 'student', subscribedClubIds: ['c5', 'c11', 'c22', 'c23', 'c36'],       followingUserIds: ['u5', 'u9', 'u15']),
  User(id: 'u12', name: 'Ayşe Çelik',     email: 'acelik@ku.edu.tr',     password: 'ayse123',   role: 'student', subscribedClubIds: ['c16', 'c19', 'c20', 'c21', 'c30', 'c38'], followingUserIds: ['u6', 'u8', 'u13']),
  User(id: 'u13', name: 'Emre Doğan',     email: 'edogan@ku.edu.tr',     password: 'emre123',   role: 'student', subscribedClubIds: ['c22', 'c24', 'c26', 'c28', 'c33'],      followingUserIds: ['u7', 'u12', 'u14']),
  User(id: 'u14', name: 'Leyla Kaplan',   email: 'lkaplan@ku.edu.tr',    password: 'leyla123',  role: 'student', subscribedClubIds: ['c6', 'c8', 'c27', 'c31', 'c41'],        followingUserIds: ['u8', 'u13']),
  User(id: 'u15', name: 'Serkan Yılmaz',  email: 'syilmaz@ku.edu.tr',    password: 'serkan123', role: 'student', subscribedClubIds: ['c4', 'c7', 'c11', 'c21', 'c26'],        followingUserIds: ['u9', 'u11']),
];

// ─── Clubs ────────────────────────────────────────────────────────────────────

final clubs = [
  Club(id: 'c1',  name: 'Arkeoloji ve Sanat Tarihi Kulübü (KUARHA)', description: 'Exploring Koç University\'s rich history through archaeology, art history exhibitions and site visits across Turkey.',          adminUserIds: []),
  Club(id: 'c2',  name: 'Atatürkçü Düşünce Kulübü (KUADK)',          description: 'Promoting Atatürk\'s principles and the ideals of the Turkish Republic through talks, panels and cultural events.',            adminUserIds: []),
  Club(id: 'c3',  name: 'Beşeri Bilimler Kulübü (KUBBE)',            description: 'Bringing together students passionate about literature, philosophy, history and the humanities for seminars and reading groups.',  adminUserIds: []),
  Club(id: 'c4',  name: 'Bilgisayar Kulübü (KUACM)',                 description: 'Hackathons, coding workshops, tech talks and open-source projects. Open to all skill levels — from beginner to pro.',            adminUserIds: ['u1']),
  Club(id: 'c5',  name: 'Dağcılık Kulübü (KUDAK)',                   description: 'Weekend hikes, technical climbing courses and multi-day expeditions to mountains across Turkey and beyond.',                      adminUserIds: []),
  Club(id: 'c6',  name: 'Dans Kulübü (KUDans)',                      description: 'Salsa, hip-hop, contemporary and traditional dances — performances, workshops and weekly practice sessions for everyone.',        adminUserIds: []),
  Club(id: 'c7',  name: 'Ekonomi Kulübü',                            description: 'Economics talks, case competitions, finance workshops and networking events with industry professionals.',                        adminUserIds: []),
  Club(id: 'c8',  name: 'Ekonomi ve Politika Kulübü (EkoPolitik)',   description: 'At the intersection of economics and politics — panel discussions, policy briefings and guest speaker events.',                   adminUserIds: []),
  Club(id: 'c9',  name: 'Ebru Kulübü',                               description: 'Learn the traditional Turkish art of marbling. Weekly sessions in our fully equipped studio with all materials provided.',       adminUserIds: []),
  Club(id: 'c10', name: 'Felsefe Topluluğu',                         description: 'Philosophy reading groups, Socratic circles, and lectures covering continental and analytic traditions.',                        adminUserIds: []),
  Club(id: 'c11', name: 'Fenerbahçeliler Topluluğu',                 description: 'The official Fenerbahçe supporter community at Koç — match screenings, fan events and friendly debates.',                       adminUserIds: []),
  Club(id: 'c12', name: 'Folklör Kulübü',                            description: 'Keeping Turkish folk dance traditions alive through regular rehearsals, costumes and performances at campus events.',             adminUserIds: []),
  Club(id: 'c13', name: 'Fotoğraf Kulübü (KUFoto)',                  description: 'Campus photo walks, darkroom sessions, editing workshops and an annual exhibition showcasing student photography.',              adminUserIds: ['u4']),
  Club(id: 'c14', name: 'Endüstri Mühendisliği Kulübü (IES)',        description: 'Tabletop RPG sessions, world-building, character creation and story-driven campaigns every week.',                               adminUserIds: []),
  Club(id: 'c15', name: 'Girişimcilik Kulübü',                       description: 'Entrepreneurship workshops, startup pitch events, mentorship programs and connections with the Koç innovation ecosystem.',       adminUserIds: []),
  Club(id: 'c16', name: 'Hemşirelik Kulübü',                         description: 'Supporting nursing students with study groups, clinical preparation resources and community health awareness campaigns.',          adminUserIds: []),
  Club(id: 'c17', name: 'Hukuk Kulübü',                              description: 'Moot court competitions, legal seminars, guest lawyer talks and support for students interested in law careers.',                adminUserIds: []),
  Club(id: 'c18', name: 'İşletme Kulübü',                            description: 'Business case competitions, corporate talks, CV and interview workshops and networking with KU alumni in business.',             adminUserIds: []),
  Club(id: 'c19', name: 'Kadın Dayanışma Kulübü',                    description: 'Promoting gender equality and women\'s rights through awareness campaigns, workshops and community support initiatives.',         adminUserIds: []),
  Club(id: 'c20', name: 'Kadın Mühendisler Kulübü (KUSWE)',          description: 'Empowering women in STEM — mentorship, industry visits, career panels and an annual Women in Engineering summit.',               adminUserIds: []),
  Club(id: 'c21', name: 'Kimya Biyoloji Mühendisliği Kulübü (AIChE)',description: 'Chemical and biological engineering talks, lab tours, AIChE chapter competitions and career development sessions.',             adminUserIds: []),
  Club(id: 'c22', name: 'KU Gönüllüleri',                            description: 'Volunteering at schools, hospitals, animal shelters and environmental projects — making a difference in the community.',         adminUserIds: []),
  Club(id: 'c23', name: 'KU Kartalları Kulübü',                      description: 'The official Koç University sports fan community — supporting all KU teams across every league and tournament.',                adminUserIds: []),
  Club(id: 'c24', name: 'Kuir Kulübü',                               description: 'A safe and supportive community for LGBTQ+ students at Koç — events, discussions and solidarity initiatives.',                  adminUserIds: []),
  Club(id: 'c25', name: 'Kürt Dili Kulübü',                          description: 'Celebrating Kurdish language and culture through language classes, cultural nights, music and literature events.',               adminUserIds: []),
  Club(id: 'c26', name: 'Makine Mühendisliği Topluluğu (KUMech)',    description: 'Robot design competitions, mechanical workshops, industry visits and career support for mechanical engineering students.',        adminUserIds: []),
  Club(id: 'c27', name: 'Münazara Kulübü',                           description: 'British Parliamentary and Oxford-style debates, public speaking training and inter-university tournament participation.',          adminUserIds: []),
  Club(id: 'c28', name: 'Müzik Kulübü (KÜMK)',                       description: 'Weekly jam sessions, open mic nights, recording studio access and live performances for musicians of all genres.',               adminUserIds: []),
  Club(id: 'c29', name: 'Müzikal Kulübü',                            description: 'Full-scale musical theatre productions — acting, singing, dancing and stage management, open to all students.',                  adminUserIds: []),
  Club(id: 'c30', name: 'Nörolojik Bilimler Topluluğu (KU-SIGN)',    description: 'Neuroscience seminars, brain awareness campaigns, research talks and clinical shadowing opportunities for students.',            adminUserIds: []),
  Club(id: 'c31', name: 'Orkestra Kulübü',                           description: 'A full student orchestra performing classical and contemporary pieces, with weekly rehearsals and semester concerts.',             adminUserIds: []),
  Club(id: 'c32', name: 'Pazarlama Kulübü',                          description: 'Marketing case studies, brand strategy workshops, social media campaigns and connections with leading marketing professionals.',   adminUserIds: []),
  Club(id: 'c33', name: 'Radyo Kulübü',                              description: 'Student-run radio shows, podcast production, DJ workshops and live broadcasting from the KU campus studio.',                    adminUserIds: []),
  Club(id: 'c34', name: 'Resim Kulübü',                              description: 'Painting, drawing, watercolour and mixed media workshops with a semester-end gallery exhibition on campus.',                     adminUserIds: []),
  Club(id: 'c35', name: 'Sinema Kulübü',                             description: 'Weekly film screenings, director retrospectives, short film productions and a campus film festival every spring.',              adminUserIds: []),
  Club(id: 'c36', name: 'Sosyal Aktiviteler Kulübü',                 description: 'Campus events, game nights, trips, social mixers — connecting students across faculties and creating lasting friendships.',       adminUserIds: []),
  Club(id: 'c37', name: 'Tarih Kulübü',                              description: 'Historical seminars, documentary screenings, debates on key events and trips to historical sites in Turkey.',                    adminUserIds: []),
  Club(id: 'c38', name: 'Tıp Öğrencileri Birliği (KUTÖB)',           description: 'Supporting medical students through study groups, clinical skill workshops, research support and USMLE preparation.',            adminUserIds: []),
  Club(id: 'c39', name: 'Tiyatro Kulübü',                            description: 'Full theatrical productions, acting workshops, improvisation sessions and annual performances on the KU stage.',                 adminUserIds: []),
  Club(id: 'c40', name: 'Türk Araştırmaları Topluluğu',              description: 'Research and discussion on Turkish history, culture, foreign policy and contemporary issues through seminars and publications.',  adminUserIds: []),
  Club(id: 'c41', name: 'Türk Halk Müziği Kulübü (THM)',             description: 'Preserving Turkish folk music with saz sessions, folk song rehearsals and performances at campus and community events.',         adminUserIds: []),
  Club(id: 'c42', name: 'HAKANS_CLUB',                               description: 'Hakan\'s personal club.',                                                                                                           adminUserIds: ['cadmin1']),
];


// ─── Board Member Requests ────────────────────────────────────────────────────

/// All board-member applications, past and present.
/// Persisted via ContentStore; starts empty (no seed requests needed).
final boardMemberRequests = <BoardMemberRequest>[];

// ─── Events ───────────────────────────────────────────────────────────────────

final events = [
  Event(id: 'ev0a', clubId: 'c28', title: 'Jazz Jam Session',              description: 'Drop-in jazz jam happening right now in SOS B Atelier. All instruments welcome. Come play or just listen!',                                                                                                                                             location: 'SOS B Atelier',            dateTime: DateTime.now().subtract(const Duration(minutes: 30)), endTime: DateTime.now().add(const Duration(hours: 2)),             attendeeUserIds: ['u1', 'u3', 'u5']),
  Event(id: 'ev0b', clubId: 'c39', title: 'Doğaçlama Tiyatro Gecesi',     description: 'Improv theatre night in full swing — walk in anytime, no ticket needed.',                                                                                                                                                                                         location: 'SOS B206',                 dateTime: DateTime.now().subtract(const Duration(hours: 1)),    endTime: DateTime.now().add(const Duration(hours: 1, minutes: 30)), attendeeUserIds: ['u2', 'u4']),
  Event(id: 'ev1',  clubId: 'c4',  title: 'Hack-KU 2025',                 description: 'Our annual 48-hour hackathon is back! Form teams of up to 4, pick a challenge track and build something amazing. Prizes, mentors and free food all weekend. All skill levels welcome!',                                                                          location: 'ENG Building, Main Hall',  dateTime: DateTime.now().add(const Duration(days: 5)),           endTime: DateTime.now().add(const Duration(days: 7)),              attendeeUserIds: ['u2', 'u4']),
  Event(id: 'ev2',  clubId: 'c13', title: 'Bahar Fotoğraf Sergisi',       description: 'Submit up to three prints for our spring gallery. Landscape, portrait, street — all genres accepted. Selected works will be displayed in the SOS atrium for two weeks.',                                                                                          location: 'SOS Atrium Gallery',       dateTime: DateTime.now().add(const Duration(days: 8)),           endTime: DateTime.now().add(const Duration(days: 8, hours: 4)),    attendeeUserIds: ['u1', 'u4']),
  Event(id: 'ev3',  clubId: 'c5',  title: 'Uludağ Kış Tırmanışı',        description: 'A two-day winter ascent of Uludağ with certified guides. Equipment rental available. Limited to 12 participants — sign up fast.',                                                                                                                                location: 'Uludağ, Bursa (departure from KU main gate)', dateTime: DateTime.now().add(const Duration(days: 14)), endTime: DateTime.now().add(const Duration(days: 16)), attendeeUserIds: ['u1', 'u2', 'u3']),
  Event(id: 'ev4',  clubId: 'c27', title: 'Üniversitelerarası Münazara',  description: 'Koç University hosts this year\'s inter-university debate championship. Motion: "This house believes AI will make democratic elections obsolete." Come watch or compete!',                                                                                         location: 'SOS B140 Amphitheatre',    dateTime: DateTime.now().add(const Duration(days: 10)),          endTime: DateTime.now().add(const Duration(days: 10, hours: 3)),   attendeeUserIds: ['u3']),
  Event(id: 'ev5',  clubId: 'c28', title: 'Open Mic Night',               description: 'Sign up to perform or come and enjoy live music by fellow students. Guitar, piano, vocals, beat-box — everything welcome. Doors open at 8 PM.',                                                                                                                   location: 'SOS B Atelier',            dateTime: DateTime.now().add(const Duration(days: 3)),           endTime: DateTime.now().add(const Duration(days: 3, hours: 3)),    attendeeUserIds: ['u2', 'u4']),
];

// ─── News Posts ───────────────────────────────────────────────────────────────

final newsPosts = [
  // ── Existing posts ──────────────────────────────────────────────────────────
  NewsPost(id: 'n1',  clubId: 'c4',  authorId: 'u1', title: 'KUACM\'ye Hoş Geldiniz!',                   content: 'New semester, new challenges! We\'re launching weekly coding workshops every Tuesday at 6 PM and our flagship hackathon Hack-KU 2025 is just around the corner. Whether you\'re a first-year curious about programming or a senior working on your thesis — you belong here. 💻',             createdAt: DateTime.now().subtract(const Duration(hours: 2))),
  NewsPost(id: 'n2',  clubId: 'c13', authorId: 'u4', title: 'Bahar Sergisi Başvuruları Açıldı',          content: 'The deadline for our Spring Photo Exhibition is next Friday. Digital submissions of print-ready files only (min. 300 dpi). One to three works per member. This is your chance to show the Koç community how you see the world through your lens! 📷',                                         createdAt: DateTime.now().subtract(const Duration(hours: 5))),
  NewsPost(id: 'n3',  clubId: 'c5',  authorId: 'u2', title: 'Yeni Ekipmanlarımız Geldi!',                content: 'We just received a full set of Black Diamond climbing gear, ice axes and crampons for our winter expeditions. Equipment is available for member rental at the club room every Monday and Wednesday afternoon. Uludağ trip gear list will be posted this week. ⛰️',                              createdAt: DateTime.now().subtract(const Duration(days: 1))),
  NewsPost(id: 'n4',  clubId: 'c28', authorId: 'u3', title: 'Open Mic — Kayıtlar Açık!',                 content: 'Spots are filling fast for this Friday\'s Open Mic Night. Singers, guitarists, pianists, poets and beatboxers — all welcome. Sign up at the club room or DM us here. Show time is 8 PM, soundcheck at 7. Free entry for everyone! 🎶',                                                       createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 3))),
  NewsPost(id: 'n5',  clubId: 'c27', authorId: 'u3', title: 'Bölge Şampiyonasını Kazandık! 🏆',          content: 'We are incredibly proud of our team who took first place at the Regional Debate Championship last weekend with a unanimous panel decision. Special congratulations to Ceren and Deniz for their outstanding speeches. We are going to nationals — see you in Ankara!',                          createdAt: DateTime.now().subtract(const Duration(days: 2))),
  NewsPost(id: 'n6',  clubId: 'c15', authorId: 'u2', title: 'KU Demo Day 2025 Duyurusu',                 content: 'Applications are now open for KU Demo Day 2025 — our flagship startup pitch event with a 500,000 TL prize pool and direct access to investors from the Koç Group ecosystem. Solo founders and teams of up to 5 welcome. Application deadline: March 15. 🚀',                                 createdAt: DateTime.now().subtract(const Duration(days: 3))),

  // ── One post per remaining club ─────────────────────────────────────────────
  NewsPost(id: 'n7',  clubId: 'c1',  authorId: 'u3', title: 'Troya Kazı Alanı Gezisi',                   content: 'KUARHA olarak bu hafta sonu Troya Kazı Alanı\'na bir gün uzunluğunda saha gezisi düzenliyoruz. Rehberli tur, açık hava sergisi ve arkeoloji uzmanlarıyla soru-cevap oturumu içermektedir. Katılım ücretsiz, ulaşım kulüp tarafından karşılanacak.',                                          createdAt: DateTime.now().subtract(const Duration(days: 4))),
  NewsPost(id: 'n8',  clubId: 'c2',  authorId: 'u4', title: '19 Mayıs Kutlama Programı',                 content: 'KUADK olarak 19 Mayıs Atatürk\'ü Anma, Gençlik ve Spor Bayramı\'nı kampüste anlamlı bir programla kutluyoruz. Şiir dinletisi, belgesel gösterimi ve panel tartışması sizi bekliyor. Herkese açık, giriş serbest!',                                                                           createdAt: DateTime.now().subtract(const Duration(days: 5))),
  NewsPost(id: 'n9',  clubId: 'c3',  authorId: 'u1', title: 'Bahar Dönemi Okuma Grubu Başlıyor',         content: 'KUBBE Okuma Grubu bu dönem Orhan Pamuk\'un "Masumiyet Müzesi" eseriyle başlıyor. Haftada bir buluşacağız, tartışma notları önceden paylaşılacak. Edebiyat, felsefe ve tarih severler davetlidir. İlk toplantı Çarşamba 18:00, SOS B108.',                                                   createdAt: DateTime.now().subtract(const Duration(days: 6))),
  NewsPost(id: 'n10', clubId: 'c6',  authorId: 'u2', title: 'Bahar Gösterisi Hazırlıkları Başladı',      content: 'KUDans olarak Bahar Şenliği\'nde sahne alacağımız gösterinin provaları başladı! Salsa, hip-hop ve çağdaş dans bölümlerimiz için son birkaç spot doldurmak üzere hızlı bir seçme yapacağız. Katılmak isteyenler Salı akşamı 19:00\'da Spor Salonu B\'ye gelsin.',                            createdAt: DateTime.now().subtract(const Duration(days: 3, hours: 5))),
  NewsPost(id: 'n11', clubId: 'c7',  authorId: 'u1', title: 'Merkez Bankası Yöneticisiyle Söyleşi',      content: 'Ekonomi Kulübü olarak bu ay Türkiye Cumhuriyet Merkez Bankası\'ndan kıdemli bir ekonomist ile özel bir söyleşi düzenliyoruz. "Enflasyon, Para Politikası ve Genç Ekonomistler" başlıklı bu etkinliğe kayıt zorunludur — kontenjan 60 kişi!',                                               createdAt: DateTime.now().subtract(const Duration(days: 2, hours: 8))),
  NewsPost(id: 'n12', clubId: 'c8',  authorId: 'u4', title: 'Yapay Zeka ve Demokrasi Paneli',            content: 'EkoPolitik, KUACM ile iş birliği yaparak "Yapay Zeka Seçimleri Nasıl Değiştirecek?" konulu disiplinlerarası bir panel düzenliyor. Siyaset bilimi, iktisat ve bilgisayar mühendisliği perspektiflerinden dört konuşmacı bir araya geliyor. Salı 18:00, SOS B140.',                          createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 10))),
  NewsPost(id: 'n13', clubId: 'c9',  authorId: 'u3', title: 'Ebru Workshoplarına Yeni Dönem Kayıtları',  content: 'Ebru Kulübü bahar dönemi atölye çalışmaları için kayıtlar açıldı! Geleneksel Türk kâğıt mermerleme sanatını öğrenmek isteyenler için haftada bir Perşembe akşamı, tüm malzemeler kulüp tarafından sağlanmaktadır. Başlangıç seviyesi için idealdir.',                                    createdAt: DateTime.now().subtract(const Duration(days: 7))),
  NewsPost(id: 'n14', clubId: 'c10', authorId: 'u2', title: 'Nietzsche Okuma Halkası — Hafta 3',         content: 'Felsefe Topluluğu olarak "Böyle Buyurdu Zerdüşt" üzerine üçüncü tartışma oturumunu tamamladık. Bir sonraki haftamızda "İyi ve Kötünün Ötesinde"ye geçiyoruz. Okuma listesi ve tartışma soruları Discord kanalımızda yayınlandı.',                                                           createdAt: DateTime.now().subtract(const Duration(days: 4, hours: 3))),
  NewsPost(id: 'n15', clubId: 'c11', authorId: 'u1', title: 'Fenerbahçe - Galatasaray Derbisi Ekranı',   content: 'Dev derbi için sahaya hazırız! Fenerbahçeliler Topluluğu olarak maçı kampüste büyük ekranda birlikte izliyoruz. Mekan: Kafeterya A, saat 20:00. Formanızı giyin, sarı-lacivert renklerinizi takın ve tribünümüzü doldurun! Giriş serbest 💛💙',                                             createdAt: DateTime.now().subtract(const Duration(hours: 18))),
  NewsPost(id: 'n16', clubId: 'c12', authorId: 'u4', title: 'Folklör Kulübü Yıl Sonu Gösterisi',         content: 'Bu yılın en büyük etkinliğine hazır mısınız? Folklör Kulübü yıl sonu gösterisi 15 Mayıs\'ta KU Amfitiyatrosu\'nda gerçekleşecek. Zeybek, horon ve halay bölümleriyle 45 dakikalık bir gösteri sizi bekliyor. Biletler ücretsiz, rezervasyon gereklidir.',                                 createdAt: DateTime.now().subtract(const Duration(days: 8))),
  NewsPost(id: 'n17', clubId: 'c14', authorId: 'u2', title: 'Yeni Kampanya: Karanlığın Kıyısı',          content: 'KUFRP\'de bu dönemin D&D kampanyası başlıyor! "Karanlığın Kıyısı" — karakter oluşturma oturumu bu Cuma 17:00\'de SOS B210\'da. Yeni oyuncular için kural rehberi ve hazır karakterler sağlanacak. Masa oyunlarına meraklı herkesi bekliyoruz!',                                           createdAt: DateTime.now().subtract(const Duration(days: 2, hours: 6))),
  NewsPost(id: 'n18', clubId: 'c16', authorId: 'u3', title: 'Sağlık Farkındalık Kampanyası Başladı',     content: 'Hemşirelik Kulübü olarak "Sağlıklı Kampüs" farkındalık kampanyamızı başlatıyoruz. Bu hafta boyunca kan basıncı ölçümü, vücut kitle indeksi taraması ve beslenme danışmanlığı hizmetleri ücretsiz sunulacak. SOS Binası giriş holü, 09:00-17:00.',                                            createdAt: DateTime.now().subtract(const Duration(days: 5, hours: 2))),
  NewsPost(id: 'n19', clubId: 'c17', authorId: 'u1', title: 'Moot Court Yarışması Sonuçları',            content: 'Hukuk Kulübü\'nün bu yılki Moot Court yarışmasında büyük final heyecanla tamamlandı! Finalist takımlar gerçek avukatlar önünde dava sundular. Birinci olan takımı tebrik ediyoruz — bu başarı çok hak edildi. Detaylı sonuçlar ve sıradaki etkinlikler yakında paylaşılacak.',              createdAt: DateTime.now().subtract(const Duration(days: 3, hours: 4))),
  NewsPost(id: 'n20', clubId: 'c18', authorId: 'u4', title: 'McKinsey ile Vaka Çalışması Workshopu',     content: 'İşletme Kulübü olarak McKinsey & Company ile özel bir vaka çalışması atölyesi düzenliyoruz. Katılımcılar gerçek bir iş problemini analiz edecek ve sunum yapacak. Seçilen 20 katılımcıya sertifika verilecek. Başvuru formu bio bağlantısında!',                                             createdAt: DateTime.now().subtract(const Duration(days: 6, hours: 1))),
  NewsPost(id: 'n21', clubId: 'c19', authorId: 'u2', title: '8 Mart Etkinlik Programı',                  content: 'Kadın Dayanışma Kulübü olarak 8 Mart Dünya Kadınlar Günü\'nü zengin bir programla kutluyoruz. Panel tartışması, sinema gösterimi ve dayanışma yürüyüşü sizi bekliyor. "Eşitlik için birlikte" sloganıyla bu yıl kampüsü renklendiriyoruz.',                                                 createdAt: DateTime.now().subtract(const Duration(days: 9))),
  NewsPost(id: 'n22', clubId: 'c20', authorId: 'u3', title: 'Women in Tech Summit 2025',                 content: 'KUSWE olarak Women in Tech Summit 2025\'i duyurmaktan gurur duyuyoruz! Google, Microsoft ve Koç Holding\'den kadın liderler konuşmacı olarak katılıyor. Tam gün etkinlik, networking öğle yemeği dahil. Kayıt ücretsiz ama sınırlı — acele edin!',                                          createdAt: DateTime.now().subtract(const Duration(days: 10))),
  NewsPost(id: 'n23', clubId: 'c21', authorId: 'u1', title: 'AIChE Bölge Konferansı Hazırlığı',          content: 'AIChE KU Öğrenci Şubesi olarak bölge konferansına hazırlanıyoruz. Poster sunumu, teknik makale yarışması ve lab tur organizasyonu için gönüllü ekip üyeleri arıyoruz. Kimya veya biyoloji mühendisliği öğrencileri önceliklidir.',                                                         createdAt: DateTime.now().subtract(const Duration(days: 11))),
  NewsPost(id: 'n24', clubId: 'c22', authorId: 'u4', title: 'Kadıköy Çocuk Parkı Projesi Tamamlandı',   content: 'KU Gönüllüleri olarak Kadıköy\'deki çocuk parkı restorasyon projemizi başarıyla tamamladık! 35 gönüllü öğrenci 2 hafta boyunca çalışarak parkı yeniledi. Çocukların mutlu yüzleri en büyük ödülümüz. Bir sonraki proje duyurusu yakında!',                                                 createdAt: DateTime.now().subtract(const Duration(days: 12))),
  NewsPost(id: 'n25', clubId: 'c23', authorId: 'u2', title: 'KU Basketbol Takımı Şampiyon Oldu!',        content: 'KU Kartalları olarak harika bir haberi paylaşıyoruz: KU Basketbol Takımı bu yılki üniversitelerarası ligde şampiyon oldu! 🦅 Final maçında verdikleri mücadele inanılmazdı. Tüm takım üyelerini tebrik ediyoruz!',                                                                         createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 6))),
  NewsPost(id: 'n26', clubId: 'c24', authorId: 'u3', title: 'Onur Haftası Programı Açıklandı',           content: 'Kuir Kulübü olarak Onur Haftası etkinlik programımızı duyuruyoruz! Belgesel gösterimi, dayanışma fotoğraf sergisi, açık panel ve sosyal buluşma bu haftanın dört gününe yayılmış olarak gerçekleşecek. Herkes davetli, güvenli alan garantimiz vardır.',                                     createdAt: DateTime.now().subtract(const Duration(days: 13))),
  NewsPost(id: 'n27', clubId: 'c25', authorId: 'u1', title: 'Kürtçe Dil Atölyesi — Seviye A1 Açıldı',   content: 'Kürt Dili Kulübü olarak bu dönem Kürtçe (Kurmancî) A1 dil kursunu açıyoruz. Haftada iki oturum, deneyimli eğitmenler eşliğinde. Kürt kültürü ve dilini öğrenmek isteyen herkese açık. Kayıt için bağlantı profilimizde!',                                                               createdAt: DateTime.now().subtract(const Duration(days: 7, hours: 3))),
  NewsPost(id: 'n28', clubId: 'c26', authorId: 'u4', title: 'Robolig 2025\'e Hazırlanıyoruz!',           content: 'KUMech olarak bu yılki Robolig yarışması için robot tasarım sürecimiz başladı. Mekanik tasarım, elektronik ve programlama ekiplerinde açık pozisyonlar var. Makine mühendisliği öğrencilerine öncelik verilecek, ancak herkese kapımız açık!',                                            createdAt: DateTime.now().subtract(const Duration(days: 4, hours: 7))),
  NewsPost(id: 'n29', clubId: 'c29', authorId: 'u2', title: '"Waiting for Godot" Ön Gösterimi Büyük İlgi Gördü', content: 'Müzikal Kulübü\'nün bu dönemki prodüksiyonu "Waiting for Godot"nun ön gösterimi büyük beğeni topladı. Beckett\'in başyapıtına modern bir yorum katan bu prodüksiyonumuz 22-24 Mayıs tarihlerinde KU Sahnesi\'nde gösterime giriyor. Biletler bitmeden yerinizi ayırtın!', createdAt: DateTime.now().subtract(const Duration(days: 6, hours: 8))),
  NewsPost(id: 'n30', clubId: 'c30', authorId: 'u3', title: 'Beyin Farkındalık Haftası Etkinlikleri',    content: 'KU-SIGN olarak Dünya Beyin Farkındalık Haftası kapsamında bir dizi etkinlik düzenliyoruz. Nörolog konuşmacılar, beyin modelleme atölyesi ve araştırma lab ziyareti programda yer alıyor. Tıp, psikoloji ve biyoloji öğrencilerine özellikle tavsiye edilir.',                               createdAt: DateTime.now().subtract(const Duration(days: 14))),
  NewsPost(id: 'n31', clubId: 'c31', authorId: 'u1', title: 'Bahar Konseri Biletleri Tükeniyor!',        content: 'Orkestra Kulübü\'nün yıllık Bahar Konseri\'ne büyük ilgi! Brahms ve Dvořák eserlerinden oluşan programımız için sahne hazırlıklarımız son aşamada. Konser 30 Mayıs\'ta KU Amfitiyatrosu\'nda. Ücretsiz biletlerin büyük çoğunluğu talep edildi — acele edin!',                            createdAt: DateTime.now().subtract(const Duration(days: 2, hours: 4))),
  NewsPost(id: 'n32', clubId: 'c32', authorId: 'u4', title: 'Sosyal Medya Strateji Yarışması Sonuçları', content: 'Pazarlama Kulübü olarak bu dönemki sosyal medya strateji yarışmamızı tamamladık. 12 takım gerçek markalar için kampanya geliştirdi; kazanan takım stratejisini gerçekte uygulama fırsatı kazandı. Tebrikler ve katılan herkese teşekkürler!',                                           createdAt: DateTime.now().subtract(const Duration(days: 9, hours: 2))),
  NewsPost(id: 'n33', clubId: 'c33', authorId: 'u2', title: 'KU Radyo Bu Hafta Canlı Yayında!',          content: 'Radyo Kulübü olarak bu hafta boyunca KU kampüs radyosu canlı yayın yapıyor. Müzik programları, söyleşiler ve haberler Spotify ve web sitemizden dinlenebilir. Yayına katılmak veya sunum yapmak isteyen gönüllüler DM atabilir!',                                                         createdAt: DateTime.now().subtract(const Duration(days: 3, hours: 9))),
  NewsPost(id: 'n34', clubId: 'c34', authorId: 'u3', title: 'Resim Sergisi "Şehir ve Ruh" Açıldı',       content: 'Resim Kulübü\'nün bahar sergisi "Şehir ve Ruh" bugün SOS Galerisi\'nde açıldı! 18 öğrenci sanatçının 40\'tan fazla eseri yer alıyor. Yağlıboya, suluboya ve karma teknik çalışmalar sergileniyor. Sergi 2 Haziran\'a kadar açık, giriş ücretsiz.',                                         createdAt: DateTime.now().subtract(const Duration(days: 5, hours: 6))),
  NewsPost(id: 'n35', clubId: 'c35', authorId: 'u1', title: 'Nuri Bilge Ceylan Retrospektifi Başladı',   content: 'Sinema Kulübü olarak bu hafta Nuri Bilge Ceylan retrospektifimizi başlatıyoruz. "Uzak", "İklimler" ve "Bir Zamanlar Anadolu\'da" haftanın üç gecesi gösterilecek. Her filmden sonra sinema eleştirmeni eşliğinde tartışma oturumu yapılacak.',                                             createdAt: DateTime.now().subtract(const Duration(days: 7, hours: 4))),
  NewsPost(id: 'n36', clubId: 'c36', authorId: 'u4', title: 'Bahar Şenliği Organizasyon Komitesi',       content: 'Sosyal Aktiviteler Kulübü olarak Bahar Şenliği\'nin organizasyonunu üstlendik! Konserler, turnuvalar, yemek stantları ve sürpriz etkinliklerle dolu 3 günlük bir program hazırlıyoruz. Gönüllü organizatör olmak isteyenler bu hafta cuma toplantımıza gelsin.',                           createdAt: DateTime.now().subtract(const Duration(days: 15))),
  NewsPost(id: 'n37', clubId: 'c37', authorId: 'u2', title: 'Osmanlı Arşivleri Workshop\'u',             content: 'Tarih Kulübü olarak İstanbul Üniversitesi\'nden Osmanlı tarihçisi Prof. Dr. Ayşe Yıldız ile özel bir arşiv atölyesi düzenliyoruz. Osmanlıca belgeleri okuma, dönemin sosyal yapısını anlama ve tarihi haritalar üzerine pratik çalışmalar yapılacak.',                                    createdAt: DateTime.now().subtract(const Duration(days: 8, hours: 5))),
  NewsPost(id: 'n38', clubId: 'c38', authorId: 'u3', title: 'USMLE Step 1 Çalışma Grubu Kuruluyor',      content: 'KUTÖB olarak USMLE Step 1 sınavına hazırlanan tıp öğrencileri için organize bir çalışma grubu kuruyoruz. Haftalık müfredat, soru bankası paylaşımı ve simülasyon sınavları planlanıyor. Tıp 2. ve 3. sınıf öğrencilerine öncelik verilecek.',                                             createdAt: DateTime.now().subtract(const Duration(days: 11, hours: 3))),
  NewsPost(id: 'n39', clubId: 'c39', authorId: 'u1', title: 'Doğaçlama Tiyatro Geceleri Başlıyor',       content: 'Tiyatro Kulübü olarak her Perşembe akşamı açık doğaçlama geceleri düzenliyoruz! Tiyatro deneyimi şart değil — sadece sahneye çıkma cesareti yeterli. İzleyici olarak da gelebilirsiniz, giriş ücretsiz. SOS B206, 19:30\'da başlıyor.',                                                   createdAt: DateTime.now().subtract(const Duration(days: 6, hours: 2))),
  NewsPost(id: 'n40', clubId: 'c40', authorId: 'u4', title: 'Türk Dış Politikası Tartışma Serisi',       content: 'Türk Araştırmaları Topluluğu olarak "Değişen Dünyada Türk Dış Politikası" başlıklı tartışma serimizi başlatıyoruz. Orta Doğu, Kafkasya ve AB ilişkileri üzerine uzman konuşmacılarla dört haftalık bir program. İlk oturum Pazartesi 17:00.',                                          createdAt: DateTime.now().subtract(const Duration(days: 10, hours: 1))),
  NewsPost(id: 'n41', clubId: 'c41', authorId: 'u2', title: 'Saz Atölyesi — Tüm Seviyeler Davetli',      content: 'Türk Halk Müziği Kulübü olarak bu dönem saz atölyelerini genişletiyoruz. Başlangıç, orta ve ileri seviye gruplar Salı-Perşembe akşamları toplanıyor. Saz temin edilebilir. Türk halk müziğini öğrenmek isteyen herkes aramıza katılabilir!',                                            createdAt: DateTime.now().subtract(const Duration(days: 3, hours: 5))),

  // ── Posts with images (templates) ───────────────────────────────────────────
  NewsPost(id: 'ni1',  clubId: 'c4',  authorId: 'u1', content: 'Hack-KU 2025 registration is now open! 48 hours of coding, mentors, food, and prizes. Tag a friend you\'re teaming up with 💻🔥', createdAt: DateTime.now().subtract(const Duration(hours: 3)), imagePath: 'tpl:0'),
  NewsPost(id: 'ni2',  clubId: 'c13', authorId: 'u4', content: 'Golden hour on campus — caught this moment between SOS and the library. Spring is officially here 🌅📷', createdAt: DateTime.now().subtract(const Duration(hours: 7)), imagePath: 'tpl:1'),
  NewsPost(id: 'ni3',  clubId: 'c6',  authorId: 'u2', content: 'Bahar Şenliği prova kareleri! Sahneye 2 hafta kaldı — enerjimiz zirvedeyken bir göz atın 🕺💃', createdAt: DateTime.now().subtract(const Duration(hours: 11)), imagePath: 'tpl:2'),
  NewsPost(id: 'ni4',  clubId: 'c27', authorId: 'u3', content: 'Regional champions 🏆 The moment the final verdict was announced — we still can\'t believe it. Ankara, here we come!', createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)), imagePath: 'tpl:3'),
  NewsPost(id: 'ni5',  clubId: 'c28', authorId: 'u3', content: 'Open Mic sound check done ✅ The vibe in SOS B Atelier tonight is going to be unreal. Doors open at 8 PM — free entry 🎵', createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 5)), imagePath: 'tpl:4'),
  NewsPost(id: 'ni6',  clubId: 'c15', authorId: 'u2', content: 'KU Demo Day 2025 pitch prep workshop recap 🚀 Founders in the room gave us chills. Applications still open — link in bio.', createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 9)), imagePath: 'tpl:5'),
  NewsPost(id: 'ni7',  clubId: 'c35', authorId: 'u1', content: '"Uzak" — Nuri Bilge Ceylan retrospective night at the KU screening room. The silence was deafening in the best possible way 🎬', createdAt: DateTime.now().subtract(const Duration(days: 2, hours: 1)), imagePath: 'tpl:6'),
  NewsPost(id: 'ni8',  clubId: 'c31', authorId: 'u1', content: 'Bahar Konseri son prova! Brahms\'ın dörtlüsü bu akustik salonla buluşunca gerçekten büyülü bir şey oluyor 🎻', createdAt: DateTime.now().subtract(const Duration(days: 2, hours: 6)), imagePath: 'tpl:7'),
  NewsPost(id: 'ni9',  clubId: 'c22', authorId: 'u4', content: 'Kadıköy çocuk parkı restorasyon projemiz tamamlandı! 35 gönüllü, 2 hafta, sıfır bütçe — saf keyif 💚', createdAt: DateTime.now().subtract(const Duration(days: 2, hours: 14)), imagePath: 'tpl:0'),
  NewsPost(id: 'ni10', clubId: 'c5',  authorId: 'u2', content: 'Uludağ summit view at sunrise after a 6-hour ascent ⛰️ Worth every step. Who\'s joining the next climb?', createdAt: DateTime.now().subtract(const Duration(days: 3, hours: 2)), imagePath: 'tpl:1'),
  NewsPost(id: 'ni11', clubId: 'c23', authorId: 'u2', content: 'KU Kartalları şampiyon! 🦅 Final maçının son saniyelerini kim hatırlar? Inanılmazdı. Kupamız evde!', createdAt: DateTime.now().subtract(const Duration(days: 3, hours: 8)), imagePath: 'tpl:2'),
  NewsPost(id: 'ni12', clubId: 'c34', authorId: 'u3', content: '"Şehir ve Ruh" sergimizin açılış gecesi — 18 sanatçı, 40+ eser, 200+ ziyaretçi. Teşekkürler KU! 🎨', createdAt: DateTime.now().subtract(const Duration(days: 3, hours: 15)), imagePath: 'tpl:3'),
  NewsPost(id: 'ni13', clubId: 'c20', authorId: 'u3', content: 'Women in Tech Summit 2025 — Google, Microsoft, Koç Holding\'den kadın liderler aynı sahnede 🌟 Kayıt bağlantısı bio\'da!', createdAt: DateTime.now().subtract(const Duration(days: 4, hours: 3)), imagePath: 'tpl:4'),
  NewsPost(id: 'ni14', clubId: 'c39', authorId: 'u1', content: 'Thursday Improv Night highlights 🎭 No script, no plan — just pure chaos and laughter. Join us every Thursday at 19:30!', createdAt: DateTime.now().subtract(const Duration(days: 4, hours: 10)), imagePath: 'tpl:5'),
  NewsPost(id: 'ni15', clubId: 'c9',  authorId: 'u3', content: 'Bahar dönemi ebru atölyesi bitti — işte öğrencilerimizin eserleri 🌊 Her biri tamamen benzersiz. Kayıt başladı!', createdAt: DateTime.now().subtract(const Duration(days: 5, hours: 1)), imagePath: 'tpl:6'),
  NewsPost(id: 'ni16', clubId: 'c33', authorId: 'u2', content: 'KU Radyo bu hafta canlı — Spotify\'da dinle, kampüste hisset 📻 Müzik, haberler, sürpriz konuklar. Yayın devam!', createdAt: DateTime.now().subtract(const Duration(days: 5, hours: 7)), imagePath: 'tpl:7'),
  NewsPost(id: 'ni17', clubId: 'c26', authorId: 'u4', content: 'Robolig 2025 robot tasarım süreci başladı 🤖 Alüminyum, motor, kod — her şey bir arada. Takımımıza katıl!', createdAt: DateTime.now().subtract(const Duration(days: 6, hours: 2)), imagePath: 'tpl:0'),
  NewsPost(id: 'ni18', clubId: 'c12', authorId: 'u4', content: 'Folklör Kulübü yıl sonu gösterisi kostüm provası 👘 Zeybek, horon, halay — 15 Mayıs\'ta KU Amfisi\'nde görüşürüz!', createdAt: DateTime.now().subtract(const Duration(days: 6, hours: 9)), imagePath: 'tpl:1'),
  NewsPost(id: 'ni19', clubId: 'c24', authorId: 'u3', content: 'Onur Haftası fotoğraf sergisi açıldı 🌈 "Görünür ol" — bu haftanın teması bu. Herkes davetli, SOS Galerisi.', createdAt: DateTime.now().subtract(const Duration(days: 7, hours: 4)), imagePath: 'tpl:2'),
  NewsPost(id: 'ni20', clubId: 'c37', authorId: 'u2', content: 'Osmanlı arşivleri workshopundan bir kare 📜 500 yıllık belgeler ellerimizde — tarih böyle öğrenilir.', createdAt: DateTime.now().subtract(const Duration(days: 7, hours: 11)), imagePath: 'tpl:3'),

  // ── Collaboration posts ──────────────────────────────────────────────────────

  // KUACM (c4) × EkoPolitik (c8): joint AI & Democracy panel
  NewsPost(
    id: 'nc1', clubId: 'c4', authorId: 'u1',
    title: 'AI & Democracy — Joint Panel with @EkoPolitik',
    content: 'We\'re teaming up with @ekopolitik for a cross-disciplinary panel: "Will AI Make Democracy Obsolete?" — bringing together computer scientists, economists and political theorists for a night of sharp debate. Tuesday 18:00, SOS B140. Free entry, limited seats. Register via the link in our bio!',
    createdAt: DateTime.now().subtract(const Duration(hours: 10)),
    taggedClubIds: ['c8'],
  ),

  // EkoPolitik (c8) × KUACM (c4): same event from their side
  NewsPost(
    id: 'nc2', clubId: 'c8', authorId: 'u4',
    title: 'Yapay Zeka Paneli — @Bilgisayar Kulübü ile Birlikte',
    content: 'EkoPolitik ve @bilgisayar kulübü (KUACM) olarak ortak bir etkinlikle karşınızdayız. "Yapay Zeka Seçimleri Nasıl Etkiler?" panelinde farklı disiplinlerden dört konuşmacı bir araya geliyor. Bu tür işbirlikleri kampüs akademik kültürünü zenginleştiriyor — birlikte daha güçlüyüz!',
    createdAt: DateTime.now().subtract(const Duration(hours: 8)),
    taggedClubIds: ['c4'],
  ),

  // KUDans (c6) × Müzikal Kulübü (c29): Spring Festival performance
  NewsPost(
    id: 'nc3', clubId: 'c6', authorId: 'u2',
    title: 'Bahar Şenliği: @Müzikal Kulübü ile Ortak Sahne!',
    content: 'Bu yılki Bahar Şenliği\'nde @müzikal kulübü ile birlikte sahne alıyoruz! Dans ve müzikal tiyatronun birleşeceği bu 20 dakikalık ortak performans için prova takvimimiz netleşti. Salsa, hip-hop ve canlı vokal performanslarını bir arada sunan bu gösteri kesinlikle kaçırılmamalı. 15 Mayıs, KU Amfitiyatrosu.',
    createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
    taggedClubIds: ['c29'],
  ),

  // Müzikal (c29) × KUDans (c6) × Orkestra (c31): triple collab
  NewsPost(
    id: 'nc4', clubId: 'c29', authorId: 'u3',
    title: 'Üçlü İşbirliği: @KUDans × @Orkestra × Müzikal',
    content: 'Bahar Şenliği için büyük sürpriz! @kudans ve @orkestra kulübü ile birlikte üç kulübün bir araya geldiği dev bir sahne performansı hazırlıyoruz. Canlı orkestra eşliğinde dans ve müzikal sahneler — kampüs tarihinde ilk kez! Prova süreci zorlu ama sonuç inanılmaz olacak. Biletler yakında!',
    createdAt: DateTime.now().subtract(const Duration(days: 2, hours: 1)),
    taggedClubIds: ['c6', 'c31'],
  ),

  // Orkestra (c31) × Türk Halk Müziği (c41): fusion concert
  NewsPost(
    id: 'nc5', clubId: 'c31', authorId: 'u1',
    title: 'Fusion Konseri: Klasik × Halk Müziği with @Türk',
    content: 'Orkestra Kulübü olarak @türk halk müziği kulübü ile birlikte tamamen yeni bir şey deniyoruz: Batı klasik müziği ile Türk halk ezgilerini birleştiren bir fusion konseri! Brahms\'ın dörtlüsü ile Karadeniz türkülerinin yan yana çalındığını hayal edin. 8 Haziran, SOS Konser Salonu. Giriş ücretsiz.',
    createdAt: DateTime.now().subtract(const Duration(days: 4)),
    taggedClubIds: ['c41'],
  ),

  // Sinema (c35) × Fotoğraf Kulübü (c13): visual arts week
  NewsPost(
    id: 'nc6', clubId: 'c35', authorId: 'u4',
    title: 'Görsel Sanatlar Haftası — @KUFoto ile Birlikte',
    content: 'Sinema Kulübü olarak @kufoto (Fotoğraf Kulübü) ile ortak bir Görsel Sanatlar Haftası düzenliyoruz! Program: fotoğraf sergisi açılışı, kısa film gösterimi, sinemacı-fotoğrafçı söyleşisi ve ortak bir fotoğraf-film atölyesi. 3-7 Haziran, SOS Galerisi. Tüm etkinlikler ücretsiz ve herkese açık.',
    createdAt: DateTime.now().subtract(const Duration(days: 3, hours: 7)),
    taggedClubIds: ['c13'],
  ),

  // KU Gönüllüleri (c22) × Hemşirelik (c16): health outreach
  NewsPost(
    id: 'nc7', clubId: 'c22', authorId: 'u2',
    title: 'Sağlıklı Kampüs Kampanyası — @Hemşirelik ile',
    content: '@hemşirelik kulübü ile birlikte bu hafta boyunca "Sağlıklı Kampüs" kampanyası yürütüyoruz! Gönüllü öğrencilerimiz, hemşirelik öğrencilerinin sağlık taraması yaparken lojistik desteği üstleniyor. Sabah 09:00\'da SOS giriş holünde başlıyor — kanda şeker ve tansiyon ölçtürmeyi unutmayın!',
    createdAt: DateTime.now().subtract(const Duration(days: 5, hours: 3)),
    taggedClubIds: ['c16'],
  ),

  // Girişimcilik (c15) × KUACM (c4) × KUSWE (c20): startup hackathon
  NewsPost(
    id: 'nc8', clubId: 'c15', authorId: 'u3',
    title: 'Tech Startup Hackathon — @Bilgisayar × @Kadın',
    content: 'Girişimcilik Kulübü olarak @bilgisayar kulübü (KUACM) ve @kadın mühendisler kulübü (KUSWE) ile ortak bir Tech Startup Hackathon düzenliyoruz. 24 saatlik etkinlikte takımlar gerçek bir sosyal soruna teknolojik çözüm geliştirecek. Ödül: KU Demo Day\'de sunum hakkı + 50.000 TL. Başvurular açık!',
    createdAt: DateTime.now().subtract(const Duration(days: 6, hours: 6)),
    taggedClubIds: ['c4', 'c20'],
  ),

  // Resim (c34) × Ebru (c9): traditional Turkish arts exhibition
  NewsPost(
    id: 'nc9', clubId: 'c34', authorId: 'u1',
    title: 'Geleneksel Türk Sanatları Sergisi — @Ebru ile',
    content: 'Resim Kulübü olarak @ebru kulübü ile birlikte "Geleneksel ve Çağdaş" başlıklı ortak bir sergi açıyoruz! Bir yanda kâğıt mermerleme ustalarının eserleri, diğer yanda yağlıboya ve suluboya tablolar... İki farklı dünya, tek sergide. 20 Mayıs açılış, SOS Galerisi. Saat 18:00\'de müzik eşliğinde vernisaj.',
    createdAt: DateTime.now().subtract(const Duration(days: 8, hours: 2)),
    taggedClubIds: ['c9'],
  ),

  // Münazara (c27) × Ekonomi (c7) × Hukuk (c17): policy debate night
  NewsPost(
    id: 'nc10', clubId: 'c27', authorId: 'u3',
    title: 'Politika Münazara Gecesi — @Ekonomi & @Hukuk',
    content: 'Bu dönemin en heyecanlı etkinliği geliyor! @ekonomi kulübü ve @hukuk kulübü ile birlikte "Minimum Ücret Kanunu: Gerekli mi, Zararlı mı?" konulu üçlü münazara gecesi düzenliyoruz. Ekonomistler, hukukçular ve münazaracılar aynı sahnede. Oxford formatında 90 dakikalık tartışma. Cuma 19:00, Amphitheater.',
    createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 14)),
    taggedClubIds: ['c7', 'c17'],
  ),
];

// ─── Comments ─────────────────────────────────────────────────────────────────

final comments = [
  Comment(id: 'cm1',  postId: 'n1', userId: 'u2', content: 'Can\'t wait for Hack-KU! 🙌',                               createdAt: DateTime.now().subtract(const Duration(hours: 1))),
  Comment(id: 'cm2',  postId: 'n1', userId: 'u4', content: 'Finally signed up for the workshops!',                       createdAt: DateTime.now().subtract(const Duration(minutes: 40))),
  Comment(id: 'cm3',  postId: 'n1', userId: 'u3', content: 'KUACM is always the best club 🤩',                           createdAt: DateTime.now().subtract(const Duration(minutes: 20))),
  Comment(id: 'cm4',  postId: 'n2', userId: 'u1', content: 'Already editing my submission 📷',                           createdAt: DateTime.now().subtract(const Duration(hours: 4))),
  Comment(id: 'cm5',  postId: 'n3', userId: 'u2', content: 'Finally! Been waiting for the new gear.',                    createdAt: DateTime.now().subtract(const Duration(hours: 22))),
  Comment(id: 'cm6',  postId: 'n5', userId: 'u1', content: 'Absolutely deserved. You all crushed it!',                   createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 20))),
  Comment(id: 'cm7',  postId: 'n5', userId: 'u2', content: 'Congrats! Nationals here we come 🔥',                        createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 18))),
  Comment(id: 'cm8',  postId: 'n5', userId: 'u4', content: 'That final round was incredible!',                           createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 10))),
  Comment(id: 'cm9',  postId: 'n4',  userId: 'u3', content: 'Signed up already, can\'t wait!',                                  createdAt: DateTime.now().subtract(const Duration(days: 1))),
  Comment(id: 'cm10', postId: 'n4',  userId: 'u4', content: 'Performing this time 🎸',                                          createdAt: DateTime.now().subtract(const Duration(hours: 20))),
  // Collab post comments
  Comment(id: 'cm11', postId: 'nc1', userId: 'u3', content: 'This is exactly the kind of cross-faculty event we need!',         createdAt: DateTime.now().subtract(const Duration(hours: 9))),
  Comment(id: 'cm12', postId: 'nc1', userId: 'u5', content: 'Registered already — see you there!',                              createdAt: DateTime.now().subtract(const Duration(hours: 7))),
  Comment(id: 'cm13', postId: 'nc2', userId: 'u2', content: 'KUACM ve EkoPolitik bir arada — harika!',                          createdAt: DateTime.now().subtract(const Duration(hours: 6))),
  Comment(id: 'cm14', postId: 'nc3', userId: 'u1', content: 'Salsa + musical theatre? This is going to be incredible 🔥',       createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 2))),
  Comment(id: 'cm15', postId: 'nc3', userId: 'u4', content: 'KUDans never disappoints, and together with Müzikal? 👏',          createdAt: DateTime.now().subtract(const Duration(hours: 22))),
  Comment(id: 'cm16', postId: 'nc4', userId: 'u2', content: 'Three clubs on one stage — this is a first for KU!',               createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 18))),
  Comment(id: 'cm17', postId: 'nc5', userId: 'u3', content: 'Klasik müzik ile halk müziğinin birleşimi gerçekten çok heyecan verici!', createdAt: DateTime.now().subtract(const Duration(days: 3, hours: 20))),
  Comment(id: 'cm18', postId: 'nc6', userId: 'u5', content: 'Sinema + fotoğraf = mükemmel combo. Kesinlikle geleceğim.',        createdAt: DateTime.now().subtract(const Duration(days: 3, hours: 4))),
  Comment(id: 'cm19', postId: 'nc7', userId: 'u1', content: 'Nursing students + volunteers = a great team for the community!',  createdAt: DateTime.now().subtract(const Duration(days: 4, hours: 22))),
  Comment(id: 'cm20', postId: 'nc8', userId: 'u4', content: 'Three clubs, one hackathon — this is what university is about 🚀', createdAt: DateTime.now().subtract(const Duration(days: 5, hours: 20))),
  Comment(id: 'cm21', postId: 'nc8', userId: 'u2', content: 'Already forming a team for this. Who wants in?',                  createdAt: DateTime.now().subtract(const Duration(days: 5, hours: 15))),
  Comment(id: 'cm22', postId: 'nc9', userId: 'u3', content: 'Ebru ve resim yan yana — çok güzel bir sergi olacak!',             createdAt: DateTime.now().subtract(const Duration(days: 7, hours: 20))),
  Comment(id: 'cm23', postId: 'nc10', userId: 'u1', content: 'Three clubs debating together — the Oxford format is perfect for this.', createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 10))),
  Comment(id: 'cm24', postId: 'nc10', userId: 'u5', content: 'Münazara + Ekonomi + Hukuk — this panel will be fire 🔥',         createdAt: DateTime.now().subtract(const Duration(hours: 22))),
];

// ─── Likes ────────────────────────────────────────────────────────────────────

final likes = [
  Like(id: 'l1',  postId: 'n1', userId: 'u2'),
  Like(id: 'l2',  postId: 'n1', userId: 'u3'),
  Like(id: 'l3',  postId: 'n1', userId: 'u4'),
  Like(id: 'l4',  postId: 'n2', userId: 'u1'),
  Like(id: 'l5',  postId: 'n2', userId: 'u4'),
  Like(id: 'l6',  postId: 'n3', userId: 'u2'),
  Like(id: 'l7',  postId: 'n5', userId: 'u1'),
  Like(id: 'l8',  postId: 'n5', userId: 'u2'),
  Like(id: 'l9',  postId: 'n5', userId: 'u4'),
  Like(id: 'l10', postId: 'n5', userId: 'u3'),
  Like(id: 'l11', postId: 'n4',  userId: 'u1'),
  Like(id: 'l12', postId: 'n4',  userId: 'u3'),
  // Collab post likes
  Like(id: 'l13', postId: 'nc1', userId: 'u2'),
  Like(id: 'l14', postId: 'nc1', userId: 'u3'),
  Like(id: 'l15', postId: 'nc1', userId: 'u4'),
  Like(id: 'l16', postId: 'nc1', userId: 'u5'),
  Like(id: 'l17', postId: 'nc2', userId: 'u1'),
  Like(id: 'l18', postId: 'nc2', userId: 'u3'),
  Like(id: 'l19', postId: 'nc3', userId: 'u1'),
  Like(id: 'l20', postId: 'nc3', userId: 'u4'),
  Like(id: 'l21', postId: 'nc3', userId: 'u5'),
  Like(id: 'l22', postId: 'nc4', userId: 'u2'),
  Like(id: 'l23', postId: 'nc4', userId: 'u3'),
  Like(id: 'l24', postId: 'nc4', userId: 'u4'),
  Like(id: 'l25', postId: 'nc5', userId: 'u1'),
  Like(id: 'l26', postId: 'nc5', userId: 'u2'),
  Like(id: 'l27', postId: 'nc6', userId: 'u3'),
  Like(id: 'l28', postId: 'nc6', userId: 'u5'),
  Like(id: 'l29', postId: 'nc7', userId: 'u1'),
  Like(id: 'l30', postId: 'nc7', userId: 'u4'),
  Like(id: 'l31', postId: 'nc8', userId: 'u2'),
  Like(id: 'l32', postId: 'nc8', userId: 'u3'),
  Like(id: 'l33', postId: 'nc8', userId: 'u5'),
  Like(id: 'l34', postId: 'nc9', userId: 'u1'),
  Like(id: 'l35', postId: 'nc9', userId: 'u4'),
  Like(id: 'l36', postId: 'nc10', userId: 'u2'),
  Like(id: 'l37', postId: 'nc10', userId: 'u3'),
  Like(id: 'l38', postId: 'nc10', userId: 'u4'),
  Like(id: 'l39', postId: 'nc10', userId: 'u5'),
];

// ─── Shares ───────────────────────────────────────────────────────────────────

final shares = [
  Share(id: 'sh1',  targetId: 'n5',  userId: 'u1', createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 15))),
  Share(id: 'sh2',  targetId: 'n5',  userId: 'u3', createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 12))),
  Share(id: 'sh3',  targetId: 'n5',  userId: 'u4', createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 8))),
  Share(id: 'sh4',  targetId: 'n1',  userId: 'u2', createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 30))),
  Share(id: 'sh5',  targetId: 'n1',  userId: 'u4', createdAt: DateTime.now().subtract(const Duration(hours: 1))),
  Share(id: 'sh6',  targetId: 'n4',  userId: 'u1', createdAt: DateTime.now().subtract(const Duration(hours: 18))),
  Share(id: 'sh7',  targetId: 'ev3', userId: 'u1', createdAt: DateTime.now().subtract(const Duration(hours: 10))),
  Share(id: 'sh8',  targetId: 'ev3', userId: 'u2', createdAt: DateTime.now().subtract(const Duration(hours: 8))),
  Share(id: 'sh9',  targetId: 'ev3', userId: 'u4', createdAt: DateTime.now().subtract(const Duration(hours: 6))),
  Share(id: 'sh10', targetId: 'ev1', userId: 'u3', createdAt: DateTime.now().subtract(const Duration(hours: 20))),
  Share(id: 'sh11', targetId: 'ev5', userId: 'u1', createdAt: DateTime.now().subtract(const Duration(hours: 30))),
];

// ─── Subscriptions ────────────────────────────────────────────────────────────

final subscriptions = [
  // u1 – Alice
  Subscription(id: 's1',  userId: 'u1',  clubId: 'c4'),
  Subscription(id: 's2',  userId: 'u1',  clubId: 'c13'),
  Subscription(id: 's3',  userId: 'u1',  clubId: 'c35'),
  // u2 – Bob
  Subscription(id: 's4',  userId: 'u2',  clubId: 'c4'),
  Subscription(id: 's5',  userId: 'u2',  clubId: 'c28'),
  Subscription(id: 's6',  userId: 'u2',  clubId: 'c15'),
  Subscription(id: 's7',  userId: 'u2',  clubId: 'c36'),
  // u3 – Ceren
  Subscription(id: 's8',  userId: 'u3',  clubId: 'c27'),
  Subscription(id: 's9',  userId: 'u3',  clubId: 'c28'),
  Subscription(id: 's10', userId: 'u3',  clubId: 'c29'),
  // u4 – Deniz
  Subscription(id: 's11', userId: 'u4',  clubId: 'c13'),
  Subscription(id: 's12', userId: 'u4',  clubId: 'c15'),
  Subscription(id: 's13', userId: 'u4',  clubId: 'c34'),
  // u5 – Hakan
  Subscription(id: 's14', userId: 'u5',  clubId: 'c4'),
  Subscription(id: 's15', userId: 'u5',  clubId: 'c22'),
  // u6 – Elif
  Subscription(id: 's16', userId: 'u6',  clubId: 'c1'),
  Subscription(id: 's17', userId: 'u6',  clubId: 'c3'),
  Subscription(id: 's18', userId: 'u6',  clubId: 'c9'),
  Subscription(id: 's19', userId: 'u6',  clubId: 'c10'),
  Subscription(id: 's20', userId: 'u6',  clubId: 'c34'),
  // u7 – Murat
  Subscription(id: 's21', userId: 'u7',  clubId: 'c2'),
  Subscription(id: 's22', userId: 'u7',  clubId: 'c3'),
  Subscription(id: 's23', userId: 'u7',  clubId: 'c25'),
  Subscription(id: 's24', userId: 'u7',  clubId: 'c37'),
  Subscription(id: 's25', userId: 'u7',  clubId: 'c40'),
  // u8 – Selin
  Subscription(id: 's26', userId: 'u8',  clubId: 'c6'),
  Subscription(id: 's27', userId: 'u8',  clubId: 'c12'),
  Subscription(id: 's28', userId: 'u8',  clubId: 'c29'),
  Subscription(id: 's29', userId: 'u8',  clubId: 'c39'),
  Subscription(id: 's30', userId: 'u8',  clubId: 'c41'),
  // u9 – Ahmet
  Subscription(id: 's31', userId: 'u9',  clubId: 'c7'),
  Subscription(id: 's32', userId: 'u9',  clubId: 'c8'),
  Subscription(id: 's33', userId: 'u9',  clubId: 'c15'),
  Subscription(id: 's34', userId: 'u9',  clubId: 'c18'),
  Subscription(id: 's35', userId: 'u9',  clubId: 'c32'),
  // u10 – Zeynep
  Subscription(id: 's36', userId: 'u10', clubId: 'c3'),
  Subscription(id: 's37', userId: 'u10', clubId: 'c10'),
  Subscription(id: 's38', userId: 'u10', clubId: 'c14'),
  Subscription(id: 's39', userId: 'u10', clubId: 'c17'),
  Subscription(id: 's40', userId: 'u10', clubId: 'c33'),
  // u11 – Kemal
  Subscription(id: 's41', userId: 'u11', clubId: 'c5'),
  Subscription(id: 's42', userId: 'u11', clubId: 'c11'),
  Subscription(id: 's43', userId: 'u11', clubId: 'c22'),
  Subscription(id: 's44', userId: 'u11', clubId: 'c23'),
  Subscription(id: 's45', userId: 'u11', clubId: 'c36'),
  // u12 – Ayşe
  Subscription(id: 's46', userId: 'u12', clubId: 'c16'),
  Subscription(id: 's47', userId: 'u12', clubId: 'c19'),
  Subscription(id: 's48', userId: 'u12', clubId: 'c20'),
  Subscription(id: 's49', userId: 'u12', clubId: 'c21'),
  Subscription(id: 's50', userId: 'u12', clubId: 'c30'),
  Subscription(id: 's51', userId: 'u12', clubId: 'c38'),
  // u13 – Emre
  Subscription(id: 's52', userId: 'u13', clubId: 'c22'),
  Subscription(id: 's53', userId: 'u13', clubId: 'c24'),
  Subscription(id: 's54', userId: 'u13', clubId: 'c26'),
  Subscription(id: 's55', userId: 'u13', clubId: 'c28'),
  Subscription(id: 's56', userId: 'u13', clubId: 'c33'),
  // u14 – Leyla
  Subscription(id: 's57', userId: 'u14', clubId: 'c6'),
  Subscription(id: 's58', userId: 'u14', clubId: 'c8'),
  Subscription(id: 's59', userId: 'u14', clubId: 'c27'),
  Subscription(id: 's60', userId: 'u14', clubId: 'c31'),
  Subscription(id: 's61', userId: 'u14', clubId: 'c41'),
  // u15 – Serkan
  Subscription(id: 's62', userId: 'u15', clubId: 'c4'),
  Subscription(id: 's63', userId: 'u15', clubId: 'c7'),
  Subscription(id: 's64', userId: 'u15', clubId: 'c11'),
  Subscription(id: 's65', userId: 'u15', clubId: 'c21'),
  Subscription(id: 's66', userId: 'u15', clubId: 'c26'),
];

// ─── Notifications ────────────────────────────────────────────────────────────

final notifications = [
  AppNotification(id: 'nt1',  userId: 'u2', message: 'Alice Yılmaz liked your post in KUACM',                        createdAt: DateTime.now().subtract(const Duration(minutes: 8)),                        targetType: 'post',  targetId: 'n1'),
  AppNotification(id: 'nt2',  userId: 'u2', message: 'Hack-KU 2025 is in 5 days — don\'t forget to register!',      createdAt: DateTime.now().subtract(const Duration(minutes: 42)),                      targetType: 'event', targetId: 'ev1'),
  AppNotification(id: 'nt3',  userId: 'u2', message: 'Ceren Arslan commented: "This is exactly what we need! 🔥"',   createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 15)),             targetType: 'post',  targetId: 'n1'),
  AppNotification(id: 'nt4',  userId: 'u2', message: 'KUFoto posted a new photo update',                             createdAt: DateTime.now().subtract(const Duration(hours: 3)),                         targetType: 'club',  targetId: 'c13'),
  AppNotification(id: 'nt5',  userId: 'u2', message: 'Deniz Kaya liked your comment in KUDans',                      createdAt: DateTime.now().subtract(const Duration(hours: 5)),                         targetType: 'club',  targetId: 'c6'),
  AppNotification(id: 'nt6',  userId: 'u2', message: 'Open Mic Night starts in 2 hours — SOS B Atelier 🎵',          createdAt: DateTime.now().subtract(const Duration(hours: 6)),                         targetType: 'event', targetId: 'ev5'),
  AppNotification(id: 'nt7',  userId: 'u2', message: 'Girişimcilik Kulübü posted: "KU Demo Day applications open!"', createdAt: DateTime.now().subtract(const Duration(hours: 9)),                         targetType: 'club',  targetId: 'c15'),
  AppNotification(id: 'nt8',  userId: 'u2', message: 'Hakan Tuncay started following you',                            createdAt: DateTime.now().subtract(const Duration(hours: 11)),                        targetType: 'user',  targetId: 'u5'),
  AppNotification(id: 'nt9',  userId: 'u2', message: 'KÜMK: Open Mic Night sign-ups are closing soon!',              createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 1)),                targetType: 'club',  targetId: 'c28'),
  AppNotification(id: 'nt10', userId: 'u2', message: 'Ceren Arslan commented on Münazara\'s championship post',      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 4)),                targetType: 'club',  targetId: 'c27'),
  AppNotification(id: 'nt11', userId: 'u2', message: 'KU Basketbol Takımı just won the championship! 🏆',            createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 7)),                targetType: 'post',  targetId: 'n25'),
  AppNotification(id: 'nt12', userId: 'u2', message: 'Uludağ Kış Tırmanışı has 3 spots left — register now!',       createdAt: DateTime.now().subtract(const Duration(days: 2, hours: 2)),                targetType: 'club',  targetId: 'c5'),
  AppNotification(id: 'nt13', userId: 'u2', message: 'Alice Yılmaz and 4 others liked your photo post',              createdAt: DateTime.now().subtract(const Duration(days: 2, hours: 8)),                targetType: 'post',  targetId: 'ni1'),
  AppNotification(id: 'nt14', userId: 'u2', message: 'Sinema Kulübü: Nuri Bilge Ceylan retrospective starts tonight', createdAt: DateTime.now().subtract(const Duration(days: 3, hours: 1)),               targetType: 'post',  targetId: 'n35'),
  AppNotification(id: 'nt15', userId: 'u2', message: 'Deniz Kaya started following you',                              createdAt: DateTime.now().subtract(const Duration(days: 4, hours: 3)),                targetType: 'user',  targetId: 'u4'),

  // ── Notifications for Hakan Tuncay (u5) ────────────────────────────────────
  AppNotification(id: 'nt20', userId: 'u5', message: 'Alice Yılmaz sent you a message',                               createdAt: DateTime.now().subtract(const Duration(minutes: 20)),               targetType: 'message', targetId: 'u1'),
  AppNotification(id: 'nt21', userId: 'u5', message: 'Bob Demir sent you a message',                                  createdAt: DateTime.now().subtract(const Duration(hours: 3)),                  targetType: 'message', targetId: 'u2'),
  AppNotification(id: 'nt22', userId: 'u5', message: 'Ceren Arslan sent you a message',                               createdAt: DateTime.now().subtract(const Duration(hours: 6)),                  targetType: 'message', targetId: 'u3'),
  AppNotification(id: 'nt23', userId: 'u5', message: 'Deniz Kaya sent you a message',                                 createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),         targetType: 'message', targetId: 'u4'),
  AppNotification(id: 'nt24', userId: 'u5', message: 'Selin Yıldız sent you a message',                               createdAt: DateTime.now().subtract(const Duration(days: 3)),                   targetType: 'message', targetId: 'u8'),
  AppNotification(id: 'nt25', userId: 'u5', message: 'Kemal Arslan sent you a message',                               createdAt: DateTime.now().subtract(const Duration(days: 5)),                   targetType: 'message', targetId: 'u11'),
  AppNotification(id: 'nt26', userId: 'u5', message: 'Alice Yılmaz liked your post in KUACM',                         createdAt: DateTime.now().subtract(const Duration(hours: 1)),                  targetType: 'post',    targetId: 'n1'),
  AppNotification(id: 'nt27', userId: 'u5', message: 'KUACM: Hack-KU 2025 is in 5 days — register now!',             createdAt: DateTime.now().subtract(const Duration(hours: 4)),                  targetType: 'event',   targetId: 'ev1'),
  AppNotification(id: 'nt28', userId: 'u5', message: 'Bob Demir started following you',                               createdAt: DateTime.now().subtract(const Duration(days: 2)),                   targetType: 'user',    targetId: 'u2'),
  AppNotification(id: 'nt29', userId: 'u5', message: 'KU Gönüllüleri: Saturday volunteering project — join us! ❤️',   createdAt: DateTime.now().subtract(const Duration(days: 4)),                   targetType: 'club',    targetId: 'c22'),
];

// ─── Direct Messages ─────────────────────────────────────────────────────────

final messages = <Message>[
  Message(id: 'msg1', senderId: 'u1', receiverId: 'u2', content: 'Hey Bob! Are you coming to Hack-KU this year?',        sentAt: DateTime.now().subtract(const Duration(hours: 2))),
  Message(id: 'msg2', senderId: 'u2', receiverId: 'u1', content: 'Absolutely! Already have my team ready 🤖',             sentAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 30))),
  Message(id: 'msg3', senderId: 'u1', receiverId: 'u2', content: 'Great! I\'ll save you a spot at the front table.',      sentAt: DateTime.now().subtract(const Duration(hours: 1))),
  Message(id: 'msg4', senderId: 'u4', receiverId: 'u2', content: 'Did you see the Open Mic Night lineup? 🎵',             sentAt: DateTime.now().subtract(const Duration(days: 1))),
  Message(id: 'msg5', senderId: 'u2', receiverId: 'u4', content: 'Yes! I\'m performing this time 🎸',                    sentAt: DateTime.now().subtract(const Duration(hours: 23))),
  Message(id: 'msg6', senderId: 'u3', receiverId: 'u4', content: 'Congrats on winning the regional debate!',              sentAt: DateTime.now().subtract(const Duration(days: 2))),
  Message(id: 'msg7', senderId: 'u4', receiverId: 'u3', content: 'Thank you! It was intense but so worth it 🏆',          sentAt: DateTime.now().subtract(const Duration(days: 1, hours: 23))),

  // ── Messages to Hakan Tuncay (u5) ──────────────────────────────────────────
  Message(id: 'msg10', senderId: 'u1', receiverId: 'u5', content: 'Hey Hakan! Are you signing up for Hack-KU? We need a strong team this year 💪',        sentAt: DateTime.now().subtract(const Duration(minutes: 20))),
  Message(id: 'msg11', senderId: 'u1', receiverId: 'u5', content: 'Also, Flutter workshop is this Friday — you should definitely come!',                   sentAt: DateTime.now().subtract(const Duration(minutes: 18))),
  Message(id: 'msg12', senderId: 'u2', receiverId: 'u5', content: 'Hakan, I saw you joined KU Gönüllüleri — the playground project this Saturday is going to be amazing!', sentAt: DateTime.now().subtract(const Duration(hours: 3))),
  Message(id: 'msg13', senderId: 'u2', receiverId: 'u5', content: 'Meet at the main gate at 09:30, don\'t be late 😄',                                    sentAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 55))),
  Message(id: 'msg14', senderId: 'u3', receiverId: 'u5', content: 'Hi! Ceren here from the Münazara Kulübü. We\'re looking for new members — interested?', sentAt: DateTime.now().subtract(const Duration(hours: 6))),
  Message(id: 'msg15', senderId: 'u4', receiverId: 'u5', content: 'Hakan bro, the KUFoto golden hour walk is this Saturday. You\'re coming right? 📷',    sentAt: DateTime.now().subtract(const Duration(days: 1, hours: 2))),
  Message(id: 'msg16', senderId: 'u4', receiverId: 'u5', content: 'Bring your phone at least — the campus looks unreal at sunset',                         sentAt: DateTime.now().subtract(const Duration(days: 1, hours: 1, minutes: 58))),
  Message(id: 'msg17', senderId: 'u8', receiverId: 'u5', content: 'Hey! Selin from the Dans Kulübü — we heard you\'re interested in the Spring Showcase. Auditions are Wed & Thu 19:00!', sentAt: DateTime.now().subtract(const Duration(days: 3))),
  Message(id: 'msg18', senderId: 'u11', receiverId: 'u5', content: 'Kemal here. Did you catch the Fenerbahçe match last night? 🔥 We\'re screening the next one at the club room', sentAt: DateTime.now().subtract(const Duration(days: 5))),
];

// ─── Club Stories ─────────────────────────────────────────────────────────────

class ClubStory {
  final String id;
  final String clubId;
  final String? emoji;
  final String text;
  final DateTime postedAt;
  final String? imagePath;
  final double textOffsetX; // fractional 0-1 (default 0.5 = center)
  final double textOffsetY; // fractional 0-1 (default 0.5 = center)
  final int textColorValue; // Color.value int

  const ClubStory({
    required this.id,
    required this.clubId,
    required this.emoji,
    required this.text,
    required this.postedAt,
    this.imagePath,
    this.textOffsetX = 0.5,
    this.textOffsetY = 0.5,
    this.textColorValue = 0xFFFFFFFF,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'clubId': clubId,
        'emoji': emoji,
        'text': text,
        'postedAt': postedAt.toIso8601String(),
        'imagePath': imagePath,
        'textOffsetX': textOffsetX,
        'textOffsetY': textOffsetY,
        'textColorValue': textColorValue,
      };

  factory ClubStory.fromMap(Map<String, dynamic> m) => ClubStory(
        id: m['id'] as String,
        clubId: m['clubId'] as String,
        emoji: m['emoji'] as String?,
        text: m['text'] as String,
        postedAt: DateTime.parse(m['postedAt'] as String),
        imagePath: m['imagePath'] as String?,
        textOffsetX: (m['textOffsetX'] as num?)?.toDouble() ?? 0.5,
        textOffsetY: (m['textOffsetY'] as num?)?.toDouble() ?? 0.5,
        textColorValue: m['textColorValue'] as int? ?? 0xFFFFFFFF,
      );
}

final clubStories = <ClubStory>[
  // KUACM – 2 stories
  ClubStory(id: 'st1',  clubId: 'c4',  emoji: '💻', text: 'Hack-KU 2025 starts in 5 days!\n48 hours, unlimited coffee, and prizes worth 100K TL. Registration closes tomorrow night — don\'t miss it!',       postedAt: DateTime.now().subtract(const Duration(hours: 1))),
  ClubStory(id: 'st2',  clubId: 'c4',  emoji: '📱', text: 'Flutter Workshop this Friday at 17:00 in ENG B13.\nBuild your first mobile app from scratch. No experience needed — just bring your laptop!',           postedAt: DateTime.now().subtract(const Duration(hours: 5))),

  // KUFoto – 2 stories
  ClubStory(id: 'st3',  clubId: 'c13', emoji: '🌅', text: 'Golden hour photo walk on campus this Saturday at 17:30.\nMeet at the main fountain. Bring your camera or phone — all levels welcome!',                postedAt: DateTime.now().subtract(const Duration(hours: 2))),
  ClubStory(id: 'st4',  clubId: 'c13', emoji: '🎞️', text: 'Darkroom sessions are back every Thursday evening starting next week.\nFilm developing, printing, and enlarger training. Book your spot now!',           postedAt: DateTime.now().subtract(const Duration(hours: 8))),

  // KUDAK – 1 story
  ClubStory(id: 'st5',  clubId: 'c5',  emoji: '⛰️', text: 'Uludağ Winter Climb — 15 February.\nOnly 4 spots remain. Certified guides, group equipment and transport included.\nPhysical briefing: Monday 18:00.',  postedAt: DateTime.now().subtract(const Duration(hours: 3))),

  // KUDans – 1 story
  ClubStory(id: 'st6',  clubId: 'c6',  emoji: '💃', text: 'Spring Showcase auditions are open!\nWe\'re looking for dancers in Salsa, Hip-Hop and Contemporary.\nAuditions: Wednesday & Thursday, 19:00–21:00, Gym B.',  postedAt: DateTime.now().subtract(const Duration(hours: 4))),

  // Girişimcilik – 1 story
  ClubStory(id: 'st7',  clubId: 'c15', emoji: '🚀', text: 'KU Demo Day 2025 applications are LIVE!\n500,000 TL prize pool. 20 startups. Real investors.\nDeadline: March 15. Apply at girişim.ku.edu.tr',             postedAt: DateTime.now().subtract(const Duration(hours: 6))),

  // KÜMK – 1 story
  ClubStory(id: 'st8',  clubId: 'c28', emoji: '🎶', text: 'Open Mic Night this Friday at 20:00 in SOS B Atelier.\nSingers, guitarists, pianists — sign up at the door or DM us.\nFree entry. See you there! 🎵',      postedAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 30))),

  // Münazara – 1 story
  ClubStory(id: 'st9',  clubId: 'c27', emoji: '🏆', text: 'We won the Regional Championship! 🎉\nUnanimous panel decision. Ceren and Deniz were outstanding.\nNationals in Ankara — April 18–20. Koç is going!',      postedAt: DateTime.now().subtract(const Duration(hours: 10))),

  // Sinema – 1 story
  ClubStory(id: 'st10', clubId: 'c35', emoji: '🎬', text: 'Nuri Bilge Ceylan Retrospective — Week 2.\n"Once Upon a Time in Anatolia" screening Wednesday at 19:00, SOS B140.\nFree for all Koç students.',             postedAt: DateTime.now().subtract(const Duration(hours: 7))),

  // KU Gönüllüleri – 1 story
  ClubStory(id: 'st11', clubId: 'c22', emoji: '❤️', text: 'Kadıköy Children\'s Playground Restoration Project.\nThis Saturday 10:00 AM. Bring gloves and good energy.\nTransportation provided from main gate at 09:30.', postedAt: DateTime.now().subtract(const Duration(hours: 12))),

  // Tiyatro – 1 story
  ClubStory(id: 'st12', clubId: 'c39', emoji: '🎭', text: 'Auditions for "Waiting for Godot" — Feb 12 & 13!\nNo prior experience required. Just show up and be yourself.\nSOS B206, 17:00–20:00. See you on stage!',      postedAt: DateTime.now().subtract(const Duration(hours: 9))),

  // KUMech – 1 story
  ClubStory(id: 'st13', clubId: 'c26', emoji: '⚙️', text: 'Robolig 2025 prep is underway!\nRobot design workshop Monday at 16:00 in MFG Lab.\nAll mechanical engineering students invited — beginners especially welcome.',  postedAt: DateTime.now().subtract(const Duration(hours: 11))),

  // EkoPolitik – 1 story
  ClubStory(id: 'st14', clubId: 'c8',  emoji: '📊', text: '"AI and the Future of Work" panel — Tuesday 18:00.\n4 speakers from 2 universities. SOS B140.\nFollow-up networking session with snacks afterwards.',            postedAt: DateTime.now().subtract(const Duration(hours: 14))),

  // KU-SIGN – 1 story
  ClubStory(id: 'st15', clubId: 'c30', emoji: '🧠', text: 'Neurological Rehabilitation Symposium registrations are open!\nCapacity: 50 students. Certificate of attendance provided.\nRegister at kusign.ku.edu.tr — closes Friday.',  postedAt: DateTime.now().subtract(const Duration(hours: 16))),
];

// ─── App Super Admin ─────────────────────────────────────────────────────────

final appAdmin = AppAdmin(
  id: 'admin1',
  name: 'Super Admin',
  email: 'youradmin@uni.edu',
  password: 'admin123',
);

// ─── Club Admins ──────────────────────────────────────────────────────────────

final clubAdmins = [
  AppAdmin(id: 'cadmin1', name: 'HAKANS_CLUB', email: 'hclub@ku.edu.tr', password: '123456789'),
];
// Note: club adminUserIds must include the AppAdmin id (e.g. 'cadmin1') for post creation to work

// ─── Scoring Helpers ──────────────────────────────────────────────────────────

double postScore(String postId) {
  final uniqueLikers     = likes.where((l) => l.postId == postId).map((l) => l.userId).toSet().length;
  final uniqueCommenters = comments.where((c) => c.postId == postId).map((c) => c.userId).toSet().length;
  final shareCount       = shares.where((s) => s.targetId == postId).length;
  return uniqueLikers + (uniqueCommenters * 1.5) + (shareCount * 2.0);
}

double eventScore(String eventId) {
  final event           = events.firstWhere((e) => e.id == eventId);
  final uniqueAttendees = event.attendeeUserIds.toSet().length;
  final shareCount      = shares.where((s) => s.targetId == eventId).length;
  final upcomingBonus   = event.dateTime.isAfter(DateTime.now()) ? 3.0 : 0.0;
  return (uniqueAttendees * 1.5) + (shareCount * 2.0) + upcomingBonus;
}

int clubMemberCount(String clubId) =>
    subscriptions.where((s) => s.clubId == clubId).length;

int postLikeCount(String postId) =>
    likes.where((l) => l.postId == postId).length;

int postShareCount(String targetId) =>
    shares.where((s) => s.targetId == targetId).length;
