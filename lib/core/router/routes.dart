/// Uygulamadaki tüm rota yolları.
abstract final class Routes {
  static const launch = '/launch';
  static const welcome = '/welcome';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const forgot = '/forgot';
  static const resetPassword = '/reset-password';

  static const pairing = '/pairing';
  static const pairingInvite = '/pairing/invite';
  static const pairingEnter = '/pairing/enter';
  static const pairingScan = '/pairing/scan';
  static const pairingRequest = '/pairing/request'; // /:id
  static const paired = '/paired';

  // Sekmeler
  static const home = '/home';
  static const chat = '/chat';
  static const memories = '/memories';
  static const plans = '/plans';
  static const profile = '/profile';

  // Detaylar
  static const notifications = '/notifications';
  static const memoryNew = '/memory/new';
  static String memory(String id) => '/memory/$id';
  static String memoryEdit(String id) => '/memory/$id/edit';
  static const story = '/story';
  static const capsules = '/capsules';
  static const capsuleNew = '/capsule/new';
  static String capsule(String id) => '/capsule/$id';
  static const questions = '/questions';
  static String question(String id) => '/question/$id';
  static const eventNew = '/event/new';
  static String event(String id) => '/event/$id';
  static const settings = '/settings';
  static const settingsPrivacy = '/settings/privacy';
  static const settingsNotifications = '/settings/notifications';
  static const settingsLock = '/settings/lock';
  static const settingsPartner = '/settings/partner';
  static const settingsAccount = '/settings/account';
  static const settingsTheme = '/settings/theme';
  static const profileEdit = '/profile/edit';
  static const relationship = '/profile/relationship';
  static const mediaViewer = '/media';

  static const publicRoutes = {welcome, onboarding, login, register, forgot};
}
