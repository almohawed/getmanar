import * as admin from "firebase-admin";

admin.initializeApp();

export {
  verifyGooglePlaySubscription,
  dailySubscriptionValidation,
} from "./subscription_google_play";
export { createPaymentRequest } from "./subscription_requests";
export {
  createSubscriptionCheckout,
  confirmSubscriptionPayment,
} from "./subscription";
export {
  computeSchoolIntelligenceNow,
  recomputeSchoolIntelligenceDaily,
} from "./intelligence";
export {
  mirrorBehaviorIncident,
  computeWeeklyBehaviorProfiles,
  logBehaviorEnhancementAction,
  recomputePendingActionEffectiveness,
} from "./behavior_enhancement";
export {
  onBathroomPassWritten,
  onAttendanceWritten,
  checkBehaviorEscalation,
  checkScheduleRunsExpiry,
  sendSchoolNotification,
} from "./student_affairs";
export {
  registerNewSchool,
  getUserEmailByIdentity,
  createSchoolAdminProvision,
  deleteSchoolDeep,
} from "./auth";
export { manageUserCode } from "./user_codes";
export { lookupUserCode, lookupCodeByInfo } from "./user_code_lookup";
export { migrateExistingUsersToCodes } from "./migration";
