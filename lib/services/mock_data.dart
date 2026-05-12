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
  Club(id: 'c1',  name: 'Arkeoloji ve Sanat Tarihi Kulübü (KUARHA)', description: 'Exploring Koç University\'s rich history through archaeology, art history exhibitions and site visits across Turkey.',          adminUserIds: ['cadmin2']),
  Club(id: 'c2',  name: 'Atatürkçü Düşünce Kulübü (KUADK)',          description: 'Promoting Atatürk\'s principles and the ideals of the Turkish Republic through talks, panels and cultural events.',            adminUserIds: ['cadmin3']),
  Club(id: 'c3',  name: 'Beşeri Bilimler Kulübü (KUBBE)',            description: 'Bringing together students passionate about literature, philosophy, history and the humanities for seminars and reading groups.',  adminUserIds: ['cadmin4']),
  Club(id: 'c4',  name: 'Bilgisayar Kulübü (KUACM)',                 description: 'Hackathons, coding workshops, tech talks and open-source projects. Open to all skill levels — from beginner to pro.',            adminUserIds: ['cadmin5']),
  Club(id: 'c5',  name: 'Dağcılık Kulübü (KUDAK)',                   description: 'Weekend hikes, technical climbing courses and multi-day expeditions to mountains across Turkey and beyond.',                      adminUserIds: ['cadmin6']),
  Club(id: 'c6',  name: 'Dans Kulübü (KUDans)',                      description: 'Salsa, hip-hop, contemporary and traditional dances — performances, workshops and weekly practice sessions for everyone.',        adminUserIds: ['cadmin7']),
  Club(id: 'c7',  name: 'Ekonomi Kulübü',                            description: 'Economics talks, case competitions, finance workshops and networking events with industry professionals.',                        adminUserIds: ['cadmin8']),
  Club(id: 'c8',  name: 'Ekonomi ve Politika Kulübü (EkoPolitik)',   description: 'At the intersection of economics and politics — panel discussions, policy briefings and guest speaker events.',                   adminUserIds: ['cadmin9']),
  Club(id: 'c9',  name: 'Ebru Kulübü',                               description: 'Learn the traditional Turkish art of marbling. Weekly sessions in our fully equipped studio with all materials provided.',       adminUserIds: ['cadmin10']),
  Club(id: 'c10', name: 'Felsefe Topluluğu',                         description: 'Philosophy reading groups, Socratic circles, and lectures covering continental and analytic traditions.',                        adminUserIds: ['cadmin11']),
  Club(id: 'c11', name: 'Fenerbahçeliler Topluluğu',                 description: 'The official Fenerbahçe supporter community at Koç — match screenings, fan events and friendly debates.',                       adminUserIds: ['cadmin12']),
  Club(id: 'c12', name: 'Folklör Kulübü',                            description: 'Keeping Turkish folk dance traditions alive through regular rehearsals, costumes and performances at campus events.',             adminUserIds: ['cadmin13']),
  Club(id: 'c13', name: 'Fotoğraf Kulübü (KUFoto)',                  description: 'Campus photo walks, darkroom sessions, editing workshops and an annual exhibition showcasing student photography.',              adminUserIds: ['cadmin14']),
  Club(id: 'c14', name: 'Endüstri Mühendisliği Kulübü (IES)',        description: 'Tabletop RPG sessions, world-building, character creation and story-driven campaigns every week.',                               adminUserIds: ['cadmin15']),
  Club(id: 'c15', name: 'Girişimcilik Kulübü',                       description: 'Entrepreneurship workshops, startup pitch events, mentorship programs and connections with the Koç innovation ecosystem.',       adminUserIds: ['cadmin16']),
  Club(id: 'c16', name: 'Hemşirelik Kulübü',                         description: 'Supporting nursing students with study groups, clinical preparation resources and community health awareness campaigns.',          adminUserIds: ['cadmin17']),
  Club(id: 'c17', name: 'Hukuk Kulübü',                              description: 'Moot court competitions, legal seminars, guest lawyer talks and support for students interested in law careers.',                adminUserIds: ['cadmin18']),
  Club(id: 'c18', name: 'İşletme Kulübü',                            description: 'Business case competitions, corporate talks, CV and interview workshops and networking with KU alumni in business.',             adminUserIds: ['cadmin19']),
  Club(id: 'c19', name: 'Kadın Dayanışma Kulübü',                    description: 'Promoting gender equality and women\'s rights through awareness campaigns, workshops and community support initiatives.',         adminUserIds: ['cadmin20']),
  Club(id: 'c20', name: 'Kadın Mühendisler Kulübü (KUSWE)',          description: 'Empowering women in STEM — mentorship, industry visits, career panels and an annual Women in Engineering summit.',               adminUserIds: ['cadmin21']),
  Club(id: 'c21', name: 'Kimya Biyoloji Mühendisliği Kulübü (AIChE)',description: 'Chemical and biological engineering talks, lab tours, AIChE chapter competitions and career development sessions.',             adminUserIds: ['cadmin22']),
  Club(id: 'c22', name: 'KU Gönüllüleri',                            description: 'Volunteering at schools, hospitals, animal shelters and environmental projects — making a difference in the community.',         adminUserIds: ['cadmin23']),
  Club(id: 'c23', name: 'KU Kartalları Kulübü',                      description: 'The official Koç University sports fan community — supporting all KU teams across every league and tournament.',                adminUserIds: ['cadmin24']),
  Club(id: 'c24', name: 'Kuir Kulübü',                               description: 'A safe and supportive community for LGBTQ+ students at Koç — events, discussions and solidarity initiatives.',                  adminUserIds: ['cadmin25']),
  Club(id: 'c25', name: 'Kürt Dili Kulübü',                          description: 'Celebrating Kurdish language and culture through language classes, cultural nights, music and literature events.',               adminUserIds: ['cadmin26']),
  Club(id: 'c26', name: 'Makine Mühendisliği Topluluğu (KUMech)',    description: 'Robot design competitions, mechanical workshops, industry visits and career support for mechanical engineering students.',        adminUserIds: ['cadmin27']),
  Club(id: 'c27', name: 'Münazara Kulübü',                           description: 'British Parliamentary and Oxford-style debates, public speaking training and inter-university tournament participation.',          adminUserIds: ['cadmin28']),
  Club(id: 'c28', name: 'Müzik Kulübü (KÜMK)',                       description: 'Weekly jam sessions, open mic nights, recording studio access and live performances for musicians of all genres.',               adminUserIds: ['cadmin29']),
  Club(id: 'c29', name: 'Müzikal Kulübü',                            description: 'Full-scale musical theatre productions — acting, singing, dancing and stage management, open to all students.',                  adminUserIds: ['cadmin30']),
  Club(id: 'c30', name: 'Nörolojik Bilimler Topluluğu (KU-SIGN)',    description: 'Neuroscience seminars, brain awareness campaigns, research talks and clinical shadowing opportunities for students.',            adminUserIds: ['cadmin31']),
  Club(id: 'c31', name: 'Orkestra Kulübü',                           description: 'A full student orchestra performing classical and contemporary pieces, with weekly rehearsals and semester concerts.',             adminUserIds: ['cadmin32']),
  Club(id: 'c32', name: 'Pazarlama Kulübü',                          description: 'Marketing case studies, brand strategy workshops, social media campaigns and connections with leading marketing professionals.',   adminUserIds: ['cadmin33']),
  Club(id: 'c33', name: 'Radyo Kulübü',                              description: 'Student-run radio shows, podcast production, DJ workshops and live broadcasting from the KU campus studio.',                    adminUserIds: ['cadmin34']),
  Club(id: 'c34', name: 'Resim Kulübü',                              description: 'Painting, drawing, watercolour and mixed media workshops with a semester-end gallery exhibition on campus.',                     adminUserIds: ['cadmin35']),
  Club(id: 'c35', name: 'Sinema Kulübü',                             description: 'Weekly film screenings, director retrospectives, short film productions and a campus film festival every spring.',              adminUserIds: ['cadmin36']),
  Club(id: 'c36', name: 'Sosyal Aktiviteler Kulübü',                 description: 'Campus events, game nights, trips, social mixers — connecting students across faculties and creating lasting friendships.',       adminUserIds: ['cadmin37']),
  Club(id: 'c37', name: 'Tarih Kulübü',                              description: 'Historical seminars, documentary screenings, debates on key events and trips to historical sites in Turkey.',                    adminUserIds: ['cadmin38']),
  Club(id: 'c38', name: 'Tıp Öğrencileri Birliği (KUTÖB)',           description: 'Supporting medical students through study groups, clinical skill workshops, research support and USMLE preparation.',            adminUserIds: ['cadmin39']),
  Club(id: 'c39', name: 'Tiyatro Kulübü',                            description: 'Full theatrical productions, acting workshops, improvisation sessions and annual performances on the KU stage.',                 adminUserIds: ['cadmin40']),
  Club(id: 'c40', name: 'Türk Araştırmaları Topluluğu',              description: 'Research and discussion on Turkish history, culture, foreign policy and contemporary issues through seminars and publications.',  adminUserIds: ['cadmin41']),
  Club(id: 'c41', name: 'Türk Halk Müziği Kulübü (THM)',             description: 'Preserving Turkish folk music with saz sessions, folk song rehearsals and performances at campus and community events.',         adminUserIds: ['cadmin42']),
  Club(id: 'c42', name: 'HAKANS_CLUB',                               description: 'Hakan\'s personal club.',                                                                                                           adminUserIds: ['cadmin1']),
];


// ─── Board Member Requests ────────────────────────────────────────────────────

/// All board-member applications, past and present.
/// Persisted via ContentStore; starts empty (no seed requests needed).
final boardMemberRequests = <BoardMemberRequest>[];

// ─── Events ───────────────────────────────────────────────────────────────────

