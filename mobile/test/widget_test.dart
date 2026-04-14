import 'package:flutter_test/flutter_test.dart';
import 'package:acadian/main.dart';

void main() {
  testWidgets('App loads login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SchoolERPApp());
    await tester.pump();
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Username or Email'), findsOneWidget);
  });
}
