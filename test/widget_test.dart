import 'package:flutter_test/flutter_test.dart';
import 'package:work_net/main.dart';

void main() {
  testWidgets('WorkNet inicia correctamente', (WidgetTester tester) async {
    await tester.pumpWidget(const WorkNetApp());

    await tester.pumpAndSettle();

    expect(find.byType(WorkNetApp), findsOneWidget);
  });
}