import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labproof_academy/app.dart';

void main() {
  testWidgets('LabProof Academy opens to authentication after splash', (
    tester,
  ) async {
    await tester.pumpWidget(const LabProofAcademyApp());
    await tester.pump(const Duration(milliseconds: 1800));

    expect(find.text('LabProof Academy'), findsWidgets);
    expect(find.byType(Scaffold), findsWidgets);
  });
}
