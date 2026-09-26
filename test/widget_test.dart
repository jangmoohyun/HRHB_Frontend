import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hrhb_frontend/main.dart';

void main() {
  setUpAll(() {
    // main() loads .env before runApp; tests have to do it themselves or
    // Env.apiBaseUrl throws NotInitializedError while building.
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8080');
  });

  testWidgets('Loading screen shows brand title', (WidgetTester tester) async {
    await tester.pumpWidget(const HrhbApp());
    await tester.pump();

    expect(find.text('하루한번'), findsOneWidget);
    expect(find.text('가족을 잇는 감성 커뮤니케이션'), findsOneWidget);

    // Screens loop decorative animations forever, so pumpAndSettle would never
    // return. Secure storage never answers under test, so the session check
    // runs into its 12s timeout; step past it and the login entry timers.
    await tester.pump(const Duration(seconds: 13));
    await tester.pump(const Duration(seconds: 3)); // splash minimum → login
    await tester.pump(const Duration(seconds: 3)); // login entry animations
    expect(find.text('이메일로 로그인'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
