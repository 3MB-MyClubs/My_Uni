import 'package:flutter_application_1/models/chat_group.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('automatic names list every member when there are two or three', () {
    expect(ChatGroup.automaticName(['Can', 'Doğu']), 'Can, Doğu');
    expect(
      ChatGroup.automaticName(['Can', 'Doğu', 'Ahmet']),
      'Can, Doğu, Ahmet',
    );
    expect(
      ChatGroup.automaticName([
        'Can Serbester',
        'Emir Karaarslan',
        'Deniz Kaya',
      ]),
      'Can, Emir, Deniz',
    );
  });

  test('automatic names abbreviate groups larger than three', () {
    expect(
      ChatGroup.automaticName(['Can', 'Doğu', 'Ahmet', 'Mehmet']),
      'Can, Doğu +2',
    );
    expect(
      ChatGroup.automaticName(['Can', 'Doğu', 'Ahmet', 'Mehmet', 'Ayşe']),
      'Can, Doğu +3',
    );
  });

  test('custom names are trimmed and whitespace falls back to members', () {
    final group = ChatGroup(
      id: 'g1',
      creatorId: 'me',
      memberIds: const ['me', 'can', 'dogu'],
      customName: '  Project Team  ',
      photoUrl: '/temporary/group.jpg',
      createdAt: DateTime(2026),
    );
    String resolve(String id) => {'can': 'Can', 'dogu': 'Doğu'}[id] ?? 'Me';

    expect(
      group.displayName(viewerId: 'me', nameForUser: resolve),
      'Project Team',
    );
    expect(ChatGroup.fromMap(group.toMap()).photoUrl, '/temporary/group.jpg');
    expect(
      group
          .withCustomName('   ')
          .displayName(viewerId: 'me', nameForUser: resolve),
      'Can, Doğu',
    );
  });
}
