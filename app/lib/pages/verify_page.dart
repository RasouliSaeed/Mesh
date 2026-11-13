import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:locara_app/gen/strings.g.dart';
import 'package:locara_app/provider/security_provider.dart';
import 'package:locara_app/theme/mesh_design_tokens.dart';
import 'package:locara_app/util/fingerprint_alphabet.dart';
import 'package:locara_app/widget/design/mesh_glass_card.dart';
import 'package:locara_app/widget/responsive_list_view.dart';
import 'package:refena_flutter/refena_flutter.dart';

class CombinedFingerprint {
  final String combined;
  final List<IconData> icons;

  CombinedFingerprint({
    required this.combined,
    required this.icons,
  });

  /// Deterministically derives a CombinedFingerprint from two certificate hashes.
  /// Sorts them so the result is identical regardless of who is sender or receiver.
  factory CombinedFingerprint.fromFingerprints({
    required String myFingerprint,
    required String peerFingerprint,
  }) {
    final fingerprints = [myFingerprint, peerFingerprint]..sort();
    final combined = fingerprints.join();
    final icons = fingerprintToIcons(combined);
    return CombinedFingerprint(
      combined: combined,
      icons: icons,
    );
  }

  factory CombinedFingerprint.load(BuildContext context, String fingerprint) {
    final myFingerprint = context.read(securityProvider.select((s) => s.certificateHash));
    return CombinedFingerprint.fromFingerprints(
      myFingerprint: myFingerprint,
      peerFingerprint: fingerprint,
    );
  }

  /// Compact Short Authentication String (SAS): the first 4 visual icons.
  List<IconData> get shortIcons => icons.take(4).toList();
}

enum VerifyMode {
  icons,
  text,
}

/// Verifies the identity of a discovered device by comparing the fingerprints
/// of both sides.
class VerifyPage extends StatefulWidget {
  final CombinedFingerprint fingerprint;

  const VerifyPage({required this.fingerprint});

  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  VerifyMode _mode = VerifyMode.icons;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LocaraDesignTokens.deepNavy,
      appBar: AppBar(
        backgroundColor: LocaraDesignTokens.darkNavy,
        elevation: 0,
        title: Text(
          t.verifyPage.title,
          style: const TextStyle(
            color: LocaraDesignTokens.primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ResponsiveListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          Center(
            child: Container(
              decoration: BoxDecoration(
                color: LocaraDesignTokens.cardSurface,
                borderRadius: LocaraDesignTokens.borderRadiusLarge,
                border: Border.all(color: LocaraDesignTokens.cardBorderSubtle),
              ),
              child: SegmentedButton<VerifyMode>(
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: LocaraDesignTokens.primaryBlue,
                  selectedForegroundColor: Colors.white,
                  foregroundColor: LocaraDesignTokens.secondaryText,
                ),
                segments: [
                  ButtonSegment(value: VerifyMode.icons, label: Text(t.verifyPage.icons)),
                  ButtonSegment(value: VerifyMode.text, label: Text(t.verifyPage.text)),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) => setState(() => _mode = selection.first),
              ),
            ),
          ),
          const SizedBox(height: 24),
          VerifyWidget(
            mode: _mode,
            fingerprint: widget.fingerprint,
          ),
          const SizedBox(height: 24),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                t.verifyPage.question,
                textAlign: TextAlign.center,
                style: LocaraDesignTokens.bodyRegular.copyWith(
                  color: LocaraDesignTokens.secondaryText,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VerifyWidget extends StatelessWidget {
  final VerifyMode mode;
  final CombinedFingerprint fingerprint;

  const VerifyWidget({
    required this.mode,
    required this.fingerprint,
  });

  static const List<Color> _iconColors = [
    LocaraDesignTokens.cyan,
    LocaraDesignTokens.electricBlue,
    LocaraDesignTokens.purple,
    LocaraDesignTokens.cyan,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        switch (mode) {
          VerifyMode.icons => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: fingerprint.icons.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final icon = fingerprint.icons[index];
                  final color = _iconColors[index % _iconColors.length];
                  return Container(
                    decoration: BoxDecoration(
                      color: LocaraDesignTokens.cardSurface,
                      borderRadius: LocaraDesignTokens.borderRadiusMedium,
                      border: Border.all(
                        color: color.withValues(alpha: 0.3),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.15),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        size: 28,
                        color: color,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          VerifyMode.text => LocaraGlassCard(
            fillColor: LocaraDesignTokens.cardSurface.withValues(alpha: 0.9),
            borderColor: LocaraDesignTokens.cardBorderSubtle,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SelectableText(
                  fingerprint.combined,
                  style: const TextStyle(
                    color: LocaraDesignTokens.primaryText,
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.6,
                    letterSpacing: 1,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: fingerprint.combined));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(t.general.copiedToClipboard),
                          backgroundColor: LocaraDesignTokens.darkNavy,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('کپی اثرانگشت'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: LocaraDesignTokens.cyan,
                    side: const BorderSide(color: LocaraDesignTokens.cyan),
                  ),
                ),
              ],
            ),
          ),
        },
      ],
    );
  }
}
