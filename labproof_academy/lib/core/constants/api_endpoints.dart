class ApiEndpoints {
  const ApiEndpoints._();

  static const baseUrl = 'https://api.labproof.academy/v1';
  static const authBaseUrl = String.fromEnvironment(
    'LABPROOF_API_BASE_URL',
    defaultValue: 'https://kdwghotfxttlawfttphl.supabase.co/functions/v1',
  );

  static const login = '/login';
  static const register = '/register';
  static const phoneStatus = '/auth/phone/status';
  static const requestTelegramCode = '/auth/telegram/request-code';
  static const requestTelegramResetCode = '/auth/telegram/request-reset-code';
  static const verifyTelegramCode = '/auth/telegram/verify-code';
  static const sendAdminReply = '/auth/telegram/send-admin-reply';
  static const markAdminInboxRead = '/auth/telegram/mark-inbox-read';
  static const markNotificationRead = '/auth/notifications/mark-read';
  static const updateProfile = '/auth/profile/update';
  static const modules = '/modules';
  static const progress = '/progress';
  static const progressUpdate = '/progress/update';

  static String module(String id) => '/module/$id';
  static String lesson(String id) => '/lesson/$id';
  static String video(String id) => '/video/$id';
  static String quiz(String id) => '/quiz/$id';
  static String submitQuiz(String id) => '/quiz/$id/submit';
  static String finalExam(String moduleId) => '/module/$moduleId/final-exam';
  static String submitFinalExam(String moduleId) {
    return '/module/$moduleId/final-exam/submit';
  }
}
