import 'package:flutter/material.dart';

class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key});

  static const _primaryColor = Color(0xFF1B5E20);
  static const _contactEmail = 'ahmedalmihawed@gmail.com';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
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
                            child: const Icon(Icons.description_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('اتفاقية الاستخدام', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
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

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _IntroCard(
                    color: _primaryColor,
                    text: 'مرحباً بك في منار. باستخدامك لهذا التطبيق، فإنك توافق على الالتزام بالشروط والأحكام التالية. يرجى قراءتها بعناية قبل الاستخدام.',
                  ),
                  const SizedBox(height: 16),

                  _TermsSection(number: '1', title: 'قبول الشروط', icon: Icons.check_circle_rounded, color: _primaryColor,
                    items: const [
                      'بمجرد تحميل التطبيق أو تسجيل الدخول، فإنك توافق على هذه الشروط',
                      'تسري هذه الشروط وفق القوانين المعمول بها في المملكة العربية السعودية',
                      'نحتفظ بحق تعديل هذه الشروط مع إشعار مسبق للمستخدمين',
                    ]),
                  const SizedBox(height: 12),

                  _TermsSection(number: '2', title: 'الأهلية والاستخدام المصرح به', icon: Icons.verified_user_rounded, color: const Color(0xFF1565C0),
                    items: const [
                      'التطبيق مخصص للمدارس، المعلمين، الطلاب، وأولياء الأمور المصرح لهم',
                      'يجب استخدام التطبيق للأغراض التعليمية والإدارية المشروعة فقط',
                      'يمنع استخدام التطبيق لأي غرض غير قانوني أو ضار',
                      'يمنع نشر أي محتوى مسيء أو مخالف للأنظمة',
                    ]),
                  const SizedBox(height: 12),

                  _TermsSection(number: '3', title: 'الحسابات والأمان', icon: Icons.lock_rounded, color: const Color(0xFF6A1B9A),
                    items: const [
                      'أنت مسؤول عن الحفاظ على سرية بيانات الدخول الخاصة بك',
                      'يجب إبلاغ إدارة المدرسة فوراً عن أي استخدام غير مصرح به',
                      'تتحمل المسؤولية الكاملة عن جميع الأنشطة تحت حسابك',
                      'يُمنع مشاركة بيانات الدخول مع أي شخص آخر',
                    ]),
                  const SizedBox(height: 12),

                  _TermsSection(number: '4', title: 'حقوق الملكية الفكرية', icon: Icons.copyright_rounded, color: const Color(0xFFE65100),
                    items: const [
                      'جميع حقوق تصميم التطبيق والكود البرمجي محفوظة لمنار',
                      'البيانات المدخلة من قبل المدرسة هي ملك للمدرسة',
                      'يُمنع نسخ أو توزيع أي جزء من التطبيق دون إذن مسبق',
                      'الشعارات والعلامات التجارية محمية بموجب قوانين الملكية الفكرية',
                    ]),
                  const SizedBox(height: 12),

                  _TermsSection(number: '5', title: 'المسؤولية والضمانات', icon: Icons.shield_rounded, color: const Color(0xFF00838F),
                    items: const [
                      'نسعى لضمان توفر الخدمة بشكل مستمر مع الحد الأدنى من الانقطاع',
                      'لسنا مسؤولين عن أي خسائر ناتجة عن سوء استخدام التطبيق',
                      'نحتفظ بحق تعليق الحسابات المخالفة لهذه الشروط',
                      'نوفر دعماً فنياً لحل المشكلات التقنية خلال أوقات العمل',
                    ]),
                  const SizedBox(height: 12),

                  _TermsSection(number: '6', title: 'إنهاء الخدمة', icon: Icons.cancel_rounded, color: const Color(0xFFC62828),
                    items: const [
                      'يمكن للمدرسة إنهاء الاشتراك في أي وقت مع إشعار مسبق',
                      'عند الإنهاء، يتم الاحتفاظ بالبيانات لمدة 90 يوماً للتصدير',
                      'نحتفظ بحق إنهاء الخدمة في حالة انتهاك الشروط',
                    ]),
                  const SizedBox(height: 12),

                  _TermsSection(number: '7', title: 'القانون المطبق', icon: Icons.gavel_rounded, color: const Color(0xFF4527A0),
                    items: const [
                      'تخضع هذه الاتفاقية لقوانين المملكة العربية السعودية',
                      'أي نزاع يُحل وفق الأنظمة المعمول بها في المملكة',
                      'تُعدّ المحاكم السعودية المختصة للفصل في أي نزاع',
                    ]),
                  const SizedBox(height: 20),

                  _ContactCard(email: _contactEmail, color: _primaryColor),
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
  final Color color;
  const _IntroCard({required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [color.withOpacity(0.08), color.withOpacity(0.03)],
        begin: Alignment.topRight, end: Alignment.bottomLeft,
      ),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.info_outline_rounded, color: color, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: const TextStyle(color: Color(0xFF1A2340), fontSize: 13.5, height: 1.6))),
    ]),
  );
}

class _TermsSection extends StatelessWidget {
  final String number, title;
  final IconData icon;
  final Color color;
  final List<String> items;

  const _TermsSection({
    required this.number, required this.title, required this.icon,
    required this.color, required this.items,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
      Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 6, left: 8),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            Expanded(child: Text(item, style: const TextStyle(color: Color(0xFF1A2340), fontSize: 13, height: 1.5))),
          ]),
        )).toList()),
      ),
    ]),
  );
}

class _ContactCard extends StatelessWidget {
  final String email;
  final Color color;
  const _ContactCard({required this.email, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [color, color.withOpacity(0.8)],
        begin: Alignment.topRight, end: Alignment.bottomLeft,
      ),
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.mail_rounded, color: Colors.white, size: 20),
        SizedBox(width: 8),
        Text('تواصل معنا', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 8),
      const Text('لأي استفسار حول اتفاقية الاستخدام:',
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
