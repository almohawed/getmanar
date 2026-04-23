// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SystemSettingsImpl _$$SystemSettingsImplFromJson(Map<String, dynamic> json) =>
    _$SystemSettingsImpl(
      currentTerm: json['currentTerm'] as String? ?? 'الفصل الدراسي الثاني',
      currentWeek: json['currentWeek'] as String? ?? 'الأسبوع 1',
      academicYear: json['academicYear'] as String? ?? '1446',
      isActive: json['isActive'] as bool? ?? true,
    );

Map<String, dynamic> _$$SystemSettingsImplToJson(
  _$SystemSettingsImpl instance,
) => <String, dynamic>{
  'currentTerm': instance.currentTerm,
  'currentWeek': instance.currentWeek,
  'academicYear': instance.academicYear,
  'isActive': instance.isActive,
};
