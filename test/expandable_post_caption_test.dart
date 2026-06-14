import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/widgets/expandable_post_caption.dart';

void main() {
  Widget buildCaption(String caption) {
    return MaterialApp(
      home: Scaffold(
        body: ExpandablePostCaption(authorName: 'Chess Club', caption: caption),
      ),
    );
  }

  testWidgets('expands and collapses a caption', (tester) async {
    const caption =
        'One two three four five six seven eight nine ten eleven twelve '
        'thirteen fourteen fifteen sixteen seventeen eighteen';

    await tester.pumpWidget(buildCaption(caption));

    expect(
      find.textContaining(
        'One two three four five six seven eight nine ten eleven twelve '
        'thirteen fourteen fifteen',
      ),
      findsOne,
    );
    expect(find.textContaining('sixteen seventeen eighteen'), findsNothing);
    expect(find.text('more'), findsOneWidget);
    expect(find.text('less'), findsNothing);

    await tester.tap(find.text('more'));
    await tester.pump();

    expect(find.textContaining(caption), findsOneWidget);
    expect(find.text('more'), findsNothing);
    expect(find.text('less'), findsOneWidget);

    await tester.tap(find.text('less'));
    await tester.pump();

    expect(
      find.textContaining(
        'One two three four five six seven eight nine ten eleven twelve '
        'thirteen fourteen fifteen',
      ),
      findsOne,
    );
    expect(find.textContaining('sixteen seventeen eighteen'), findsNothing);
    expect(find.text('more'), findsOneWidget);
    expect(find.text('less'), findsNothing);
  });

  testWidgets('does not show more for captions with fifteen words', (
    tester,
  ) async {
    const caption =
        'One two three four five six seven eight nine ten eleven twelve '
        'thirteen fourteen fifteen';

    await tester.pumpWidget(buildCaption(caption));

    expect(find.textContaining(caption), findsOneWidget);
    expect(find.text('more'), findsNothing);
    expect(find.text('less'), findsNothing);
  });
}
