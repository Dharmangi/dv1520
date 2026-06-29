import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dv1520_app/app.dart';

void main() {
  testWidgets('App shows bottom navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: DV1520App()));
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('People'), findsOneWidget);
  });
}
