import 'package:flutter_test/flutter_test.dart';

import 'package:hrhb_frontend/main.dart';

void main() {
  testWidgets('Loading screen shows brand title', (WidgetTester tester) async {
    await tester.pumpWidget(const HrhbApp());
    await tester.pump();

    expect(find.text('하루한번'), findsOneWidget);
    expect(find.text('가족을 잇는 감성 커뮤니케이션'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pumpAndSettle();
  });
}
