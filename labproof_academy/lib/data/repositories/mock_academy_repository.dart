import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../models/academy_models.dart';

class MockAcademyRepository {
  const MockAcademyRepository._();

  static final modules = <AcademyModule>[
    AcademyModule(
      id: 'm1',
      title: 'Elektr toki va zanjirlar',
      description:
          'Tok kuchi, qarshilik, Om qonuni va asosiy laboratoriya sxemalari.',
      order: 1,
      progress: .78,
      isUnlocked: true,
      isPassed: false,
      studentCount: 1245,
      completionRate: .75,
      topics: const [
        TopicLesson(
          id: 't1',
          moduleId: 'm1',
          title: 'Elektr zaryad va tok',
          summary: 'Elektr zaryad, tok yo‘nalishi va o‘lchov birliklari.',
          pdfTitle: 'elektr_zaryad_va_tok.pdf',
          videoTitle: 'Elektr toki asoslari',
          duration: Duration(minutes: 8, seconds: 40),
          status: TopicStatus.completed,
          quizScore: 1,
          formula: 'I = Q / t',
        ),
        TopicLesson(
          id: 't2',
          moduleId: 'm1',
          title: 'Om qonuni',
          summary: 'Kuchlanish, tok kuchi va qarshilik orasidagi bog‘liqlik.',
          pdfTitle: 'om_qonuni.pdf',
          videoTitle: 'Om qonunini tushuntirish',
          duration: Duration(minutes: 8, seconds: 45),
          status: TopicStatus.current,
          quizScore: .8,
          formula: 'I = U / R',
        ),
        TopicLesson(
          id: 't3',
          moduleId: 'm1',
          title: 'Ketma-ket va parallel ulanish',
          summary: 'Zanjirlarni yig‘ish va umumiy qarshilikni hisoblash.',
          pdfTitle: 'zanjir_ulanishlari.pdf',
          videoTitle: 'Zanjir ulanishlari laboratoriyasi',
          duration: Duration(minutes: 11, seconds: 25),
          status: TopicStatus.locked,
          quizScore: 0,
          formula: 'R = R1 + R2',
        ),
        TopicLesson(
          id: 't4',
          moduleId: 'm1',
          title: 'Kirxgof qonunlari',
          summary: 'Kontur va tugunlar bo‘yicha laboratoriya tahlili.',
          pdfTitle: 'kirxgof_qonunlari.pdf',
          videoTitle: 'Kirxgof qonunlari amaliyoti',
          duration: Duration(minutes: 13, seconds: 10),
          status: TopicStatus.locked,
          quizScore: 0,
          formula: 'ΣI = 0',
        ),
        TopicLesson(
          id: 't5',
          moduleId: 'm1',
          title: 'Quvvat va energiya',
          summary: 'Elektr quvvati, ish va energiyani hisoblash.',
          pdfTitle: 'quvvat_va_energiya.pdf',
          videoTitle: 'Elektr quvvati tajribasi',
          duration: Duration(minutes: 9, seconds: 30),
          status: TopicStatus.locked,
          quizScore: 0,
          formula: 'P = U × I',
        ),
      ],
    ),
    const AcademyModule(
      id: 'm2',
      title: 'Magnit maydon',
      description:
          'Magnit induksiya, kuch chiziqlari va elektromagnit tajribalar.',
      order: 2,
      progress: 0,
      isUnlocked: false,
      isPassed: false,
      studentCount: 982,
      completionRate: .68,
      topics: [],
    ),
    const AcademyModule(
      id: 'm3',
      title: 'Optik hodisalar',
      description: 'Yorug‘lik sinishi, qaytishi va laboratoriya optikasi.',
      order: 3,
      progress: 0,
      isUnlocked: false,
      isPassed: false,
      studentCount: 761,
      completionRate: .6,
      topics: [],
    ),
    const AcademyModule(
      id: 'm4',
      title: 'Mexanika asoslari',
      description: 'Kuch, tezlanish, impuls va o‘lchash tajribalari.',
      order: 4,
      progress: 0,
      isUnlocked: false,
      isPassed: false,
      studentCount: 645,
      completionRate: .55,
      topics: [],
    ),
    const AcademyModule(
      id: 'm5',
      title: 'Termodinamika',
      description:
          'Issiqlik jarayonlari, energiya almashinuvi va gaz qonunlari.',
      order: 5,
      progress: 0,
      isUnlocked: false,
      isPassed: false,
      studentCount: 532,
      completionRate: .4,
      topics: [],
    ),
  ];