final events = [
  Event(id: 'ev0a', clubId: 'c28', title: 'Jazz Jam Session',
    description: 'Drop-in jazz jam happening right now in SOS B Atelier. All instruments welcome. Come play or just listen!',
    location: 'SOS B Atelier',
    dateTime: DateTime.now().subtract(const Duration(minutes: 30)),
    endTime: DateTime.now().add(const Duration(hours: 2)),
    attendeeUserIds: ['u1', 'u3', 'u5'],
    rsvpTimestamps: {'u1': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'u3': DateTime.now().subtract(const Duration(hours: 18)).toIso8601String(), 'u5': DateTime.now().subtract(const Duration(hours: 12)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/jazzjam/800/500'),

  Event(id: 'ev0b', clubId: 'c39', title: 'Doğaçlama Tiyatro Gecesi',
    description: 'Improv theatre night in full swing — walk in anytime, no ticket needed.',
    location: 'SOS B206',
    dateTime: DateTime.now().subtract(const Duration(hours: 1)),
    endTime: DateTime.now().add(const Duration(hours: 1, minutes: 30)),
    attendeeUserIds: ['u2', 'u4'],
    rsvpTimestamps: {'u2': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u4': DateTime.now().subtract(const Duration(days: 1)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/improv_theatre/800/500'),

  Event(id: 'ev1', clubId: 'c4', title: 'Hack-KU 2025',
    description: 'Our annual 48-hour hackathon is back! Form teams of up to 4, pick a challenge track and build something amazing. Prizes, mentors and free food all weekend. All skill levels welcome!',
    location: 'ENG Building, Main Hall',
    dateTime: DateTime.now().add(const Duration(days: 5)),
    endTime: DateTime.now().add(const Duration(days: 7)),
    attendeeUserIds: ['u2', 'u4', 'u5'],
    rsvpTimestamps: {'u2': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u4': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u5': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/hackku2025/800/500',
    tags: ['Hackathon', 'Free Food', 'Prizes', 'All Night'],
    scheduleGated: true,
    schedule: [
      EventSlot(time: DateTime.now().add(const Duration(days: 5)), title: 'Opening & Team Formation'),
      EventSlot(time: DateTime.now().add(const Duration(days: 5, hours: 2)), title: 'Google Cloud Workshop', subtitle: 'Google Developer Expert', isHighlighted: true),
      EventSlot(time: DateTime.now().add(const Duration(days: 5, hours: 5)), title: 'Mentor Speed Dating'),
      EventSlot(time: DateTime.now().add(const Duration(days: 5, hours: 8)), title: 'AWS Serverless Deep-Dive', subtitle: 'Amazon Web Services', isHighlighted: true),
      EventSlot(time: DateTime.now().add(const Duration(days: 6, hours: 4)), title: 'Project Submissions Due'),
      EventSlot(time: DateTime.now().add(const Duration(days: 6, hours: 6)), title: 'Final Presentations & Judging'),
      EventSlot(time: DateTime.now().add(const Duration(days: 6, hours: 9)), title: 'Awards Ceremony & After-Party', isHighlighted: true),
    ]),

  Event(id: 'ev2', clubId: 'c13', title: 'Bahar Fotoğraf Sergisi',
    description: 'Submit up to three prints for our spring gallery. Landscape, portrait, street — all genres accepted. Selected works will be displayed in the SOS atrium for two weeks.',
    location: 'SOS Atrium Gallery',
    dateTime: DateTime.now().add(const Duration(days: 8)),
    endTime: DateTime.now().add(const Duration(days: 8, hours: 4)),
    attendeeUserIds: ['u1', 'u4', 'u5'],
    rsvpTimestamps: {'u1': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'u4': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u5': DateTime.now().subtract(const Duration(days: 1)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/photoexhibit_spring/800/500'),

  Event(id: 'ev3', clubId: 'c5', title: 'Uludağ Kış Tırmanışı',
    description: 'A two-day winter ascent of Uludağ with certified guides. Equipment rental available. Limited to 12 participants — sign up fast.',
    location: 'Uludağ, Bursa (departure from KU main gate)',
    dateTime: DateTime.now().add(const Duration(days: 14)),
    endTime: DateTime.now().add(const Duration(days: 16)),
    attendeeUserIds: ['u1', 'u2', 'u3'],
    rsvpTimestamps: {'u1': DateTime.now().subtract(const Duration(days: 7)).toIso8601String(), 'u2': DateTime.now().subtract(const Duration(days: 6)).toIso8601String(), 'u3': DateTime.now().subtract(const Duration(days: 4)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/uludag_climb/800/500'),

  Event(id: 'ev4', clubId: 'c27', title: 'Üniversitelerarası Münazara',
    description: 'Koç University hosts this year\'s inter-university debate championship. Motion: "This house believes AI will make democratic elections obsolete." Come watch or compete!',
    location: 'SOS B140 Amphitheatre',
    dateTime: DateTime.now().add(const Duration(days: 10)),
    endTime: DateTime.now().add(const Duration(days: 10, hours: 3)),
    attendeeUserIds: ['u3', 'u7', 'u9', 'u14'],
    rsvpTimestamps: {'u3': DateTime.now().subtract(const Duration(days: 8)).toIso8601String(), 'u7': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'u9': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u14': DateTime.now().subtract(const Duration(days: 2)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/debate_champ/800/500'),

  Event(id: 'ev5', clubId: 'c28', title: 'Open Mic Night',
    description: 'Sign up to perform or come and enjoy live music by fellow students. Guitar, piano, vocals, beat-box — everything welcome. Doors open at 8 PM.',
    location: 'SOS B Atelier',
    dateTime: DateTime.now().add(const Duration(days: 3)),
    endTime: DateTime.now().add(const Duration(days: 3, hours: 3)),
    attendeeUserIds: ['u2', 'u4', 'u5', 'u8', 'u13'],
    rsvpTimestamps: {'u2': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u4': DateTime.now().subtract(const Duration(days: 1, hours: 10)).toIso8601String(), 'u5': DateTime.now().subtract(const Duration(hours: 8)).toIso8601String(), 'u8': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'u13': DateTime.now().subtract(const Duration(hours: 20)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/openmic_night/800/500'),

  Event(id: 'ev6', clubId: 'c15', title: 'Startup Pitch Night',
    description: 'Got an idea? Pitch it to a panel of investors and mentors in 3 minutes. No slides required — just your vision. Open to all students.',
    location: 'SOS B140 Amphitheatre',
    dateTime: DateTime.now().add(const Duration(days: 2)),
    endTime: DateTime.now().add(const Duration(days: 2, hours: 2)),
    attendeeUserIds: ['u1', 'u2', 'u5', 'u7', 'u11', 'u13'],
    rsvpTimestamps: {'u1': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u2': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u5': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u7': DateTime.now().subtract(const Duration(days: 3, hours: 5)).toIso8601String(), 'u11': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'u13': DateTime.now().subtract(const Duration(hours: 14)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/startup_pitch/800/500',
    tags: ['Pitching', 'Networking', 'Entrepreneurship'],
    guestSpeaker: 'Kerem Alper — Co-founder, Getir',
    schedule: [
      EventSlot(time: DateTime.now().add(const Duration(days: 2)), title: 'Opening'),
      EventSlot(time: DateTime.now().add(const Duration(days: 2, minutes: 30)), title: 'Student Pitches Round 1'),
      EventSlot(time: DateTime.now().add(const Duration(days: 2, hours: 1)), title: 'Keynote by Kerem Alper', isHighlighted: true),
      EventSlot(time: DateTime.now().add(const Duration(days: 2, hours: 1, minutes: 30)), title: 'Student Pitches Round 2'),
      EventSlot(time: DateTime.now().add(const Duration(days: 2, hours: 2)), title: 'Networking & Investor Q&A'),
    ]),

  Event(id: 'ev7', clubId: 'c22', title: 'Kampüs Temizlik Günü',
    description: 'Join 50+ volunteers to clean up the campus gardens and shoreline. Gloves and bags provided. A great way to give back — and it counts for community service hours.',
    location: 'KU Main Gate',
    dateTime: DateTime.now().add(const Duration(days: 1)),
    endTime: DateTime.now().add(const Duration(days: 1, hours: 3)),
    attendeeUserIds: ['u5', 'u6', 'u8', 'u12', 'u14'],
    rsvpTimestamps: {'u5': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(), 'u6': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u8': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u12': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'u14': DateTime.now().subtract(const Duration(hours: 10)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/campus_cleanup/800/500'),

  Event(id: 'ev8', clubId: 'c20', title: 'Women in Tech Panel',
    description: 'Four engineers and entrepreneurs share their journeys. Q&A session and networking with refreshments afterward. Everyone is welcome.',
    location: 'ENG Z27',
    dateTime: DateTime.now().add(const Duration(days: 4)),
    endTime: DateTime.now().add(const Duration(days: 4, hours: 2)),
    attendeeUserIds: ['u1', 'u4', 'u5', 'u6', 'u8', 'u10', 'u12'],
    rsvpTimestamps: {'u1': DateTime.now().subtract(const Duration(days: 6)).toIso8601String(), 'u4': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'u5': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'u6': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u8': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u12': DateTime.now().subtract(const Duration(days: 1, hours: 6)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/women_tech_panel/800/500',
    tags: ['Panel', 'Career', 'Networking', 'Women in Tech'],
    guestSpeaker: 'Dr. Ayşe Mumcu — AI Research Lead, Google DeepMind'),

  Event(id: 'ev9', clubId: 'c34', title: 'Açık Atölye: Suluboya',
    description: 'Drop in, pick up a brush, and paint whatever moves you. All materials on the table. No instruction — just creative freedom. Studio stays open until midnight.',
    location: 'Arts Building Studio 2',
    dateTime: DateTime.now().add(const Duration(hours: 4)),
    endTime: DateTime.now().add(const Duration(hours: 10)),
    attendeeUserIds: ['u3', 'u6', 'u10'],
    rsvpTimestamps: {'u3': DateTime.now().subtract(const Duration(hours: 6)).toIso8601String(), 'u6': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/watercolour_atelier/800/500'),

  Event(id: 'ev10', clubId: 'c36', title: 'Campus Trivia Night',
    description: 'Form teams of up to 5 and battle it out across 6 rounds of campus trivia. Themes include KU history, pop culture, science and memes. Prizes for the top 3 teams.',
    location: 'SCI 103',
    dateTime: DateTime.now().add(const Duration(days: 2, hours: 3)),
    endTime: DateTime.now().add(const Duration(days: 2, hours: 5)),
    attendeeUserIds: ['u2', 'u4', 'u5', 'u9', 'u11', 'u13', 'u15'],
    rsvpTimestamps: {'u2': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u4': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u5': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'u9': DateTime.now().subtract(const Duration(hours: 30)).toIso8601String(), 'u11': DateTime.now().subtract(const Duration(hours: 18)).toIso8601String(), 'u13': DateTime.now().subtract(const Duration(hours: 12)).toIso8601String(), 'u15': DateTime.now().subtract(const Duration(hours: 6)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/trivia_night/800/500'),

  Event(id: 'ev11', clubId: 'c11', title: 'Fenerbahçe — Galatasaray Derbisi',
    description: 'Anadolu Efes - Galatasaray karşılaşmasını Kafeterya A\'daki büyük ekranda birlikte izliyoruz. Atıştırmalıklar kulüpten. Yanında formanı getir!',
    location: 'Cafeteria A',
    dateTime: DateTime.now().subtract(const Duration(minutes: 20)),
    endTime: DateTime.now().add(const Duration(hours: 2)),
    attendeeUserIds: ['u3', 'u5', 'u7', 'u9', 'u11', 'u13', 'u14', 'u15'],
    rsvpTimestamps: {'u3': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'u5': DateTime.now().subtract(const Duration(hours: 10)).toIso8601String(), 'u7': DateTime.now().subtract(const Duration(days: 1, hours: 2)).toIso8601String(), 'u9': DateTime.now().subtract(const Duration(hours: 8)).toIso8601String(), 'u11': DateTime.now().subtract(const Duration(hours: 6)).toIso8601String(), 'u13': DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(), 'u14': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(), 'u15': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/fb_gs_derby/800/500'),

  Event(id: 'ev12', clubId: 'c5', title: 'Koşu Kulübü Sabah Antrenmanı',
    description: 'Weekly morning run departing from the gym entrance. 5 km loop around campus. All paces welcome. Bring water and trainers.',
    location: 'Sports Center',
    dateTime: DateTime.now().add(const Duration(days: 1, hours: 6)),
    endTime: DateTime.now().add(const Duration(days: 1, hours: 8)),
    attendeeUserIds: ['u2', 'u6', 'u8', 'u12'],
    rsvpTimestamps: {'u2': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u6': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'u8': DateTime.now().subtract(const Duration(hours: 20)).toIso8601String(), 'u12': DateTime.now().subtract(const Duration(hours: 10)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/morning_run/800/500'),

  Event(id: 'ev13', clubId: 'c4', title: 'FastAPI Kodlama Atölyesi',
    description: 'Hands-on workshop: build a REST API with FastAPI and deploy it on Railway. Bring your laptop. No prior Python needed — just curiosity.',
    location: 'Library Lab 3',
    dateTime: DateTime.now().add(const Duration(hours: 2)),
    endTime: DateTime.now().add(const Duration(hours: 5)),
    attendeeUserIds: ['u1', 'u2', 'u3', 'u4', 'u5'],
    rsvpTimestamps: {'u1': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u2': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u3': DateTime.now().subtract(const Duration(days: 2, hours: 6)).toIso8601String(), 'u4': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'u5': DateTime.now().subtract(const Duration(hours: 4)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/coding_workshop/800/500'),

  Event(id: 'ev14', clubId: 'c16', title: 'Sağlık Tarama Standı',
    description: 'Free blood pressure, BMI and nutrition checks at the main gate. Our nursing club volunteers are on site 09:00–17:00. No appointment needed.',
    location: 'KU Main Gate',
    dateTime: DateTime.now().subtract(const Duration(hours: 2)),
    endTime: DateTime.now().add(const Duration(hours: 6)),
    attendeeUserIds: ['u6', 'u8', 'u10', 'u12', 'u14'],
    rsvpTimestamps: {'u6': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u8': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(hours: 20)).toIso8601String(), 'u12': DateTime.now().subtract(const Duration(hours: 15)).toIso8601String(), 'u14': DateTime.now().subtract(const Duration(hours: 8)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/health_fair/800/500'),

  // ── Past events (completed) ───────────────────────────────────────────────
  Event(id: 'ev_past1', clubId: 'c4', title: 'Flutter Dev Workshop',
    description: 'Three-hour hands-on intro to Flutter — state management, navigation and widgets. Hugely popular with 40+ attendees!',
    location: 'ENG B13',
    dateTime: DateTime.now().subtract(const Duration(days: 5, hours: 3)),
    endTime: DateTime.now().subtract(const Duration(days: 5)),
    attendeeUserIds: ['u1', 'u2', 'u3', 'u4', 'u5', 'u7', 'u9', 'u11', 'u13', 'u15'],
    rsvpTimestamps: {'u1': DateTime.now().subtract(const Duration(days: 8)).toIso8601String(), 'u2': DateTime.now().subtract(const Duration(days: 7)).toIso8601String(), 'u5': DateTime.now().subtract(const Duration(days: 6)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/flutter_workshop_past/800/500'),

  Event(id: 'ev_past2', clubId: 'c27', title: 'Bölge Münazara Şampiyonası',
    description: 'We won first place at the regional championship! Unanimous panel decision — Koç goes to nationals.',
    location: 'İstanbul Teknik Üniversitesi',
    dateTime: DateTime.now().subtract(const Duration(days: 4, hours: 5)),
    endTime: DateTime.now().subtract(const Duration(days: 4)),
    attendeeUserIds: ['u3', 'u7', 'u14'],
    rsvpTimestamps: {'u3': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(), 'u7': DateTime.now().subtract(const Duration(days: 9)).toIso8601String(), 'u14': DateTime.now().subtract(const Duration(days: 8)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/debate_regionals/800/500'),

  Event(id: 'ev_past3', clubId: 'c6', title: 'Salsa Dance Workshop',
    description: 'Two-hour beginner salsa workshop with professional instructor. 60 participants — our biggest single workshop ever!',
    location: 'Sports Hall B',
    dateTime: DateTime.now().subtract(const Duration(days: 6, hours: 2)),
    endTime: DateTime.now().subtract(const Duration(days: 6)),
    attendeeUserIds: ['u4', 'u6', 'u8', 'u12', 'u14'],
    rsvpTimestamps: {'u4': DateTime.now().subtract(const Duration(days: 9)).toIso8601String(), 'u6': DateTime.now().subtract(const Duration(days: 8)).toIso8601String(), 'u8': DateTime.now().subtract(const Duration(days: 7)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/salsa_workshop/800/500'),

  // ── Live now (additional) ───────────────────────────────────────────────────

  Event(id: 'ev_live1', clubId: 'c33', title: 'KU Radyo Canlı Yayın',
    description: 'KU Campus Radio is live! Tune in on Spotify or come hang out in the studio. Guest DJ set + live interviews with club presidents.',
    location: 'SOS B111 — Radyo Stüdyosu',
    dateTime: DateTime.now().subtract(const Duration(hours: 1)),
    endTime: DateTime.now().add(const Duration(hours: 3)),
    attendeeUserIds: ['u7', 'u13', 'u15'],
    rsvpTimestamps: {'u7': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'u13': DateTime.now().subtract(const Duration(hours: 20)).toIso8601String(), 'u15': DateTime.now().subtract(const Duration(hours: 10)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/radio_live/800/500'),

  Event(id: 'ev_live2', clubId: 'c12', title: 'Folklör Prova Açık Kapı',
    description: 'Weekly rehearsal open to spectators! Watch our zeybek and horon teams prepare for the Spring Showcase. No ticket needed — just walk in.',
    location: 'Sports Hall A',
    dateTime: DateTime.now().subtract(const Duration(minutes: 45)),
    endTime: DateTime.now().add(const Duration(hours: 1, minutes: 15)),
    attendeeUserIds: ['u8', 'u12', 'u6'],
    rsvpTimestamps: {'u8': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u12': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'u6': DateTime.now().subtract(const Duration(hours: 6)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/folklor_rehearsal/800/500'),

  // ── Today (hours away) ─────────────────────────────────────────────────────

  Event(id: 'ev_today1', clubId: 'c35', title: 'Sinema Gecesi: "Bir Zamanlar Anadolu\'da"',
    description: 'Week 3 of our Nuri Bilge Ceylan retrospective. Screening followed by a 30-minute discussion with a film critic. Free for all KU students.',
    location: 'SOS B140 Amphitheatre',
    dateTime: DateTime.now().add(const Duration(hours: 3)),
    endTime: DateTime.now().add(const Duration(hours: 6)),
    attendeeUserIds: ['u1', 'u3', 'u5', 'u7', 'u10'],
    rsvpTimestamps: {'u1': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u3': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u5': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'u7': DateTime.now().subtract(const Duration(hours: 20)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(hours: 14)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/cinema_screening/800/500'),

  Event(id: 'ev_today2', clubId: 'c10', title: 'Felsefe Okuma Halkası',
    description: 'Week 4 of our Nietzsche series — "İyi ve Kötünün Ötesinde." Reading notes shared on Discord. Open to all, no philosophy background needed.',
    location: 'SOS B108',
    dateTime: DateTime.now().add(const Duration(hours: 5)),
    endTime: DateTime.now().add(const Duration(hours: 7)),
    attendeeUserIds: ['u6', 'u10', 'u7'],
    rsvpTimestamps: {'u6': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u7': DateTime.now().subtract(const Duration(days: 1)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/philosophy_circle/800/500',
    tags: ['Reading Group', 'Discussion', 'Philosophy']),

  Event(id: 'ev_today3', clubId: 'c29', title: '"Waiting for Godot" Final Prova',
    description: 'Last full run-through before opening night. Spectators welcome — give us your honest feedback! We\'ll provide snacks.',
    location: 'KU Sahnesi',
    dateTime: DateTime.now().add(const Duration(hours: 6)),
    endTime: DateTime.now().add(const Duration(hours: 9)),
    attendeeUserIds: ['u2', 'u8', 'u14'],
    rsvpTimestamps: {'u2': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'u8': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u14': DateTime.now().subtract(const Duration(days: 2)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/theatre_rehearsal/800/500'),

  // ── Tomorrow ──────────────────────────────────────────────────────────────

  Event(id: 'ev_tom1', clubId: 'c17', title: 'Hukuk Kulübü Moot Court',
    description: 'Practice session for our upcoming inter-university Moot Court competition. Watch our teams argue a real constitutional case in front of a judge panel.',
    location: 'SOS B206',
    dateTime: DateTime.now().add(const Duration(days: 1, hours: 2)),
    endTime: DateTime.now().add(const Duration(days: 1, hours: 5)),
    attendeeUserIds: ['u3', 'u9', 'u10', 'u14'],
    rsvpTimestamps: {'u3': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'u9': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u14': DateTime.now().subtract(const Duration(days: 1)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/moot_court/800/500',
    tags: ['Competition', 'Debate', 'Legal']),

  Event(id: 'ev_tom2', clubId: 'c9', title: 'Ebru Atölyesi — Başlangıç',
    description: 'Learn the ancient Turkish art of paper marbling in this beginner-friendly session. All inks, combs and paper provided. Leave with your own handcrafted art piece!',
    location: 'SOS Art Studio 1',
    dateTime: DateTime.now().add(const Duration(days: 1, hours: 4)),
    endTime: DateTime.now().add(const Duration(days: 1, hours: 6)),
    attendeeUserIds: ['u4', 'u6', 'u10', 'u12'],
    rsvpTimestamps: {'u4': DateTime.now().subtract(const Duration(days: 6)).toIso8601String(), 'u6': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u12': DateTime.now().subtract(const Duration(days: 2)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/ebru_workshop/800/500'),

  Event(id: 'ev_tom3', clubId: 'c8', title: 'Yapay Zeka ve Demokrasi Paneli',
    description: 'Cross-disciplinary panel with speakers from Computer Science, Economics and Political Science. "Will AI make democratic elections obsolete?" — sharp debate guaranteed.',
    location: 'SOS B140 Amphitheatre',
    dateTime: DateTime.now().add(const Duration(days: 1, hours: 10)),
    endTime: DateTime.now().add(const Duration(days: 1, hours: 12)),
    attendeeUserIds: ['u1', 'u2', 'u5', 'u7', 'u9', 'u13'],
    rsvpTimestamps: {'u1': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u2': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u5': DateTime.now().subtract(const Duration(hours: 8)).toIso8601String(), 'u7': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u9': DateTime.now().subtract(const Duration(days: 1, hours: 6)).toIso8601String(), 'u13': DateTime.now().subtract(const Duration(hours: 18)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/ai_democracy_panel/800/500',
    tags: ['Panel', 'AI', 'Discussion'],
    guestSpeaker: 'Prof. Selim Balcısoy — Koç University CS'),

  // ── Later this week ───────────────────────────────────────────────────────

  Event(id: 'ev_week1', clubId: 'c31', title: 'Orkestra Bahar Konseri',
    description: 'Our annual Spring Concert featuring Brahms\'s String Quartet and Dvořák\'s Symphony No. 9. 45 student musicians performing on the KU Amphitheatre stage. Free admission.',
    location: 'KU Amfitiyatrosu',
    dateTime: DateTime.now().add(const Duration(days: 3, hours: 8)),
    endTime: DateTime.now().add(const Duration(days: 3, hours: 11)),
    attendeeUserIds: ['u1', 'u3', 'u5', 'u6', 'u8', 'u10', 'u14'],
    rsvpTimestamps: {'u1': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(), 'u3': DateTime.now().subtract(const Duration(days: 8)).toIso8601String(), 'u5': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u6': DateTime.now().subtract(const Duration(days: 7)).toIso8601String(), 'u8': DateTime.now().subtract(const Duration(days: 6)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'u14': DateTime.now().subtract(const Duration(days: 4)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/orchestra_concert/800/500',
    tags: ['Concert', 'Classical', 'Free Entry']),

  Event(id: 'ev_week2', clubId: 'c26', title: 'Robolig 2025 Tasarım Workshopu',
    description: 'KUMech\'s robot design workshop — mechanical, electronics and software teams all in one room. Hands-on building session for the upcoming Robolig competition. Beginners welcome!',
    location: 'MFG Manufacturing Lab',
    dateTime: DateTime.now().add(const Duration(days: 4, hours: 2)),
    endTime: DateTime.now().add(const Duration(days: 4, hours: 5)),
    attendeeUserIds: ['u7', 'u9', 'u13', 'u15'],
    rsvpTimestamps: {'u7': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'u9': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u13': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u15': DateTime.now().subtract(const Duration(days: 2)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/robotics_workshop/800/500',
    tags: ['Workshop', 'Robotics', 'Engineering', 'Hands-on']),

  Event(id: 'ev_week3', clubId: 'c14', title: 'D&D Karakter Yaratma Gecesi',
    description: 'Starting our new campaign "Karanlığın Kıyısı"! Character creation session — pre-made character sheets available for beginners. Bring snacks and dice if you have them.',
    location: 'SOS B210',
    dateTime: DateTime.now().add(const Duration(days: 4, hours: 9)),
    endTime: DateTime.now().add(const Duration(days: 4, hours: 13)),
    attendeeUserIds: ['u2', 'u5', 'u11'],
    rsvpTimestamps: {'u2': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u5': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'u11': DateTime.now().subtract(const Duration(days: 2)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/dnd_session/800/500'),

  Event(id: 'ev_week4', clubId: 'c21', title: 'AIChE Kimya Lab Turu',
    description: 'Exclusive guided tour of the Chemical Engineering research labs. See ongoing thesis projects, talk to PhD students and learn about career paths in chemical engineering.',
    location: 'ENG B Wing — Research Labs',
    dateTime: DateTime.now().add(const Duration(days: 5, hours: 3)),
    endTime: DateTime.now().add(const Duration(days: 5, hours: 5)),
    attendeeUserIds: ['u9', 'u12', 'u15'],
    rsvpTimestamps: {'u9': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u12': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u15': DateTime.now().subtract(const Duration(days: 2)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/chem_lab_tour/800/500'),

  Event(id: 'ev_week5', clubId: 'c32', title: 'Pazarlama Kulübü: McKinsey Vaka Atölyesi',
    description: 'Exclusive case study workshop with McKinsey & Company consultants. 20 selected participants will analyze a real business problem and present their solutions.',
    location: 'SOS B140 Amphitheatre',
    dateTime: DateTime.now().add(const Duration(days: 5, hours: 7)),
    endTime: DateTime.now().add(const Duration(days: 5, hours: 10)),
    attendeeUserIds: ['u2', 'u7', 'u9', 'u13'],
    rsvpTimestamps: {'u2': DateTime.now().subtract(const Duration(days: 6)).toIso8601String(), 'u7': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'u9': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u13': DateTime.now().subtract(const Duration(days: 3)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/mckinsey_case/800/500',
    tags: ['Workshop', 'Case Study', 'Career', 'Consulting'],
    guestSpeaker: 'McKinsey Istanbul Consulting Team',
    scheduleGated: true,
    schedule: [
      EventSlot(time: DateTime.now().add(const Duration(days: 5, hours: 7)), title: 'Introduction to Case Frameworks', subtitle: 'McKinsey Istanbul', isHighlighted: true),
      EventSlot(time: DateTime.now().add(const Duration(days: 5, hours: 8)), title: 'Live Case Cracking'),
      EventSlot(time: DateTime.now().add(const Duration(days: 5, hours: 8, minutes: 45)), title: 'Group Breakout'),
      EventSlot(time: DateTime.now().add(const Duration(days: 5, hours: 9, minutes: 30)), title: 'Feedback & Debrief with McKinsey Analysts', isHighlighted: true),
      EventSlot(time: DateTime.now().add(const Duration(days: 5, hours: 10)), title: 'Networking & Coffee'),
    ]),

  Event(id: 'ev_week6', clubId: 'c41', title: 'Saz Atölyesi — Orta Seviye',
    description: 'Intermediate saz session covering makam theory, tremolo technique and a new folk song. Saz instruments available to borrow. Bring your enthusiasm!',
    location: 'SOS B107',
    dateTime: DateTime.now().add(const Duration(days: 6, hours: 4)),
    endTime: DateTime.now().add(const Duration(days: 6, hours: 6)),
    attendeeUserIds: ['u8', 'u14'],
    rsvpTimestamps: {'u8': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'u14': DateTime.now().subtract(const Duration(days: 3)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/saz_workshop/800/500'),

  // ── Next week ─────────────────────────────────────────────────────────────

  Event(id: 'ev_next1', clubId: 'c37', title: 'Osmanlı Tarih Workshopu',
    description: 'Prof. Dr. Ayşe Yıldız (İstanbul Üniversitesi) joins us for a hands-on archive session. Work with real 500-year-old Ottoman documents. Capacity: 20 students.',
    location: 'SOS B209 — Seminar Room',
    dateTime: DateTime.now().add(const Duration(days: 9, hours: 3)),
    endTime: DateTime.now().add(const Duration(days: 9, hours: 6)),
    attendeeUserIds: ['u3', 'u7', 'u10'],
    rsvpTimestamps: {'u3': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u7': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(days: 2)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/ottoman_workshop/800/500'),

  Event(id: 'ev_next2', clubId: 'c19', title: 'Kadın Dayanışma: Film Gösterimi',
    description: 'Screening of "Portrait of a Lady on Fire" followed by a panel discussion on gender representation in cinema. All are welcome — safe space guaranteed.',
    location: 'SOS B140 Amphitheatre',
    dateTime: DateTime.now().add(const Duration(days: 10, hours: 5)),
    endTime: DateTime.now().add(const Duration(days: 10, hours: 8)),
    attendeeUserIds: ['u6', 'u8', 'u10', 'u12'],
    rsvpTimestamps: {'u6': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'u8': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u12': DateTime.now().subtract(const Duration(days: 1)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/film_screening_panel/800/500'),

  Event(id: 'ev_next3', clubId: 'c18', title: 'İşletme Kulübü: Girişimci Söyleşisi',
    description: 'Three KU alumni who founded successful startups share their journey — the highs, the lows, and what they wish they knew as students. Networking dinner follows.',
    location: 'ENG Z27',
    dateTime: DateTime.now().add(const Duration(days: 11, hours: 7)),
    endTime: DateTime.now().add(const Duration(days: 11, hours: 10)),
    attendeeUserIds: ['u2', 'u5', 'u7', 'u9', 'u11', 'u13'],
    rsvpTimestamps: {'u2': DateTime.now().subtract(const Duration(days: 7)).toIso8601String(), 'u5': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u7': DateTime.now().subtract(const Duration(days: 6)).toIso8601String(), 'u9': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'u11': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u13': DateTime.now().subtract(const Duration(days: 3)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/startup_talk/800/500',
    tags: ['Talk', 'Entrepreneurship', 'Q&A'],
    guestSpeaker: 'Mert Koç — Co-founder & CEO, Insider'),

  Event(id: 'ev_next4', clubId: 'c24', title: 'Kuir Kulübü: Onur Haftası Açılışı',
    description: 'Opening event of Pride Week — documentary screening "Welcome to Chechnya" followed by an open discussion. Safe, supportive space for everyone. Allies welcome.',
    location: 'SOS B206',
    dateTime: DateTime.now().add(const Duration(days: 12, hours: 4)),
    endTime: DateTime.now().add(const Duration(days: 12, hours: 7)),
    attendeeUserIds: ['u3', 'u6', 'u10', 'u13'],
    rsvpTimestamps: {'u3': DateTime.now().subtract(const Duration(days: 6)).toIso8601String(), 'u6': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u13': DateTime.now().subtract(const Duration(days: 3)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/pride_opening/800/500'),

  Event(id: 'ev_next5', clubId: 'c38', title: 'KUTÖB: USMLE Step 1 Bilgi Yarışması',
    description: 'Monthly Jeopardy-style quiz night for medical students — all subjects from Biochemistry to Pathology. Great for exam prep and a chance to win tutoring hours.',
    location: 'Tıp Binası Konferans Salonu',
    dateTime: DateTime.now().add(const Duration(days: 13, hours: 6)),
    endTime: DateTime.now().add(const Duration(days: 13, hours: 8)),
    attendeeUserIds: ['u9', 'u12'],
    rsvpTimestamps: {'u9': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u12': DateTime.now().subtract(const Duration(days: 2)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/med_quiz/800/500'),

  // ── Additional past events ────────────────────────────────────────────────

  Event(id: 'ev_past4', clubId: 'c35', title: '"Uzak" Film Gösterimi',
    description: 'First night of the Nuri Bilge Ceylan retrospective. Packed room, great discussion. Next screening: "Bir Zamanlar Anadolu\'da" this week.',
    location: 'SOS B140 Amphitheatre',
    dateTime: DateTime.now().subtract(const Duration(days: 3, hours: 3)),
    endTime: DateTime.now().subtract(const Duration(days: 3)),
    attendeeUserIds: ['u1', 'u5', 'u7', 'u10', 'u13'],
    rsvpTimestamps: {'u1': DateTime.now().subtract(const Duration(days: 8)).toIso8601String(), 'u5': DateTime.now().subtract(const Duration(days: 6)).toIso8601String(), 'u7': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u13': DateTime.now().subtract(const Duration(days: 4, hours: 6)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/uzak_screening/800/500'),

  Event(id: 'ev_past5', clubId: 'c23', title: 'KU Basketbol Şampiyonluk Kutlaması',
    description: 'Campus-wide celebration of KU Basketball Team\'s championship win! Live music, free ice cream and the trophy on display. 300+ students attended.',
    location: 'KU Amfitiyatrosu',
    dateTime: DateTime.now().subtract(const Duration(days: 2, hours: 4)),
    endTime: DateTime.now().subtract(const Duration(days: 2, hours: 1)),
    attendeeUserIds: ['u3', 'u5', 'u7', 'u9', 'u11', 'u13', 'u14', 'u15'],
    rsvpTimestamps: {'u3': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u5': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u7': DateTime.now().subtract(const Duration(days: 3, hours: 6)).toIso8601String(), 'u9': DateTime.now().subtract(const Duration(days: 2, hours: 12)).toIso8601String(), 'u11': DateTime.now().subtract(const Duration(days: 3, hours: 2)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/basketball_celebration/800/500'),

  Event(id: 'ev_past6', clubId: 'c3', title: 'KUBBE Okuma Grubu: Orhan Pamuk',
    description: 'First session of our reading group discussing "Masumiyet Müzesi." Lively conversation, great snacks, 18 attendees. Next session next Wednesday 18:00.',
    location: 'SOS B108',
    dateTime: DateTime.now().subtract(const Duration(days: 4, hours: 2)),
    endTime: DateTime.now().subtract(const Duration(days: 4)),
    attendeeUserIds: ['u3', 'u6', 'u7', 'u10'],
    rsvpTimestamps: {'u3': DateTime.now().subtract(const Duration(days: 7)).toIso8601String(), 'u6': DateTime.now().subtract(const Duration(days: 6)).toIso8601String(), 'u7': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(days: 5, hours: 6)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/reading_group/800/500'),

  // ════════════════════════════════════════════════════════════════════════════
  // TODAY (Thursday) — LIVE NOW
  // ════════════════════════════════════════════════════════════════════════════

  Event(id: 'ev_th_live1', clubId: 'c4', title: 'Hackathon Kick-off Tanışma Toplantısı',
    description: 'Pre-Hack-KU meetup happening right now! Meet your future teammates, hear about this year\'s challenge tracks and grab free pizza. Teams can register on the spot.',
    location: 'ENG Building, Main Hall',
    dateTime: DateTime.now().subtract(const Duration(minutes: 40)),
    endTime: DateTime.now().add(const Duration(hours: 1, minutes: 30)),
    attendeeUserIds: ['u1', 'u2', 'u3', 'u4', 'u5', 'u7', 'u9'],
    rsvpTimestamps: {'u1': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u2': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'u3': DateTime.now().subtract(const Duration(hours: 20)).toIso8601String(), 'u4': DateTime.now().subtract(const Duration(hours: 18)).toIso8601String(), 'u5': DateTime.now().subtract(const Duration(hours: 6)).toIso8601String(), 'u7': DateTime.now().subtract(const Duration(hours: 14)).toIso8601String(), 'u9': DateTime.now().subtract(const Duration(hours: 10)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/hackathon_kickoff/800/500'),

  Event(id: 'ev_th_live2', clubId: 'c31', title: 'Orkestra Bahar Provası',
    description: 'Full orchestra rehearsal in progress — seats available for observers. Hear Dvořák and Brahms come alive as 45 student musicians prepare for next week\'s concert.',
    location: 'KU Amfitiyatrosu',
    dateTime: DateTime.now().subtract(const Duration(hours: 1, minutes: 15)),
    endTime: DateTime.now().add(const Duration(hours: 1)),
    attendeeUserIds: ['u6', 'u8', 'u14'],
    rsvpTimestamps: {'u6': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u8': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u14': DateTime.now().subtract(const Duration(days: 1)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/orchestra_rehearsal/800/500'),

  Event(id: 'ev_th_live3', clubId: 'c24', title: 'Kuir Kulübü Haftalık Buluşma',
    description: 'Weekly open social happening now — coffee, conversations and community. New faces always welcome. No agenda, just vibes and solidarity.',
    location: 'SOS B108',
    dateTime: DateTime.now().subtract(const Duration(minutes: 20)),
    endTime: DateTime.now().add(const Duration(hours: 2)),
    attendeeUserIds: ['u3', 'u6', 'u10', 'u13'],
    rsvpTimestamps: {'u3': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(), 'u6': DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(), 'u13': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/queer_gathering/800/500'),

  Event(id: 'ev_th_live4', clubId: 'c25', title: 'Kürtçe Konuşma Pratiği',
    description: 'Intermediate Kurdish (Kurmancî) conversation session in progress. Native speakers paired with learners for 90 minutes of guided conversation practice.',
    location: 'SOS B209',
    dateTime: DateTime.now().subtract(const Duration(minutes: 50)),
    endTime: DateTime.now().add(const Duration(minutes: 40)),
    attendeeUserIds: ['u7', 'u10'],
    rsvpTimestamps: {'u7': DateTime.now().subtract(const Duration(hours: 8)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(hours: 6)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/kurdish_class/800/500'),

  // ════════════════════════════════════════════════════════════════════════════
  // TODAY (Thursday) — LATER TODAY
  // ════════════════════════════════════════════════════════════════════════════

  Event(id: 'ev_th1', clubId: 'c28', title: 'Akustik Gece: Singer-Songwriter Showcase',
    description: 'An intimate evening of original songs by KU students. Six acts performing original material — acoustic guitar, piano and vocal sets. Doors open 30 min early.',
    location: 'SOS B Atelier',
    dateTime: DateTime.now().add(const Duration(hours: 2)),
    endTime: DateTime.now().add(const Duration(hours: 4, minutes: 30)),
    attendeeUserIds: ['u2', 'u4', 'u5', 'u8', 'u14'],
    rsvpTimestamps: {'u2': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u4': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u5': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'u8': DateTime.now().subtract(const Duration(hours: 20)).toIso8601String(), 'u14': DateTime.now().subtract(const Duration(hours: 12)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/acoustic_night/800/500'),

  Event(id: 'ev_th2', clubId: 'c10', title: 'Platon\'un Devleti — Tartışma Gecesi',
    description: 'Is Plato\'s Republic still relevant? Special one-off debate on justice, power and the ideal society. No prep needed — just come with your opinions.',
    location: 'SOS B108',
    dateTime: DateTime.now().add(const Duration(hours: 3)),
    endTime: DateTime.now().add(const Duration(hours: 5)),
    attendeeUserIds: ['u3', 'u7', 'u10', 'u5'],
    rsvpTimestamps: {'u3': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u7': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u5': DateTime.now().subtract(const Duration(hours: 8)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/plato_debate/800/500'),

  Event(id: 'ev_th3', clubId: 'c32', title: 'Sosyal Medya İçerik Yarışması Sunumları',
    description: 'Final presentations of this semester\'s Social Media Strategy Competition. 8 teams pitch their brand campaigns to a panel of industry judges. Public welcome.',
    location: 'SOS B140 Amphitheatre',
    dateTime: DateTime.now().add(const Duration(hours: 4)),
    endTime: DateTime.now().add(const Duration(hours: 7)),
    attendeeUserIds: ['u2', 'u7', 'u9', 'u13', 'u15'],
    rsvpTimestamps: {'u2': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'u7': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u9': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u13': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u15': DateTime.now().subtract(const Duration(days: 1)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/marketing_finals/800/500'),

  Event(id: 'ev_th4', clubId: 'c16', title: 'İlk Yardım Sertifika Kursu',
    description: 'Certified 3-hour first aid course covering CPR, AED use and basic wound care. Completion certificate provided. Limited to 20 participants — register at the door.',
    location: 'SOS B206',
    dateTime: DateTime.now().add(const Duration(hours: 5)),
    endTime: DateTime.now().add(const Duration(hours: 8)),
    attendeeUserIds: ['u6', 'u8', 'u10', 'u12'],
    rsvpTimestamps: {'u6': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u8': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'u12': DateTime.now().subtract(const Duration(hours: 16)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/firstaid_course/800/500'),

  Event(id: 'ev_th5', clubId: 'c39', title: 'Doğaçlama Tiyatro: Açık Sahne Perşembe',
    description: 'Every Thursday — Improv Night at KU Theatre Club. No script, no plan, pure chaos. Audience members can jump on stage anytime. Free entry, all welcome.',
    location: 'SOS B206',
    dateTime: DateTime.now().add(const Duration(hours: 6, minutes: 30)),
    endTime: DateTime.now().add(const Duration(hours: 9)),
    attendeeUserIds: ['u1', 'u3', 'u8', 'u11'],
    rsvpTimestamps: {'u1': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u3': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'u8': DateTime.now().subtract(const Duration(hours: 18)).toIso8601String(), 'u11': DateTime.now().subtract(const Duration(hours: 10)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/improv_thursday/800/500'),

  // ════════════════════════════════════════════════════════════════════════════
  // TOMORROW (Friday)
  // ════════════════════════════════════════════════════════════════════════════

  Event(id: 'ev_fri1', clubId: 'c4', title: 'Flutter ile Mobil Uygulama Geliştirme',
    description: 'Build a fully working campus events app from scratch in one session. Covers widgets, navigation, state management and API calls. Bring your laptop.',
    location: 'ENG B13',
    dateTime: DateTime.now().add(const Duration(days: 1, hours: 1)),
    endTime: DateTime.now().add(const Duration(days: 1, hours: 4)),
    attendeeUserIds: ['u1', 'u2', 'u3', 'u4', 'u5', 'u9', 'u11', 'u15'],
    rsvpTimestamps: {'u1': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u2': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u3': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u4': DateTime.now().subtract(const Duration(days: 2, hours: 6)).toIso8601String(), 'u5': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'u9': DateTime.now().subtract(const Duration(hours: 22)).toIso8601String(), 'u11': DateTime.now().subtract(const Duration(hours: 18)).toIso8601String(), 'u15': DateTime.now().subtract(const Duration(hours: 10)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/flutter_mobile/800/500'),

  Event(id: 'ev_fri2', clubId: 'c27', title: 'Münazara Kulübü Antrenman Gecesi',
    description: 'Weekly practice session with motions from this season\'s upcoming tournaments. Experienced members coach newcomers. Great way to sharpen your public speaking.',
    location: 'SOS B209',
    dateTime: DateTime.now().add(const Duration(days: 1, hours: 3)),
    endTime: DateTime.now().add(const Duration(days: 1, hours: 5, minutes: 30)),
    attendeeUserIds: ['u3', 'u7', 'u9', 'u14'],
    rsvpTimestamps: {'u3': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u7': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u9': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'u14': DateTime.now().subtract(const Duration(hours: 14)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/debate_training/800/500'),

  Event(id: 'ev_fri3', clubId: 'c6', title: 'Bahar Şenliği Dans Gösterisi',
    description: 'KUDans Spring Showcase — the biggest performance of the year! Salsa, Hip-Hop, Contemporary and Folk segments with 35 dancers. Free tickets at the door.',
    location: 'KU Amfitiyatrosu',
    dateTime: DateTime.now().add(const Duration(days: 1, hours: 6)),
    endTime: DateTime.now().add(const Duration(days: 1, hours: 8)),
    attendeeUserIds: ['u1', 'u4', 'u5', 'u6', 'u8', 'u10', 'u12', 'u13', 'u14'],
    rsvpTimestamps: {'u1': DateTime.now().subtract(const Duration(days: 6)).toIso8601String(), 'u4': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'u5': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u6': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u8': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u12': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'u13': DateTime.now().subtract(const Duration(hours: 20)).toIso8601String(), 'u14': DateTime.now().subtract(const Duration(hours: 12)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/dance_showcase/800/500'),

  Event(id: 'ev_fri4', clubId: 'c33', title: 'Podcast Kayıt Workshopu',
    description: 'KU Radio hosts a hands-on workshop: script writing, mic technique, GarageBand editing and publishing your first episode. Studio access provided after the session.',
    location: 'SOS B111 — Radyo Stüdyosu',
    dateTime: DateTime.now().add(const Duration(days: 1, hours: 2)),
    endTime: DateTime.now().add(const Duration(days: 1, hours: 5)),
    attendeeUserIds: ['u7', 'u11', 'u13', 'u15'],
    rsvpTimestamps: {'u7': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u11': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u13': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u15': DateTime.now().subtract(const Duration(days: 1)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/podcast_workshop/800/500'),

  Event(id: 'ev_fri5', clubId: 'c15', title: 'Girişimci Networking Kahvaltısı',
    description: 'Informal Friday morning breakfast for founders, aspiring entrepreneurs and startup enthusiasts. No agenda — just coffee, croissants and ambitious people.',
    location: 'SOS Cafeteria — Upper Floor',
    dateTime: DateTime.now().add(const Duration(days: 1)),
    endTime: DateTime.now().add(const Duration(days: 1, hours: 2)),
    attendeeUserIds: ['u2', 'u5', 'u7', 'u9', 'u11', 'u13'],
    rsvpTimestamps: {'u2': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u5': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'u7': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u9': DateTime.now().subtract(const Duration(hours: 20)).toIso8601String(), 'u11': DateTime.now().subtract(const Duration(hours: 16)).toIso8601String(), 'u13': DateTime.now().subtract(const Duration(hours: 8)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/startup_breakfast/800/500',
    tags: ['Networking', 'Breakfast', 'Startup'],
    guestSpeaker: 'Alper Utku — Managing Partner, 212'),

  Event(id: 'ev_fri6', clubId: 'c29', title: '"Waiting for Godot" — Açılış Gecesi',
    description: 'Opening night of the KU Musical Club\'s production of Beckett\'s masterpiece. Minimalist staging, powerful performances. Running time: 110 minutes. Free entry.',
    location: 'KU Sahnesi',
    dateTime: DateTime.now().add(const Duration(days: 1, hours: 7)),
    endTime: DateTime.now().add(const Duration(days: 1, hours: 9, minutes: 15)),
    attendeeUserIds: ['u1', 'u2', 'u3', 'u5', 'u6', 'u10', 'u14'],
    rsvpTimestamps: {'u1': DateTime.now().subtract(const Duration(days: 7)).toIso8601String(), 'u2': DateTime.now().subtract(const Duration(days: 6)).toIso8601String(), 'u3': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'u5': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u6': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u14': DateTime.now().subtract(const Duration(days: 1)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/godot_opening/800/500'),

  // ════════════════════════════════════════════════════════════════════════════
  // SUNDAY (April 27)
  // ════════════════════════════════════════════════════════════════════════════

  Event(id: 'ev_sun1', clubId: 'c5', title: 'Belgrad Ormanı Sabah Koşusu',
    description: 'Sunday trail run through Belgrad Forest — 8 km route with easy and hard variants. Transport departs KU main gate at 08:00. Bring water, trail shoes and good energy.',
    location: 'Belgrad Ormanı (KU Main Gate Departure)',
    dateTime: DateTime.now().add(const Duration(days: 3, hours: 1)),
    endTime: DateTime.now().add(const Duration(days: 3, hours: 4)),
    attendeeUserIds: ['u2', 'u3', 'u5', 'u6', 'u8', 'u12'],
    rsvpTimestamps: {'u2': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'u3': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u5': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u6': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u8': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'u12': DateTime.now().subtract(const Duration(hours: 18)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/trail_run_forest/800/500'),

  Event(id: 'ev_sun2', clubId: 'c13', title: 'İstanbul Altın Saati Fotoğraf Gezisi',
    description: 'Golden hour shoot around Karaköy and Galata Tower. Meet at Tünel Square, shoot until sunset, then group dinner. Bring any camera — phone shooters very welcome!',
    location: 'Tünel Meydanı, Beyoğlu (KU Departure 15:30)',
    dateTime: DateTime.now().add(const Duration(days: 3, hours: 6)),
    endTime: DateTime.now().add(const Duration(days: 3, hours: 10)),
    attendeeUserIds: ['u1', 'u4', 'u5', 'u10'],
    rsvpTimestamps: {'u1': DateTime.now().subtract(const Duration(days: 6)).toIso8601String(), 'u4': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'u5': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(days: 1)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/istanbul_photo_walk/800/500'),

  Event(id: 'ev_sun3', clubId: 'c36', title: 'Pazar Oyun Günü',
    description: 'Board games, card games, video games — bring your favourites or just show up. Settlers of Catan, Ticket to Ride, Among Us, and more. Food and drinks in the lounge.',
    location: 'SCI 103',
    dateTime: DateTime.now().add(const Duration(days: 3, hours: 3)),
    endTime: DateTime.now().add(const Duration(days: 3, hours: 8)),
    attendeeUserIds: ['u2', 'u4', 'u5', 'u9', 'u11', 'u13', 'u15'],
    rsvpTimestamps: {'u2': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u4': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u5': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'u9': DateTime.now().subtract(const Duration(hours: 30)).toIso8601String(), 'u11': DateTime.now().subtract(const Duration(hours: 22)).toIso8601String(), 'u13': DateTime.now().subtract(const Duration(hours: 14)).toIso8601String(), 'u15': DateTime.now().subtract(const Duration(hours: 6)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/game_day_sunday/800/500'),

  Event(id: 'ev_sun4', clubId: 'c22', title: 'Beykoz Hayvan Barınağı Ziyareti',
    description: 'Volunteer visit to Beykoz Animal Shelter — bring food donations, spend time with the animals and help with cleaning. Transport from KU at 10:00. Capacity: 20.',
    location: 'Beykoz Hayvan Barınağı (KU Departure 10:00)',
    dateTime: DateTime.now().add(const Duration(days: 3, hours: 2, minutes: 30)),
    endTime: DateTime.now().add(const Duration(days: 3, hours: 6)),
    attendeeUserIds: ['u5', 'u6', 'u8', 'u12', 'u14'],
    rsvpTimestamps: {'u5': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u6': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u8': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u12': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'u14': DateTime.now().subtract(const Duration(hours: 20)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/animal_shelter_visit/800/500'),

  Event(id: 'ev_sun5', clubId: 'c34', title: 'Pazar Sabahı Çizim Serbest Atölye',
    description: 'Open Sunday morning drawing session — urban sketching, portraits, still life. No theme, no pressure. Bring your own supplies or borrow from the club. Coffee provided.',
    location: 'Arts Building Studio 2',
    dateTime: DateTime.now().add(const Duration(days: 3)),
    endTime: DateTime.now().add(const Duration(days: 3, hours: 3)),
    attendeeUserIds: ['u4', 'u6', 'u10', 'u12'],
    rsvpTimestamps: {'u4': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u6': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'u12': DateTime.now().subtract(const Duration(hours: 14)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/sunday_drawing/800/500'),

  Event(id: 'ev_sun6', clubId: 'c35', title: 'Kısa Film Maratonu: Öğrenci Yapımları',
    description: 'Watch 12 short films made by KU Cinema Club members this semester — from comedy to documentary. Q&A with directors after each screening. Popcorn included.',
    location: 'SOS B140 Amphitheatre',
    dateTime: DateTime.now().add(const Duration(days: 3, hours: 4)),
    endTime: DateTime.now().add(const Duration(days: 3, hours: 8)),
    attendeeUserIds: ['u1', 'u3', 'u5', 'u7', 'u10', 'u13'],
    rsvpTimestamps: {'u1': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'u3': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u5': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u7': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'u13': DateTime.now().subtract(const Duration(hours: 16)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/short_film_marathon/800/500'),

  // ════════════════════════════════════════════════════════════════════════════
  // BATCH 2 — 20 new events from diverse clubs
  // ════════════════════════════════════════════════════════════════════════════

  // ── Live now ─────────────────────────────────────────────────────────────────
  Event(id: 'ev_x3', clubId: 'c2', title: '23 Nisan Anma Etkinliği',
    description: 'KUADK olarak 23 Nisan Ulusal Egemenlik ve Çocuk Bayramı\'nı şiir dinletisi ve belgesel gösterimiyle kutluyoruz. Etkinlik şu an devam ediyor, her an katılabilirsiniz.',
    location: 'SOS Amfitiyatrosu',
    dateTime: DateTime.now().subtract(const Duration(minutes: 30)),
    endTime: DateTime.now().add(const Duration(hours: 1, minutes: 30)),
    attendeeUserIds: ['u1', 'u7', 'u8', 'u10'],
    rsvpTimestamps: {'u1': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u7': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'u8': DateTime.now().subtract(const Duration(hours: 8)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/april23_celebration/800/500'),

  Event(id: 'ev_x7', clubId: 'c23', title: 'UEFA Şampiyonlar Ligi Çeyrek Final İzleme',
    description: 'KU Kartalları olarak şampiyonlar liginin çeyrek final maçını canlı büyük ekranda izliyoruz! Kafeterya B\'de alan hazır, atıştırmalıklar benden. Şimdi başladı, hemen gel!',
    location: 'Cafeteria B',
    dateTime: DateTime.now().subtract(const Duration(minutes: 15)),
    endTime: DateTime.now().add(const Duration(hours: 2)),
    attendeeUserIds: ['u3', 'u5', 'u7', 'u9', 'u11', 'u13', 'u15'],
    rsvpTimestamps: {'u3': DateTime.now().subtract(const Duration(hours: 6)).toIso8601String(), 'u5': DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(), 'u7': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(), 'u9': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(), 'u11': DateTime.now().subtract(const Duration(hours: 2, minutes: 30)).toIso8601String(), 'u13': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(), 'u15': DateTime.now().subtract(const Duration(minutes: 45)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/ucl_watchparty/800/500'),

  // ── Today later ───────────────────────────────────────────────────────────────
  Event(id: 'ev_x6', clubId: 'c3', title: 'Masumiyet Müzesi — 2. Okuma Oturumu',
    description: 'KUBBE Orhan Pamuk okuma grubunun ikinci haftası. Bu oturum 100–200. sayfaları kapsıyor. Tartışma soruları Discord\'da paylaşıldı; kitabı bitirmeden de gelebilirsiniz!',
    location: 'SOS B108',
    dateTime: DateTime.now().add(const Duration(hours: 5)),
    endTime: DateTime.now().add(const Duration(hours: 7)),
    attendeeUserIds: ['u3', 'u6', 'u7', 'u10'],
    rsvpTimestamps: {'u3': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u6': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u7': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(hours: 10)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/masumiyetmuzesi/800/500'),

  Event(id: 'ev_x13', clubId: 'c11', title: 'Şampiyonlar Ligi Çeyrek Final — 2. Maç',
    description: 'Bu akşamki kritik maçı birlikte izliyoruz. Büyük ekran, snacklar kulüpten. Formanı giy, sarı-lacivert renklerinle gel ve tribünümüzü doldur! 💛💙',
    location: 'Cafeteria A',
    dateTime: DateTime.now().add(const Duration(hours: 3)),
    endTime: DateTime.now().add(const Duration(hours: 5)),
    attendeeUserIds: ['u5', 'u7', 'u9', 'u11', 'u15'],
    rsvpTimestamps: {'u5': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(), 'u7': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(), 'u9': DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(), 'u11': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(), 'u15': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/fenerbahce_ucl/800/500'),

  Event(id: 'ev_x14', clubId: 'c37', title: 'İstanbul\'un Fethinin 572. Yıldönümü',
    description: 'Tarih Kulübü olarak 29 Mayıs\'ı önceden anıyoruz — belgesel gösterimi, harita okumaları ve Osmanlı uzmanı Dr. Serkan Yılmaz ile soru-cevap. Tarih meraklısı herkes davetlidir.',
    location: 'SOS B209 Seminer Salonu',
    dateTime: DateTime.now().add(const Duration(hours: 5)),
    endTime: DateTime.now().add(const Duration(hours: 8)),
    attendeeUserIds: ['u3', 'u6', 'u7', 'u10'],
    rsvpTimestamps: {'u3': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u6': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u7': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(days: 1)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/conquest_anniversary/800/500'),

  Event(id: 'ev_x20', clubId: 'c14', title: 'Karanlığın Kıyısı — 2. Oturum',
    description: 'D&D kampanyamızın ikinci oturumu! Tavern dövüşü, gizemli NPC\'ler ve beklenmedik bir dönüş sizi bekliyor. Geçen haftayı kaçıranlar için hazır karakter sayfaları mevcut.',
    location: 'SOS B210',
    dateTime: DateTime.now().add(const Duration(hours: 7)),
    endTime: DateTime.now().add(const Duration(hours: 11)),
    attendeeUserIds: ['u2', 'u5', 'u11'],
    rsvpTimestamps: {'u2': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'u5': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u11': DateTime.now().subtract(const Duration(days: 4)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/dnd_session2/800/500'),

  // ── Tomorrow ──────────────────────────────────────────────────────────────────
  Event(id: 'ev_x1', clubId: 'c7', title: 'Enflasyon ve Para Politikası Paneli',
    description: 'TCMB\'den kıdemli uzman ve iki akademisyenin katılımıyla Türkiye\'nin mevcut enflasyon dinamiklerini ve faiz politikasını ele alıyoruz. 90 dakika panel + soru-cevap. Ekonomi severlere şiddetle tavsiye edilir!',
    location: 'SOS B140 Amfitiyatrosu',
    dateTime: DateTime.now().add(const Duration(days: 1, hours: 3)),
    endTime: DateTime.now().add(const Duration(days: 1, hours: 5)),
    attendeeUserIds: ['u2', 'u7', 'u9', 'u13'],
    rsvpTimestamps: {'u2': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u7': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u9': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'u13': DateTime.now().subtract(const Duration(hours: 15)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/inflation_panel/800/500',
    tags: ['Panel', 'Economics', 'Finance'],
    guestSpeaker: 'Dr. Hakan Kara — Former TCMB Chief Economist'),

  Event(id: 'ev_x4', clubId: 'c30', title: 'Beyin Anatomisi Atölyesi',
    description: 'KU-SIGN\'in aylık nöroanatomi atölyesi. 3D beyin modeli üzerinde lobus, korteks ve derin yapıların tespiti. Tıp, psikoloji ve biyoloji öğrencileri için özellikle faydalı. Kayıt gerekmiyor.',
    location: 'Tıp Binası Simülasyon Lab',
    dateTime: DateTime.now().add(const Duration(days: 1, hours: 5)),
    endTime: DateTime.now().add(const Duration(days: 1, hours: 7)),
    attendeeUserIds: ['u9', 'u12', 'u10'],
    rsvpTimestamps: {'u9': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u12': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(days: 2)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/brain_anatomy_workshop/800/500'),

  Event(id: 'ev_x8', clubId: 'c38', title: 'Klinik Beceriler Simülasyon Günü',
    description: 'KUTÖB\'ün aylık simülasyon etkinliği. IV hat açma, venepuntur ve temel fizik muayene becerileri üzerine pratik. Kıdemli tıp öğrencileri gözetiminde manikenlerle çalışma fırsatı.',
    location: 'Tıp Binası Beceri Lab',
    dateTime: DateTime.now().add(const Duration(days: 1, hours: 6)),
    endTime: DateTime.now().add(const Duration(days: 1, hours: 9)),
    attendeeUserIds: ['u9', 'u12'],
    rsvpTimestamps: {'u9': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'u12': DateTime.now().subtract(const Duration(days: 4)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/clinical_skills_day/800/500'),

  // ── This week ──────────────────────────────────────────────────────────────────
  Event(id: 'ev_x17', clubId: 'c7', title: 'Borsa ve Yatırım 101',
    description: 'BIST hisse analizi, temel göstergeler ve portföy çeşitlendirmesi üzerine interaktif atölye. Bloomberg terminali uygulaması dahil. Ekonomi veya finansa meraklı herkes davetlidir!',
    location: 'ENG Z27',
    dateTime: DateTime.now().add(const Duration(days: 3, hours: 3)),
    endTime: DateTime.now().add(const Duration(days: 3, hours: 5)),
    attendeeUserIds: ['u2', 'u7', 'u9', 'u13', 'u15'],
    rsvpTimestamps: {'u2': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'u7': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u9': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u13': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u15': DateTime.now().subtract(const Duration(days: 1)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/stock_market_101/800/500'),

  Event(id: 'ev_x9', clubId: 'c41', title: 'Türk Halk Müziği Bahar Akşamı',
    description: 'THM Kulübü\'nün bahar dönemi konseri! Saz ve bağlama topluluğumuz halkın sevdiği türküleri seslendirecek. Geleneksel ezgiler, modern yorumlar. Serbest giriş, kayıt gerekmez.',
    location: 'SOS B Atelier',
    dateTime: DateTime.now().add(const Duration(days: 3, hours: 6)),
    endTime: DateTime.now().add(const Duration(days: 3, hours: 9)),
    attendeeUserIds: ['u8', 'u10', 'u12', 'u14'],
    rsvpTimestamps: {'u8': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u12': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u14': DateTime.now().subtract(const Duration(days: 1)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/folk_music_concert/800/500'),

  Event(id: 'ev_x2', clubId: 'c1', title: 'Boğaziçi Kıyısı Tarihi Mimari Yürüyüşü',
    description: 'KUARHA ile Boğaziçi\'nin yalılarını, köşklerini ve 19. yüzyıl mimarisini keşfediyoruz. Rehberli 3 saatlik yürüyüş, KU ana kapısından hareket. İstanbul\'un mirasına yakın bakış!',
    location: 'KU Ana Kapısı (Hareket Noktası)',
    dateTime: DateTime.now().add(const Duration(days: 4, hours: 2)),
    endTime: DateTime.now().add(const Duration(days: 4, hours: 5)),
    attendeeUserIds: ['u3', 'u6', 'u7', 'u10'],
    rsvpTimestamps: {'u3': DateTime.now().subtract(const Duration(days: 6)).toIso8601String(), 'u6': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'u7': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(days: 3)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/bosphorus_walk/800/500'),

  Event(id: 'ev_x5', clubId: 'c40', title: 'Kafkasya Jeopolitiği: Türk Perspektifi',
    description: 'Güney Kafkasya\'daki çatışmalar ve Türkiye\'nin bölgesel politikasını ele alıyoruz. Uluslararası ilişkiler fakültesinden iki akademisyen ile derinlemesine analiz. Herkese açık.',
    location: 'SOS B209',
    dateTime: DateTime.now().add(const Duration(days: 5, hours: 3)),
    endTime: DateTime.now().add(const Duration(days: 5, hours: 5)),
    attendeeUserIds: ['u3', 'u7', 'u10', 'u13'],
    rsvpTimestamps: {'u3': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u7': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u13': DateTime.now().subtract(const Duration(days: 1)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/caucasus_geopolitics/800/500'),

  Event(id: 'ev_x19', clubId: 'c17', title: 'Yapay Zeka ve Hukuk: Hukuki Çerçeve Paneli',
    description: 'AB Yapay Zeka Yasası, kişisel veri koruma ve algoritma hesap verebilirliği üzerine panel. Hukuk fakültesinden iki akademisyen ve teknoloji sektöründen bir avukat. Herkese açık.',
    location: 'SOS B206',
    dateTime: DateTime.now().add(const Duration(days: 6, hours: 4)),
    endTime: DateTime.now().add(const Duration(days: 6, hours: 7)),
    attendeeUserIds: ['u3', 'u9', 'u10', 'u13'],
    rsvpTimestamps: {'u3': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'u9': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u13': DateTime.now().subtract(const Duration(days: 2)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/ai_law_panel/800/500'),

  Event(id: 'ev_x10', clubId: 'c9', title: 'İleri Ebru: Battal Tekniği Atölyesi',
    description: 'Battal Ebru — geleneksel Türk kâğıt mermerleme sanatının en temel ve estetik formu. Bu özel atölyede büyük formatlı kâğıtlara çalışacağız. Temel deneyimi olanlar için.',
    location: 'SOS Art Studio 1',
    dateTime: DateTime.now().add(const Duration(days: 6, hours: 7)),
    endTime: DateTime.now().add(const Duration(days: 6, hours: 9)),
    attendeeUserIds: ['u4', 'u6', 'u10', 'u12'],
    rsvpTimestamps: {'u4': DateTime.now().subtract(const Duration(days: 7)).toIso8601String(), 'u6': DateTime.now().subtract(const Duration(days: 6)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'u12': DateTime.now().subtract(const Duration(days: 4)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/battal_ebru/800/500'),

  // ── Next week ──────────────────────────────────────────────────────────────────
  Event(id: 'ev_x11', clubId: 'c25', title: 'Kürt Kültürü ve Gastronomi Gecesi',
    description: 'Kürt mutfağından tatlar, müzik ve kültürel sunum. Nevruz geleneğinden esinlenen dekorasyon, geleneksel kıyafet sergisi ve dil oyunları. Herkes davetlidir, giriş ücretsiz!',
    location: 'SOS Amfitiyatrosu',
    dateTime: DateTime.now().add(const Duration(days: 8, hours: 6)),
    endTime: DateTime.now().add(const Duration(days: 8, hours: 10)),
    attendeeUserIds: ['u3', 'u6', 'u7', 'u10', 'u13'],
    rsvpTimestamps: {'u3': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'u6': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u7': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'u13': DateTime.now().subtract(const Duration(days: 1)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/kurdish_cultural_night/800/500'),

  Event(id: 'ev_x18', clubId: 'c30', title: 'Nörolojik Rehabilitasyon Sempozyumu',
    description: 'KU-SIGN yıllık sempozyumu — nörolog, nöropsikolog ve fizyoterapist ile inme sonrası rehabilitasyon, MS tedavisi ve yenilikçi yöntemler. Sertifika verilecek. Kontenjan: 50.',
    location: 'Tıp Binası Konferans Salonu',
    dateTime: DateTime.now().add(const Duration(days: 9, hours: 5)),
    endTime: DateTime.now().add(const Duration(days: 9, hours: 9)),
    attendeeUserIds: ['u9', 'u12', 'u10'],
    rsvpTimestamps: {'u9': DateTime.now().subtract(const Duration(days: 6)).toIso8601String(), 'u12': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(days: 4)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/neurology_symposium/800/500'),

  Event(id: 'ev_x12', clubId: 'c12', title: 'Folklör Kulübü Yıl Sonu Gala Gecesi',
    description: 'Yılın en büyük folklör etkinliği! Zeybek, horon ve halay bölümleriyle 90 dakikalık gösteriyi kaçırmayın. Kostümler, canlı müzik, fotoğraf standı. Biletler ücretsiz.',
    location: 'KU Amfitiyatrosu',
    dateTime: DateTime.now().add(const Duration(days: 10, hours: 7)),
    endTime: DateTime.now().add(const Duration(days: 10, hours: 10)),
    attendeeUserIds: ['u4', 'u6', 'u8', 'u12', 'u14'],
    rsvpTimestamps: {'u4': DateTime.now().subtract(const Duration(days: 7)).toIso8601String(), 'u6': DateTime.now().subtract(const Duration(days: 6)).toIso8601String(), 'u8': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'u12': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u14': DateTime.now().subtract(const Duration(days: 3)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/folklore_gala/800/500'),

  // ── Past events ───────────────────────────────────────────────────────────────
  Event(id: 'ev_x15', clubId: 'c19', title: 'Kariyer Mentörlük Günü',
    description: 'Kadın Dayanışma\'nın mentörlük günü harika geçti! 20 mentor ve 60 öğrenci ile sektörleri aşan bire bir görüşmeler yapıldı. Katılan herkese teşekkürler — bir sonraki yıl görüşürüz!',
    location: 'SOS B140 Amfitiyatrosu',
    dateTime: DateTime.now().subtract(const Duration(days: 2, hours: 5)),
    endTime: DateTime.now().subtract(const Duration(days: 2, hours: 1)),
    attendeeUserIds: ['u4', 'u6', 'u8', 'u10', 'u12', 'u14'],
    rsvpTimestamps: {'u6': DateTime.now().subtract(const Duration(days: 7)).toIso8601String(), 'u8': DateTime.now().subtract(const Duration(days: 6)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'u12': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'u4': DateTime.now().subtract(const Duration(days: 4, hours: 6)).toIso8601String(), 'u14': DateTime.now().subtract(const Duration(days: 3)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/career_mentorship/800/500'),

  Event(id: 'ev_x16', clubId: 'c2', title: 'Atatürk Belgeseli Gösterimi',
    description: 'KUADK olarak "Atatürk" belgeselini büyük ekranda izledik. Cumhuriyet tarihinin önemli anları ve günümüze yansımaları üzerine çok derin bir tartışma oturumu gerçekleşti.',
    location: 'SOS B206',
    dateTime: DateTime.now().subtract(const Duration(days: 4, hours: 3)),
    endTime: DateTime.now().subtract(const Duration(days: 4)),
    attendeeUserIds: ['u1', 'u6', 'u7', 'u8', 'u10'],
    rsvpTimestamps: {'u1': DateTime.now().subtract(const Duration(days: 8)).toIso8601String(), 'u6': DateTime.now().subtract(const Duration(days: 7)).toIso8601String(), 'u7': DateTime.now().subtract(const Duration(days: 6)).toIso8601String(), 'u8': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'u10': DateTime.now().subtract(const Duration(days: 6, hours: 6)).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/ataturk_documentary/800/500'),

  // ════════════════════════════════════════════════════════════════════════════
  // MAY 8 – MAY 15 events
  // ════════════════════════════════════════════════════════════════════════════

  Event(id: 'ev_may1', clubId: 'c4', title: 'LeetCode Haftalık Maratonu',
    description: 'Haftalık LeetCode çözüm oturumu — bu hafta graph ve DP problemlerine odaklanıyoruz. Her seviyeye uygun sorular, takım bazlı çözüm tartışmaları. Dizüstü bilgisayarını getir!',
    location: 'Library Lab 3',
    dateTime: DateTime(2026, 5, 8, 14, 0),
    endTime:  DateTime(2026, 5, 8, 18, 0),
    attendeeUserIds: ['u1', 'u2', 'u4', 'u5'],
    rsvpTimestamps: {'u1': DateTime(2026,5,7,10,0).toIso8601String(),'u2': DateTime(2026,5,7,12,0).toIso8601String(),'u4': DateTime(2026,5,8,8,0).toIso8601String(),'u5': DateTime(2026,5,8,9,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/leetcode_marathon/800/500'),

  Event(id: 'ev_may2', clubId: 'c28', title: 'Caz Çarşamba: İlkbahar Konseri',
    description: 'KÜMK\'nin bahar konseri — trio, quartet ve solo setlerle unutulmaz bir gece. Sahnede 12 müzisyen, ücretsiz giriş. İçecekler kulüpten.',
    location: 'SOS B Atelier',
    dateTime: DateTime(2026, 5, 8, 20, 0),
    endTime:  DateTime(2026, 5, 8, 23, 0),
    attendeeUserIds: ['u2', 'u4', 'u5', 'u8', 'u13', 'u14'],
    rsvpTimestamps: {'u2': DateTime(2026,5,6,15,0).toIso8601String(),'u4': DateTime(2026,5,7,9,0).toIso8601String(),'u5': DateTime(2026,5,7,18,0).toIso8601String(),'u8': DateTime(2026,5,8,10,0).toIso8601String(),'u13': DateTime(2026,5,8,11,0).toIso8601String(),'u14': DateTime(2026,5,8,12,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/jazz_wednesday_spring/800/500'),

  Event(id: 'ev_may3', clubId: 'c15', title: 'Startup Sabah Kahvaltısı',
    description: 'Girişimcilik Kulübü\'nün haftalık networking kahvaltısı. Fikrinden ürüne, üründen yatırıma yolculuğunu anlatan konuşmacılar. Hafif kahvaltı dahil.',
    location: 'SOS Cafeteria — Upper Floor',
    dateTime: DateTime(2026, 5, 9, 9, 30),
    endTime:  DateTime(2026, 5, 9, 11, 30),
    attendeeUserIds: ['u2', 'u5', 'u7', 'u9', 'u11'],
    rsvpTimestamps: {'u2': DateTime(2026,5,7,20,0).toIso8601String(),'u5': DateTime(2026,5,8,8,0).toIso8601String(),'u7': DateTime(2026,5,8,9,0).toIso8601String(),'u9': DateTime(2026,5,8,10,0).toIso8601String(),'u11': DateTime(2026,5,8,11,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/startup_breakfast_may/800/500',
    tags: ['Networking', 'Kahvaltı', 'Girişimcilik']),

  Event(id: 'ev_may4', clubId: 'c27', title: 'BP Münazara Antrenman Gecesi',
    description: 'British Parliamentary formatında haftalık antrenman. Bu hafta\'nın motionu: "Bu meclis yapay zekanın sanat üretmesini yasaklamalıdır." Yeni üyeler için mükemmel!',
    location: 'SOS B209',
    dateTime: DateTime(2026, 5, 9, 18, 0),
    endTime:  DateTime(2026, 5, 9, 20, 30),
    attendeeUserIds: ['u3', 'u7', 'u9', 'u14'],
    rsvpTimestamps: {'u3': DateTime(2026,5,8,10,0).toIso8601String(),'u7': DateTime(2026,5,8,12,0).toIso8601String(),'u9': DateTime(2026,5,8,14,0).toIso8601String(),'u14': DateTime(2026,5,8,16,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/debate_training_may/800/500'),

  Event(id: 'ev_may5', clubId: 'c34', title: 'Suluboya Açık Stüdyo Cuma',
    description: 'Cuma akşamı açık stüdyo — dilediğin teknikle dilediğin şeyi yap. Suluboya malzemeleri hazır, sehpalar servis. 17:00\'den gece yarısına kadar.',
    location: 'Arts Building Studio 2',
    dateTime: DateTime(2026, 5, 9, 15, 0),
    endTime:  DateTime(2026, 5, 9, 21, 0),
    attendeeUserIds: ['u3', 'u6', 'u10', 'u12'],
    rsvpTimestamps: {'u3': DateTime(2026,5,8,9,0).toIso8601String(),'u6': DateTime(2026,5,8,11,0).toIso8601String(),'u10': DateTime(2026,5,8,13,0).toIso8601String(),'u12': DateTime(2026,5,9,8,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/watercolour_friday/800/500'),

  Event(id: 'ev_may6', clubId: 'c36', title: 'Cuma Oyun Gecesi',
    description: 'Catan, Ticket to Ride, Codenames, Dixit ve daha fazlası! Ekibini getir ya da yalnız gel ve yeni arkadaşlar edin. İçecekler ve atıştırmalıklar kulüpten.',
    location: 'SCI 103',
    dateTime: DateTime(2026, 5, 9, 19, 0),
    endTime:  DateTime(2026, 5, 9, 23, 0),
    attendeeUserIds: ['u2', 'u4', 'u5', 'u9', 'u11', 'u13'],
    rsvpTimestamps: {'u2': DateTime(2026,5,8,15,0).toIso8601String(),'u4': DateTime(2026,5,8,16,0).toIso8601String(),'u5': DateTime(2026,5,8,17,0).toIso8601String(),'u9': DateTime(2026,5,9,8,0).toIso8601String(),'u11': DateTime(2026,5,9,9,0).toIso8601String(),'u13': DateTime(2026,5,9,10,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/game_night_may/800/500'),

  Event(id: 'ev_may7', clubId: 'c13', title: 'Makro Fotoğraf Atölyesi',
    description: 'Kampüs bahçesinde makro fotoğrafçılık atölyesi — çiçekler, böcekler, doğa detayları. Telefon kamerasıyla da katılabilirsiniz. Compositon ve ışık üzerine pratik ipuçları.',
    location: 'KU Campus Gardens',
    dateTime: DateTime(2026, 5, 10, 11, 0),
    endTime:  DateTime(2026, 5, 10, 14, 0),
    attendeeUserIds: ['u1', 'u4', 'u5', 'u10'],
    rsvpTimestamps: {'u1': DateTime(2026,5,8,14,0).toIso8601String(),'u4': DateTime(2026,5,8,15,0).toIso8601String(),'u5': DateTime(2026,5,9,9,0).toIso8601String(),'u10': DateTime(2026,5,9,10,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/macro_photo_may/800/500'),

  Event(id: 'ev_may8', clubId: 'c5', title: 'Sabah Yürüyüşü ve Yoga',
    description: 'KU Gündoğumu Serisi: kampüs yollarında 3 km yürüyüş ardından 30 dakika açık havada yoga. Mat getirmeyi unutma. Tüm seviyelere açık.',
    location: 'Sports Center Entrance',
    dateTime: DateTime(2026, 5, 10, 7, 30),
    endTime:  DateTime(2026, 5, 10, 9, 30),
    attendeeUserIds: ['u2', 'u6', 'u8', 'u12'],
    rsvpTimestamps: {'u2': DateTime(2026,5,9,18,0).toIso8601String(),'u6': DateTime(2026,5,9,19,0).toIso8601String(),'u8': DateTime(2026,5,9,20,0).toIso8601String(),'u12': DateTime(2026,5,9,21,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/morning_yoga_may/800/500'),

  Event(id: 'ev_may9', clubId: 'c31', title: 'KU Orkestra Yıl Sonu Bahar Konseri',
    description: 'Dvorak\'ın 9. Senfonisi ve Brahms Keman Konçertosu. 50 öğrenci müzisyen en büyük sahneye çıkıyor. Yıllık en beklenen etkinlik — ücretsiz bilet, rezervasyon zorunlu.',
    location: 'KU Amfitiyatrosu',
    dateTime: DateTime(2026, 5, 10, 20, 0),
    endTime:  DateTime(2026, 5, 10, 22, 30),
    attendeeUserIds: ['u1', 'u3', 'u5', 'u6', 'u8', 'u10', 'u14'],
    rsvpTimestamps: {'u1': DateTime(2026,5,5,10,0).toIso8601String(),'u3': DateTime(2026,5,5,12,0).toIso8601String(),'u5': DateTime(2026,5,6,9,0).toIso8601String(),'u6': DateTime(2026,5,6,10,0).toIso8601String(),'u8': DateTime(2026,5,7,9,0).toIso8601String(),'u10': DateTime(2026,5,7,11,0).toIso8601String(),'u14': DateTime(2026,5,7,14,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/orchestra_spring_final/800/500',
    tags: ['Konser', 'Klasik Müzik', 'Ücretsiz']),

  Event(id: 'ev_may10', clubId: 'c39', title: 'İmprov Tiyatro Pazar Matinesi',
    description: 'Pazar öğleden sonrası doğaçlama tiyatro — sahneye çık ya da izle. Hiçbir deneyim şart değil. Seyirciler de sahneye davet edilecek!',
    location: 'SOS B206',
    dateTime: DateTime(2026, 5, 11, 14, 0),
    endTime:  DateTime(2026, 5, 11, 17, 0),
    attendeeUserIds: ['u1', 'u3', 'u8', 'u11'],
    rsvpTimestamps: {'u1': DateTime(2026,5,9,12,0).toIso8601String(),'u3': DateTime(2026,5,9,14,0).toIso8601String(),'u8': DateTime(2026,5,10,9,0).toIso8601String(),'u11': DateTime(2026,5,10,11,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/improv_sunday_may/800/500'),

  Event(id: 'ev_may11', clubId: 'c22', title: 'Çocuk Hastanesi Gönüllülük Günü',
    description: 'KU Gönüllüleri ile çocuk hastanesini ziyaret ediyoruz — oyun aktiviteleri, sanat etkinlikleri ve küçük misafirlere sürpriz. KU Ana Kapı\'dan 09:30\'da hareket.',
    location: 'Darüşşafaka Çocuk Hastanesi (KU Departure 09:30)',
    dateTime: DateTime(2026, 5, 11, 10, 0),
    endTime:  DateTime(2026, 5, 11, 14, 0),
    attendeeUserIds: ['u5', 'u6', 'u8', 'u12', 'u14'],
    rsvpTimestamps: {'u5': DateTime(2026,5,9,10,0).toIso8601String(),'u6': DateTime(2026,5,9,11,0).toIso8601String(),'u8': DateTime(2026,5,9,13,0).toIso8601String(),'u12': DateTime(2026,5,10,8,0).toIso8601String(),'u14': DateTime(2026,5,10,9,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/hospital_volunteer_may/800/500'),

  Event(id: 'ev_may12', clubId: 'c7', title: 'Borsa Simülasyon Atölyesi',
    description: 'Ekonomi Kulübü Bloomberg terminali atölyesi — BIST hisse analizi, teknik göstergeler ve portföy yönetimi. Gerçek piyasa datası üzerinde pratik uygulama.',
    location: 'ENG Z27',
    dateTime: DateTime(2026, 5, 12, 14, 0),
    endTime:  DateTime(2026, 5, 12, 16, 30),
    attendeeUserIds: ['u2', 'u7', 'u9', 'u13', 'u15'],
    rsvpTimestamps: {'u2': DateTime(2026,5,10,14,0).toIso8601String(),'u7': DateTime(2026,5,10,15,0).toIso8601String(),'u9': DateTime(2026,5,11,9,0).toIso8601String(),'u13': DateTime(2026,5,11,10,0).toIso8601String(),'u15': DateTime(2026,5,11,12,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/stock_simulation_may/800/500'),

  Event(id: 'ev_may13', clubId: 'c4', title: 'Web3 ve Blockchain Workshop',
    description: 'Solidity ile akıllı kontrat yazma, Ethereum test ağında deploy. Web3.js ve MetaMask entegrasyonu. DApp geliştirmeye meraklılar için ideal başlangıç noktası.',
    location: 'Library Lab 3',
    dateTime: DateTime(2026, 5, 12, 17, 0),
    endTime:  DateTime(2026, 5, 12, 20, 0),
    attendeeUserIds: ['u1', 'u2', 'u3', 'u4', 'u5'],
    rsvpTimestamps: {'u1': DateTime(2026,5,10,10,0).toIso8601String(),'u2': DateTime(2026,5,10,12,0).toIso8601String(),'u3': DateTime(2026,5,11,8,0).toIso8601String(),'u4': DateTime(2026,5,11,9,0).toIso8601String(),'u5': DateTime(2026,5,11,11,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/web3_workshop_may/800/500',
    tags: ['Workshop', 'Blockchain', 'Web3', 'Kod']),

  Event(id: 'ev_may14', clubId: 'c6', title: 'Salsa Soiree Gecesi',
    description: 'KUDans\'ın aylık Salsa Gecesi — başlangıç dersi 20:00, serbest dans 21:00. Partner getirmek zorunda değilsiniz. Dans pistine katılın ya da izleyerek keyif çıkarın!',
    location: 'Sports Hall B',
    dateTime: DateTime(2026, 5, 12, 20, 0),
    endTime:  DateTime(2026, 5, 12, 23, 0),
    attendeeUserIds: ['u4', 'u6', 'u8', 'u10', 'u12', 'u14'],
    rsvpTimestamps: {'u4': DateTime(2026,5,10,16,0).toIso8601String(),'u6': DateTime(2026,5,10,17,0).toIso8601String(),'u8': DateTime(2026,5,11,10,0).toIso8601String(),'u10': DateTime(2026,5,11,11,0).toIso8601String(),'u12': DateTime(2026,5,12,8,0).toIso8601String(),'u14': DateTime(2026,5,12,9,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/salsa_soiree_may/800/500'),

  Event(id: 'ev_may15', clubId: 'c32', title: 'Dijital Pazarlama ve İçerik Üretimi Paneli',
    description: '3 başarılı içerik yaratıcısı ve bir dijital ajans kurucusu ile panel: algoritma, marka, özgünlük. Q&A bölümünde sorularınızı yanıtlıyorlar.',
    location: 'SOS B140 Amphitheatre',
    dateTime: DateTime(2026, 5, 13, 15, 0),
    endTime:  DateTime(2026, 5, 13, 17, 30),
    attendeeUserIds: ['u2', 'u7', 'u9', 'u11', 'u13'],
    rsvpTimestamps: {'u2': DateTime(2026,5,11,13,0).toIso8601String(),'u7': DateTime(2026,5,11,14,0).toIso8601String(),'u9': DateTime(2026,5,12,9,0).toIso8601String(),'u11': DateTime(2026,5,12,10,0).toIso8601String(),'u13': DateTime(2026,5,12,11,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/digital_marketing_panel/800/500',
    guestSpeaker: 'Barış Özcan — İçerik Yaratıcısı & Girişimci'),

  Event(id: 'ev_may16', clubId: 'c17', title: 'Yapay Zeka ve Hukuk Paneli',
    description: 'AB Yapay Zeka Yasası\'nı tartışıyoruz: algoritmik sorumluluk, deepfake hukuku ve otomatik karar sistemleri. Hukuk, bilgisayar mühendisliği ve siyaset bilimi perspektifleri bir arada.',
    location: 'SOS B206',
    dateTime: DateTime(2026, 5, 13, 16, 0),
    endTime:  DateTime(2026, 5, 13, 18, 30),
    attendeeUserIds: ['u3', 'u9', 'u10', 'u14'],
    rsvpTimestamps: {'u3': DateTime(2026,5,11,9,0).toIso8601String(),'u9': DateTime(2026,5,11,10,0).toIso8601String(),'u10': DateTime(2026,5,12,8,0).toIso8601String(),'u14': DateTime(2026,5,12,9,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/ai_law_panel_may/800/500',
    tags: ['Panel', 'Hukuk', 'YZ', 'Tartışma']),

  Event(id: 'ev_may17', clubId: 'c35', title: 'Kusturica Film Gecesi: "Underground"',
    description: 'Sinema Kulübü Balkan Sineması Haftası — Emir Kusturica\'nın "Underground" (1995) filminin gösterimi. Palme d\'Or ödüllü başyapıt. Film sonrası tartışma oturumu.',
    location: 'SOS B140 Amphitheatre',
    dateTime: DateTime(2026, 5, 14, 19, 0),
    endTime:  DateTime(2026, 5, 14, 22, 0),
    attendeeUserIds: ['u1', 'u3', 'u5', 'u7', 'u10'],
    rsvpTimestamps: {'u1': DateTime(2026,5,12,11,0).toIso8601String(),'u3': DateTime(2026,5,12,13,0).toIso8601String(),'u5': DateTime(2026,5,13,9,0).toIso8601String(),'u7': DateTime(2026,5,13,10,0).toIso8601String(),'u10': DateTime(2026,5,13,11,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/kusturica_underground/800/500'),

  Event(id: 'ev_may18', clubId: 'c8', title: 'İklim Politikası Roundtable',
    description: 'EkoPolitik: Türkiye\'nin iklim taahhütleri ve Paris Anlaşması sonrası süreç. Enerji geçişi, karbon vergisi ve genç aktivizm üzerine öğrenci odaklı tartışma.',
    location: 'SOS B209 Seminar Room',
    dateTime: DateTime(2026, 5, 14, 17, 0),
    endTime:  DateTime(2026, 5, 14, 19, 30),
    attendeeUserIds: ['u1', 'u5', 'u7', 'u9', 'u10'],
    rsvpTimestamps: {'u1': DateTime(2026,5,12,10,0).toIso8601String(),'u5': DateTime(2026,5,12,12,0).toIso8601String(),'u7': DateTime(2026,5,13,8,0).toIso8601String(),'u9': DateTime(2026,5,13,9,0).toIso8601String(),'u10': DateTime(2026,5,13,10,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/climate_roundtable_may/800/500',
    tags: ['Panel', 'İklim', 'Politika', 'Tartışma']),

  Event(id: 'ev_may19', clubId: 'c12', title: 'Folklör Kulübü Yıl Sonu Gala Gecesi',
    description: 'Bu yılın en büyük folklör gösterisi! Zeybek, horon, halay ve karşılama bölümleriyle 50 dakikalık sahne performansı. Canlı saz eşliğiyle geleneksel kıyafetler. Ücretsiz giriş.',
    location: 'KU Amfitiyatrosu',
    dateTime: DateTime(2026, 5, 15, 20, 0),
    endTime:  DateTime(2026, 5, 15, 22, 30),
    attendeeUserIds: ['u1', 'u3', 'u4', 'u5', 'u6', 'u8', 'u10', 'u12', 'u14'],
    rsvpTimestamps: {'u1': DateTime(2026,5,8,9,0).toIso8601String(),'u3': DateTime(2026,5,8,10,0).toIso8601String(),'u4': DateTime(2026,5,9,8,0).toIso8601String(),'u5': DateTime(2026,5,9,9,0).toIso8601String(),'u6': DateTime(2026,5,10,8,0).toIso8601String(),'u8': DateTime(2026,5,10,9,0).toIso8601String(),'u10': DateTime(2026,5,11,8,0).toIso8601String(),'u12': DateTime(2026,5,11,9,0).toIso8601String(),'u14': DateTime(2026,5,12,8,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/folklore_gala_may/800/500',
    tags: ['Gala', 'Folklör', 'Canlı Müzik', 'Ücretsiz']),

  Event(id: 'ev_may20', clubId: 'c28', title: 'Perküsyon ve Ritim Atölyesi',
    description: 'Canlı perküsyon demosuyla başlayan, katılımcıların davul, bongo ve cajon denediği eğlenceli bir ritim atölyesi. Müzik bilgisi gerekmez — sadece ritim duygusu yeterli!',
    location: 'SOS B Atelier',
    dateTime: DateTime(2026, 5, 15, 15, 0),
    endTime:  DateTime(2026, 5, 15, 17, 0),
    attendeeUserIds: ['u2', 'u4', 'u8', 'u13'],
    rsvpTimestamps: {'u2': DateTime(2026,5,13,11,0).toIso8601String(),'u4': DateTime(2026,5,13,13,0).toIso8601String(),'u8': DateTime(2026,5,14,9,0).toIso8601String(),'u13': DateTime(2026,5,14,10,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/percussion_workshop_may/800/500'),

  // ── May 16–31 batch ──────────────────────────────────────────────────────────
  Event(id: 'ev_jun1', clubId: 'c4', title: 'Web Dev Workshop: React & Flutter',
    description: 'KUACM\'in haftalık workshop serisinin bu haftaki konusu modern frontend geliştirme. React hooks ve Flutter widget tree karşılaştırması, hands-on coding session ile birlikte.',
    location: 'ENG 208',
    dateTime: DateTime(2026, 5, 16, 14, 0),
    endTime:  DateTime(2026, 5, 16, 17, 0),
    attendeeUserIds: ['u1', 'u2', 'u5', 'u9'],
    rsvpTimestamps: {'u1': DateTime(2026,5,14,10,0).toIso8601String(),'u2': DateTime(2026,5,15,9,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/webdev_workshop/800/500',
    tags: ['Coding', 'Workshop', 'Frontend']),

  Event(id: 'ev_jun2', clubId: 'c27', title: 'Münazara: Yapay Zeka Etiği',
    description: '"Yapay zeka kararları insan kararlarının yerini alabilir mi?" — Bu hafta turnuva formatında iki takım karşı karşıya geliyor. İzleyiciler de tartışmaya katılabilir.',
    location: 'SCI 103',
    dateTime: DateTime(2026, 5, 17, 16, 0),
    endTime:  DateTime(2026, 5, 17, 18, 30),
    attendeeUserIds: ['u3', 'u6', 'u11', 'u14'],
    rsvpTimestamps: {'u3': DateTime(2026,5,15,11,0).toIso8601String(),'u6': DateTime(2026,5,16,8,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/debate_ai/800/500',
    tags: ['Münazara', 'Yapay Zeka', 'Etik']),

  Event(id: 'ev_jun3', clubId: 'c15', title: 'Startup Pitch Night #12',
    description: 'Girişimcilik Kulübü\'nün aylık pitch gecesi. 8 ekip 3 dakikada fikirlerini sunuyor, jüri geri bildirim veriyor. En iyi pitch 5.000 TL ödül kazanıyor.',
    location: 'Kurucular Salonu',
    dateTime: DateTime(2026, 5, 18, 18, 0),
    endTime:  DateTime(2026, 5, 18, 21, 0),
    attendeeUserIds: ['u1', 'u2', 'u4', 'u7', 'u10'],
    rsvpTimestamps: {'u1': DateTime(2026,5,16,9,0).toIso8601String(),'u2': DateTime(2026,5,16,10,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/pitch_night/800/500',
    tags: ['Girişimcilik', 'Pitch', 'Ödül']),

  Event(id: 'ev_jun4', clubId: 'c13', title: 'Golden Hour Photo Walk',
    description: 'KUFoto olarak kampüsün altın saatini yakalıyoruz. 17:30\'da SCI önünden yürüyüşe başlıyoruz. Kamera veya telefon — herkes bekliyor. Sonuçlar Instagram\'da paylaşılacak.',
    location: 'SCI Önü',
    dateTime: DateTime(2026, 5, 19, 17, 30),
    endTime:  DateTime(2026, 5, 19, 19, 30),
    attendeeUserIds: ['u2', 'u5', 'u8', 'u12'],
    rsvpTimestamps: {'u2': DateTime(2026,5,17,14,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/golden_hour_walk/800/500',
    tags: ['Fotoğraf', 'Golden Hour', 'Doğa']),

  Event(id: 'ev_jun5', clubId: 'c5', title: 'KU Tiyatrosu: "Kirli Eller" Provası Açık',
    description: 'KUDAK bu yıl Jean-Paul Sartre\'ın Kirli Eller oyununu sahnelemeye hazırlanıyor. Açık prova seyrinde olmak isteyenlere sınırlı sayıda yer.',
    location: 'SNA Tiyatro Salonu',
    dateTime: DateTime(2026, 5, 20, 19, 0),
    endTime:  DateTime(2026, 5, 20, 21, 30),
    attendeeUserIds: ['u3', 'u6', 'u9', 'u13', 'u15'],
    rsvpTimestamps: {'u3': DateTime(2026,5,18,11,0).toIso8601String(),'u6': DateTime(2026,5,18,12,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/kudak_rehearsal/800/500',
    tags: ['Tiyatro', 'Sartre', 'Prova']),

  Event(id: 'ev_jun6', clubId: 'c22', title: 'Çevre Temizliği — Sariyer Sahili',
    description: 'KU Gönüllüleri bu hafta Sarıyer sahilini temizliyor. Eldiven ve poşet sağlanacak. Minibüs kampüs ana kapısından 9:00\'da kalkıyor. Sonrasında mangal keyfi!',
    location: 'KU Ana Kapı (buluşma)',
    dateTime: DateTime(2026, 5, 21, 9, 0),
    endTime:  DateTime(2026, 5, 21, 13, 0),
    attendeeUserIds: ['u1', 'u4', 'u7', 'u10', 'u14'],
    rsvpTimestamps: {'u1': DateTime(2026,5,19,9,0).toIso8601String(),'u4': DateTime(2026,5,19,10,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/beach_cleanup/800/500',
    tags: ['Gönüllülük', 'Çevre', 'Temizlik']),

  Event(id: 'ev_jun7', clubId: 'c7', title: 'Ekonomi Semineri: Enflasyon Dinamikleri',
    description: 'Merkez Bankası eski baş ekonomisti Dr. Ayşe Koç\'un konuk konuşmacı olarak katılacağı bu seminer, Türkiye\'nin enflasyon dinamiklerini küresel perspektifle ele alıyor.',
    location: 'SOS 301',
    dateTime: DateTime(2026, 5, 22, 15, 0),
    endTime:  DateTime(2026, 5, 22, 17, 0),
    attendeeUserIds: ['u2', 'u5', 'u8', 'u11'],
    rsvpTimestamps: {'u2': DateTime(2026,5,20,10,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/econ_seminar/800/500',
    tags: ['Ekonomi', 'Seminer', 'Enflasyon']),

  Event(id: 'ev_jun8', clubId: 'c6', title: 'Dans Gösterisi: "Fusion 2026"',
    description: 'KUDans\'ın yıl sonu gösterisi — street dance, contemporary ve Latin füzyonu. 3 ay süren provanın meyvesi bu sahneye taşınıyor. Biletler sınırlı, kayıt gerekli.',
    location: 'KU Amfitiyatrosu',
    dateTime: DateTime(2026, 5, 23, 20, 0),
    endTime:  DateTime(2026, 5, 23, 22, 0),
    attendeeUserIds: ['u1', 'u3', 'u6', 'u9', 'u12', 'u15'],
    rsvpTimestamps: {'u1': DateTime(2026,5,21,9,0).toIso8601String(),'u3': DateTime(2026,5,21,10,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/kudans_show/800/500',
    tags: ['Dans', 'Gösteri', 'Fusion']),

  Event(id: 'ev_jun9', clubId: 'c34', title: 'Serbest Resim Günü — Açık Atölye',
    description: 'Resim Kulübü\'nün aylık açık atölye günü. Yağlı boya, suluboya, akrilik — tüm malzemeler sağlanıyor. İstediğin şeyi çiz, dilediğin süre kal. Kahve ve müzik eşliğinde.',
    location: 'SNA 201 Atölye',
    dateTime: DateTime(2026, 5, 24, 13, 0),
    endTime:  DateTime(2026, 5, 24, 18, 0),
    attendeeUserIds: ['u2', 'u4', 'u8'],
    rsvpTimestamps: {'u2': DateTime(2026,5,22,11,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/open_art_day/800/500',
    tags: ['Resim', 'Açık Atölye', 'Yaratıcılık']),

  Event(id: 'ev_jun10', clubId: 'c8', title: 'Model BM: Güvenlik Konseyi Simülasyonu',
    description: 'EkoPolitik Kulübü\'nün Model BM simülasyonunda bu dönem Güvenlik Konseyi gündemdeki kriz bölgeleri üzerine müzakere yapacak. Delegeler rollerini önceden çalışarak gelsin.',
    location: 'SOS 401',
    dateTime: DateTime(2026, 5, 25, 10, 0),
    endTime:  DateTime(2026, 5, 25, 16, 0),
    attendeeUserIds: ['u3', 'u5', 'u9', 'u13'],
    rsvpTimestamps: {'u3': DateTime(2026,5,23,9,0).toIso8601String(),'u5': DateTime(2026,5,23,10,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/model_un/800/500',
    tags: ['Model BM', 'Siyaset', 'Simülasyon']),

  Event(id: 'ev_jun11', clubId: 'c31', title: 'Oda Müziği Konseri',
    description: 'KU Orkestra Kulübü\'nün oda müziği topluluğundan özel bir konser. Beethoven, Brahms ve Bartók eserlerinden seçmeler. Sahne boyunca program notları ekrana yansıtılacak.',
    location: 'Kurucular Salonu',
    dateTime: DateTime(2026, 5, 26, 19, 30),
    endTime:  DateTime(2026, 5, 26, 21, 30),
    attendeeUserIds: ['u1', 'u4', 'u7', 'u11', 'u14'],
    rsvpTimestamps: {'u1': DateTime(2026,5,24,10,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/chamber_music/800/500',
    tags: ['Müzik', 'Klasik', 'Konser']),

  Event(id: 'ev_jun12', clubId: 'c17', title: 'Hukuk Moot Court: Ticaret Hukuku',
    description: 'KU Hukuk Kulübü\'nün moot court yarışmasında bu dönem ticaret hukuku vakaları ele alınıyor. Jüride gerçek avukatlar ve akademisyenler yer alıyor.',
    location: 'SOS 204',
    dateTime: DateTime(2026, 5, 27, 14, 0),
    endTime:  DateTime(2026, 5, 27, 18, 0),
    attendeeUserIds: ['u2', 'u6', 'u10'],
    rsvpTimestamps: {'u2': DateTime(2026,5,25,9,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/moot_court/800/500',
    tags: ['Hukuk', 'Moot Court', 'Ticaret']),

  Event(id: 'ev_jun13', clubId: 'c35', title: 'Film Gecesi: Wong Kar-wai Retrospektifi',
    description: 'KU Sinema Kulübü bu hafta Wong Kar-wai retrospektifine başlıyor. İlk gece "In the Mood for Love" ve "Chungking Express" arka arkaya gösterilecek. Popcorn bedava.',
    location: 'SOS Sinema Salonu',
    dateTime: DateTime(2026, 5, 28, 18, 0),
    endTime:  DateTime(2026, 5, 28, 23, 0),
    attendeeUserIds: ['u3', 'u5', 'u8', 'u12', 'u15'],
    rsvpTimestamps: {'u3': DateTime(2026,5,26,11,0).toIso8601String(),'u5': DateTime(2026,5,26,12,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/wkw_retro/800/500',
    tags: ['Film', 'Sinema', 'Wong Kar-wai']),

  Event(id: 'ev_jun14', clubId: 'c36', title: 'Sosyal Etkinlik: Kampüs Kaçış Oyunu',
    description: 'Bu hafta kampüste büyük kaçış oyunu! 4 kişilik takımlar bölümlere dağılmış ipuçlarını toplayıp 60 dakikada sırrı çözmeye çalışıyor. Kayıt sınırlı.',
    location: 'Kampüs Geneli',
    dateTime: DateTime(2026, 5, 29, 14, 0),
    endTime:  DateTime(2026, 5, 29, 17, 0),
    attendeeUserIds: ['u1', 'u2', 'u4', 'u7', 'u9'],
    rsvpTimestamps: {'u1': DateTime(2026,5,27,9,0).toIso8601String(),'u2': DateTime(2026,5,27,10,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/escape_game/800/500',
    tags: ['Sosyal', 'Oyun', 'Takım']),

  Event(id: 'ev_jun15', clubId: 'c39', title: 'Tiyatro Atölyesi: Doğaçlama',
    description: 'KUDAK bünyesindeki tiyatro atölyesinde bu hafta doğaçlama teknikleri işlenecek. "Evet, ve..." oyunları, sahne varlığı egzersizleri. Deneyim gerekmez!',
    location: 'SNA Küçük Sahne',
    dateTime: DateTime(2026, 5, 30, 15, 0),
    endTime:  DateTime(2026, 5, 30, 17, 30),
    attendeeUserIds: ['u6', 'u10', 'u13'],
    rsvpTimestamps: {'u6': DateTime(2026,5,28,10,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/improv_workshop/800/500',
    tags: ['Tiyatro', 'Doğaçlama', 'Atölye']),

  Event(id: 'ev_jun16', clubId: 'c4', title: 'Hackathon: Campus Tech Challenge',
    description: 'KUACM\'in 24 saatlik hackathonu! Kampüs sorunlarına teknolojik çözümler üretin. Takımlar 3-4 kişilik. Ödül havuzu 30.000 TL. Yemek ve enerji içeceği sağlanıyor.',
    location: 'ENG Zemin Kat Lobby',
    dateTime: DateTime(2026, 5, 31, 10, 0),
    endTime:  DateTime(2026, 6, 1, 10, 0),
    attendeeUserIds: ['u1', 'u2', 'u5', 'u7', 'u9', 'u11'],
    rsvpTimestamps: {'u1': DateTime(2026,5,29,9,0).toIso8601String(),'u2': DateTime(2026,5,29,10,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/campus_hackathon/800/500',
    tags: ['Hackathon', '24 Saat', 'Ödül']),

  Event(id: 'ev_jun17', clubId: 'c32', title: 'Pazarlama Vaka Yarışması',
    description: 'KU Pazarlama Kulübü\'nün vaka yarışmasında gerçek bir şirketin pazarlama problemini çözün. Takımlar 48 saat içinde sunum hazırlıyor. Finalistler sektör profesyonellerine sunum yapacak.',
    location: 'SOS 302',
    dateTime: DateTime(2026, 5, 17, 10, 0),
    endTime:  DateTime(2026, 5, 17, 13, 0),
    attendeeUserIds: ['u3', 'u6', 'u8', 'u12'],
    rsvpTimestamps: {'u3': DateTime(2026,5,15,9,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/marketing_case/800/500',
    tags: ['Pazarlama', 'Vaka', 'Yarışma']),

  Event(id: 'ev_jun18', clubId: 'c28', title: 'Türk Sanat Müziği Korosu: Bahar Konseri',
    description: 'KÜMK\'nün bahar dönemi kapanış konseri. 25 sesli koro, fasıl formatında Hicaz ve Uşşak makamlarından eserler icra edecek. Konser öncesi çay ve kurabiye ikramı.',
    location: 'Kurucular Salonu',
    dateTime: DateTime(2026, 5, 24, 19, 0),
    endTime:  DateTime(2026, 5, 24, 21, 0),
    attendeeUserIds: ['u1', 'u4', 'u8', 'u11', 'u14'],
    rsvpTimestamps: {'u1': DateTime(2026,5,22,9,0).toIso8601String(),'u4': DateTime(2026,5,22,10,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/sanat_muzik_bahar/800/500',
    tags: ['Müzik', 'Koro', 'Klasik']),

  Event(id: 'ev_jun19', clubId: 'c15', title: 'Angel Investor Buluşması',
    description: 'İstanbul\'dan 5 angel investor kampüse geliyor. Girişimcilik Kulübü üyeleri 1-on-1 15 dakikalık görüşme talep edebilir. Fikirlerinizi ve LinkedIn profilinizi hazır tutun.',
    location: 'Kurucular Salonu Lounge',
    dateTime: DateTime(2026, 5, 26, 14, 0),
    endTime:  DateTime(2026, 5, 26, 18, 0),
    attendeeUserIds: ['u2', 'u5', 'u9'],
    rsvpTimestamps: {'u2': DateTime(2026,5,24,10,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/angel_investor/800/500',
    tags: ['Yatırım', 'Networking', 'Girişimcilik']),

  Event(id: 'ev_jun20', clubId: 'c22', title: 'Kan Bağışı Kampanyası',
    description: 'KU Gönüllüleri ve Kızılay iş birliğiyle kampüste kan bağışı kampanyası. Sağlıklı ve 18+ herkes bağışçı olabilir. Bağış sonrası atıştırmalık ve sertifika verilecek.',
    location: 'SCI Giriş Holü',
    dateTime: DateTime(2026, 5, 28, 10, 0),
    endTime:  DateTime(2026, 5, 28, 16, 0),
    attendeeUserIds: ['u1', 'u3', 'u6', 'u10', 'u13'],
    rsvpTimestamps: {'u1': DateTime(2026,5,26,9,0).toIso8601String(),'u3': DateTime(2026,5,26,10,0).toIso8601String()},
    imagePath: 'https://picsum.photos/seed/blood_drive/800/500',
    tags: ['Sağlık', 'Gönüllülük', 'Kan Bağışı']),
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

  // ── Posts with real photos (Picsum — deterministic seeds) ───────────────────
  NewsPost(id: 'ni1',  clubId: 'c4',  authorId: 'u1', content: 'Hack-KU 2025 registration is now open! 48 hours of coding, mentors, food, and prizes. Tag a friend you\'re teaming up with 💻🔥',                                          createdAt: DateTime.now().subtract(const Duration(hours: 3)),            imagePath: 'https://picsum.photos/seed/hackku/800/500'),
  NewsPost(id: 'ni2',  clubId: 'c13', authorId: 'u4', content: 'Golden hour on campus — caught this moment between SOS and the library. Spring is officially here 🌅📷',                                                                   createdAt: DateTime.now().subtract(const Duration(hours: 7)),            imagePath: 'https://picsum.photos/seed/goldhour/800/500'),
  NewsPost(id: 'ni3',  clubId: 'c6',  authorId: 'u2', content: 'Bahar Şenliği prova kareleri! Sahneye 2 hafta kaldı — enerjimiz zirvedeyken bir göz atın 🕺💃',                                                                             createdAt: DateTime.now().subtract(const Duration(hours: 11)),           imagePath: 'https://picsum.photos/seed/dancekudan/800/500'),
  NewsPost(id: 'ni4',  clubId: 'c27', authorId: 'u3', content: 'Regional champions 🏆 The moment the final verdict was announced — we still can\'t believe it. Ankara, here we come!',                                                      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),  imagePath: 'https://picsum.photos/seed/debatewon/800/500'),
  NewsPost(id: 'ni5',  clubId: 'c28', authorId: 'u3', content: 'Open Mic sound check done ✅ The vibe in SOS B Atelier tonight is going to be unreal. Doors open at 8 PM — free entry 🎵',                                                  createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 5)),  imagePath: 'https://picsum.photos/seed/openmicku/800/500'),
  NewsPost(id: 'ni6',  clubId: 'c15', authorId: 'u2', content: 'KU Demo Day 2025 pitch prep workshop recap 🚀 Founders in the room gave us chills. Applications still open — link in bio.',                                                  createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 9)),  imagePath: 'https://picsum.photos/seed/demoday25/800/500'),
  NewsPost(id: 'ni7',  clubId: 'c35', authorId: 'u1', content: '"Uzak" — Nuri Bilge Ceylan retrospective night at the KU screening room. The silence was deafening in the best possible way 🎬',                                           createdAt: DateTime.now().subtract(const Duration(days: 2, hours: 1)),  imagePath: 'https://picsum.photos/seed/cinemanight/800/500'),
  NewsPost(id: 'ni8',  clubId: 'c31', authorId: 'u1', content: 'Bahar Konseri son prova! Brahms\'ın dörtlüsü bu akustik salonla buluşunca gerçekten büyülü bir şey oluyor 🎻',                                                             createdAt: DateTime.now().subtract(const Duration(days: 2, hours: 6)),  imagePath: 'https://picsum.photos/seed/orchestraku/800/500'),
  NewsPost(id: 'ni9',  clubId: 'c22', authorId: 'u4', content: 'Kadıköy çocuk parkı restorasyon projemiz tamamlandı! 35 gönüllü, 2 hafta, sıfır bütçe — saf keyif 💚',                                                                     createdAt: DateTime.now().subtract(const Duration(days: 2, hours: 14)), imagePath: 'https://picsum.photos/seed/volunteer22/800/500'),
  NewsPost(id: 'ni10', clubId: 'c5',  authorId: 'u2', content: 'Uludağ summit view at sunrise after a 6-hour ascent ⛰️ Worth every step. Who\'s joining the next climb?',                                                                  createdAt: DateTime.now().subtract(const Duration(days: 3, hours: 2)),  imagePath: 'https://picsum.photos/seed/uludag25/800/500'),
  NewsPost(id: 'ni11', clubId: 'c23', authorId: 'u2', content: 'KU Kartalları şampiyon! 🦅 Final maçının son saniyelerini kim hatırlar? İnanılmazdı. Kupamız evde!',                                                                       createdAt: DateTime.now().subtract(const Duration(days: 3, hours: 8)),  imagePath: 'https://picsum.photos/seed/basketballku/800/500'),
  NewsPost(id: 'ni12', clubId: 'c34', authorId: 'u3', content: '"Şehir ve Ruh" sergimizin açılış gecesi — 18 sanatçı, 40+ eser, 200+ ziyaretçi. Teşekkürler KU! 🎨',                                                                      createdAt: DateTime.now().subtract(const Duration(days: 3, hours: 15)), imagePath: 'https://picsum.photos/seed/artexhibit/800/500'),
  NewsPost(id: 'ni13', clubId: 'c20', authorId: 'u3', content: 'Women in Tech Summit 2025 — Google, Microsoft, Koç Holding\'den kadın liderler aynı sahnede 🌟 Kayıt bağlantısı bio\'da!',                                               createdAt: DateTime.now().subtract(const Duration(days: 4, hours: 3)),  imagePath: 'https://picsum.photos/seed/womenintech/800/500'),
  NewsPost(id: 'ni14', clubId: 'c39', authorId: 'u1', content: 'Thursday Improv Night highlights 🎭 No script, no plan — just pure chaos and laughter. Join us every Thursday at 19:30!',                                                  createdAt: DateTime.now().subtract(const Duration(days: 4, hours: 10)), imagePath: 'https://picsum.photos/seed/theatreimprov/800/500'),
  NewsPost(id: 'ni15', clubId: 'c9',  authorId: 'u3', content: 'Bahar dönemi ebru atölyesi bitti — işte öğrencilerimizin eserleri 🌊 Her biri tamamen benzersiz. Kayıt başladı!',                                                         createdAt: DateTime.now().subtract(const Duration(days: 5, hours: 1)),  imagePath: 'https://picsum.photos/seed/ebruart/800/500'),
  NewsPost(id: 'ni16', clubId: 'c33', authorId: 'u2', content: 'KU Radyo bu hafta canlı — Spotify\'da dinle, kampüste hisset 📻 Müzik, haberler, sürpriz konuklar. Yayın devam!',                                                         createdAt: DateTime.now().subtract(const Duration(days: 5, hours: 7)),  imagePath: 'https://picsum.photos/seed/radiostation/800/500'),
  NewsPost(id: 'ni17', clubId: 'c26', authorId: 'u4', content: 'Robolig 2025 robot tasarım süreci başladı 🤖 Alüminyum, motor, kod — her şey bir arada. Takımımıza katıl!',                                                               createdAt: DateTime.now().subtract(const Duration(days: 6, hours: 2)),  imagePath: 'https://picsum.photos/seed/robotdesign/800/500'),
  NewsPost(id: 'ni18', clubId: 'c12', authorId: 'u4', content: 'Folklör Kulübü yıl sonu gösterisi kostüm provası 👘 Zeybek, horon, halay — 15 Mayıs\'ta KU Amfisi\'nde görüşürüz!',                                                      createdAt: DateTime.now().subtract(const Duration(days: 6, hours: 9)),  imagePath: 'https://picsum.photos/seed/folklordance/800/500'),
  NewsPost(id: 'ni19', clubId: 'c24', authorId: 'u3', content: 'Onur Haftası fotoğraf sergisi açıldı 🌈 "Görünür ol" — bu haftanın teması bu. Herkes davetli, SOS Galerisi.',                                                             createdAt: DateTime.now().subtract(const Duration(days: 7, hours: 4)),  imagePath: 'https://picsum.photos/seed/pride24/800/500'),
  NewsPost(id: 'ni20', clubId: 'c37', authorId: 'u2', content: 'Osmanlı arşivleri workshopundan bir kare 📜 500 yıllık belgeler ellerimizde — tarih böyle öğrenilir.',                                                                    createdAt: DateTime.now().subtract(const Duration(days: 7, hours: 11)), imagePath: 'https://picsum.photos/seed/historyworkshop/800/500'),
  // ── Extra photo posts ────────────────────────────────────────────────────────
  NewsPost(id: 'ni21', clubId: 'c4',  authorId: 'u1', content: 'Late-night debugging session with the Hack-KU team 🌙 Three monitors, one energy drink, zero bugs (hopefully). Wish us luck!',                                             createdAt: DateTime.now().subtract(const Duration(hours: 1)),            imagePath: 'https://picsum.photos/seed/latenightcode/800/500'),
  NewsPost(id: 'ni22', clubId: 'c13', authorId: 'u4', content: 'Campus in the snow ❄️ Grabbed the camera before everyone woke up. These corridors hit different at 6 AM.',                                                                 createdAt: DateTime.now().subtract(const Duration(hours: 4)),            imagePath: 'https://picsum.photos/seed/snowcampus/800/500'),
  NewsPost(id: 'ni23', clubId: 'c5',  authorId: 'u2', content: 'Equipment check before the Uludağ ascent 🧗 Harness, ice axe, crampons — all good. See you at the summit!',                                                               createdAt: DateTime.now().subtract(const Duration(hours: 6)),            imagePath: 'https://picsum.photos/seed/climbgear/800/500'),
  NewsPost(id: 'ni24', clubId: 'c15', authorId: 'u2', content: 'Our Demo Day mentors this year are absolutely elite. Koç Group, Accenture, and Peak Games all in one room. Founders — this is your shot 🚀',                               createdAt: DateTime.now().subtract(const Duration(hours: 9)),            imagePath: 'https://picsum.photos/seed/startuproom/800/500'),
  NewsPost(id: 'ni25', clubId: 'c28', authorId: 'u3', content: 'Backstage before Open Mic Night 🎸 Nerves? A little. Excitement? Through the roof. Tonight is going to be special.',                                                       createdAt: DateTime.now().subtract(const Duration(hours: 14)),           imagePath: 'https://picsum.photos/seed/backstagemusic/800/500'),
  NewsPost(id: 'ni26', clubId: 'c27', authorId: 'u3', content: 'Nationals prep in full swing 📣 Motion: "This house believes AI will make democratic elections obsolete." Who\'s on which side?',                                           createdAt: DateTime.now().subtract(const Duration(hours: 20)),           imagePath: 'https://picsum.photos/seed/debateprep/800/500'),
  NewsPost(id: 'ni27', clubId: 'c22', authorId: 'u4', content: 'Beykoz Animal Shelter visit this Saturday 🐾 We\'re bringing food donations and volunteers. DM if you want to join — the more the merrier!',                              createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 1)),  imagePath: 'https://picsum.photos/seed/animalshelter/800/500'),
  NewsPost(id: 'ni28', clubId: 'c34', authorId: 'u3', content: 'Acrylic session from last Tuesday — mixing pigments, losing track of time, and loving every second of it 🎨',                                                              createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 7)),  imagePath: 'https://picsum.photos/seed/acrylicpaint/800/500'),
  NewsPost(id: 'ni29', clubId: 'c6',  authorId: 'u2', content: 'Hip-hop choreography workshop with 40+ participants yesterday 🔥 Energy was unreal. Video coming soon!',                                                                  createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 13)), imagePath: 'https://picsum.photos/seed/hiphopworkshop/800/500'),
  NewsPost(id: 'ni30', clubId: 'c39', authorId: 'u1', content: '"Waiting for Godot" set construction begins 🎭 Minimalist but powerful — exactly how Beckett intended it.',                                                                createdAt: DateTime.now().subtract(const Duration(days: 2, hours: 3)),  imagePath: 'https://picsum.photos/seed/theatreset/800/500'),

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

  // ══════════════════════════════════════════════════════════════════════════════
  // BATCH 2 — 20 new posts from diverse clubs (10 text + 10 image)
  // ══════════════════════════════════════════════════════════════════════════════

  // ── Text posts ────────────────────────────────────────────────────────────────
  NewsPost(id: 'n41', clubId: 'c7',  authorId: 'u1', title: 'Enflasyon Paneli Yarın!',
    content: 'Ekonomi Kulübü olarak yarın TCMB uzmanı ve iki akademisyenle "Enflasyon ve Para Politikası" paneli düzenliyoruz. Türkiye\'nin faiz ve enflasyon dinamiklerini anlayabileceğiniz nadir bir fırsat. SOS B140, saat 15:00 — ekonomiyi merak eden herkes beklenilir!',
    createdAt: DateTime.now().subtract(const Duration(hours: 3))),

  NewsPost(id: 'n42', clubId: 'c1',  authorId: 'u3', title: 'Boğaziçi Yürüyüşü Bu Hafta',
    content: 'KUARHA olarak bu hafta Boğaziçi kıyısının tarihi mimari mirasını keşfeden rehberli bir yürüyüş düzenliyoruz. Yalılar, köşkler ve 19. yüzyıl Osmanlı dönemi yapılarını yakından göreceğiz. KU ana kapısından hareket, ulaşım kendi imkânlarınızla. Katılım ücretsiz!',
    createdAt: DateTime.now().subtract(const Duration(hours: 6))),

  NewsPost(id: 'n43', clubId: 'c2',  authorId: 'u1', title: '23 Nisan Anma Etkinliğimiz Başladı',
    content: 'KUADK olarak 23 Nisan Ulusal Egemenlik ve Çocuk Bayramı kutlamalarımız şu an devam ediyor! Şiir dinletisi, belgesel gösterimi ve öğrenci sunumlarıyla dolu bir program. SOS Amfi\'de hâlâ devam ediyor — gel, paylaş!',
    createdAt: DateTime.now().subtract(const Duration(minutes: 45))),

  NewsPost(id: 'n44', clubId: 'c30', authorId: 'u3', title: 'Beyin Farkındalık Ayı Başladı',
    content: 'KU-SIGN olarak Mayıs Beyin Farkındalık Ayı\'nda bir dizi etkinlik düzenliyoruz. Yarınki beyin anatomisi atölyesinin ardından önümüzdeki hafta Nörolojik Rehabilitasyon Sempozyumu geliyor. Tıp, psikoloji ve biyoloji öğrencilerine özellikle tavsiye edilir!',
    createdAt: DateTime.now().subtract(const Duration(days: 1))),

  NewsPost(id: 'n45', clubId: 'c40', authorId: 'u4', title: 'Kafkasya Jeopolitiği Serimiz Bu Hafta',
    content: 'Türk Araştırmaları Topluluğu olarak bu hafta "Kafkasya Jeopolitiği: Türk Perspektifi" semineriyle yeni seminer serimize başlıyoruz. Güney Kafkasya\'daki dinamikler ve Türkiye\'nin politikasını derinlemesine analiz edeceğiz. Uluslararası ilişkiler öğrencileri mutlaka kaçırmasın!',
    createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 5))),

  NewsPost(id: 'n46', clubId: 'c3',  authorId: 'u2', title: 'Masumiyet Müzesi — 2. Oturum Bu Akşam',
    content: 'KUBBE Orhan Pamuk okuma grubumuzun ikinci oturumu bu akşam 21:00\'de SOS B108\'de! Bu hafta 100–200. sayfaları tartışıyoruz. Tartışma soruları Discord\'da paylaşıldı. Kitabı bitirmeseniz de gelebilirsiniz — herkese açık, sıcak bir atmosfer garanti!',
    createdAt: DateTime.now().subtract(const Duration(hours: 2))),

  NewsPost(id: 'n47', clubId: 'c23', authorId: 'u1', title: 'Basketbol Kupası Sergileniyor!',
    content: 'KU Basketbol Takımı\'nın şampiyonluk kupası bu hafta boyunca SOS giriş holünde sergileniyor! Fotoğraf çektirmek isteyenler sabah 09:00 ile akşam 18:00 arasında uğrayabilir. Tüm KU camiasını gururlandıran bu başarıyı birlikte kutlayalım! 🦅🏆',
    createdAt: DateTime.now().subtract(const Duration(hours: 14))),

  NewsPost(id: 'n48', clubId: 'c38', authorId: 'u3', title: 'Klinik Beceriler Günü Yarın',
    content: 'KUTÖB olarak yarın Tıp Binası Beceri Lab\'ında aylık simülasyon gününü düzenliyoruz. IV hat, venepuntur ve fizik muayene istasyonları hazır. Kıdemli tıp öğrencileri eğitici olarak katılacak. Tıp fakültesi 1–3. sınıf öğrencilerine öncelikle tavsiye edilir.',
    createdAt: DateTime.now().subtract(const Duration(hours: 8))),

  NewsPost(id: 'n49', clubId: 'c41', authorId: 'u4', title: 'Halk Müziği Konseri Bu Hafta',
    content: 'Türk Halk Müziği Kulübü olarak bu haftaki bahar konserimizi duyuruyoruz! Saz ve bağlama topluluğumuz geleneksel türkülerden modern yorumlara uzanan bir repertuvar sunacak. SOS B Atelier\'de, giriş tamamen ücretsiz. Tüm kampüsü bekliyoruz!',
    createdAt: DateTime.now().subtract(const Duration(days: 2))),

  NewsPost(id: 'n50', clubId: 'c9',  authorId: 'u2', title: 'Ebru Eserlerimiz Sergide!',
    content: 'Ebru Kulübü\'nün bu dönem atölyelerinde üretilen eserler bu hafta SOS Koridoru\'nda sergileniyor. Battal, taraklı ve bülbül yuvası teknikleriyle üretilmiş 30\'dan fazla özgün çalışma var. Geçerken bir göz atın, destekleriniz bizi mutlu ediyor!',
    createdAt: DateTime.now().subtract(const Duration(days: 3))),

  // ── Image posts ────────────────────────────────────────────────────────────────
  NewsPost(id: 'ni31', clubId: 'c7',  authorId: 'u1',
    content: 'Bloomberg terminali başında analiz seansı 📊 Bu hafta BIST 100 bileşenlerini inceledik. Yarın Borsa ve Yatırım 101 atölyesinde bu verileri gerçek hayata bağlıyoruz!',
    createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    imagePath: 'https://picsum.photos/seed/bloomberg_terminal/800/500'),

  NewsPost(id: 'ni32', clubId: 'c1',  authorId: 'u3',
    content: 'Troya\'dan ışıl ışıl kareler ✨ Geçen ayki saha gezisinden favori fotoğraflarım. Agamemnon\'un çatısının altında tarihle yüzleşmek inanılmaz bir his.',
    createdAt: DateTime.now().subtract(const Duration(days: 2, hours: 4)),
    imagePath: 'https://picsum.photos/seed/troy_archaeological/800/500'),

  NewsPost(id: 'ni33', clubId: 'c2',  authorId: 'u1',
    content: 'Atatürk\'ü anma törenimizden kareler 🇹🇷 Kampüste okunan şiirler, dalgalanan bayraklar ve saygı duruşu. Her yıl bu anı birlikte yaşamak büyük bir onur.',
    createdAt: DateTime.now().subtract(const Duration(days: 5, hours: 3)),
    imagePath: 'https://picsum.photos/seed/ataturk_ceremony/800/500'),

  NewsPost(id: 'ni34', clubId: 'c30', authorId: 'u3',
    content: 'Beyin modeli workshopundan kareler 🧠 Frontal lob, hipokampüs, amigdala… 3D model üzerinde çalışmak teorinin çok ötesinde bir anlayış kazandırıyor. Bir sonraki atölyeye kayıt açık!',
    createdAt: DateTime.now().subtract(const Duration(days: 3, hours: 6)),
    imagePath: 'https://picsum.photos/seed/brain_model_workshop/800/500'),

  NewsPost(id: 'ni35', clubId: 'c40', authorId: 'u4',
    content: 'Kafkasya panel hazırlıklarımızdan bir an 🗺️ Haritalar, kaynak makaleler ve flip chart ile dolu bir seminer odası. Bu hafta Perşembe — meraklısını bekleriz!',
    createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 9)),
    imagePath: 'https://picsum.photos/seed/caucasus_panel/800/500'),

  NewsPost(id: 'ni36', clubId: 'c12', authorId: 'u4',
    content: 'Gala gecesi provası tam gaz devam ediyor! 💃 Zeybek grubumuzun bu hareketine bayıldım. 10 gün sonra KU Amfi\'deyiz — biletler ücretsiz, yerinizi ayırtmayı unutmayın!',
    createdAt: DateTime.now().subtract(const Duration(hours: 11)),
    imagePath: 'https://picsum.photos/seed/folklor_gala_rehearsal/800/500'),

  NewsPost(id: 'ni37', clubId: 'c11', authorId: 'u1',
    content: 'Derby kutlamaları sürüyor! 💛💙 Kafeterya A dün gece bu haldeydi. Bu akşam Şampiyonlar Ligi için tekrar buradayız — yerinizi erkenden alın 🔥',
    createdAt: DateTime.now().subtract(const Duration(hours: 16)),
    imagePath: 'https://picsum.photos/seed/fenerbahce_celebration/800/500'),

  NewsPost(id: 'ni38', clubId: 'c14', authorId: 'u2',
    content: 'Hafta 1 dungeon haritamızı çizdik 🗺️ DM olarak bu kadar detaylı bir dünya oluşturmak harikaydı. Bu akşam Hafta 2\'de neler olacak bilemiyorum ama karakterleriniz için endişelenin 😈',
    createdAt: DateTime.now().subtract(const Duration(hours: 20)),
    imagePath: 'https://picsum.photos/seed/dnd_dungeon_map/800/500'),

  NewsPost(id: 'ni39', clubId: 'c17', authorId: 'u1',
    content: 'Moot Court hazırlıklarında son rötuşlar 📋 Takımımız davayı içselleştirdi, argümanlar keskin. Yapay Zeka ve Hukuk paneline hazır mısınız? 6 gün kaldı — kayıt açık!',
    createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 12)),
    imagePath: 'https://picsum.photos/seed/moot_court_prep/800/500'),

  NewsPost(id: 'ni40', clubId: 'c25', authorId: 'u3',
    content: 'Kürt Kültür Gecesi hazırlıklarından 🌿 Nevruz sofrasını kuruyor, geleneksel kıyafetleri düzenliyoruz. 8 gün sonra SOS Amfi\'deyiz. Herkesi bekliyoruz — birlikte öğrenelim!',
    createdAt: DateTime.now().subtract(const Duration(days: 4, hours: 7)),
    imagePath: 'https://picsum.photos/seed/kurdish_culture_prep/800/500'),

  // ── May 8–15 posts ──────────────────────────────────────────────────────────
  NewsPost(id: 'np_may1', clubId: 'c4', authorId: 'u1',
    title: 'LeetCode Maratonu Bu Hafta!',
    content: 'Bugün 14:00\'de Library Lab 3\'te haftalık LeetCode maratonumuz başlıyor. Graph ve DP ağırlıklı olacak bu hafta. Gelemeyen üyeler için çözümler Discord\'da paylaşılacak. Herkesi bekliyoruz! 💻',
    createdAt: DateTime(2026, 5, 8, 8, 30),
    imagePath: 'https://picsum.photos/seed/leetcode_post_may/800/500'),

  NewsPost(id: 'np_may2', clubId: 'c28', authorId: 'u3',
    title: 'Caz Çarşamba — Bu Gece!',
    content: 'Bu gece 20:00\'de SOS B Atelier\'de KÜMK\'nin bahar konseri var! Trio, quartet ve solo setler sizi bekliyor. 12 müzisyen, ücretsiz giriş, içecekler kulüpten. Harika bir gece olacak 🎷🎶',
    createdAt: DateTime(2026, 5, 8, 11, 0),
    imagePath: 'https://picsum.photos/seed/jazz_wednesday_post/800/500'),

  NewsPost(id: 'np_may3', clubId: 'c15', authorId: 'u2',
    title: 'Girişimci Kahvaltısı — Yarın Sabah!',
    content: 'Yarın 09:30\'da SOS Cafeteria Üst Kat\'ta haftalık startup kahvaltımız var. Bu hafta konuğumuz: ürünü pazara çıkarma aşamasındaki 2 kurucu. Kayıt gereksiz — sadece gel! ☕🚀',
    createdAt: DateTime(2026, 5, 8, 18, 0)),

  NewsPost(id: 'np_may4', clubId: 'c27', authorId: 'u3',
    content: 'Yarınki BP antrenmanının motionu açıklandı: "Bu meclis yapay zekanın sanat üretmesini yasaklamalıdır." Hazırlıklı gelmeniz şart değil — tartışma ortamı her şeyi götürür. SOS B209, 18:00 🎤',
    createdAt: DateTime(2026, 5, 8, 20, 0),
    imagePath: 'https://picsum.photos/seed/debate_motion_may/800/500'),

  NewsPost(id: 'np_may5', clubId: 'c31', authorId: 'u1',
    title: 'Bahar Konseri Biletle Hemen!',
    content: 'Cumartesi 20:00\'de KU Amfisi\'nde Dvořák ve Brahms ile unutulmaz bir gece yaşayacaksınız. 50 öğrenci müzisyen sahnede! Ücretsiz biletler tükenmeden yerinizi ayırtın — bağlantı bio\'da 🎻',
    createdAt: DateTime(2026, 5, 9, 9, 0),
    imagePath: 'https://picsum.photos/seed/orchestra_spring_post/800/500'),

  NewsPost(id: 'np_may6', clubId: 'c13', authorId: 'u4',
    content: 'Cumartesi sabahı makro fotoğraf atölyemiz için kampüs bahçesi hazır 🌸 Küçük detaylar büyük hikayeler anlatır. Telefon kameranız yeterli — sadece merakınızı getirin!',
    createdAt: DateTime(2026, 5, 9, 12, 0),
    imagePath: 'https://picsum.photos/seed/macro_photo_post/800/500'),

  NewsPost(id: 'np_may7', clubId: 'c36', authorId: 'u2',
    title: 'Cuma Oyun Gecesi!',
    content: 'Bu akşam 19:00\'da SCI 103\'te Cuma Oyun Gecesi var! Catan, Ticket to Ride, Codenames, Dixit... Arkadaşlarınla gel ya da yalnız gel ve yeni insanlarla tanış. Atıştırmalıklar kulüpten 🎲',
    createdAt: DateTime(2026, 5, 9, 16, 30),
    imagePath: 'https://picsum.photos/seed/game_night_post/800/500'),

  NewsPost(id: 'np_may8', clubId: 'c5', authorId: 'u2',
    content: 'Yarın sabah 07:30\'da Sports Center girişinden buluşuyoruz. 3 km yürüyüş + 30 dk açık hava yogası. Güneş henüz yükselirken kampüs gerçekten büyülü. Matınızı getirmeyi unutmayın 🧘🌅',
    createdAt: DateTime(2026, 5, 9, 21, 0),
    imagePath: 'https://picsum.photos/seed/morning_yoga_post/800/500'),

  NewsPost(id: 'np_may9', clubId: 'c34', authorId: 'u3',
    title: 'Açık Stüdyo Bugün!',
    content: 'Bugün 15:00\'den gece yarısına kadar Arts Studio 2\'deyiz. Suluboya, karakalem, akrilik — ne istersen yap. Tüm malzemeler mevcut, sehpalar hazır. Gel, çiz, rahatla 🎨',
    createdAt: DateTime(2026, 5, 9, 14, 0),
    imagePath: 'https://picsum.photos/seed/open_studio_post/800/500'),

  NewsPost(id: 'np_may10', clubId: 'c22', authorId: 'u4',
    title: 'Çocuk Hastanesi Ziyareti — Yarın!',
    content: 'Yarın sabah 09:30\'da KU Ana Kapı\'dan hareket ediyoruz. Çocuklar için oyunlar, çizimler, sürprizler... Gönüllülük saatlerini doldurmak ya da sadece iyi hissetmek için gel ❤️',
    createdAt: DateTime(2026, 5, 10, 19, 0)),

  NewsPost(id: 'np_may11', clubId: 'c39', authorId: 'u1',
    content: 'Bugün öğleden sonra pazar matinesimiz var! SOS B206, 14:00. Hiçbir deneyim şart değil — sadece sahneye çıkma cesareti. Gülmek garantili 😄🎭',
    createdAt: DateTime(2026, 5, 11, 11, 0),
    imagePath: 'https://picsum.photos/seed/improv_sunday_post/800/500'),

  NewsPost(id: 'np_may12', clubId: 'c7', authorId: 'u1',
    title: 'Bloomberg Terminali Atölyesi — Pazartesi',
    content: 'Ekonomi Kulübü\'nün Bloomberg terminali atölyesi Pazartesi 14:00\'de ENG Z27\'de. BIST hisse analizi, teknik göstergeler ve portföy çeşitlendirmesi. Kayıt için DM at! 📊',
    createdAt: DateTime(2026, 5, 11, 15, 0),
    imagePath: 'https://picsum.photos/seed/bloomberg_post/800/500'),

  NewsPost(id: 'np_may13', clubId: 'c4', authorId: 'u5',
    title: 'Web3 Workshop Kaydı Açıldı!',
    content: 'Pazartesi 17:00\'de Library Lab 3\'te Web3 ve Blockchain Workshopu başlıyor. Solidity, Ethereum test ağı, MetaMask. Sıfırdan başlayacağız — önceden bilgi şart değil. Kontenjan sınırlı! ⛓️',
    createdAt: DateTime(2026, 5, 11, 18, 0),
    imagePath: 'https://picsum.photos/seed/web3_workshop_post/800/500'),

  NewsPost(id: 'np_may14', clubId: 'c6', authorId: 'u2',
    title: 'Salsa Soiree — Bu Akşam!',
    content: 'Bu akşam 20:00\'de Sports Hall B\'de Salsa Soiree! Başlangıç dersi 20:00, serbest dans 21:00. Partner getirmek zorunda değilsiniz. Salsa\'nın ritmi sizi bulur 💃🕺',
    createdAt: DateTime(2026, 5, 12, 17, 0),
    imagePath: 'https://picsum.photos/seed/salsa_soiree_post/800/500'),

  NewsPost(id: 'np_may15', clubId: 'c32', authorId: 'u4',
    title: 'Dijital Pazarlama Paneli — Yarın!',
    content: 'Yarın 15:00\'de SOS B140\'ta içerik üretimi ve dijital pazarlama panelimiz var. Barış Özcan dahil 3 konuşmacı sahne alıyor. Sorularınızı hazırlayın — Q&A bölümü uzun tutulacak! 📱',
    createdAt: DateTime(2026, 5, 12, 20, 0),
    imagePath: 'https://picsum.photos/seed/digital_marketing_post/800/500'),

  NewsPost(id: 'np_may16', clubId: 'c17', authorId: 'u1',
    content: 'Yarın 16:00\'da "Yapay Zeka ve Hukuk" panelimiz var. AB YZ Yasası\'nı, deepfake hukukunu ve algoritmik sorumluluğu konuşacağız. Hukuk, CS ve siyaset bilimi öğrencileri — bu panel tam size göre! ⚖️',
    createdAt: DateTime(2026, 5, 12, 22, 0)),

  NewsPost(id: 'np_may17', clubId: 'c8', authorId: 'u4',
    title: 'İklim Politikası Roundtable — Çarşamba',
    content: 'Çarşamba 17:00\'de SOS B209\'da iklim politikası tartışması. Türkiye\'nin karbon taahhütleri, enerji geçişi ve yeşil yatırımlar gündemdeyiz. Tüm bölümlerden öğrenciler davetli 🌍',
    createdAt: DateTime(2026, 5, 13, 10, 0),
    imagePath: 'https://picsum.photos/seed/climate_post/800/500'),

  NewsPost(id: 'np_may18', clubId: 'c35', authorId: 'u1',
    title: 'Kusturica: Underground — Perşembe',
    content: 'Balkan Sineması Haftası devam ediyor! Perşembe 19:00\'da Kusturica\'nın Palme d\'Or ödüllü Underground filmini birlikte izliyoruz. Film sonrası tartışma oturumu. Popcorn benden 🎬🍿',
    createdAt: DateTime(2026, 5, 13, 14, 0),
    imagePath: 'https://picsum.photos/seed/underground_post/800/500'),

  NewsPost(id: 'np_may19', clubId: 'c12', authorId: 'u4',
    title: 'Gala Gecesi Cuma!',
    content: 'YARIN — Folklör Kulübü Yıl Sonu Gala Gecesi! KU Amfisi, 20:00. Zeybek, horon, halay, karşılama... 50 dakika saf Anadolu dansı ve canlı saz müziği. Ücretsiz giriş. Sizi bekliyoruz! 🌙💃',
    createdAt: DateTime(2026, 5, 14, 15, 0),
    imagePath: 'https://picsum.photos/seed/folklore_gala_post/800/500'),

  NewsPost(id: 'np_may20', clubId: 'c28', authorId: 'u3',
    title: 'Perküsyon Atölyesi — Bu Öğleden Sonra!',
    content: 'Bugün 15:00\'de SOS B Atelier\'de perküsyon atölyemiz var. Davul, bongo, cajon — hepsini deneyeceksiniz. Müzik bilgisi gerekmez, sadece ritim duygunuzu getirin! Ücretsiz 🥁',
    createdAt: DateTime(2026, 5, 15, 10, 0),
    imagePath: 'https://picsum.photos/seed/percussion_post/800/500'),

  // ── May 16–31 posts ──────────────────────────────────────────────────────────
  NewsPost(id: 'np_jun1', clubId: 'c4', authorId: 'u1',
    title: 'Web Dev Workshop Bu Cumartesi!',
    content: 'React hooks vs Flutter widgets — hangisi daha güçlü? Cevabı Cumartesi 14:00\'de ENG 208\'de tartışıyoruz. Laptop getirin, hazır olun! 💻🔥',
    createdAt: DateTime(2026, 5, 15, 12, 0),
    imagePath: 'https://picsum.photos/seed/webdev_post/800/500'),

  NewsPost(id: 'np_jun2', clubId: 'c27', authorId: 'u3',
    title: 'Yapay Zeka Münazarası — Pazar 16:00',
    content: '"AI insan kararlarının yerini alabilir mi?" sorusunu Pazar 16:00\'da SCI 103\'te tartışıyoruz. Tarafınızı şimdiden seçin ve argümanlarınızı hazırlayın! 🤖⚖️',
    createdAt: DateTime(2026, 5, 16, 10, 0),
    imagePath: 'https://picsum.photos/seed/debate_ai_post/800/500'),

  NewsPost(id: 'np_jun3', clubId: 'c15', authorId: 'u2',
    title: 'Pitch Night #12 — 3 Gün Kaldı!',
    content: 'Bu Pazartesi akşamı 18:00\'de Kurucular Salonu\'nda 8 ekip sahneye çıkıyor. Jüri, ödüller, network — hepsi var. Seyirci olarak gelin, ilham alın! 🚀',
    createdAt: DateTime(2026, 5, 17, 14, 0),
    imagePath: 'https://picsum.photos/seed/pitch_post/800/500'),

  NewsPost(id: 'np_jun4', clubId: 'c13', authorId: 'u5',
    title: 'Golden Hour Photo Walk — Salı 17:30',
    content: 'Kampüsün en güzel ışığını yakalayacağız. SCI önünde buluşuyoruz, gün batımına kadar yürüyoruz. Kamera veya telefon — fark etmez. Gelin! 📸🌅',
    createdAt: DateTime(2026, 5, 18, 11, 0),
    imagePath: 'https://picsum.photos/seed/photo_walk_post/800/500'),

  NewsPost(id: 'np_jun5', clubId: 'c5', authorId: 'u6',
    title: 'Açık Prova: Kirli Eller',
    content: 'Sartre\'ın Kirli Eller oyununu sahnelemeye hazırlanıyoruz. Çarşamba akşamı 19:00\'da SNA Tiyatro Salonu\'nda açık prova izleyicileri bekliyoruz. Ücretsiz! 🎭',
    createdAt: DateTime(2026, 5, 19, 9, 0),
    imagePath: 'https://picsum.photos/seed/kudak_post/800/500'),

  NewsPost(id: 'np_jun6', clubId: 'c22', authorId: 'u7',
    title: 'Sarıyer Sahil Temizliği — Cumartesi!',
    content: 'Bu hafta sonu sahile gidiyoruz — çöp toplamak için! 😄 Minibüs 09:00\'da ana kapıdan kalkıyor. Öğleden sonra mangal var. Kayıt linki biyografide!',
    createdAt: DateTime(2026, 5, 20, 10, 0),
    imagePath: 'https://picsum.photos/seed/cleanup_post/800/500'),

  NewsPost(id: 'np_jun7', clubId: 'c7', authorId: 'u8',
    title: 'Enflasyon Semineri — Cuma 15:00',
    content: 'Merkez Bankası eski baş ekonomisti Dr. Ayşe Koç ile Türkiye\'nin enflasyon dinamiklerini konuşacağız. SOS 301, bu Cuma 15:00. Ekonomi meraklıları kaçırmasın! 📊',
    createdAt: DateTime(2026, 5, 21, 12, 0),
    imagePath: 'https://picsum.photos/seed/econ_post/800/500'),

  NewsPost(id: 'np_jun8', clubId: 'c6', authorId: 'u9',
    title: '"Fusion 2026" Gösterisi — Cumartesi!',
    content: '3 aylık çalışmanın meyvesi bu hafta sahneye çıkıyor. Street dance + contemporary + Latin füzyonu. KU Amfisi, Cumartesi 20:00. Biletler tükeniyor! 💃🕺',
    createdAt: DateTime(2026, 5, 22, 11, 0),
    imagePath: 'https://picsum.photos/seed/dance_show_post/800/500'),

  NewsPost(id: 'np_jun9', clubId: 'c34', authorId: 'u4',
    title: 'Açık Atölye Günü — Pazar 13:00',
    content: 'Bu Pazar SNA 201\'de serbest resim günümüz var. Yağlı boya, suluboya, akrilik... Tüm malzemeler sağlanıyor. İstediğin kadar kal. Kahve eşliğinde boyayalım! 🎨',
    createdAt: DateTime(2026, 5, 23, 10, 0),
    imagePath: 'https://picsum.photos/seed/art_day_post/800/500'),

  NewsPost(id: 'np_jun10', clubId: 'c8', authorId: 'u11',
    title: 'Model BM Simülasyonu — Pazar 10:00',
    content: 'EkoPolitik Model BM\'de bu dönem Güvenlik Konseyi masaya oturuyor. Delegeler rollerini önceden çalışarak SOS 401\'e gelsin. Simülasyon 10:00\'da başlıyor! 🌍',
    createdAt: DateTime(2026, 5, 24, 9, 0),
    imagePath: 'https://picsum.photos/seed/mun_post/800/500'),

  NewsPost(id: 'np_jun11', clubId: 'c31', authorId: 'u14',
    title: 'Oda Müziği Konseri — Pazartesi 19:30',
    content: 'Beethoven\'dan Bartók\'a kadar Kurucular Salonu\'nda özel bir gece. Pazartesi 19:30. Koltuğunuzu şimdiden ayırtın — kapasitesi sınırlı! 🎻🎹',
    createdAt: DateTime(2026, 5, 25, 10, 0),
    imagePath: 'https://picsum.photos/seed/chamber_post/800/500'),

  NewsPost(id: 'np_jun12', clubId: 'c17', authorId: 'u10',
    title: 'Moot Court: Ticaret Hukuku Finalleri',
    content: 'Hukuk Kulübü moot court finallerinde gerçek avukatlar ve akademisyenler jüri koltuğunda. Salı 14:00 SOS 204. Hukuk öğrencileri izlemeye davet edildi! ⚖️',
    createdAt: DateTime(2026, 5, 26, 10, 0),
    imagePath: 'https://picsum.photos/seed/moot_post/800/500'),

  NewsPost(id: 'np_jun13', clubId: 'c35', authorId: 'u12',
    title: 'Wong Kar-wai Gecesi — Çarşamba!',
    content: '"In the Mood for Love" + "Chungking Express" arka arkaya! Sinema Kulübü retrospektifin ilk gecesi Çarşamba 18:00\'de SOS Sinema Salonu\'nda. Popcorn bedava 🎬',
    createdAt: DateTime(2026, 5, 27, 12, 0),
    imagePath: 'https://picsum.photos/seed/wkw_post/800/500'),

  NewsPost(id: 'np_jun14', clubId: 'c36', authorId: 'u13',
    title: 'Kampüs Kaçış Oyunu — Perşembe!',
    content: '4 kişilik takımlar, 60 dakika, 1 sır! Bu Perşembe 14:00\'de kampüs genelinde büyük kaçış oyunu başlıyor. Takımını kur, kayıt ol, ipuçlarını bul! 🔍',
    createdAt: DateTime(2026, 5, 28, 9, 0),
    imagePath: 'https://picsum.photos/seed/escape_post/800/500'),

  NewsPost(id: 'np_jun15', clubId: 'c39', authorId: 'u15',
    title: 'Doğaçlama Atölyesi — Cuma 15:00',
    content: '"Evet, ve..." — doğaçlamanın altın kuralı. Bu Cuma SNA Küçük Sahne\'de başlangıç seviyesi atölye. Deneyim gerekmez, sadece açık bir zihin getir! 🎭',
    createdAt: DateTime(2026, 5, 29, 11, 0),
    imagePath: 'https://picsum.photos/seed/improv_post/800/500'),

  NewsPost(id: 'np_jun16', clubId: 'c4', authorId: 'u1',
    title: 'Hackathon Kayıtları Son Gün!',
    content: '24 saatlik Campus Tech Challenge için son kayıt günü BUGÜN! 3-4 kişilik takımlarla başvur, 30.000 TL ödül havuzundan pay al. Yemek ve enerji içeceği bizden 💻🏆',
    createdAt: DateTime(2026, 5, 30, 9, 0),
    imagePath: 'https://picsum.photos/seed/hackathon_post/800/500'),

  NewsPost(id: 'np_jun17', clubId: 'c32', authorId: 'u3',
    title: 'Pazarlama Vaka Yarışması Başlıyor!',
    content: 'Gerçek bir şirketin pazarlama problemini çözme şansı! 48 saat, 1 sunum, sektör profesyonelleri karşısında. Takımını kur ve başvur. Son tarih Cuma! 📱',
    createdAt: DateTime(2026, 5, 16, 11, 0),
    imagePath: 'https://picsum.photos/seed/marketing_post/800/500'),

  NewsPost(id: 'np_jun18', clubId: 'c28', authorId: 'u3',
    title: 'Bahar Konseri — Pazar 19:00',
    content: 'KÜMK 25 sesli korosuyla Kurucular Salonu\'nda bu Pazar! Hicaz ve Uşşak makamlarından fasıl. Konser öncesi çay ve kurabiye ikramımız var. Herkesi bekliyoruz 🎵',
    createdAt: DateTime(2026, 5, 23, 12, 0),
    imagePath: 'https://picsum.photos/seed/koro_post/800/500'),

  NewsPost(id: 'np_jun19', clubId: 'c15', authorId: 'u2',
    title: 'Angel Investor Buluşması — Pazartesi!',
    content: '5 angel investor kampüste! 1-on-1 görüşme için kayıt formu açıldı. Fikrinizi ve LinkedIn profilinizi hazırlayın. Pazartesi 14:00-18:00 Kurucular Salonu Lounge. 🤝',
    createdAt: DateTime(2026, 5, 25, 9, 0),
    imagePath: 'https://picsum.photos/seed/investor_post/800/500'),

  NewsPost(id: 'np_jun20', clubId: 'c22', authorId: 'u7',
    title: 'Kan Bağışı Kampanyası — Çarşamba!',
    content: 'KU Gönüllüleri × Kızılay kan bağışı kampanyası bu Çarşamba! SCI Giriş Holü, 10:00-16:00. Sağlıklı ve 18+ herkes bağışçı olabilir. Sertifika ve ikramiye verilecek 🩸❤️',
    createdAt: DateTime(2026, 5, 27, 10, 0),
    imagePath: 'https://picsum.photos/seed/blood_post/800/500'),
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
  // Photo post comments
  Comment(id: 'cm25', postId: 'ni1',  userId: 'u3', content: 'Can\'t wait for Hack-KU!! 🔥 Our team is ready',                  createdAt: DateTime.now().subtract(const Duration(hours: 2))),
  Comment(id: 'cm26', postId: 'ni1',  userId: 'u5', content: 'Just signed up! See you there 💪',                               createdAt: DateTime.now().subtract(const Duration(hours: 1))),
  Comment(id: 'cm27', postId: 'ni2',  userId: 'u2', content: 'That shot is stunning 😍 The lighting is perfect',               createdAt: DateTime.now().subtract(const Duration(hours: 6))),
  Comment(id: 'cm28', postId: 'ni2',  userId: 'u5', content: 'This is what I miss every morning when I sleep in 😅',           createdAt: DateTime.now().subtract(const Duration(hours: 4))),
  Comment(id: 'cm29', postId: 'ni4',  userId: 'u1', content: 'You were incredible in that final round! Congrats 🏆',           createdAt: DateTime.now().subtract(const Duration(days: 1))),
  Comment(id: 'cm30', postId: 'ni4',  userId: 'u5', content: 'WE\'RE GOING TO NATIONALS 🎉',                                   createdAt: DateTime.now().subtract(const Duration(hours: 20))),
  Comment(id: 'cm31', postId: 'ni5',  userId: 'u1', content: 'Performing tonight? What song?? 🎸',                             createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 4))),
  Comment(id: 'cm32', postId: 'ni5',  userId: 'u4', content: 'The vibe in that room is always unreal',                        createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 3))),
  Comment(id: 'cm33', postId: 'ni9',  userId: 'u2', content: 'So proud of everyone who worked on this project ❤️',            createdAt: DateTime.now().subtract(const Duration(days: 2, hours: 12))),
  Comment(id: 'cm34', postId: 'ni10', userId: 'u3', content: 'That view after 6 hours of climbing… absolutely worth it ⛰️',   createdAt: DateTime.now().subtract(const Duration(days: 3))),
  Comment(id: 'cm35', postId: 'ni11', userId: 'u5', content: 'I was screaming at that last buzzer 😭🦅',                       createdAt: DateTime.now().subtract(const Duration(days: 3, hours: 6))),
  Comment(id: 'cm36', postId: 'ni21', userId: 'u2', content: 'Tag me as a teammate!! We\'re doing this 💻',                   createdAt: DateTime.now().subtract(const Duration(minutes: 30))),
  Comment(id: 'cm37', postId: 'ni25', userId: 'u4', content: 'Butterflies right before going on stage 🎶 Relatable',          createdAt: DateTime.now().subtract(const Duration(hours: 13))),
  // Comments on batch-2 posts
  Comment(id: 'cm38', postId: 'n41', userId: 'u2', content: 'TCMB\'den uzman geliyor mu? Kesinlikle orada olacağım 📈',                  createdAt: DateTime.now().subtract(const Duration(hours: 2))),
  Comment(id: 'cm39', postId: 'n41', userId: 'u9', content: 'Enflasyon konusu bu dönemin en kritik tartışması — çok değerli bir panel!',  createdAt: DateTime.now().subtract(const Duration(hours: 1))),
  Comment(id: 'cm40', postId: 'n43', userId: 'u7', content: 'Az önce geçtim, ortam çok güzeldi. Herkese gitmesini tavsiye ederim!',        createdAt: DateTime.now().subtract(const Duration(minutes: 20))),
  Comment(id: 'cm41', postId: 'n46', userId: 'u3', content: 'Geçen hafta harikaydi, bu hafta da geliyorum 📚',                             createdAt: DateTime.now().subtract(const Duration(hours: 1))),
  Comment(id: 'cm42', postId: 'n47', userId: 'u5', content: 'Fotoğrafı çektirdim bile! Kupayla poz vermek ayrı bir duygu 🏆🦅',           createdAt: DateTime.now().subtract(const Duration(hours: 12))),
  Comment(id: 'cm43', postId: 'ni31', userId: 'u2', content: 'Bloomberg erişimi olan bir kulüp — bu muhteşem. Yarın kesinlikle oradayım!',  createdAt: DateTime.now().subtract(const Duration(hours: 4))),
  Comment(id: 'cm44', postId: 'ni32', userId: 'u6', content: 'Bu fotoğraf bir müzeye yakışır. KUARHA her zaman farklı bir perspektif sunar!', createdAt: DateTime.now().subtract(const Duration(days: 2, hours: 2))),
  Comment(id: 'cm45', postId: 'ni36', userId: 'u8', content: 'Zeybek grubumuz bu yıl çok iyi, gala gecesi efsane olacak 🔥',               createdAt: DateTime.now().subtract(const Duration(hours: 9))),
  Comment(id: 'cm46', postId: 'ni37', userId: 'u11', content: 'BU AKŞAM KAFETERYADA 💛💙 Kim gelmiyor ki??',                               createdAt: DateTime.now().subtract(const Duration(hours: 14))),
  Comment(id: 'cm47', postId: 'ni38', userId: 'u5', content: 'O harita çok detaylı, DM gerçekten çok çalışmış. Bu akşam hazır mıyız?? 🎲', createdAt: DateTime.now().subtract(const Duration(hours: 18))),
  Comment(id: 'cm48', postId: 'ni40', userId: 'u6', content: 'Bu etkinliği çok bekliyorum! Kürt mutfağını ilk kez deneyeceğim 🌿',          createdAt: DateTime.now().subtract(const Duration(days: 4, hours: 5))),
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
  // Photo post likes
  Like(id: 'l40', postId: 'ni1',  userId: 'u3'),
  Like(id: 'l41', postId: 'ni1',  userId: 'u5'),
  Like(id: 'l42', postId: 'ni1',  userId: 'u7'),
  Like(id: 'l43', postId: 'ni2',  userId: 'u1'),
  Like(id: 'l44', postId: 'ni2',  userId: 'u2'),
  Like(id: 'l45', postId: 'ni2',  userId: 'u5'),
  Like(id: 'l46', postId: 'ni3',  userId: 'u4'),
  Like(id: 'l47', postId: 'ni3',  userId: 'u6'),
  Like(id: 'l48', postId: 'ni4',  userId: 'u1'),
  Like(id: 'l49', postId: 'ni4',  userId: 'u2'),
  Like(id: 'l50', postId: 'ni4',  userId: 'u4'),
  Like(id: 'l51', postId: 'ni4',  userId: 'u5'),
  Like(id: 'l52', postId: 'ni5',  userId: 'u1'),
  Like(id: 'l53', postId: 'ni5',  userId: 'u4'),
  Like(id: 'l54', postId: 'ni5',  userId: 'u5'),
  Like(id: 'l55', postId: 'ni6',  userId: 'u3'),
  Like(id: 'l56', postId: 'ni6',  userId: 'u5'),
  Like(id: 'l57', postId: 'ni7',  userId: 'u2'),
  Like(id: 'l58', postId: 'ni7',  userId: 'u4'),
  Like(id: 'l59', postId: 'ni8',  userId: 'u1'),
  Like(id: 'l60', postId: 'ni8',  userId: 'u3'),
  Like(id: 'l61', postId: 'ni9',  userId: 'u1'),
  Like(id: 'l62', postId: 'ni9',  userId: 'u5'),
  Like(id: 'l63', postId: 'ni10', userId: 'u3'),
  Like(id: 'l64', postId: 'ni10', userId: 'u4'),
  Like(id: 'l65', postId: 'ni11', userId: 'u5'),
  Like(id: 'l66', postId: 'ni11', userId: 'u9'),
  Like(id: 'l67', postId: 'ni12', userId: 'u6'),
  Like(id: 'l68', postId: 'ni12', userId: 'u10'),
  Like(id: 'l69', postId: 'ni21', userId: 'u2'),
  Like(id: 'l70', postId: 'ni21', userId: 'u4'),
  Like(id: 'l71', postId: 'ni21', userId: 'u5'),
  Like(id: 'l72', postId: 'ni22', userId: 'u1'),
  Like(id: 'l73', postId: 'ni22', userId: 'u5'),
  Like(id: 'l74', postId: 'ni25', userId: 'u2'),
  Like(id: 'l75', postId: 'ni25', userId: 'u5'),
  Like(id: 'l76', postId: 'ni29', userId: 'u4'),
  Like(id: 'l77', postId: 'ni29', userId: 'u8'),
  // Likes for batch-2 posts
  Like(id: 'l78',  postId: 'n41',  userId: 'u2'),
  Like(id: 'l79',  postId: 'n41',  userId: 'u7'),
  Like(id: 'l80',  postId: 'n41',  userId: 'u9'),
  Like(id: 'l81',  postId: 'n42',  userId: 'u3'),
  Like(id: 'l82',  postId: 'n42',  userId: 'u6'),
  Like(id: 'l83',  postId: 'n43',  userId: 'u1'),
  Like(id: 'l84',  postId: 'n43',  userId: 'u8'),
  Like(id: 'l85',  postId: 'n44',  userId: 'u9'),
  Like(id: 'l86',  postId: 'n44',  userId: 'u12'),
  Like(id: 'l87',  postId: 'n45',  userId: 'u3'),
  Like(id: 'l88',  postId: 'n45',  userId: 'u7'),
  Like(id: 'l89',  postId: 'n46',  userId: 'u6'),
  Like(id: 'l90',  postId: 'n46',  userId: 'u10'),
  Like(id: 'l91',  postId: 'n47',  userId: 'u5'),
  Like(id: 'l92',  postId: 'n47',  userId: 'u9'),
  Like(id: 'l93',  postId: 'n47',  userId: 'u11'),
  Like(id: 'l94',  postId: 'n48',  userId: 'u9'),
  Like(id: 'l95',  postId: 'n49',  userId: 'u8'),
  Like(id: 'l96',  postId: 'n49',  userId: 'u14'),
  Like(id: 'l97',  postId: 'n50',  userId: 'u4'),
  Like(id: 'l98',  postId: 'ni31', userId: 'u2'),
  Like(id: 'l99',  postId: 'ni31', userId: 'u9'),
  Like(id: 'l100', postId: 'ni32', userId: 'u6'),
  Like(id: 'l101', postId: 'ni32', userId: 'u7'),
  Like(id: 'l102', postId: 'ni33', userId: 'u1'),
  Like(id: 'l103', postId: 'ni33', userId: 'u8'),
  Like(id: 'l104', postId: 'ni34', userId: 'u9'),
  Like(id: 'l105', postId: 'ni34', userId: 'u10'),
  Like(id: 'l106', postId: 'ni35', userId: 'u3'),
  Like(id: 'l107', postId: 'ni36', userId: 'u4'),
  Like(id: 'l108', postId: 'ni36', userId: 'u8'),
  Like(id: 'l109', postId: 'ni36', userId: 'u12'),
  Like(id: 'l110', postId: 'ni37', userId: 'u5'),
  Like(id: 'l111', postId: 'ni37', userId: 'u7'),
  Like(id: 'l112', postId: 'ni37', userId: 'u11'),
  Like(id: 'l113', postId: 'ni38', userId: 'u5'),
  Like(id: 'l114', postId: 'ni38', userId: 'u11'),
  Like(id: 'l115', postId: 'ni39', userId: 'u3'),
  Like(id: 'l116', postId: 'ni39', userId: 'u10'),
  Like(id: 'l117', postId: 'ni40', userId: 'u6'),
  Like(id: 'l118', postId: 'ni40', userId: 'u7'),
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

  // ── Messages to/from Hakan Tuncay (u5) ─────────────────────────────────────
  // — Conversation with Alice (u1) —
  Message(id: 'msg10', senderId: 'u1', receiverId: 'u5', content: 'Hey Hakan! Are you signing up for Hack-KU? We need a strong team this year 💪',        sentAt: DateTime.now().subtract(const Duration(minutes: 20))),
  Message(id: 'msg11', senderId: 'u1', receiverId: 'u5', content: 'Also, Flutter workshop is this Friday — you should definitely come!',                   sentAt: DateTime.now().subtract(const Duration(minutes: 18))),
  Message(id: 'msg10r', senderId: 'u5', receiverId: 'u1', content: 'Yes! 100% signing up. Who else is on the team so far?',                               sentAt: DateTime.now().subtract(const Duration(minutes: 15))),
  Message(id: 'msg10r2', senderId: 'u1', receiverId: 'u5', content: 'Me, Can, and maybe Deniz. We need one more with backend skills 👀',                   sentAt: DateTime.now().subtract(const Duration(minutes: 12))),
  Message(id: 'msg10r3', senderId: 'u5', receiverId: 'u1', content: 'I can do backend! I\'ve been doing FastAPI stuff all semester',                       sentAt: DateTime.now().subtract(const Duration(minutes: 10))),
  Message(id: 'msg10r4', senderId: 'u1', receiverId: 'u5', content: 'Perfect 🎉 I\'ll add you to our WhatsApp group. Flutter workshop is the pre-game!',   sentAt: DateTime.now().subtract(const Duration(minutes: 8))),

  // — Conversation with Can (u2) —
  Message(id: 'msg12', senderId: 'u2', receiverId: 'u5', content: 'Hakan, I saw you joined KU Gönüllüleri — the playground project this Saturday is going to be amazing!', sentAt: DateTime.now().subtract(const Duration(hours: 3))),
  Message(id: 'msg13', senderId: 'u2', receiverId: 'u5', content: 'Meet at the main gate at 09:30, don\'t be late 😄',                                    sentAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 55))),
  Message(id: 'msg12r', senderId: 'u5', receiverId: 'u2', content: 'I\'ll be there! Should I bring anything specific?',                                   sentAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 40))),
  Message(id: 'msg12r2', senderId: 'u2', receiverId: 'u5', content: 'Just old clothes you don\'t mind getting dirty 😂 and maybe snacks for the group',   sentAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 30))),
  Message(id: 'msg12r3', senderId: 'u5', receiverId: 'u2', content: 'On it. Bringing enough simit for everyone 🥨',                                       sentAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 20))),
  Message(id: 'msg12r4', senderId: 'u2', receiverId: 'u5', content: 'Legend 😂😂 see you Saturday!',                                                      sentAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 15))),

  // — Conversation with Emir (u3) —
  Message(id: 'msg14', senderId: 'u3', receiverId: 'u5', content: 'Hi! Emir here from the Münazara Kulübü. We\'re looking for new members — interested?', sentAt: DateTime.now().subtract(const Duration(hours: 6))),
  Message(id: 'msg14r', senderId: 'u5', receiverId: 'u3', content: 'Hey Emir! Yeah, actually I\'ve been thinking about joining. What\'s the time commitment like?', sentAt: DateTime.now().subtract(const Duration(hours: 5, minutes: 40))),
  Message(id: 'msg14r2', senderId: 'u3', receiverId: 'u5', content: 'One practice session per week + tournaments 3-4 times a semester. Very manageable!',  sentAt: DateTime.now().subtract(const Duration(hours: 5, minutes: 20))),
  Message(id: 'msg14r3', senderId: 'u5', receiverId: 'u3', content: 'That sounds doable. When\'s the next meeting?',                                       sentAt: DateTime.now().subtract(const Duration(hours: 5))),
  Message(id: 'msg14r4', senderId: 'u3', receiverId: 'u5', content: 'This Thursday 18:00, SOS B108. Come by and see if you like the vibe 🎤',               sentAt: DateTime.now().subtract(const Duration(hours: 4, minutes: 45))),
  Message(id: 'msg14r5', senderId: 'u5', receiverId: 'u3', content: 'I\'ll be there 👍',                                                                   sentAt: DateTime.now().subtract(const Duration(hours: 4, minutes: 30))),

  // — Conversation with Deniz (u4) —
  Message(id: 'msg15', senderId: 'u4', receiverId: 'u5', content: 'Hakan bro, the KUFoto golden hour walk is this Saturday. You\'re coming right? 📷',    sentAt: DateTime.now().subtract(const Duration(days: 1, hours: 2))),
  Message(id: 'msg16', senderId: 'u4', receiverId: 'u5', content: 'Bring your phone at least — the campus looks unreal at sunset',                         sentAt: DateTime.now().subtract(const Duration(days: 1, hours: 1, minutes: 58))),
  Message(id: 'msg15r', senderId: 'u5', receiverId: 'u4', content: 'Definitely coming! Should I bring a tripod? I have a small one',                       sentAt: DateTime.now().subtract(const Duration(days: 1, hours: 1, minutes: 30))),
  Message(id: 'msg15r2', senderId: 'u4', receiverId: 'u5', content: 'Yes please! Great for long exposures. It\'s going to be a perfect shoot',             sentAt: DateTime.now().subtract(const Duration(days: 1, hours: 1, minutes: 15))),
  Message(id: 'msg15r3', senderId: 'u5', receiverId: 'u4', content: 'Also — are we submitting anything to the spring exhibition? Deadline is soon I think', sentAt: DateTime.now().subtract(const Duration(days: 1, hours: 1))),
  Message(id: 'msg15r4', senderId: 'u4', receiverId: 'u5', content: 'Next Friday! I can help you pick your best 3 shots after the walk 📸',                sentAt: DateTime.now().subtract(const Duration(days: 1, minutes: 50))),

  // — Conversation with Selin (u8) —
  Message(id: 'msg17', senderId: 'u8', receiverId: 'u5', content: 'Hey! Selin from the Dans Kulübü — we heard you\'re interested in the Spring Showcase. Auditions are Wed & Thu 19:00!', sentAt: DateTime.now().subtract(const Duration(days: 3))),
  Message(id: 'msg17r', senderId: 'u5', receiverId: 'u8', content: 'Hi Selin! Yeah I\'ve been thinking about it. I have zero dance experience though 😅', sentAt: DateTime.now().subtract(const Duration(days: 2, hours: 23))),
  Message(id: 'msg17r2', senderId: 'u8', receiverId: 'u5', content: 'No worries at all! We teach from scratch. Hip-hop beginner group still has spots',    sentAt: DateTime.now().subtract(const Duration(days: 2, hours: 22))),
  Message(id: 'msg17r3', senderId: 'u5', receiverId: 'u8', content: 'Okay you convinced me 😄 Wednesday at 19:00 in Gym B right?',                         sentAt: DateTime.now().subtract(const Duration(days: 2, hours: 21, minutes: 30))),
  Message(id: 'msg17r4', senderId: 'u8', receiverId: 'u5', content: 'Exactly! Wear comfortable clothes. See you there 🕺',                                 sentAt: DateTime.now().subtract(const Duration(days: 2, hours: 21))),

  // — Conversation with Yunuscan (u11) —
  Message(id: 'msg18', senderId: 'u11', receiverId: 'u5', content: 'Kemal here. Did you catch the Fenerbahçe match last night? 🔥 We\'re screening the next one at the club room', sentAt: DateTime.now().subtract(const Duration(days: 5))),
  Message(id: 'msg18r', senderId: 'u5', receiverId: 'u11', content: 'That second half was INSANE 😭 Yes I\'m coming to the screening, when is it?',       sentAt: DateTime.now().subtract(const Duration(days: 4, hours: 23))),
  Message(id: 'msg18r2', senderId: 'u11', receiverId: 'u5', content: 'Derby is in 3 days! We\'re meeting at Kafeterya A, 20:00. Come early for a good spot', sentAt: DateTime.now().subtract(const Duration(days: 4, hours: 22))),
  Message(id: 'msg18r3', senderId: 'u5', receiverId: 'u11', content: 'I\'ll be there at 19:30 to grab seats. Should I bring anything?',                   sentAt: DateTime.now().subtract(const Duration(days: 4, hours: 21, minutes: 30))),
  Message(id: 'msg18r4', senderId: 'u11', receiverId: 'u5', content: 'Just your jersey 💛💙 Club handles snacks. CMON FENERBAHÇE',                          sentAt: DateTime.now().subtract(const Duration(days: 4, hours: 21))),
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
  // The user/admin ID of whoever created this story. Used for ownership-based deletion.
  final String? createdByUserId;

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
    this.createdByUserId,
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
        'createdByUserId': createdByUserId,
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
        createdByUserId: m['createdByUserId'] as String?,
      );
}

final clubStories = <ClubStory>[
  // KUACM – 2 stories
  ClubStory(id: 'st1',  clubId: 'c4',  emoji: '💻', text: 'Hack-KU 2025 starts in 5 days!\n48 hours, unlimited coffee, and prizes worth 100K TL. Registration closes tomorrow night — don\'t miss it!',       postedAt: DateTime.now().subtract(const Duration(hours: 1)),            imagePath: 'https://picsum.photos/seed/hackku_story/400/700'),
  ClubStory(id: 'st2',  clubId: 'c4',  emoji: '📱', text: 'Flutter Workshop this Friday at 17:00 in ENG B13.\nBuild your first mobile app from scratch. No experience needed — just bring your laptop!',           postedAt: DateTime.now().subtract(const Duration(hours: 5))),

  // KUFoto – 2 stories
  ClubStory(id: 'st3',  clubId: 'c13', emoji: '🌅', text: 'Golden hour photo walk on campus this Saturday at 17:30.\nMeet at the main fountain. Bring your camera or phone — all levels welcome!',                postedAt: DateTime.now().subtract(const Duration(hours: 2)),            imagePath: 'https://picsum.photos/seed/goldhour_story/400/700'),
  ClubStory(id: 'st4',  clubId: 'c13', emoji: '🎞️', text: 'Darkroom sessions are back every Thursday evening starting next week.\nFilm developing, printing, and enlarger training. Book your spot now!',           postedAt: DateTime.now().subtract(const Duration(hours: 8)),            imagePath: 'https://picsum.photos/seed/darkroom_story/400/700'),

  // KUDAK – 1 story
  ClubStory(id: 'st5',  clubId: 'c5',  emoji: '⛰️', text: 'Uludağ Winter Climb — 15 February.\nOnly 4 spots remain. Certified guides, group equipment and transport included.\nPhysical briefing: Monday 18:00.',  postedAt: DateTime.now().subtract(const Duration(hours: 3)),            imagePath: 'https://picsum.photos/seed/uludag_story/400/700'),

  // KUDans – 1 story
  ClubStory(id: 'st6',  clubId: 'c6',  emoji: '💃', text: 'Spring Showcase auditions are open!\nWe\'re looking for dancers in Salsa, Hip-Hop and Contemporary.\nAuditions: Wednesday & Thursday, 19:00–21:00, Gym B.',  postedAt: DateTime.now().subtract(const Duration(hours: 4)),          imagePath: 'https://picsum.photos/seed/dance_story/400/700'),

  // Girişimcilik – 1 story
  ClubStory(id: 'st7',  clubId: 'c15', emoji: '🚀', text: 'KU Demo Day 2025 applications are LIVE!\n500,000 TL prize pool. 20 startups. Real investors.\nDeadline: March 15. Apply at girişim.ku.edu.tr',             postedAt: DateTime.now().subtract(const Duration(hours: 6)),            imagePath: 'https://picsum.photos/seed/startup_story/400/700'),

  // KÜMK – 1 story
  ClubStory(id: 'st8',  clubId: 'c28', emoji: '🎶', text: 'Open Mic Night this Friday at 20:00 in SOS B Atelier.\nSingers, guitarists, pianists — sign up at the door or DM us.\nFree entry. See you there! 🎵',      postedAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 30)), imagePath: 'https://picsum.photos/seed/openmic_story/400/700'),

  // Münazara – 1 story
  ClubStory(id: 'st9',  clubId: 'c27', emoji: '🏆', text: 'We won the Regional Championship! 🎉\nUnanimous panel decision. Ceren and Deniz were outstanding.\nNationals in Ankara — April 18–20. Koç is going!',      postedAt: DateTime.now().subtract(const Duration(hours: 10)),           imagePath: 'https://picsum.photos/seed/debate_story/400/700'),

  // Sinema – 1 story
  ClubStory(id: 'st10', clubId: 'c35', emoji: '🎬', text: 'Nuri Bilge Ceylan Retrospective — Week 2.\n"Once Upon a Time in Anatolia" screening Wednesday at 19:00, SOS B140.\nFree for all Koç students.',             postedAt: DateTime.now().subtract(const Duration(hours: 7)),            imagePath: 'https://picsum.photos/seed/cinema_story/400/700'),

  // KU Gönüllüleri – 1 story
  ClubStory(id: 'st11', clubId: 'c22', emoji: '❤️', text: 'Kadıköy Children\'s Playground Restoration Project.\nThis Saturday 10:00 AM. Bring gloves and good energy.\nTransportation provided from main gate at 09:30.', postedAt: DateTime.now().subtract(const Duration(hours: 12))),

  // Tiyatro – 1 story
  ClubStory(id: 'st12', clubId: 'c39', emoji: '🎭', text: 'Auditions for "Waiting for Godot" — Feb 12 & 13!\nNo prior experience required. Just show up and be yourself.\nSOS B206, 17:00–20:00. See you on stage!',      postedAt: DateTime.now().subtract(const Duration(hours: 9)),            imagePath: 'https://picsum.photos/seed/theatre_story/400/700'),

  // KUMech – 1 story
  ClubStory(id: 'st13', clubId: 'c26', emoji: '⚙️', text: 'Robolig 2025 prep is underway!\nRobot design workshop Monday at 16:00 in MFG Lab.\nAll mechanical engineering students invited — beginners especially welcome.',  postedAt: DateTime.now().subtract(const Duration(hours: 11)),         imagePath: 'https://picsum.photos/seed/robotics_story/400/700'),

  // EkoPolitik – 1 story
  ClubStory(id: 'st14', clubId: 'c8',  emoji: '📊', text: '"AI and the Future of Work" panel — Tuesday 18:00.\n4 speakers from 2 universities. SOS B140.\nFollow-up networking session with snacks afterwards.',            postedAt: DateTime.now().subtract(const Duration(hours: 14))),

  // KU-SIGN – 1 story
  ClubStory(id: 'st15', clubId: 'c30', emoji: '🧠', text: 'Neurological Rehabilitation Symposium registrations are open!\nCapacity: 50 students. Certificate of attendance provided.\nRegister at kusign.ku.edu.tr — closes Friday.',  postedAt: DateTime.now().subtract(const Duration(hours: 16))),

  // Fenerbahçeliler (c11) – live match story
  ClubStory(id: 'st16', clubId: 'c11', emoji: '💛', text: 'DERBY NIGHT IS HERE! 🔥\nFenerbahçe vs Galatasaray — LIVE right now!\nCafeteria A, come join us! Snacks provided 💙',
    postedAt: DateTime.now().subtract(const Duration(minutes: 15)),
    imagePath: 'https://picsum.photos/seed/derby_story/400/700'),

  // Girişimcilik (c15) – pitch night reminder
  ClubStory(id: 'st17', clubId: 'c15', emoji: '💡', text: 'Startup Pitch Night is in 2 days!\nSpots for pitching are almost full.\nCome as an audience — investors + mentors will be in the room 🎯',
    postedAt: DateTime.now().subtract(const Duration(hours: 3)),
    imagePath: 'https://picsum.photos/seed/pitchnight_story/400/700'),

  // KU Gönüllüleri (c22) – volunteering story
  ClubStory(id: 'st18', clubId: 'c22', emoji: '🌿', text: 'Campus Clean-Up Day — TOMORROW!\nMeet at main gate 09:30 AM.\nGloves + bags provided. Counts for community service hours! ❤️',
    postedAt: DateTime.now().subtract(const Duration(hours: 4)),
    imagePath: 'https://picsum.photos/seed/volunteer_story2/400/700'),

  // Resim Kulübü (c34) – open studio story
  ClubStory(id: 'st19', clubId: 'c34', emoji: '🎨', text: 'Open Watercolour Studio TODAY!\nStarting in 4 hours — Arts Building Studio 2.\nAll materials provided. Drop in anytime until midnight 🖌️',
    postedAt: DateTime.now().subtract(const Duration(hours: 1)),
    imagePath: 'https://picsum.photos/seed/studio_story/400/700'),

  // KUSWE (c20) – Women in Tech story
  ClubStory(id: 'st20', clubId: 'c20', emoji: '🌟', text: 'Women in Tech Panel — this Thursday!\nGoogle · Microsoft · Koç Holding speakers.\nFree registration — link in bio. Don\'t miss it! 👩‍💻',
    postedAt: DateTime.now().subtract(const Duration(hours: 2)),
    imagePath: 'https://picsum.photos/seed/wit_story/400/700'),

  // KUDAK (c5) – morning run story
  ClubStory(id: 'st21', clubId: 'c5', emoji: '🏃', text: 'Morning Run — tomorrow 07:00!\nSports Center entrance. 5K campus loop.\nAll paces welcome — come clear your head 🌅',
    postedAt: DateTime.now().subtract(const Duration(hours: 5))),

  // Sosyal Aktiviteler (c36) – trivia night story
  ClubStory(id: 'st22', clubId: 'c36', emoji: '🧠', text: 'Campus Trivia Night in 2 days!\nTeams of up to 5. Prizes for top 3.\n6 rounds: KU history, pop culture, science & memes 🏆',
    postedAt: DateTime.now().subtract(const Duration(hours: 6)),
    imagePath: 'https://picsum.photos/seed/trivia_story/400/700'),

  // ── New stories — today, live, tomorrow, Sunday ───────────────────────────

  // KUACM (c4) – hackathon kickoff live
  ClubStory(id: 'st23', clubId: 'c4', emoji: '🔴', text: 'HAPPENING RIGHT NOW 🔥\nHackathon Kick-off Meetup — ENG Main Hall.\nFree pizza, team formation, challenge reveal.\nCome now, doors open!',
    postedAt: DateTime.now().subtract(const Duration(minutes: 35)),
    imagePath: 'https://picsum.photos/seed/hackathon_live_story/400/700'),

  // Müzik Kulübü (c28) – tonight acoustic
  ClubStory(id: 'st24', clubId: 'c28', emoji: '🎸', text: 'TONIGHT — Akustik Gece!\nSOS B Atelier, 8 PM.\n6 original acts, intimate setting.\nFree entry — see you there 🎶',
    postedAt: DateTime.now().subtract(const Duration(hours: 1)),
    imagePath: 'https://picsum.photos/seed/acoustic_tonight_story/400/700'),

  // Tiyatro Kulübü (c39) – improv tonight
  ClubStory(id: 'st25', clubId: 'c39', emoji: '🎭', text: 'Perşembe = Doğaçlama Gecesi!\nBu gece 19:30\'da SOS B206.\nSahneye çık ya da izle — her ikisi de harika 😄',
    postedAt: DateTime.now().subtract(const Duration(hours: 2)),
    imagePath: 'https://picsum.photos/seed/improv_tonight_story/400/700'),

  // Orkestra (c31) – rehearsal live
  ClubStory(id: 'st26', clubId: 'c31', emoji: '🎻', text: 'Şu an prova yapıyoruz!\nKU Amfisi\'nde Brahms ve Dvořák sesleri yükseliyor.\nGelip izleyebilirsiniz — koltuklar açık 🎼',
    postedAt: DateTime.now().subtract(const Duration(minutes: 50)),
    imagePath: 'https://picsum.photos/seed/orchestra_live_story/400/700'),

  // Felsefe (c10) – tonight debate
  ClubStory(id: 'st27', clubId: 'c10', emoji: '🏛️', text: 'Bu Gece: Platon\'un Devleti Tartışması\nSOS B108 — 21:00\n"Adalet nedir?" sorusunu birlikte sorgulayacağız.\nHerkese açık, kayıt gerekmez.',
    postedAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 30))),

  // Pazarlama (c32) – finals today
  ClubStory(id: 'st28', clubId: 'c32', emoji: '📈', text: 'Bugün sosyal medya strateji finalleri!\nSOS B140, 16:00\'da başlıyor.\n8 takım sunuyor — jüriye siz de dahil olabilirsiniz 🏆',
    postedAt: DateTime.now().subtract(const Duration(hours: 3)),
    imagePath: 'https://picsum.photos/seed/marketing_story/400/700'),

  // KUDans (c6) – showcase tomorrow
  ClubStory(id: 'st29', clubId: 'c6', emoji: '🕺', text: 'YARIN — Bahar Şenliği Dans Gösterisi!\nKU Amfi, 20:00.\nSalsa · Hip-Hop · Contemporary · Folk\nBiletler kapıda ücretsiz 💃🔥',
    postedAt: DateTime.now().subtract(const Duration(hours: 2)),
    imagePath: 'https://picsum.photos/seed/dance_tomorrow_story/400/700'),

  // KUACM (c4) – flutter workshop tomorrow
  ClubStory(id: 'st30', clubId: 'c4', emoji: '📱', text: 'YARIN — Flutter Workshop!\nENG B13, 17:00.\nSıfırdan mobil uygulama yapıyoruz.\nLaptopunu getir, deneyim gerekmez 💻',
    postedAt: DateTime.now().subtract(const Duration(hours: 4)),
    imagePath: 'https://picsum.photos/seed/flutter_tomorrow_story/400/700'),

  // Müzikal (c29) – opening night tomorrow
  ClubStory(id: 'st31', clubId: 'c29', emoji: '🌟', text: 'YARIN AÇILIŞ GECESİ! 🎉\n"Waiting for Godot" — KU Sahnesi, 20:00.\nTüm provalar tamamlandı, hazırız!\nBizi destekleyin — giriş ücretsiz.',
    postedAt: DateTime.now().subtract(const Duration(hours: 1)),
    imagePath: 'https://picsum.photos/seed/godot_opening_story/400/700'),

  // Radyo (c33) – podcast workshop tomorrow
  ClubStory(id: 'st32', clubId: 'c33', emoji: '🎙️', text: 'Yarın Podcast Workshopu!\nSOS B111 Stüdyo, 15:00.\nScripting · Recording · Editing — her şeyi öğreniyoruz.\nKatılmak için DM at!',
    postedAt: DateTime.now().subtract(const Duration(hours: 3)),
    imagePath: 'https://picsum.photos/seed/podcast_tomorrow_story/400/700'),

  // Girişimcilik (c15) – networking breakfast tomorrow
  ClubStory(id: 'st33', clubId: 'c15', emoji: '☕', text: 'Yarın Girişimci Kahvaltısı!\nSOS Cafeteria Üst Kat, 09:30.\nKroasan + kahve + hırslı insanlar.\nGelmek için kayıt gerekmez 🚀',
    postedAt: DateTime.now().subtract(const Duration(hours: 5)),
    imagePath: 'https://picsum.photos/seed/startup_brunch_story/400/700'),

  // KUDAK (c5) – forest run Sunday
  ClubStory(id: 'st34', clubId: 'c5', emoji: '🌲', text: 'Pazar — Belgrad Ormanı Koşusu!\nKU Ana Kapı, 08:00 hareket.\n8 km parkur, iki seviye var.\nAraç ücretsiz, su getir! 🏃',
    postedAt: DateTime.now().subtract(const Duration(hours: 7)),
    imagePath: 'https://picsum.photos/seed/forest_run_story/400/700'),

  // KUFoto (c13) – Istanbul photo walk Sunday
  ClubStory(id: 'st35', clubId: 'c13', emoji: '🌇', text: 'Pazar — İstanbul Altın Saati Çekimi!\nTünel\'de buluşuyoruz 15:30\'da.\nGalata, Karaköy, sunset shots.\nAkşam yemeği sonrası birlikte 📸',
    postedAt: DateTime.now().subtract(const Duration(hours: 8)),
    imagePath: 'https://picsum.photos/seed/istanbul_walk_story/400/700'),

  // Sosyal Aktiviteler (c36) – game day Sunday
  ClubStory(id: 'st36', clubId: 'c36', emoji: '🎲', text: 'Pazar Oyun Günü! 🎮\nSCI 103, 13:00–18:00.\nCatan · Ticket to Ride · Among Us ve daha fazlası.\nAtıştırmalıklar bende — sen gel 😄',
    postedAt: DateTime.now().subtract(const Duration(hours: 4)),
    imagePath: 'https://picsum.photos/seed/game_day_story/400/700'),

  // KU Gönüllüleri (c22) – shelter visit Sunday
  ClubStory(id: 'st37', clubId: 'c22', emoji: '🐾', text: 'Pazar — Hayvan Barınağı Ziyareti!\nBeykoz\'a gidiyoruz, 10:00\'da KU\'dan hareket.\nYiyecek bağışı getir, köpekler seni bekliyor 🐶❤️',
    postedAt: DateTime.now().subtract(const Duration(hours: 6)),
    imagePath: 'https://picsum.photos/seed/shelter_sunday_story/400/700'),

  // Resim Kulübü (c34) – Sunday open studio
  ClubStory(id: 'st38', clubId: 'c34', emoji: '✏️', text: 'Pazar Sabahı Serbest Atölye!\nArts Studio 2, 10:00–13:00.\nÇiz, boya, eskiz yap — istediğin gibi.\nKahve ikramı benden ☕🎨',
    postedAt: DateTime.now().subtract(const Duration(hours: 5)),
    imagePath: 'https://picsum.photos/seed/sunday_studio_story/400/700'),

  // Sinema Kulübü (c35) – short film marathon Sunday
  ClubStory(id: 'st39', clubId: 'c35', emoji: '🎞️', text: 'Pazar — Kısa Film Maratonu!\nSOS B140, 16:00.\n12 film, 12 yönetmen, 1 harika akşam.\nPopcorn bende, sen gel 🍿🎬',
    postedAt: DateTime.now().subtract(const Duration(hours: 3)),
    imagePath: 'https://picsum.photos/seed/short_films_story/400/700'),

  // Münazara (c27) – training tomorrow
  ClubStory(id: 'st40', clubId: 'c27', emoji: '🎤', text: 'Yarın Antrenman Gecesi — 18:00, SOS B209.\nYeni motionlar, koçluk, gerçek turnuva pratiği.\nYeni üyeler için mükemmel bir başlangıç noktası!',
    postedAt: DateTime.now().subtract(const Duration(hours: 2))),

  // Hemşirelik (c16) – first aid today
  ClubStory(id: 'st41', clubId: 'c16', emoji: '🩺', text: 'Bugün İlk Yardım Kursu!\nSOS B206 — 17:00\'de başlıyor.\nSertifika verilecek, sadece 20 kişilik kontenjan.\nKapıda kayıt yapılıyor — acele et!',
    postedAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 45))),

  // Kuir Kulübü (c24) – weekly meetup live
  ClubStory(id: 'st42', clubId: 'c24', emoji: '🌈', text: 'Haftalık buluşmamız şu an başladı!\nSOS B108 — kapılar açık, herkese açık.\nKahve var, sohbet var, güvenli alan garantili ✨',
    postedAt: DateTime.now().subtract(const Duration(minutes: 10)),
    imagePath: 'https://picsum.photos/seed/queer_meetup_story/400/700'),

  // ════════════════════════════════════════════════════════════════════════════
  // BATCH 2 — 20 new stories from diverse clubs
  // ════════════════════════════════════════════════════════════════════════════

  // Ekonomi Kulübü (c7)
  ClubStory(id: 'st43', clubId: 'c7', emoji: '📈', text: 'YARIN — Enflasyon ve Para Politikası Paneli!\nSOS B140, saat 15:00.\nTCMB uzmanı + 2 akademisyen.\nEkonomiyi seviyorsan bu paneli kaçırma 🔥',
    postedAt: DateTime.now().subtract(const Duration(hours: 3)),
    imagePath: 'https://picsum.photos/seed/econ_panel_story/400/700'),

  // KUARHA (c1) — Arkeoloji ve Sanat Tarihi
  ClubStory(id: 'st44', clubId: 'c1', emoji: '🏛️', text: 'Bu Hafta — Boğaziçi Tarihi Yürüyüşü!\nKU Ana Kapı, 4 gün sonra 10:00\'da.\nYalılar · Köşkler · Osmanlı mimarisi.\nRehberli tur, giriş ücretsiz 🚶',
    postedAt: DateTime.now().subtract(const Duration(hours: 7)),
    imagePath: 'https://picsum.photos/seed/bosphorus_arch_story/400/700'),

  // KUADK (c2)
  ClubStory(id: 'st45', clubId: 'c2', emoji: '🇹🇷', text: '23 Nisan kutlamalarımız şu an devam ediyor!\nSOS Amfi — şiir, belgesel, sohbet.\nHâlâ devam ediyor, gel katıl!\nMilli birlik ruhu herkesi bekliyor 🌟',
    postedAt: DateTime.now().subtract(const Duration(minutes: 20))),

  // KU-SIGN (c30) — Nöroloji
  ClubStory(id: 'st46', clubId: 'c30', emoji: '🧠', text: 'YARIN — Beyin Anatomisi Atölyesi!\nTıp Binası Sim Lab, 17:00.\n3D beyin modeli üzerinde pratik çalışma.\nTıp · Psikoloji · Biyoloji öğrencileri ❤️',
    postedAt: DateTime.now().subtract(const Duration(hours: 5)),
    imagePath: 'https://picsum.photos/seed/brain_workshop_story/400/700'),

  // Türk Araştırmaları (c40)
  ClubStory(id: 'st47', clubId: 'c40', emoji: '🗺️', text: 'Bu Hafta Perşembe — Kafkasya Jeopolitiği\nSOS B209, 5 gün sonra 15:00.\nGüney Kafkasya ve Türk dış politikası.\nUluslararası ilişkiler severlere tavsiye!',
    postedAt: DateTime.now().subtract(const Duration(hours: 9))),

  // KUBBE (c3) — Beşeri Bilimler
  ClubStory(id: 'st48', clubId: 'c3', emoji: '📚', text: 'Bu Akşam — Masumiyet Müzesi 2. Oturum!\nSOS B108, saat 21:00.\n100–200. sayfalar tartışılıyor.\nKitabı bitirmesen de gel — sıcak ortam garantili ☕',
    postedAt: DateTime.now().subtract(const Duration(hours: 1)),
    imagePath: 'https://picsum.photos/seed/bookclub_story/400/700'),

  // KU Kartalları (c23)
  ClubStory(id: 'st49', clubId: 'c23', emoji: '⚽', text: 'ŞU AN CANLI — UEFA Çeyrek Final!\nCafeteria B — büyük ekran, snacklar hazır.\nHemen gel, zaman kaybetme!\nKU takımı birlikte izliyor 🦅🔥',
    postedAt: DateTime.now().subtract(const Duration(minutes: 10)),
    imagePath: 'https://picsum.photos/seed/ucl_watchparty_story/400/700'),

  // KUTÖB (c38) — Tıp
  ClubStory(id: 'st50', clubId: 'c38', emoji: '🩻', text: 'YARIN — Klinik Beceriler Günü!\nBeceri Lab, 18:00.\nIV hat · Venepuntur · Fizik muayene.\nSınırlı kontenjan — yer ayırt!',
    postedAt: DateTime.now().subtract(const Duration(hours: 6))),

  // THM (c41) — Türk Halk Müziği
  ClubStory(id: 'st51', clubId: 'c41', emoji: '🎸', text: 'Bu Hafta Cuma — Halk Müziği Bahar Akşamı!\nSOS B Atelier, 20:00.\nSaz · Bağlama · Türküler · Şarkılar.\nGiriş ücretsiz, gel dinle 🌙',
    postedAt: DateTime.now().subtract(const Duration(hours: 8)),
    imagePath: 'https://picsum.photos/seed/folk_music_story/400/700'),

  // Ebru Kulübü (c9)
  ClubStory(id: 'st52', clubId: 'c9', emoji: '🎨', text: '6 Gün Sonra — Battal Ebru Atölyesi!\nSOS Art Studio 1, 19:00.\nBüyük formatlı kâğıtlara battal tekniği.\nTemel deneyim yeterli. Tüm malzeme kulüpten 🌊',
    postedAt: DateTime.now().subtract(const Duration(hours: 12)),
    imagePath: 'https://picsum.photos/seed/battal_ebru_story/400/700'),

  // Kürt Dili (c25)
  ClubStory(id: 'st53', clubId: 'c25', emoji: '🌿', text: '8 Gün Sonra — Kürt Kültür Gecesi!\nSOS Amfi, 18:00.\nYemek · Müzik · Kıyafet · Dil Oyunları.\nHerkes davetli, giriş ücretsiz! Birlikte öğrenelim 💛',
    postedAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
    imagePath: 'https://picsum.photos/seed/kurdish_night_story/400/700'),

  // Folklör (c12)
  ClubStory(id: 'st54', clubId: 'c12', emoji: '💃', text: 'Gala Gecesine 10 Gün Kaldı! 🎉\nKU Amfi\'de zeybek, horon ve halay.\n45 dansçı, canlı müzik, kostümler.\nBilet ücretsiz — yerinizi ayırtın!',
    postedAt: DateTime.now().subtract(const Duration(hours: 10)),
    imagePath: 'https://picsum.photos/seed/folklore_gala_story/400/700'),

  // Fenerbahçeliler (c11)
  ClubStory(id: 'st55', clubId: 'c11', emoji: '💛', text: 'BU AKŞAM — Şampiyonlar Ligi!\nCafeteria A, 3 saat sonra.\nBüyük ekran hazır, yerler dolmadan gel!\nFormanı giy, sarı-lacivert renklerini tak 💙🔥',
    postedAt: DateTime.now().subtract(const Duration(hours: 2)),
    imagePath: 'https://picsum.photos/seed/fenerbahce_ucl_story/400/700'),

  // Tarih Kulübü (c37)
  ClubStory(id: 'st56', clubId: 'c37', emoji: '🏰', text: 'Bu Akşam — İstanbul\'un Fethi Anma!\nSOS B209, 5 saat sonra.\nBelgesel · Harita okumaları · Uzman Q&A.\n572 yıl önce bugün… tarih yaşanıyor! 🌙',
    postedAt: DateTime.now().subtract(const Duration(hours: 4))),

  // Kadın Dayanışma (c19)
  ClubStory(id: 'st57', clubId: 'c19', emoji: '🌸', text: 'Kariyer Mentörlük Günü tamamlandı!\n60 öğrenci, 20 mentor, sayısız bağlantı.\nPaylaşımlarınız için teşekkürler 💕\nBir sonraki etkinlik duyurusu yakında!',
    postedAt: DateTime.now().subtract(const Duration(days: 2, hours: 3))),

  // Hukuk Kulübü (c17)
  ClubStory(id: 'st58', clubId: 'c17', emoji: '⚖️', text: '6 Gün Sonra — Yapay Zeka ve Hukuk Paneli!\nSOS B206, 16:00.\nAB YZ Yasası · Veri Koruma · Hesap Verebilirlik.\nHukuk severlerin buluşma noktası 📋',
    postedAt: DateTime.now().subtract(const Duration(days: 1, hours: 2))),

  // IES / D&D (c14)
  ClubStory(id: 'st59', clubId: 'c14', emoji: '🎲', text: 'BU AKŞAM — Karanlığın Kıyısı Hafta 2!\nSOS B210, 7 saat sonra.\nDungeon bekliyor, karakterler hazır.\nHazır karakter isteyenler DM atabilir 🗡️',
    postedAt: DateTime.now().subtract(const Duration(hours: 3))),

  // KUMech (c26)
  ClubStory(id: 'st60', clubId: 'c26', emoji: '🤖', text: 'Robolig robotumuzun prototipi hazır! ⚙️\nMFG Lab\'dan ilk fotoğraflar...\nMekanik + elektronik + yazılım tamam.\nFinal tasarım yarışma öncesi açıklanacak!',
    postedAt: DateTime.now().subtract(const Duration(days: 1, hours: 6)),
    imagePath: 'https://picsum.photos/seed/robot_prototype_story/400/700'),

  // AIChE (c21)
  ClubStory(id: 'st61', clubId: 'c21', emoji: '🔬', text: 'AIChE Bölge Konferansı Hazırlıkları!\nPoster sunumu · Makale yarışması.\nKimya/BioMüh öğrencisi iseniz katılın.\nKayıt için Discord\'a gelin 🧪',
    postedAt: DateTime.now().subtract(const Duration(days: 2, hours: 8))),

  // İşletme Kulübü (c18)
  ClubStory(id: 'st62', clubId: 'c18', emoji: '🤝', text: 'Girişimci Networking Dinnerı 11 gün sonra!\nENG Z27, 19:00.\n3 KU mezunu girişimci konuşuyor.\nNetworking yemeği dahil — kayıt ücretsiz 🚀',
    postedAt: DateTime.now().subtract(const Duration(hours: 13)),
    imagePath: 'https://picsum.photos/seed/startup_networking_story/400/700'),

  // ── May 8–15 stories ────────────────────────────────────────────────────────
  ClubStory(id: 'stm1', clubId: 'c4', emoji: '💻',
    text: 'LeetCode Maratonu Başlıyor!\nBugün 14:00 — Library Lab 3\nGraph + DP problemleri\nHerkese açık, gel katıl! 🚀',
    postedAt: DateTime(2026, 5, 8, 9, 0),
    imagePath: 'https://picsum.photos/seed/leetcode_story_may/400/700'),

  ClubStory(id: 'stm2', clubId: 'c28', emoji: '🎷',
    text: 'BU GECE — Caz Çarşamba!\nSOS B Atelier · 20:00\n12 müzisyen · Ücretsiz giriş\nİçecekler kulüpten 🎶',
    postedAt: DateTime(2026, 5, 8, 12, 0),
    imagePath: 'https://picsum.photos/seed/jazz_story_may/400/700'),

  ClubStory(id: 'stm3', clubId: 'c15', emoji: '☕',
    text: 'Startup Kahvaltısı YARIN!\nSOS Cafe Üst Kat · 09:30\n2 kurucu konuşuyor\nKayıt gerekmez — sadece gel ✨',
    postedAt: DateTime(2026, 5, 8, 18, 30),
    imagePath: 'https://picsum.photos/seed/startup_breakfast_story_may/400/700'),

  ClubStory(id: 'stm4', clubId: 'c31', emoji: '🎻',
    text: 'Bahar Konseri — Cumartesi!\nKU Amfisi · 20:00\nDvořák + Brahms\n50 öğrenci müzisyen 🎼',
    postedAt: DateTime(2026, 5, 9, 10, 0),
    imagePath: 'https://picsum.photos/seed/orchestra_story_may/400/700'),

  ClubStory(id: 'stm5', clubId: 'c13', emoji: '🌸',
    text: 'Makro Fotoğraf Atölyesi!\nCumartesi 11:00 — Kampüs Bahçesi\nTelefon kameran yeterli\nDoğanın detaylarını keşfet 📷',
    postedAt: DateTime(2026, 5, 9, 13, 0),
    imagePath: 'https://picsum.photos/seed/macro_story_may/400/700'),

  ClubStory(id: 'stm6', clubId: 'c36', emoji: '🎲',
    text: 'Cuma Oyun Gecesi!\nBu akşam 19:00 · SCI 103\nCatan · Codenames · Dixit\nAtıştırmalıklar benden 😄',
    postedAt: DateTime(2026, 5, 9, 17, 0),
    imagePath: 'https://picsum.photos/seed/game_night_story_may/400/700'),

  ClubStory(id: 'stm7', clubId: 'c5', emoji: '🧘',
    text: 'Sabah Yürüyüşü + Yoga\nYARIN · 07:30 · Sports Center\n3 km yürüyüş + 30 dk yoga\nMatını getir, güneşi yakala 🌅',
    postedAt: DateTime(2026, 5, 9, 21, 30),
    imagePath: 'https://picsum.photos/seed/yoga_story_may/400/700'),

  ClubStory(id: 'stm8', clubId: 'c34', emoji: '🎨',
    text: 'Açık Stüdyo — Bugün!\n15:00\'dan gece yarısına kadar\nArts Studio 2\nSuluboya · Karakalem · Akrilik',
    postedAt: DateTime(2026, 5, 9, 14, 30),
    imagePath: 'https://picsum.photos/seed/studio_story_may/400/700'),

  ClubStory(id: 'stm9', clubId: 'c39', emoji: '🎭',
    text: 'Pazar Matinesi — Bugün!\nSOS B206 · 14:00\nDoğaçlama Tiyatro\nGel, gül, sahneye çık! 😂',
    postedAt: DateTime(2026, 5, 11, 12, 0),
    imagePath: 'https://picsum.photos/seed/improv_story_may/400/700'),

  ClubStory(id: 'stm10', clubId: 'c22', emoji: '❤️',
    text: 'Hastane Gönüllülüğü — Bugün!\nKU Ana Kapı · 09:30 hareket\nÇocuk Hastanesi ziyareti\nSevgi dolu bir gün seni bekliyor 🌈',
    postedAt: DateTime(2026, 5, 11, 8, 0),
    imagePath: 'https://picsum.photos/seed/volunteer_story_may/400/700'),

  ClubStory(id: 'stm11', clubId: 'c7', emoji: '📊',
    text: 'Bloomberg Atölyesi — Pazartesi!\nENG Z27 · 14:00\nBIST analizi + portföy yönetimi\nEkonomi severlere özel 💹',
    postedAt: DateTime(2026, 5, 11, 16, 0),
    imagePath: 'https://picsum.photos/seed/bloomberg_story_may/400/700'),

  ClubStory(id: 'stm12', clubId: 'c4', emoji: '⛓️',
    text: 'Web3 Workshop — Pazartesi!\nLibrary Lab 3 · 17:00\nSolidity · Ethereum · MetaMask\nSıfırdan başlıyoruz — gel! 🚀',
    postedAt: DateTime(2026, 5, 11, 19, 0),
    imagePath: 'https://picsum.photos/seed/web3_story_may/400/700'),

  ClubStory(id: 'stm13', clubId: 'c6', emoji: '💃',
    text: 'Salsa Soiree — Bu Akşam!\nSports Hall B · 20:00\nBaşlangıç dersi + serbest dans\nPartner şart değil 🕺',
    postedAt: DateTime(2026, 5, 12, 18, 0),
    imagePath: 'https://picsum.photos/seed/salsa_story_may/400/700'),

  ClubStory(id: 'stm14', clubId: 'c32', emoji: '📱',
    text: 'Dijital Pazarlama Paneli!\nYARIN · SOS B140 · 15:00\nBarış Özcan dahil 3 konuşmacı\nQ&A bölümü var — hazır ol!',
    postedAt: DateTime(2026, 5, 12, 21, 0),
    imagePath: 'https://picsum.photos/seed/marketing_story_may/400/700'),

  ClubStory(id: 'stm15', clubId: 'c17', emoji: '⚖️',
    text: 'YZ ve Hukuk Paneli Yarın!\nSOS B206 · 16:00\nAB YZ Yasası · Deepfake · Sorumluluk\nHukuk + CS + Siyaset bilimiyle 📋',
    postedAt: DateTime(2026, 5, 12, 23, 0)),

  ClubStory(id: 'stm16', clubId: 'c8', emoji: '🌍',
    text: 'İklim Roundtable — Çarşamba!\nSOS B209 · 17:00\nTürkiye iklim taahhütleri\nKarbon vergisi · Enerji geçişi 🌱',
    postedAt: DateTime(2026, 5, 13, 11, 0),
    imagePath: 'https://picsum.photos/seed/climate_story_may/400/700'),

  ClubStory(id: 'stm17', clubId: 'c27', emoji: '🎤',
    text: 'Bu Hafta Antrenman!\nSOS B209 · Cuma 18:00\nYZ ve Sanat motionu\nYeni üyeler çok bekleniyor 🏆',
    postedAt: DateTime(2026, 5, 13, 14, 0)),

  ClubStory(id: 'stm18', clubId: 'c35', emoji: '🎬',
    text: 'Kusturica Gecesi — Perşembe!\nSOS B140 · 19:00\n"Underground" — Palme d\'Or\nPopcorn benden 🍿',
    postedAt: DateTime(2026, 5, 13, 15, 0),
    imagePath: 'https://picsum.photos/seed/kusturica_story_may/400/700'),

  ClubStory(id: 'stm19', clubId: 'c12', emoji: '💃',
    text: 'YARIN — Gala Gecesi!\nKU Amfisi · 20:00\nZeybek · Horon · Halay · Karşılama\nCanlı saz · Ücretsiz giriş 🌙',
    postedAt: DateTime(2026, 5, 14, 16, 0),
    imagePath: 'https://picsum.photos/seed/gala_story_may/400/700'),

  ClubStory(id: 'stm20', clubId: 'c28', emoji: '🥁',
    text: 'Perküsyon Atölyesi — Bugün!\nSOS B Atelier · 15:00\nDavul · Bongo · Cajon\nMüzik bilgisi şart değil! 🎶',
    postedAt: DateTime(2026, 5, 15, 11, 0),
    imagePath: 'https://picsum.photos/seed/percussion_story_may/400/700'),

  // ── May 16–31 stories ────────────────────────────────────────────────────────
  ClubStory(id: 'stj1', clubId: 'c4', emoji: '💻',
    text: 'React vs Flutter\nworkshop bugün!\nENG 208 · 14:00\nLaptopunu getir 🔥',
    postedAt: DateTime(2026, 5, 16, 13, 0),
    imagePath: 'https://picsum.photos/seed/webdev_story/400/700'),

  ClubStory(id: 'stj2', clubId: 'c27', emoji: '🤖',
    text: 'AI Münazarası\nBugün 16:00\nSCI 103\nTarafını seç! ⚖️',
    postedAt: DateTime(2026, 5, 17, 15, 0),
    imagePath: 'https://picsum.photos/seed/debate_story/400/700'),

  ClubStory(id: 'stj3', clubId: 'c15', emoji: '🚀',
    text: 'Pitch Night #12\nBu Akşam 18:00\nKurucular Salonu\n8 ekip · 30K TL 💰',
    postedAt: DateTime(2026, 5, 18, 17, 0),
    imagePath: 'https://picsum.photos/seed/pitch_story/400/700'),

  ClubStory(id: 'stj4', clubId: 'c13', emoji: '📸',
    text: 'Golden Hour\nPhoto Walk!\nSCI Önü · 17:30\nGelin! 🌅',
    postedAt: DateTime(2026, 5, 19, 16, 0),
    imagePath: 'https://picsum.photos/seed/photowalk_story/400/700'),

  ClubStory(id: 'stj5', clubId: 'c5', emoji: '🎭',
    text: 'Açık Prova\nKirli Eller\nSNA Tiyatro · 19:00\nSartre gecesi! ✨',
    postedAt: DateTime(2026, 5, 20, 18, 0),
    imagePath: 'https://picsum.photos/seed/kudak_story2/400/700'),

  ClubStory(id: 'stj6', clubId: 'c22', emoji: '🌊',
    text: 'Sarıyer Sahili\nTemizliği Yarın!\nMinibüs 09:00\nAna Kapı · Mangal var 🔥',
    postedAt: DateTime(2026, 5, 20, 19, 0),
    imagePath: 'https://picsum.photos/seed/cleanup_story/400/700'),

  ClubStory(id: 'stj7', clubId: 'c7', emoji: '📊',
    text: 'Enflasyon Semineri\nCuma 15:00\nSOS 301\nDr. Ayşe Koç konuğumuz!',
    postedAt: DateTime(2026, 5, 21, 12, 0),
    imagePath: 'https://picsum.photos/seed/econ_story/400/700'),

  ClubStory(id: 'stj8', clubId: 'c6', emoji: '💃',
    text: 'Fusion 2026\nYARIN 20:00\nKU Amfisi\nStreet · Contemporary · Latin 🕺',
    postedAt: DateTime(2026, 5, 22, 18, 0),
    imagePath: 'https://picsum.photos/seed/dance_story2/400/700'),

  ClubStory(id: 'stj9', clubId: 'c34', emoji: '🎨',
    text: 'Açık Atölye Günü\nBugün 13:00–18:00\nSNA 201\nTüm malzemeler bedava!',
    postedAt: DateTime(2026, 5, 24, 12, 0),
    imagePath: 'https://picsum.photos/seed/art_story2/400/700'),

  ClubStory(id: 'stj10', clubId: 'c8', emoji: '🌍',
    text: 'Model BM\nGüvenlik Konseyi\nPazar 10:00 · SOS 401\nDelegeler hazır mısınız?',
    postedAt: DateTime(2026, 5, 24, 10, 0),
    imagePath: 'https://picsum.photos/seed/mun_story/400/700'),

  ClubStory(id: 'stj11', clubId: 'c31', emoji: '🎻',
    text: 'Oda Müziği Konseri\nPazartesi 19:30\nKurucular Salonu\nBeethoven · Brahms · Bartók 🎹',
    postedAt: DateTime(2026, 5, 25, 18, 0),
    imagePath: 'https://picsum.photos/seed/chamber_story/400/700'),

  ClubStory(id: 'stj12', clubId: 'c17', emoji: '⚖️',
    text: 'Moot Court Finali\nSalı 14:00\nSOS 204\nTicaret Hukuku vakası!',
    postedAt: DateTime(2026, 5, 26, 11, 0),
    imagePath: 'https://picsum.photos/seed/law_story/400/700'),

  ClubStory(id: 'stj13', clubId: 'c35', emoji: '🎬',
    text: 'Wong Kar-wai Gecesi\nBugün 18:00\nSOS Sinema\nPopcorn bedava! 🍿',
    postedAt: DateTime(2026, 5, 28, 17, 0),
    imagePath: 'https://picsum.photos/seed/cinema_story/400/700'),

  ClubStory(id: 'stj14', clubId: 'c36', emoji: '🔍',
    text: 'Kampüs Kaçış Oyunu\nBUGÜN 14:00\n60 dakika · 4 kişi\nSırrı çözebilir misin?',
    postedAt: DateTime(2026, 5, 29, 13, 0),
    imagePath: 'https://picsum.photos/seed/escape_story/400/700'),

  ClubStory(id: 'stj15', clubId: 'c39', emoji: '🎭',
    text: 'Doğaçlama Atölyesi\nBugün 15:00\nSNA Küçük Sahne\nYes, and... 😄',
    postedAt: DateTime(2026, 5, 30, 14, 0),
    imagePath: 'https://picsum.photos/seed/improv_story/400/700'),

  ClubStory(id: 'stj16', clubId: 'c4', emoji: '🏆',
    text: 'HACKATHON\nBaşlıyor!\nENG Lobby · 10:00\n24 saat · 30K TL ödül 💻',
    postedAt: DateTime(2026, 5, 31, 9, 0),
    imagePath: 'https://picsum.photos/seed/hackathon_story/400/700'),

  ClubStory(id: 'stj17', clubId: 'c32', emoji: '📱',
    text: 'Pazarlama\nVaka Yarışması\nSon başvuru BUGÜN!\n48 saat · Gerçek vaka',
    postedAt: DateTime(2026, 5, 16, 12, 0),
    imagePath: 'https://picsum.photos/seed/marketing_story/400/700'),

  ClubStory(id: 'stj18', clubId: 'c28', emoji: '🎵',
    text: 'Bahar Konseri\nBu Pazar 19:00\nKurucular Salonu\nHicaz · Uşşak Fasıl 🎶',
    postedAt: DateTime(2026, 5, 23, 11, 0),
    imagePath: 'https://picsum.photos/seed/koro_story/400/700'),

  ClubStory(id: 'stj19', clubId: 'c15', emoji: '🤝',
    text: 'Angel Investor\nBuluşması Yarın!\n14:00–18:00\nKurucular Lounge 💡',
    postedAt: DateTime(2026, 5, 25, 10, 0),
    imagePath: 'https://picsum.photos/seed/investor_story/400/700'),

  ClubStory(id: 'stj20', clubId: 'c22', emoji: '🩸',
    text: 'Kan Bağışı\nKampanyası BUGÜN\nSCI Giriş · 10:00–16:00\nHayat kurtar ❤️',
    postedAt: DateTime(2026, 5, 28, 9, 0),
    imagePath: 'https://picsum.photos/seed/blood_story/400/700'),
];

// ─── App Super Admin ─────────────────────────────────────────────────────────

final appAdmin = AppAdmin(
  id: 'admin1',
  name: 'Super Admin',
  email: 'admin@ku.edu.tr',
  password: 'admin123',
);

// ─── Club Admins ──────────────────────────────────────────────────────────────

final clubAdmins = [
  AppAdmin(id: 'cadmin1',  name: 'HAKANS_CLUB',          email: 'hclub@ku.edu.tr',        password: '123456789'),
  AppAdmin(id: 'cadmin2',  name: 'KUARHA',                email: 'kuarha@ku.edu.tr',        password: 'kuarha123'),
  AppAdmin(id: 'cadmin3',  name: 'KUADK',                 email: 'kuadk@ku.edu.tr',         password: 'kuadk123'),
  AppAdmin(id: 'cadmin4',  name: 'KUBBE',                 email: 'kubbe@ku.edu.tr',         password: 'kubbe123'),
  AppAdmin(id: 'cadmin5',  name: 'KUACM',                 email: 'kuacm@ku.edu.tr',         password: 'kuacm123'),
  AppAdmin(id: 'cadmin6',  name: 'KUDAK',                 email: 'kudak@ku.edu.tr',         password: 'kudak123'),
  AppAdmin(id: 'cadmin7',  name: 'KUDans',                email: 'kudans@ku.edu.tr',        password: 'kudans123'),
  AppAdmin(id: 'cadmin8',  name: 'Ekonomi Kulübü',        email: 'kuekon@ku.edu.tr',        password: 'kuekon123'),
  AppAdmin(id: 'cadmin9',  name: 'EkoPolitik',            email: 'ekopolitik@ku.edu.tr',    password: 'ekopolitik123'),
  AppAdmin(id: 'cadmin10', name: 'Ebru Kulübü',           email: 'kuebru@ku.edu.tr',        password: 'kuebru123'),
  AppAdmin(id: 'cadmin11', name: 'Felsefe Topluluğu',     email: 'kufelsefe@ku.edu.tr',     password: 'kufelsefe123'),
  AppAdmin(id: 'cadmin12', name: 'Fenerbahçeliler',       email: 'kufenerbahce@ku.edu.tr',  password: 'kufenerbahce123'),
  AppAdmin(id: 'cadmin13', name: 'Folklör Kulübü',        email: 'kufolklor@ku.edu.tr',     password: 'kufolklor123'),
  AppAdmin(id: 'cadmin14', name: 'KUFoto',                email: 'kufoto@ku.edu.tr',        password: 'kufoto123'),
  AppAdmin(id: 'cadmin15', name: 'IES',                   email: 'kuies@ku.edu.tr',         password: 'kuies123'),
  AppAdmin(id: 'cadmin16', name: 'Girişimcilik Kulübü',   email: 'kugirisim@ku.edu.tr',     password: 'kugirisim123'),
  AppAdmin(id: 'cadmin17', name: 'Hemşirelik Kulübü',     email: 'kuhemsire@ku.edu.tr',     password: 'kuhemsire123'),
  AppAdmin(id: 'cadmin18', name: 'Hukuk Kulübü',          email: 'kuhukuk@ku.edu.tr',       password: 'kuhukuk123'),
  AppAdmin(id: 'cadmin19', name: 'İşletme Kulübü',        email: 'kuisletme@ku.edu.tr',     password: 'kuisletme123'),
  AppAdmin(id: 'cadmin20', name: 'Kadın Dayanışma',       email: 'kukadin@ku.edu.tr',       password: 'kukadin123'),
  AppAdmin(id: 'cadmin21', name: 'KUSWE',                 email: 'kuswe@ku.edu.tr',         password: 'kuswe123'),
  AppAdmin(id: 'cadmin22', name: 'AIChE',                 email: 'kuaiche@ku.edu.tr',       password: 'kuaiche123'),
  AppAdmin(id: 'cadmin23', name: 'KU Gönüllüleri',        email: 'kugonullu@ku.edu.tr',     password: 'kugonullu123'),
  AppAdmin(id: 'cadmin24', name: 'KU Kartalları',         email: 'kukartallari@ku.edu.tr',  password: 'kukartallari123'),
  AppAdmin(id: 'cadmin25', name: 'Kuir Kulübü',           email: 'kukuir@ku.edu.tr',        password: 'kukuir123'),
  AppAdmin(id: 'cadmin26', name: 'Kürt Dili Kulübü',      email: 'kukurt@ku.edu.tr',        password: 'kukurt123'),
  AppAdmin(id: 'cadmin27', name: 'KUMech',                email: 'kumech@ku.edu.tr',        password: 'kumech123'),
  AppAdmin(id: 'cadmin28', name: 'Münazara Kulübü',       email: 'kumunazara@ku.edu.tr',    password: 'kumunazara123'),
  AppAdmin(id: 'cadmin29', name: 'KÜMK',                  email: 'kumuzik@ku.edu.tr',       password: 'kumuzik123'),
  AppAdmin(id: 'cadmin30', name: 'Müzikal Kulübü',        email: 'kumuzikal@ku.edu.tr',     password: 'kumuzikal123'),
  AppAdmin(id: 'cadmin31', name: 'KU-SIGN',               email: 'kusign@ku.edu.tr',        password: 'kusign123'),
  AppAdmin(id: 'cadmin32', name: 'Orkestra Kulübü',       email: 'kuorkestra@ku.edu.tr',    password: 'kuorkestra123'),
  AppAdmin(id: 'cadmin33', name: 'Pazarlama Kulübü',      email: 'kupazarlama@ku.edu.tr',   password: 'kupazarlama123'),
  AppAdmin(id: 'cadmin34', name: 'Radyo Kulübü',          email: 'kuradyo@ku.edu.tr',       password: 'kuradyo123'),
  AppAdmin(id: 'cadmin35', name: 'Resim Kulübü',          email: 'kuresim@ku.edu.tr',       password: 'kuresim123'),
  AppAdmin(id: 'cadmin36', name: 'Sinema Kulübü',         email: 'kusinema@ku.edu.tr',      password: 'kusinema123'),
  AppAdmin(id: 'cadmin37', name: 'Sosyal Aktiviteler',    email: 'kusosyal@ku.edu.tr',      password: 'kusosyal123'),
  AppAdmin(id: 'cadmin38', name: 'Tarih Kulübü',          email: 'kutarih@ku.edu.tr',       password: 'kutarih123'),
  AppAdmin(id: 'cadmin39', name: 'KUTÖB',                 email: 'kutob@ku.edu.tr',         password: 'kutob123'),
  AppAdmin(id: 'cadmin40', name: 'Tiyatro Kulübü',        email: 'kutiyatro@ku.edu.tr',     password: 'kutiyatro123'),
  AppAdmin(id: 'cadmin41', name: 'Türk Araştırmaları',    email: 'kutarastirma@ku.edu.tr',  password: 'kutarastirma123'),
  AppAdmin(id: 'cadmin42', name: 'THM',                   email: 'kuthm@ku.edu.tr',         password: 'kuthm123'),
];

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
