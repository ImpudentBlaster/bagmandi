import 'package:flutter_test/flutter_test.dart';
import 'package:bagmandi/app.dart';

void main() {
  testWidgets('BagMandi app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const BagMandiApp());
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('BagMandi'), findsWidgets);
  });
}