  static const quizQuestions = <QuizQuestion>[
    QuizQuestion(
      topic: 'Om qonuni',
      question: 'Om qonuniga ko‘ra, tok kuchi qanday formula bilan topiladi?',
      options: ['I = U × R', 'I = U / R', 'I = R / U', 'I = U + R'],
      correctIndex: 1,
    ),
    QuizQuestion(
      topic: 'Elektr zaryad va tok',
      question:
          'Tok kuchi 2 A va qarshilik 6 Ohm bo‘lsa, kuchlanish nechaga teng?',
      options: ['3 V', '8 V', '12 V', '18 V'],
      correctIndex: 2,
      assetLabel: 'U = I × R',
    ),
    QuizQuestion(
      topic: 'Ketma-ket ulanish',
      question:
          'Ketma-ket ulangan R1=4 Ohm va R2=6 Ohm qarshiliklar umumiy qiymati?',
      options: ['2 Ohm', '10 Ohm', '24 Ohm', '1.6 Ohm'],
      correctIndex: 1,
      assetLabel: 'R = R1 + R2',
    ),
  ];

  static const studentRecords = <StudentRecord>[
    StudentRecord(
      name: 'Azizbek Tursunov',
      email: 'azizbek@example.com',
      module: 'Elektr toki va zanjirlar',
      score: 90,
      status: 'Yaxshi',
      progress: .82,
    ),
    StudentRecord(
      name: 'Sardor Karimov',
      email: 'sardor@example.com',
      module: 'Elektr toki va zanjirlar',
      score: 80,
      status: 'Yaxshi',
      progress: .74,
    ),
    StudentRecord(
      name: 'Malika Rustamova',
      email: 'malika@example.com',
      module: 'Optik hodisalar',
      score: 75,
      status: 'Yaxshi',
      progress: .68,
    ),
    StudentRecord(
      name: 'Jasur Mamanazarov',
      email: 'jasur@example.com',
      module: 'Magnit maydon',
      score: 60,
      status: 'O‘rtacha',
      progress: .5,
    ),
    StudentRecord(
      name: 'Diyorbek Holikov',
      email: 'diyorbek@example.com',
      module: 'Mexanika asoslari',
      score: 40,
      status: 'Qoniqarsiz',
      progress: .35,
    ),
  ];

  static const activities = <ActivityItem>[
    ActivityItem(
      title: 'Om qonuni testi topshirildi',
      subtitle: 'Azizbek Tursunov 90% natija oldi',
      icon: Icons.quiz_rounded,
      color: AppColors.primaryBlue,
    ),
    ActivityItem(
      title: 'Yangi modul qo‘shildi',
      subtitle: 'Termodinamika o‘qituvchi tomonidan tayyorlandi',
      icon: Icons.library_books_rounded,
      color: AppColors.successGreen,
    ),
    ActivityItem(
      title: 'Final imtihon qayta topshirildi',
      subtitle: 'Magnit maydon moduli uchun retake ochildi',
      icon: Icons.restart_alt_rounded,
      color: AppColors.amber,
    ),
    ActivityItem(
      title: 'Sertifikat yaratildi',
      subtitle: 'Elektr toki va zanjirlar moduli yakunlandi',
      icon: Icons.workspace_premium_rounded,
      color: AppColors.violet,
    ),
  ];

  static const adminMetrics = <AdminMetric>[
    AdminMetric(
      title: 'Jami talabalar',
      value: '2,458',
      delta: '+12.5%',
      icon: Icons.people_alt_rounded,
      color: AppColors.primaryBlue,
    ),
    AdminMetric(
      title: 'Faol foydalanuvchilar',
      value: '1,897',
      delta: '+8.3%',
      icon: Icons.person_pin_rounded,
      color: AppColors.successGreen,
    ),
    AdminMetric(
      title: 'Modullar soni',
      value: '24',
      delta: '+4',
      icon: Icons.view_module_rounded,
      color: AppColors.violet,
    ),
    AdminMetric(
      title: 'Mavzular soni',
      value: '156',
      delta: '+18',
      icon: Icons.topic_rounded,
      color: AppColors.amber,
    ),
    AdminMetric(
      title: 'Testlar soni',
      value: '342',
      delta: '+27',
      icon: Icons.fact_check_rounded,
      color: AppColors.errorRed,
    ),
  ];

  static const growthChart = <double>[
    900,
    760,
    1120,
    880,
    1320,
    1020,
    1260,
    1710,
  ];
  static const completionChart = <double>[42, 48, 58, 61, 65, 71, 77, 82];
}
