import 'package:flutter/material.dart';
import 'package:locara_app/gen/assets.gen.dart';
import 'package:locara_app/gen/strings.g.dart';

class LocaraLogo extends StatelessWidget {
  final bool withText;

  const LocaraLogo({required this.withText});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logo = (isDark ? Assets.img.logo512White : Assets.img.logo512).image(
      width: 200,
      height: 200,
    );

    if (withText) {
      return Column(
        children: [
          logo,
          const SizedBox(height: 16),
          Text(
            t.appName,
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      );
    } else {
      return logo;
    }
  }
}

/// Mesh logo widget alias for backward compatibility and rebranding
typedef MeshLogo = LocaraLogo;
