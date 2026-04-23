import 'dart:math';

import '../domain/models/user.dart';

class EmailGenerator {
  static final _random = Random();

  static String generateEmail(
    UserRole role, {
    String? identityNumber,
    String? phoneNumber,
  }) {
    // User requested prefixes for email:
    // Parent: p
    // Student: st
    // Teacher: tc
    // Deputy (Wakil): wk
    // Counselor (Murshid): cn
    // Administrative (Idari): ad
    // Admin/Manager (Mudeer): mg

    String prefix;
    String idSuffix = '';

    if (identityNumber != null && identityNumber.isNotEmpty) {
      idSuffix = identityNumber;
    } else {
      // Generate a compliant System ID if none provided
      idSuffix = _generateSystemId(role);
    }

    switch (role) {
      case UserRole.parent:
        if (phoneNumber != null && phoneNumber.isNotEmpty) {
          final cleanPhone = phoneNumber.replaceAll(' ', '');
          return 'p$cleanPhone@getmanar.com';
        }
        return 'p$idSuffix@getmanar.com';

      case UserRole.student:
        prefix = 'st';
        break;
      case UserRole.teacher:
        prefix = 'tc';
        break;
      case UserRole.deputy:
        prefix = 'wk';
        break;
      case UserRole.counselor:
        prefix = 'cn';
        break;
      case UserRole.administrative:
        prefix = 'ad';
        break;
      case UserRole.technicalSupport:
      case UserRole.supportAdmin:
        prefix = 'ts';
        break;
      case UserRole.admin: // Usually School Manager
      case UserRole.superAdmin:
        prefix = 'mg';
        break;
    }

    return '$prefix$idSuffix@getmanar.com';
  }

  static String _generateSystemId(UserRole role) {
    final digits = _generateRandomDigits(6);
    switch (role) {
      case UserRole.student:
        return 'ST$digits';
      case UserRole.teacher:
        return 'TC$digits';
      case UserRole.deputy:
        return 'WK$digits';
      case UserRole.counselor:
        return 'CN$digits';
      case UserRole.administrative:
        return 'AD$digits';
      case UserRole.technicalSupport:
      case UserRole.supportAdmin:
        return 'TS$digits';
      case UserRole.admin:
      case UserRole.superAdmin:
        return 'MG$digits';
      case UserRole.parent:
        return 'PR$digits';
      default:
        return 'ID$digits';
    }
  }

  static String _generateRandomDigits(int length) {
    String result = '';
    for (var i = 0; i < length; i++) {
      result += _random.nextInt(10).toString();
    }
    return result;
  }
}
