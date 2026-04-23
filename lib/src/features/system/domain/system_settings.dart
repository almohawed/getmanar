
import 'package:freezed_annotation/freezed_annotation.dart';

part 'system_settings.freezed.dart';
part 'system_settings.g.dart';

@freezed
class SystemSettings with _$SystemSettings {
  const factory SystemSettings({
    @Default('الفصل الدراسي الثاني') String currentTerm,
    @Default('الأسبوع 1') String currentWeek,
    @Default('1446') String academicYear,
    @Default(true) bool isActive,
  }) = _SystemSettings;

  factory SystemSettings.fromJson(Map<String, dynamic> json) =>
      _$SystemSettingsFromJson(json);
}
