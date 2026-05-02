import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _primaryColor = Color(0xFF1565C0);
  static const _accentColor = Color(0xFF0288D1);
  static const _bgColor = Color(0xFFF5F7FA);
  static const _cardColor = Colors.white;
  static const _textColor = Color(0xFF1A2340);
  static const _subtextColor = Color(0xFF64748B);
  static const _contactEmail = 'ahmedalmihawed@gmail.com';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1976D2)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.privacy_tip_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('سياسة الخصوصية', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                            Text('آخر تحديث: يناير 2026', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ]),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // مقدمة
                  _IntroCard(
                    text: 'نحن في منار نلتزم بحماية خصوصية مستخدمينا بشكل كامل. تم إعداد هذه السياسة لتتوافق مع الأنظمة المعمول بها في المملكة العربية السعودية ومتطلبات متاجر التطبيقات العالمية.',
                  ),
                  const SizedBox(height: 16),

                  _PolicySection(
                    number: '1',
                    title: 'المعلومات التي نجمعها',
                    icon: Icons.data_usage_rounded,
                    color: _primaryColor,
                    items: const [
                      'البيانات الشخصية: الاسم، رقم الهوية، تاريخ الميلاد، ورقم الهاتف',
                      'البيانات الأكاديمية: الفصول الدراسية، المواد، والجداول الدراسية',
                      'البيانات السلوكية: سجلات الحضور والغياب والملاحظات',
                      'البيانات التقنية: معرف الجهاز لإرسال الإشعارات وتأمين الحساب',
                    ],
                  ),
                  const SizedBox(height: 12),

                  _PolicySection(
                    number: '2',
                    title: 'كيفية استخدام المعلومات',
                    icon: Icons.settings_applications_rounded,
                    color: const Color(0xFF2E7D32),
                    items: const [
                      'توثيق السلوك والمواظبة اليومية للطلاب',
                      'تسهيل التواصل الرسمي بين المدرسة والمنزل',
                      'إصدار التقارير الإحصائية للإدارة المدرسية',
                      'تحسين تجربة المستخدم وضمان أمان الحسابات',
                    ],
                    note: 'لا نستخدم أي بيانات لأغراض إعلانية أو تجارية',
                  ),
                  const SizedBox(height: 12),

                  _PolicySection(
                    number: '3',
                    title: 'مشاركة البيانات',
                    icon: Icons.share_rounded,
                    color: const Color(0xFF6A1B9A),
                    items: const [
                      'داخل المدرسة: مشاركة بيانات الطالب مع المعلمين والإداريين المعنيين فقط',
                      'مع الجهات الحكومية: عند الطلب الرسمي من وزارة التعليم',
                      'مزودو الخدمة: Firebase (Google) لتخزين البيانات بشكل آمن',
                      'لا نبيع أو نؤجر بياناتك لأي طرف ثالث',
                    ],
                  ),
                  const SizedBox(height: 12),

                  _PolicySection(
                    number: '4',
                    title: 'أمان البيانات',
                    icon: Icons.security_rounded,
                    color: const Color(0xFFC62828),
                    items: const [
                      'تشفير SSL/TLS لجميع البيانات المنقولة',
                      'Firebase Security Rules لحماية قاعدة البيانات',
                      'مصادقة ثنائية للحسابات الإدارية',
                      'نسخ احتياطية دورية لضمان استمرارية الخدمة',
                    ],
                  ),
                  const SizedBox(height: 12),

                  _PolicySection(
                    number: '5',
                    title: 'حقوق المستخدم',
                    icon: Icons.verified_user_rounded,
                    color: const Color(0xFF00838F),
                    items: const [
                      'الحق في الاطلاع على بياناتك الشخصية',
                      'الحق في تصحيح البيانات غير الدقيقة',
                      'الحق في طلب حذف البيانات عند انتهاء الاشتراك',
                      'الحق في الاعتراض على معالجة بياناتك',
                    ],
                  ),
                  const SizedBox(height: 12),

                  _PolicySection(
                    number: '6',
                    title: 'الاحتفاظ بالبيانات',
                    icon: Icons.storage_rounded,
                    color: const Color(0xFFE65100),
                    items: const [
                      'يتم الاحتفاظ ببيانات الطلاب طوال فترة الاشتراك',
                      'بعد انتهاء الاشتراك: حذف البيانات خلال 90 يوماً',
                      'يمكن للمدرسة تصدير بياناتها قبل الحذف',
                    ],
                  ),
                  const SizedBox(height: 20),

                  // تواصل معنا
                  _ContactCard(email: _contactEmail),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _IntroCard extends StatelessWidget {
  final String text;
  const _IntroCard({required this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [const Color(0xFF1565C0).withOpacity(0.08), const Color(0xFF0288D1).withOpacity(0.04)],
        begin: Alignment.topRight, end: Alignment.bottomLeft,
      ),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.2)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.info_outline_rounded, color: Color(0xFF1565C0), size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: const TextStyle(color: Color(0xFF1A2340), fontSize: 13.5, height: 1.6))),
    ]),
  );
}

class _PolicySection extends StatelessWidget {
  final String number, title;
  final IconData icon;
  final Color color;
  final List<String> items;
  final String? note;

  const _PolicySection({
    required this.number, required this.title, required this.icon,
    required this.color, required this.items, this.note,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          border: Border(bottom: BorderSide(color: color.withOpacity(0.15))),
        ),
        child: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text(number, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800))),
          ),
          const SizedBox(width: 10),
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
      ),
      // Items
      Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 6, left: 8),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              Expanded(child: Text(item, style: const TextStyle(color: Color(0xFF1A2340), fontSize: 13, height: 1.5))),
            ]),
          )),
          if (note != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Row(children: [
                Icon(Icons.star_rounded, color: color, size: 14),
                const SizedBox(width: 6),
                Expanded(child: Text(note!, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600))),
              ]),
            ),
          ],
        ]),
      ),
    ]),
  );
}

class _ContactCard extends StatelessWidget {
  final String email;
  const _ContactCard({required this.email});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
        begin: Alignment.topRight, end: Alignment.bottomLeft,
      ),
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: const Color(0xFF1565C0).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.mail_rounded, color: Colors.white, size: 20),
        SizedBox(width: 8),
        Text('تواصل معنا', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 8),
      const Text('لأي استفسار حول سياسة الخصوصية أو بياناتك:',
          style: TextStyle(color: Colors.white70, fontSize: 12)),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.alternate_email_rounded, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Text(email, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
    ]),
  );
}
