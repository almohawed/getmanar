import 'package:flutter/material.dart';

enum GuidanceCategory {
  lateness,
  homework,
  discipline,
  mergedLateHomework,
  mergedHomeworkDiscipline,
  mergedLateDiscipline,
  positive,
}

enum GuidanceSeverity {
  soft,
  medium,
  strong,
}

enum SchoolStage {
  primary,
  middle,
  secondary,
}

class GuidanceMessage {
  final String id;
  final String text;
  final GuidanceCategory category;
  final GuidanceSeverity severity;

  const GuidanceMessage({
    required this.id,
    required this.text,
    required this.category,
    required this.severity,
  });
}

class SilentGuidanceConstants {
  // LATE MESSAGES
  static const List<GuidanceMessage> lateMessages = [
    // Soft
    GuidanceMessage(id: 'LATE_S_01', text: "الانطلاقة المبكرة تساعدك تبدأ الحصة بثقة وهدوء.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'LATE_S_02', text: "الوصول في الوقت يجعل فهم الدرس أسهل من البداية.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'LATE_S_03', text: "بداية اليوم الهادئة تفرق كثيرًا في تركيزك.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'LATE_S_04', text: "جرّب تجهيز أغراضك من الليل لتبدأ يومك بسلاسة.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'LATE_S_05', text: "الدقائق الأولى من الحصة هي مفتاح الفهم.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'LATE_S_06', text: "ابدأ يومك مبكرًا… وستلاحظ فرقًا جميلًا.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'LATE_S_07', text: "الالتزام بالوقت عادة تصنع نجاحًا كبيرًا.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'LATE_S_08', text: "الوصول مبكرًا يخفف التوتر ويزيد التركيز.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'LATE_S_09', text: "خطوة بسيطة: اخرج قبل الوقت بدقائق.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'LATE_S_10', text: "البداية المنتظمة تساعدك تكمل اليوم بنشاط.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'LATE_S_11', text: "انتظام الحضور يسهّل عليك متابعة المعلم.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'LATE_S_12', text: "أول الحصة فرصة ذهبية لا تفوّتها.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.soft),
    // Medium
    GuidanceMessage(id: 'LATE_M_01', text: "انتظامك في بداية اليوم يدعم تركيزك طوال الحصص.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'LATE_M_02', text: "الحضور في الوقت يساعدك تستوعب تسلسل الدرس من البداية.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'LATE_M_03', text: "الالتزام بوقت الحصة يعزز أداءك الأكاديمي بشكل واضح.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'LATE_M_04', text: "حاول تثبيت روتين صباحي بسيط يساعدك على الانتظام.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'LATE_M_05', text: "البداية المنتظمة تمنحك أفضلية في الفهم والمشاركة.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'LATE_M_06', text: "الحضور المبكر ينعكس على ثقتك ومشاركتك داخل الفصل.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'LATE_M_07', text: "عندما تبدأ مع الجميع… يصبح التعلم أسهل وأسرع.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'LATE_M_08', text: "الالتزام بالوقت عادة مدرسية ترفع مستواك تدريجيًا.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'LATE_M_09', text: "ابدأ يومك دون استعجال: خطّط لخروجك مبكرًا.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'LATE_M_10', text: "الوقت جزء من الانضباط… والانضباط طريق التفوق.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'LATE_M_11', text: "البداية الصحيحة تسهّل عليك بقية اليوم الدراسي.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'LATE_M_12', text: "انتظام الحضور يساعدك على تثبيت المعلومات بشكل أفضل.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.medium),
    // Strong
    GuidanceMessage(id: 'LATE_T_01', text: "حافظ على الحضور في الوقت؛ البداية المنتظمة تصنع فرقًا كبيرًا.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'LATE_T_02', text: "الالتزام ببداية الحصة يحمي تقدمك الدراسي ويزيد فهمك.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'LATE_T_03', text: "اجعل بداية يومك ثابتة؛ هذا ينعكس مباشرة على مستواك.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'LATE_T_04', text: "حاول معالجة سبب التأخر مبكرًا لتستعيد انتظامك.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'LATE_T_05', text: "انتظام الحضور من أهم عوامل التفوق داخل الفصل.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'LATE_T_06', text: "لا تجعل التأخر عادة؛ انطلق مبكرًا لتكسب الحصة كاملة.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'LATE_T_07', text: "ابدأ يومك في الوقت… وستلاحظ تحسنًا سريعًا.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'LATE_T_08', text: "الدقائق الأولى ليست بسيطة؛ فيها أساس الدرس.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'LATE_T_09', text: "ثبت وقت نومك واستيقاظك لتحافظ على بداية قوية.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'LATE_T_10', text: "ابدأ بقرار واحد: الوصول قبل الجرس بدقائق.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'LATE_T_11', text: "انتظام البداية يحمي تركيزك ويقلل التشتت.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'LATE_T_12', text: "الالتزام بالوقت مسؤولية مدرسية تعكس نضجك.", category: GuidanceCategory.lateness, severity: GuidanceSeverity.strong),
  ];

  // HOMEWORK MESSAGES
  static const List<GuidanceMessage> homeworkMessages = [
    // Soft
    GuidanceMessage(id: 'HW_S_01', text: "إنجاز المهام أولًا بأول يجعل المذاكرة أخف وأسهل.", category: GuidanceCategory.homework, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'HW_S_02', text: "قسّم واجبك إلى خطوات صغيرة… وستنجزه بسرعة.", category: GuidanceCategory.homework, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'HW_S_03', text: "ابدأ بالقليل يوميًا… وستصل للتميز.", category: GuidanceCategory.homework, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'HW_S_04', text: "وقت بسيط للواجبات اليوم يريحك غدًا.", category: GuidanceCategory.homework, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'HW_S_05', text: "الواجب يساعدك تثبّت الفهم بعد الحصة.", category: GuidanceCategory.homework, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'HW_S_06', text: "رتّب وقتًا قصيرًا يوميًا للمهام… وستلاحظ فرقًا.", category: GuidanceCategory.homework, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'HW_S_07', text: "عندما تنهي واجبك مبكرًا… تصبح أكثر هدوءًا.", category: GuidanceCategory.homework, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'HW_S_08', text: "ابدأ بالأسهل ثم الأصعب… خطّة ذكية للإنجاز.", category: GuidanceCategory.homework, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'HW_S_09', text: "الاستمرار أهم من الكمال… خطوة يومية تكفي.", category: GuidanceCategory.homework, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'HW_S_10', text: "إنجاز الواجبات عادة ترفع مستواك تدريجيًا.", category: GuidanceCategory.homework, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'HW_S_11', text: "الواجب فرصة تدريب… ليس عبئًا.", category: GuidanceCategory.homework, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'HW_S_12', text: "جرّب تحديد وقت ثابت بعد العودة من المدرسة.", category: GuidanceCategory.homework, severity: GuidanceSeverity.soft),
    // Medium
    GuidanceMessage(id: 'HW_M_01', text: "إنجاز الواجبات باستمرار يقوّي فهمك ويزيد ثقتك.", category: GuidanceCategory.homework, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'HW_M_02', text: "ثبّت وقتًا يوميًا للمهام؛ هذا يحافظ على تقدمك.", category: GuidanceCategory.homework, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'HW_M_03', text: "متابعة الواجبات تساعدك تواكب الدروس بدون تراكم.", category: GuidanceCategory.homework, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'HW_M_04', text: "إنجاز المهام أولًا بأول يرفع مستوى التحصيل بشكل ملحوظ.", category: GuidanceCategory.homework, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'HW_M_05', text: "الواجبات تُظهر نقاط القوة وما يحتاج دعمًا… انتبه لها.", category: GuidanceCategory.homework, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'HW_M_06', text: "عندما تلتزم بالواجب… يصبح الاختبار أسهل.", category: GuidanceCategory.homework, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'HW_M_07', text: "العمل اليومي البسيط أفضل من التراكم في آخر الأسبوع.", category: GuidanceCategory.homework, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'HW_M_08', text: "ابدأ بوقت 15–20 دقيقة يوميًا للمهام.", category: GuidanceCategory.homework, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'HW_M_09', text: "ثبات العادة أهم من طول الوقت… التزم ثم زِد تدريجيًا.", category: GuidanceCategory.homework, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'HW_M_10', text: "إنجاز واجباتك يساعد المعلم يفهم احتياجك بدقة.", category: GuidanceCategory.homework, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'HW_M_11', text: "تقدمك الدراسي يتغذى من الالتزام اليومي بالمهام.", category: GuidanceCategory.homework, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'HW_M_12', text: "رتّب أولوياتك: مهامك أولًا ثم وقتك الحر.", category: GuidanceCategory.homework, severity: GuidanceSeverity.medium),
    // Strong
    GuidanceMessage(id: 'HW_T_01', text: "حاول تثبيت وقت يومي للواجبات؛ هذا يحمي تقدمك الدراسي.", category: GuidanceCategory.homework, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'HW_T_02', text: "إنجاز المهام باستمرار ضرورة للحفاظ على مستواك.", category: GuidanceCategory.homework, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'HW_T_03', text: "اجعل الواجب جزءًا ثابتًا من يومك لتمنع التراكم.", category: GuidanceCategory.homework, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'HW_T_04', text: "التأجيل يراكم الصعوبة… ابدأ مبكرًا لتبقى مرتاحًا.", category: GuidanceCategory.homework, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'HW_T_05', text: "الالتزام بالواجبات هو الجسر الحقيقي نحو التفوق.", category: GuidanceCategory.homework, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'HW_T_06', text: "حافظ على عادة يومية للمهام؛ ستشكر نفسك لاحقًا.", category: GuidanceCategory.homework, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'HW_T_07', text: "ثبت خطة بسيطة: وقت قصير يوميًا أفضل من فترات طويلة متقطعة.", category: GuidanceCategory.homework, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'HW_T_08', text: "ابدأ اليوم… لا تنتظر؛ الاستمرار يصنع الفرق.", category: GuidanceCategory.homework, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'HW_T_09', text: "الواجب تدريب مباشر على الاختبارات—لا تهمله.", category: GuidanceCategory.homework, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'HW_T_10', text: "الإنجاز المنتظم يمنحك ثباتًا أكاديميًا واضحًا.", category: GuidanceCategory.homework, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'HW_T_11', text: "تابع مهامك أولًا بأول لتبقى على مسار التميز.", category: GuidanceCategory.homework, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'HW_T_12', text: "اجعل الواجب أولوية؛ فهو أساس التحصيل.", category: GuidanceCategory.homework, severity: GuidanceSeverity.strong),
  ];

  // DISCIPLINE MESSAGES
  static const List<GuidanceMessage> disciplineMessages = [
    // Soft
    GuidanceMessage(id: 'DISC_S_01', text: "التزامك داخل الحصة يساعدك تتعلم بهدوء.", category: GuidanceCategory.discipline, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'DISC_S_02', text: "الهدوء والتركيز داخل الفصل يصنعان فرقًا كبيرًا.", category: GuidanceCategory.discipline, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'DISC_S_03', text: "احترام وقت الحصة يساعدك وتساعد زملاءك.", category: GuidanceCategory.discipline, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'DISC_S_04', text: "الالتزام سلوك جميل يعكس شخصيتك.", category: GuidanceCategory.discipline, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'DISC_S_05', text: "كل يوم فرصة جديدة لتكون أفضل.", category: GuidanceCategory.discipline, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'DISC_S_06', text: "ركز على الاستماع في بداية الشرح… وستفهم أسرع.", category: GuidanceCategory.discipline, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'DISC_S_07', text: "التعاون والهدوء يرفعان جودة الحصة.", category: GuidanceCategory.discipline, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'DISC_S_08', text: "كن قدوة في الالتزام… وستشعر بالتميز.", category: GuidanceCategory.discipline, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'DISC_S_09', text: "حافظ على هدوئك داخل الفصل لتستفيد أكثر.", category: GuidanceCategory.discipline, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'DISC_S_10', text: "الالتزام عادة تتكوّن خطوة بخطوة.", category: GuidanceCategory.discipline, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'DISC_S_11', text: "الانتباه خلال الشرح يجعل الواجب أسهل.", category: GuidanceCategory.discipline, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'DISC_S_12', text: "جرّب تنظيم أدواتك قبل بدء الدرس.", category: GuidanceCategory.discipline, severity: GuidanceSeverity.soft),
    // Medium (Assumed from pattern as user only provided Soft/Strong for DISC explicitly in first prompt part but Strong was provided later. Using Generic Medium based on tone)
    GuidanceMessage(id: 'DISC_M_01', text: "استمر على سلوكك الإيجابي؛ فهو يدعم تحصيلك وثقتك بنفسك.", category: GuidanceCategory.discipline, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'DISC_M_02', text: "التركيز والهدوء داخل الفصل يقلل التشتت ويزيد الفهم.", category: GuidanceCategory.discipline, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'DISC_M_03', text: "التزامك بالقواعد المدرسية يعكس اهتمامك بمستقبلك.", category: GuidanceCategory.discipline, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'DISC_M_04', text: "حافظ على انضباطك؛ فهو مفتاح الاستفادة من المعلم.", category: GuidanceCategory.discipline, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'DISC_M_05', text: "الهدوء داخل الحصة يساعدك على تدوين الملاحظات المهمة.", category: GuidanceCategory.discipline, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'DISC_M_06', text: "كن مستمعًا جيدًا في الفصل؛ هذا يختصر وقت المذاكرة.", category: GuidanceCategory.discipline, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'DISC_M_07', text: "الالتزام داخل الصف هو الخطوة الأولى نحو النجاح.", category: GuidanceCategory.discipline, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'DISC_M_08', text: "سلوكك المنضبط يمنحك فرصة أكبر للمشاركة والتفاعل.", category: GuidanceCategory.discipline, severity: GuidanceSeverity.medium),
    // Strong
    GuidanceMessage(id: 'DISC_T_01', text: "حافظ على هدوئك وتركيزك داخل الحصة؛ هذا يحمي تقدمك.", category: GuidanceCategory.discipline, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'DISC_T_02', text: "الالتزام بالتعليمات داخل الفصل ضروري لتحقيق نتائج أفضل.", category: GuidanceCategory.discipline, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'DISC_T_03', text: "ثبت سلوكك داخل الحصة—الالتزام أساس التفوق.", category: GuidanceCategory.discipline, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'DISC_T_04', text: "اجعل تركيزك داخل الحصة هدفًا ثابتًا هذا الأسبوع.", category: GuidanceCategory.discipline, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'DISC_T_05', text: "السلوك المنضبط يساعدك ترفع مستواك بشكل واضح.", category: GuidanceCategory.discipline, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'DISC_T_06', text: "الالتزام مسؤولية مدرسية تعكس نضجك.", category: GuidanceCategory.discipline, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'DISC_T_07', text: "حافظ على احترام وقت الحصة لتستفيد من الدرس كاملًا.", category: GuidanceCategory.discipline, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'DISC_T_08', text: "ركز على الاستماع وابتعد عن المشتتات داخل الفصل.", category: GuidanceCategory.discipline, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'DISC_T_09', text: "التزامك اليوم يصنع فرقًا في نتائجك قريبًا.", category: GuidanceCategory.discipline, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'DISC_T_10', text: "ثبت سلوكك الإيجابي… وستلاحظ أثره سريعًا.", category: GuidanceCategory.discipline, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'DISC_T_11', text: "الالتزام داخل الحصة خطوة أساسية نحو التميز.", category: GuidanceCategory.discipline, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'DISC_T_12', text: "اجعل الحصة وقت تعلم حقيقي—ستجني النتائج.", category: GuidanceCategory.discipline, severity: GuidanceSeverity.strong),
  ];

  // MERGED: LATE + HOMEWORK
  static const List<GuidanceMessage> mergedLateHomeworkMessages = [
    // Soft
    GuidanceMessage(id: 'MLH_S_01', text: "الانطلاقة المبكرة مع إنجاز المهام أولًا بأول تساعدك على نتائج أفضل.", category: GuidanceCategory.mergedLateHomework, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'MLH_S_02', text: "ابدأ يومك في الوقت، وأنهِ مهامك تدريجيًا… وسترتاح.", category: GuidanceCategory.mergedLateHomework, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'MLH_S_03', text: "البداية المنتظمة مع متابعة الواجبات ترفع فهمك بسرعة.", category: GuidanceCategory.mergedLateHomework, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'MLH_S_04', text: "خطوتان بسيطتان: حضور مبكر + واجبات منتظمة.", category: GuidanceCategory.mergedLateHomework, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'MLH_S_05', text: "الوصول في الوقت يجعل الواجب أسهل لأنك فهمت الدرس من البداية.", category: GuidanceCategory.mergedLateHomework, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'MLH_S_06', text: "عندما تبدأ الحصة مبكرًا… يصبح إنجاز مهامك أسهل.", category: GuidanceCategory.mergedLateHomework, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'MLH_S_07', text: "التزامك بالوقت والمهام يصنع تقدمًا جميلًا.", category: GuidanceCategory.mergedLateHomework, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'MLH_S_08', text: "ابدأ مبكرًا اليوم، وحدد وقتًا قصيرًا للمهام.", category: GuidanceCategory.mergedLateHomework, severity: GuidanceSeverity.soft),
    // Medium
    GuidanceMessage(id: 'MLH_M_01', text: "انتظامك في الحضور يدعم تركيزك، ومع متابعة الواجبات يصبح تقدمك أسرع.", category: GuidanceCategory.mergedLateHomework, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'MLH_M_02', text: "اجعل بداية يومك ثابتة، وثبّت وقتًا يوميًا للواجبات.", category: GuidanceCategory.mergedLateHomework, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'MLH_M_03', text: "البداية المنتظمة تقلل التراكم، والواجب يثبت الفهم.", category: GuidanceCategory.mergedLateHomework, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'MLH_M_04', text: "حضورك في الوقت + واجب منتظم = تحسن واضح في التحصيل.", category: GuidanceCategory.mergedLateHomework, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'MLH_M_05', text: "ابدأ مع الجرس، ثم خصص وقتًا ثابتًا للمهام.", category: GuidanceCategory.mergedLateHomework, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'MLH_M_06', text: "عندما تنتظم في الحضور، تواكب الشرح، فيسهل عليك الواجب.", category: GuidanceCategory.mergedLateHomework, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'MLH_M_07', text: "حافظ على بداية قوية، ولا تؤجل المهام لتبقى مرتاحًا.", category: GuidanceCategory.mergedLateHomework, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'MLH_M_08', text: "انتظامك اليومي في الحضور والمهام ينعكس على نتائجك.", category: GuidanceCategory.mergedLateHomework, severity: GuidanceSeverity.medium),
    // Strong
    GuidanceMessage(id: 'MLH_T_01', text: "حافظ على البداية المنتظمة وثبّت وقتًا للواجبات؛ هذا يحمي تحصيلك.", category: GuidanceCategory.mergedLateHomework, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'MLH_T_02', text: "عالج التأخر مبكرًا، وامنَع تراكم الواجبات بخطة يومية.", category: GuidanceCategory.mergedLateHomework, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'MLH_T_03', text: "ابدأ يومك في الوقت، وأنهِ مهامك باستمرار لتستعيد ثباتك الدراسي.", category: GuidanceCategory.mergedLateHomework, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'MLH_T_04', text: "انتظام الحضور والواجبات ضرورة للحفاظ على تقدمك.", category: GuidanceCategory.mergedLateHomework, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'MLH_T_05', text: "البداية المنتظمة مع الواجب اليومي هي طريقك نحو الاستقرار الأكاديمي.", category: GuidanceCategory.mergedLateHomework, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'MLH_T_06', text: "لا تجعل التأخر والتأجيل عادة؛ التزم بخطتين ثابتتين.", category: GuidanceCategory.mergedLateHomework, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'MLH_T_07', text: "حضور منتظم + واجب منتظم = نتائج أقوى خلال فترة قصيرة.", category: GuidanceCategory.mergedLateHomework, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'MLH_T_08', text: "ثبت روتينك: بداية قوية، ومهام منجزة يوميًا.", category: GuidanceCategory.mergedLateHomework, severity: GuidanceSeverity.strong),
  ];

  // MERGED: HOMEWORK + DISCIPLINE
  static const List<GuidanceMessage> mergedHomeworkDisciplineMessages = [
    // Soft
    GuidanceMessage(id: 'MHD_S_01', text: "هدوءك داخل الحصة مع متابعة المهام يجعل التعلم أسهل.", category: GuidanceCategory.mergedHomeworkDiscipline, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'MHD_S_02', text: "التركيز في الحصة يساعدك على إنجاز المهام بسرعة.", category: GuidanceCategory.mergedHomeworkDiscipline, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'MHD_S_03', text: "استمع جيدًا في الشرح، ثم أنجز مهامك خطوة بخطوة.", category: GuidanceCategory.mergedHomeworkDiscipline, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'MHD_S_04', text: "تنظيمك داخل الفصل يسهّل عليك الواجب بعد المدرسة.", category: GuidanceCategory.mergedHomeworkDiscipline, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'MHD_S_05', text: "التركيز أولًا… ثم الواجب يصبح بسيطًا.", category: GuidanceCategory.mergedHomeworkDiscipline, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'MHD_S_06', text: "الالتزام داخل الحصة يدعم إنجاز المهام بسلاسة.", category: GuidanceCategory.mergedHomeworkDiscipline, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'MHD_S_07', text: "حين تهدأ وتنتبه… تفهم أكثر وتنجز أسرع.", category: GuidanceCategory.mergedHomeworkDiscipline, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'MHD_S_08', text: "التزامك في الشرح يساعدك تبني عادة إنجاز ممتازة.", category: GuidanceCategory.mergedHomeworkDiscipline, severity: GuidanceSeverity.soft),
    // Medium
    GuidanceMessage(id: 'MHD_M_01', text: "الالتزام داخل الحصة يرفع فهمك، ومع الواجب المنتظم يصبح تقدمك واضحًا.", category: GuidanceCategory.mergedHomeworkDiscipline, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'MHD_M_02', text: "ركز في الشرح، ثم ثبّت وقتًا يوميًا للمهام لتحافظ على مستواك.", category: GuidanceCategory.mergedHomeworkDiscipline, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'MHD_M_03', text: "ثبات سلوكك + إنجاز الواجبات = ثبات أكاديمي ممتاز.", category: GuidanceCategory.mergedHomeworkDiscipline, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'MHD_M_04', text: "هدوءك داخل الفصل يقلل الأخطاء، والواجب يثبت التعلم.", category: GuidanceCategory.mergedHomeworkDiscipline, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'MHD_M_05', text: "التركيز في الحصة يختصر وقت الواجب ويزيد الفهم.", category: GuidanceCategory.mergedHomeworkDiscipline, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'MHD_M_06', text: "حافظ على التزامك داخل الفصل وأنهِ مهامك أولًا بأول.", category: GuidanceCategory.mergedHomeworkDiscipline, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'MHD_M_07', text: "عندما يثبت سلوكك، يسهل عليك متابعة المهام بدون تراكم.", category: GuidanceCategory.mergedHomeworkDiscipline, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'MHD_M_08', text: "التزامك وواجبك اليومي يصنعان فرقًا كبيرًا.", category: GuidanceCategory.mergedHomeworkDiscipline, severity: GuidanceSeverity.medium),
    // Strong
    GuidanceMessage(id: 'MHD_T_01', text: "ثبت التزامك داخل الحصة وثبّت وقتًا للمهام؛ هذا يحمي تقدمك الدراسي.", category: GuidanceCategory.mergedHomeworkDiscipline, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'MHD_T_02', text: "قلّل المشتتات داخل الفصل، وامنع تراكم الواجب بخطة يومية.", category: GuidanceCategory.mergedHomeworkDiscipline, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'MHD_T_03', text: "الالتزام والواجبات المنتظمة ضرورة للحفاظ على نتائج قوية.", category: GuidanceCategory.mergedHomeworkDiscipline, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'MHD_T_04', text: "اجعل الحصة وقت تعلم حقيقي، ثم أنجز مهامك باستمرار.", category: GuidanceCategory.mergedHomeworkDiscipline, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'MHD_T_05', text: "السلوك المنضبط والمهام المنجزة يصنعان تفوقًا ثابتًا.", category: GuidanceCategory.mergedHomeworkDiscipline, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'MHD_T_06', text: "حافظ على تركيزك داخل الحصة، ولا تؤجل المهام.", category: GuidanceCategory.mergedHomeworkDiscipline, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'MHD_T_07', text: "التزامك اليوم + واجبك اليومي = تحسن سريع.", category: GuidanceCategory.mergedHomeworkDiscipline, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'MHD_T_08', text: "التزام قوي داخل الفصل مع مهام منتظمة يرفع مستواك بوضوح.", category: GuidanceCategory.mergedHomeworkDiscipline, severity: GuidanceSeverity.strong),
  ];

  // MERGED: LATE + DISCIPLINE
  static const List<GuidanceMessage> mergedLateDisciplineMessages = [
    // Soft
    GuidanceMessage(id: 'MLD_S_01', text: "ابدأ يومك مبكرًا وركز داخل الحصة لتستفيد أكثر.", category: GuidanceCategory.mergedLateDiscipline, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'MLD_S_02', text: "الوصول في الوقت يساعدك تدخل الحصة بهدوء وتركيز.", category: GuidanceCategory.mergedLateDiscipline, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'MLD_S_03', text: "بداية منتظمة مع هدوء داخل الفصل تصنع يومًا أفضل.", category: GuidanceCategory.mergedLateDiscipline, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'MLD_S_04', text: "حضورك المبكر يساعدك تبدأ الشرح دون تشتت.", category: GuidanceCategory.mergedLateDiscipline, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'MLD_S_05', text: "التزامك بالوقت والهدوء يجعل الحصة أسهل.", category: GuidanceCategory.mergedLateDiscipline, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'MLD_S_06', text: "ابدأ مع الجرس… ثم ركز في الشرح.", category: GuidanceCategory.mergedLateDiscipline, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'MLD_S_07', text: "البداية الصحيحة تساعدك تثبت تركيزك.", category: GuidanceCategory.mergedLateDiscipline, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'MLD_S_08', text: "حضور مبكر + تركيز جيد = استفادة أكبر.", category: GuidanceCategory.mergedLateDiscipline, severity: GuidanceSeverity.soft),
    // Medium
    GuidanceMessage(id: 'MLD_M_01', text: "انتظامك في الحضور يدعم هدوءك داخل الحصة ويزيد الفهم.", category: GuidanceCategory.mergedLateDiscipline, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'MLD_M_02', text: "ابدأ يومك في الوقت، وحافظ على تركيزك داخل الفصل.", category: GuidanceCategory.mergedLateDiscipline, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'MLD_M_03', text: "بداية منتظمة تساعدك تواكب الشرح وتحافظ على الانضباط.", category: GuidanceCategory.mergedLateDiscipline, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'MLD_M_04', text: "حضورك المبكر يقلل التوتر ويزيد جودة تركيزك.", category: GuidanceCategory.mergedLateDiscipline, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'MLD_M_05', text: "الالتزام بالوقت والسلوك الإيجابي يرفعان مستواك.", category: GuidanceCategory.mergedLateDiscipline, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'MLD_M_06', text: "انتظام البداية يدعم الالتزام داخل الحصة.", category: GuidanceCategory.mergedLateDiscipline, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'MLD_M_07', text: "ابدأ بقوة، وركز في الحصة لتحصل على أفضل نتيجة.", category: GuidanceCategory.mergedLateDiscipline, severity: GuidanceSeverity.medium),
    GuidanceMessage(id: 'MLD_M_08', text: "الوقت والتركيز… مفتاحان للتقدم.", category: GuidanceCategory.mergedLateDiscipline, severity: GuidanceSeverity.medium),
    // Strong
    GuidanceMessage(id: 'MLD_T_01', text: "حافظ على الحضور في الوقت وثبّت تركيزك داخل الحصة؛ هذا يحمي تقدمك.", category: GuidanceCategory.mergedLateDiscipline, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'MLD_T_02', text: "عالج التأخر مبكرًا وقلّل المشتتات داخل الفصل.", category: GuidanceCategory.mergedLateDiscipline, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'MLD_T_03', text: "انتظام الحضور والسلوك المنضبط ضرورة لثبات التحصيل.", category: GuidanceCategory.mergedLateDiscipline, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'MLD_T_04', text: "ابدأ يومك ثابتًا، واجعل الحصة وقت تعلم حقيقي.", category: GuidanceCategory.mergedLateDiscipline, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'MLD_T_05', text: "البداية المنتظمة مع التزام قوي داخل الفصل تصنع فرقًا واضحًا.", category: GuidanceCategory.mergedLateDiscipline, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'MLD_T_06', text: "ثبت حضورك وهدوءك داخل الحصة لتستعيد الاستفادة الكاملة.", category: GuidanceCategory.mergedLateDiscipline, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'MLD_T_07', text: "حضور منتظم + تركيز ثابت = نتائج أقوى.", category: GuidanceCategory.mergedLateDiscipline, severity: GuidanceSeverity.strong),
    GuidanceMessage(id: 'MLD_T_08', text: "اجعل وقت الحصة وقت تعلم… وابدأه في الوقت.", category: GuidanceCategory.mergedLateDiscipline, severity: GuidanceSeverity.strong),
  ];

  // POSITIVE MESSAGES
  static const List<GuidanceMessage> positiveMessages = [
    GuidanceMessage(id: 'POS_01', text: "التزامك ينعكس إيجابًا على تحصيلك الدراسي. استمر على هذا النهج.", category: GuidanceCategory.positive, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'POS_02', text: "أحسنت! ثباتك في الالتزام يمنحك قوة في التعلم.", category: GuidanceCategory.positive, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'POS_03', text: "استمرارك على هذا المستوى يدل على نضجك الدراسي.", category: GuidanceCategory.positive, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'POS_04', text: "سلوكك الإيجابي يساعدك ويحفّز من حولك.", category: GuidanceCategory.positive, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'POS_05', text: "جميل جدًا… التزامك يصنع فرقًا في يومك الدراسي.", category: GuidanceCategory.positive, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'POS_06', text: "ثبات الالتزام خطوة كبيرة نحو التفوق.", category: GuidanceCategory.positive, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'POS_07', text: "مستواك في الالتزام ممتاز—واصل التقدم.", category: GuidanceCategory.positive, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'POS_08', text: "التزامك اليومي يفتح لك أبواب التميز.", category: GuidanceCategory.positive, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'POS_09', text: "أداءك مستقر ومميز—حافظ عليه.", category: GuidanceCategory.positive, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'POS_10', text: "أنت على الطريق الصحيح—استمر.", category: GuidanceCategory.positive, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'POS_11', text: "التزامك قوة… وتقدمك دليل.", category: GuidanceCategory.positive, severity: GuidanceSeverity.soft),
    GuidanceMessage(id: 'POS_12', text: "ممتاز… استمر على هذا السلوك الإيجابي.", category: GuidanceCategory.positive, severity: GuidanceSeverity.soft),
  ];
}
