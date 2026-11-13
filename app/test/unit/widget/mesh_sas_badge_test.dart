import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:locara_app/pages/verify_page.dart';
import 'package:locara_app/widget/design/mesh_sas_badge.dart';

void main() {
  group('CombinedFingerprint SAS Logic', () {
    const fpAlpha = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    const fpBeta = 'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
    const fpGamma = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

    test('is symmetric regardless of sender/receiver order', () {
      final fp1 = CombinedFingerprint.fromFingerprints(
        myFingerprint: fpAlpha,
        peerFingerprint: fpBeta,
      );
      final fp2 = CombinedFingerprint.fromFingerprints(
        myFingerprint: fpBeta,
        peerFingerprint: fpAlpha,
      );

      expect(fp1.combined, equals(fp2.combined));
      expect(fp1.icons, equals(fp2.icons));
      expect(fp1.shortIcons, equals(fp2.shortIcons));
      expect(fp1.shortIcons.length, 4);
    });

    test('is sensitive to differences in certificate hashes', () {
      final fp1 = CombinedFingerprint.fromFingerprints(
        myFingerprint: fpAlpha,
        peerFingerprint: fpBeta,
      );
      final fp3 = CombinedFingerprint.fromFingerprints(
        myFingerprint: fpAlpha,
        peerFingerprint: fpGamma,
      );

      expect(fp1.combined, isNot(equals(fp3.combined)));
      expect(fp1.icons, isNot(equals(fp3.icons)));
    });

    test('shortIcons extracts exactly the first 4 icons', () {
      final fp = CombinedFingerprint.fromFingerprints(
        myFingerprint: fpAlpha,
        peerFingerprint: fpBeta,
      );
      expect(fp.shortIcons.length, 4);
      expect(fp.shortIcons, equals(fp.icons.sublist(0, 4)));
    });
  });

  group('LocaraSasBadge Widget', () {
    const fpAlpha = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    const fpBeta = 'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';

    testWidgets('renders shield and 4 SAS icons when fingerprint is provided', (tester) async {
      final combined = CombinedFingerprint.fromFingerprints(
        myFingerprint: fpAlpha,
        peerFingerprint: fpBeta,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: LocaraSasBadge(
                fingerprint: combined,
                compact: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.shield_rounded), findsOneWidget);
      // Verify that all 4 short icons are found
      for (final icon in combined.shortIcons) {
        expect(find.byIcon(icon), findsWidgets);
      }
    });

    testWidgets('returns SizedBox.shrink when fingerprints are missing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: LocaraSasBadge(),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.shield_rounded), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('tapping badge triggers custom onTap callback when provided', (tester) async {
      bool tapped = false;
      final combined = CombinedFingerprint.fromFingerprints(
        myFingerprint: fpAlpha,
        peerFingerprint: fpBeta,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: LocaraSasBadge(
                fingerprint: combined,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(LocaraSasBadge));
      expect(tapped, isTrue);
    });
  });
}
