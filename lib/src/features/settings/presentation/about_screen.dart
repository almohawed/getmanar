import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _version = '3.0.0';
  static const _buildNumber = '42';
  static const _developerName = 'أحمد المهود';
  static const _developerWebsite = 'https://7saven.com';
  static const _appName = 'منار';
  static const _appTagline = 'نظام إدارة المدارس الذكي';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('حول التطبيق', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Hero Section ──────────────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1976D2)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 48),
              child: Column(
                children: [
                  // App Icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'م',
                        style: TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    _appName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _appTagline,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.4)),
                    ),
                    child: Text(
                      'الإصدار $_version (Build $_buildNumber)',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            // ── Features ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionTitle(title: 'مميزات النظام'),
                  const SizedBox(height: 12),
                  _FeatureGrid(),
                  const SizedBox(height: 24),

                  // ── Developer Info ────────────────────────────────────
                  _SectionTitle(title: 'المطوّر'),
                  const SizedBox(height: 12),
                  _DeveloperCard(),
                  const SizedBox(height: 24),

                  // ── App Info ──────────────────────────────────────────
                  _SectionTitle(title: 'معلومات التطبيق'),
                  const SizedBox(height: 12),
                  _InfoCard(items: [
                    _InfoItem(icon: Icons.apps_rounded, label: 'اسم التطبيق', value: _appName),
                    _InfoItem(icon: Icons.tag_rounded, label: 'الإصدار', value: '$_version+$_buildNumber'),
                    _InfoItem(icon: Icons.phone_android_rounded, label: 'المنصة', value: 'Android • iOS • Web'),
                    _InfoItem(icon: Icons.cloud_rounded, label: 'الخادم', value: 'Firebase Cloud'),
                    _InfoItem(icon: Icons.language_rounded, label: 'اللغة', value: 'العربية'),
                    _InfoItem(icon: Icons.calendar_today_rounded, label: 'سنة الإصدار', value: '2025'),
                  ]),
                  const SizedBox(height: 24),

                  // ── Legal ─────────────────────────────────────────────
                  _SectionTitle(title: 'قانوني'),
                  const SizedBox(height: 12),
                  _LegalCard(),
                  const SizedBox(height: 32),

                  // ── Copyright ─────────────────────────────────────────
                  Center(
                    child: Column(
                      children: [
                        Text(
                          '© ${DateTime.now().year} جميع الحقوق محفوظة',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => _launchUrl(_developerWebsite),
                          child: const Text(
                            'تصميم وبرمجة: $_developerName',
                            style: TextStyle(
                              color: Color(0xFF1565C0),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => _launchUrl(_developerWebsite),
                          child: const Text(
                            '7saven.com',
                            style: TextStyle(
                              color: Color(0xFF0288D1),
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ─── Section Title ────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 4, height: 20, decoration: BoxDecoration(
      color: const Color(0xFF1565C0), borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 10),
    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A2340))),
  ]);
}

// ─── Feature Grid ─────────────────────────────────────────────────────────────
class _FeatureGrid extends StatelessWidget {
  final _features = const [
    _Feature(icon: Icons.school_rounded, label: 'إدارة المدارس', color: Color(0xFF1565C0)),
    _Feature(icon: Icons.people_rounded, label: 'إدارة الطلاب', color: Color(0xFF2E7D32)),
    _Feature(icon: Icons.auto_awesome_rounded, label: 'الجدول الذكي', color: Color(0xFF6A1B9A)),
    _Feature(icon: Icons.supervisor_account_rounded, label: 'الإشراف والمناوبة', color: Color(0xFF0D47A1)),
    _Feature(icon: Icons.gavel_rounded, label: 'السلوك والمواظبة', color: Color(0xFFE65100)),
    _Feature(icon: Icons.psychology_rounded, label: 'الإرشاد الطلابي', color: Color(0xFF00838F)),
    _Feature(icon: Icons.health_and_safety_rounded, label: 'الصحة المدرسية', color: Color(0xFFC62828)),
    _Feature(icon: Icons.sms_rounded, label: 'رسائل SMS', color: Color(0xFF1B5E20)),
    _Feature(icon: Icons.notifications_rounded, label: 'الإشعارات الذكية', color: Color(0xFFF57F17)),
    _Feature(icon: Icons.bar_chart_rounded, label: 'التقارير والإحصاء', color: Color(0xFF4527A0)),
    _Feature(icon: Icons.picture_as_pdf_rounded, label: 'تصدير PDF', color: Color(0xFFB71C1C)),
    _Feature(icon: Icons.cloud_sync_rounded, label: 'مزامنة سحابية', color: Color(0xFF006064)),
  ];

  const _FeatureGrid();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _features.map((f) => Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: f.color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(f.icon, color: f.color, size: 18),
          ),
          const SizedBox(height: 6),
          Text(f.label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF1A2340)),
            textAlign: TextAlign.center, maxLines: 2,
            overflow: TextOverflow.ellipsis),
        ]),
      )).toList(),
    );
  }
}

class _Feature {
  final IconData icon;
  final String label;
  final Color color;
  const _Feature({required this.icon, required this.label, required this.color});
}

// ─── Developer Card ───────────────────────────────────────────────────────────
class _DeveloperCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: const Color(0xFF1565C0).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
          ),
          child: const Center(child: Text('أ', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900))),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('تصميم وبرمجة', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 2),
          const Text('أحمد المهود', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              final uri = Uri.parse('https://7saven.com');
              if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.language_rounded, color: Colors.white, size: 14),
                const SizedBox(width: 5),
                const Text('7saven.com', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ])),
      ]),
    );
  }
}

// ─── Info Card ────────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final List<_InfoItem> items;
  const _InfoCard({required this.items});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(
      children: items.asMap().entries.map((e) {
        final item = e.value;
        final isLast = e.key == items.length - 1;
        return Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(color: const Color(0xFF1565C0).withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                child: Icon(item.icon, color: const Color(0xFF1565C0), size: 18)),
              const SizedBox(width: 12),
              Expanded(child: Text(item.label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13))),
              Text(item.value, style: const TextStyle(color: Color(0xFF1A2340), fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
          if (!isLast) const Divider(height: 1, indent: 64),
        ]);
      }).toList(),
    ),
  );
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;
  const _InfoItem({required this.icon, required this.label, required this.value});
}

// ─── Legal Card ───────────────────────────────────────────────────────────────
class _LegalCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(children: [
      _LegalTile(icon: Icons.privacy_tip_rounded, label: 'سياسة الخصوصية',
          onTap: () => context.push('/privacy-policy')),
      const Divider(height: 1, indent: 64),
      _LegalTile(icon: Icons.description_rounded, label: 'شروط الاستخدام',
          onTap: () => context.push('/terms-of-use')),
      const Divider(height: 1, indent: 64),
      _LegalTile(icon: Icons.security_rounded, label: 'الأمان والحماية',
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('يستخدم منار تشفير SSL وFirebase Security Rules لحماية بياناتك')))),
    ]),
  );
}

class _LegalTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _LegalTile({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(width: 36, height: 36,
      decoration: BoxDecoration(color: const Color(0xFF1565C0).withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: const Color(0xFF1565C0), size: 18)),
    title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF64748B)),
    onTap: onTap,
  );
}
