import 'dart:async';
import 'package:flutter/material.dart';
import 'package:locara_app/gen/strings.g.dart';
import 'package:locara_app/pages/debug/debug_page.dart';
import 'package:locara_app/theme/mesh_design_tokens.dart';
import 'package:locara_app/widget/locara_logo.dart';
import 'package:locara_app/widget/responsive_list_view.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:routerino/routerino.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    unawaited(
      PackageInfo.fromPlatform().then((info) {
        if (mounted) {
          setState(() {
            _packageInfo = info;
          });
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPersian = LocaleSettings.currentLocale == AppLocale.fa;
    final versionStr = _packageInfo != null ? '${_packageInfo!.version} (${_packageInfo!.buildNumber})' : '...';

    return Scaffold(
      appBar: AppBar(
        title: Text(t.aboutPage.title),
      ),
      body: ResponsiveListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          const Center(
            child: LocaraLogo(withText: false),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'MESH',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: LocaraDesignTokens.cyan,
              ),
            ),
          ),
          Center(
            child: Text(
              isPersian ? 'نزدیک. فوری. خصوصی.' : 'Nearby. Instant. Private.',
              style: const TextStyle(
                fontSize: 15,
                color: LocaraDesignTokens.mutedText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: LocaraDesignTokens.cardSurfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: LocaraDesignTokens.cardBorderSubtle),
              ),
              child: Text(
                '${isPersian ? "نسخه" : "Version"} $versionStr',
                style: const TextStyle(
                  fontSize: 13,
                  color: LocaraDesignTokens.primaryText,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            color: LocaraDesignTokens.cardSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: LocaraDesignTokens.cardBorderSubtle),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPersian ? 'درباره نرم‌افزار' : 'About MESH',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: LocaraDesignTokens.cyan,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isPersian
                        ? 'مش (MESH) یک نرم‌افزار متن‌باز، امن و سبک برای تبادل مستقیم و پرسرعت فایل و پیام در شبکه محلی (Wi-Fi / LAN) بدون نیاز به اینترنت و بدون ارسال داده‌ها به سرورهای ابری است.'
                        : 'MESH is an open-source, secure, and lightweight application for direct, high-speed peer-to-peer file transfer and local messaging over Wi-Fi / LAN without internet access or cloud servers.',
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: LocaraDesignTokens.primaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: LocaraDesignTokens.cardSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: LocaraDesignTokens.cardBorderSubtle),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPersian ? 'توسعه‌دهنده و طراح' : 'Developer & Designer',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: LocaraDesignTokens.cyan,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: LocaraDesignTokens.cardSurfaceLight,
                        child: Icon(Icons.person, color: LocaraDesignTokens.cyan),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPersian ? 'سعید رسولی' : 'Saeed Rasouli',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Text(
                              'RasouliSaeed',
                              style: TextStyle(
                                fontSize: 13,
                                color: LocaraDesignTokens.mutedText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: LocaraDesignTokens.cardSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: LocaraDesignTokens.cardBorderSubtle),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.code_rounded, color: LocaraDesignTokens.cyan),
                  title: Text(isPersian ? 'مخزن رسمی گیت‌هاب' : 'Official GitHub Repository'),
                  subtitle: const Text('github.com/RasouliSaeed/Mesh'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () async {
                    await launchUrl(
                      Uri.parse('https://github.com/RasouliSaeed/Mesh'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
                const Divider(height: 1, color: LocaraDesignTokens.cardBorderSubtle),
                ListTile(
                  leading: const Icon(Icons.article_outlined, color: LocaraDesignTokens.cyan),
                  title: Text(isPersian ? 'مجوزها و لایسنس‌ها' : 'Open Source Licenses'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await context.push(() => const LicensePage());
                  },
                ),
                const Divider(height: 1, color: LocaraDesignTokens.cardBorderSubtle),
                ListTile(
                  leading: const Icon(Icons.bug_report_outlined, color: LocaraDesignTokens.cyan),
                  title: Text(isPersian ? 'ابزار عیب‌یابی و لاگ‌ها' : 'Debugging & Logs'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await context.push(() => const DebugPage());
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              '© ${DateTime.now().year} Saeed Rasouli • Released under MIT / Apache 2.0',
              style: const TextStyle(
                fontSize: 12,
                color: LocaraDesignTokens.mutedText,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
