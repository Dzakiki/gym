import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/app/app.dart';

void main() {
  testWidgets('app starts and shows the title', (tester) async {
    await tester.pumpWidget(const FormCoachApp());

    expect(find.text('FormCoach'), findsOneWidget);
  });
}
