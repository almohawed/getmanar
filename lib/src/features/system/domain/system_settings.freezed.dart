// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'system_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

SystemSettings _$SystemSettingsFromJson(Map<String, dynamic> json) {
  return _SystemSettings.fromJson(json);
}

/// @nodoc
mixin _$SystemSettings {
  String get currentTerm => throw _privateConstructorUsedError;
  String get currentWeek => throw _privateConstructorUsedError;
  String get academicYear => throw _privateConstructorUsedError;
  bool get isActive => throw _privateConstructorUsedError;

  /// Serializes this SystemSettings to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SystemSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SystemSettingsCopyWith<SystemSettings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SystemSettingsCopyWith<$Res> {
  factory $SystemSettingsCopyWith(
    SystemSettings value,
    $Res Function(SystemSettings) then,
  ) = _$SystemSettingsCopyWithImpl<$Res, SystemSettings>;
  @useResult
  $Res call({
    String currentTerm,
    String currentWeek,
    String academicYear,
    bool isActive,
  });
}

/// @nodoc
class _$SystemSettingsCopyWithImpl<$Res, $Val extends SystemSettings>
    implements $SystemSettingsCopyWith<$Res> {
  _$SystemSettingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SystemSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? currentTerm = null,
    Object? currentWeek = null,
    Object? academicYear = null,
    Object? isActive = null,
  }) {
    return _then(
      _value.copyWith(
            currentTerm: null == currentTerm
                ? _value.currentTerm
                : currentTerm // ignore: cast_nullable_to_non_nullable
                      as String,
            currentWeek: null == currentWeek
                ? _value.currentWeek
                : currentWeek // ignore: cast_nullable_to_non_nullable
                      as String,
            academicYear: null == academicYear
                ? _value.academicYear
                : academicYear // ignore: cast_nullable_to_non_nullable
                      as String,
            isActive: null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SystemSettingsImplCopyWith<$Res>
    implements $SystemSettingsCopyWith<$Res> {
  factory _$$SystemSettingsImplCopyWith(
    _$SystemSettingsImpl value,
    $Res Function(_$SystemSettingsImpl) then,
  ) = __$$SystemSettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String currentTerm,
    String currentWeek,
    String academicYear,
    bool isActive,
  });
}

/// @nodoc
class __$$SystemSettingsImplCopyWithImpl<$Res>
    extends _$SystemSettingsCopyWithImpl<$Res, _$SystemSettingsImpl>
    implements _$$SystemSettingsImplCopyWith<$Res> {
  __$$SystemSettingsImplCopyWithImpl(
    _$SystemSettingsImpl _value,
    $Res Function(_$SystemSettingsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SystemSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? currentTerm = null,
    Object? currentWeek = null,
    Object? academicYear = null,
    Object? isActive = null,
  }) {
    return _then(
      _$SystemSettingsImpl(
        currentTerm: null == currentTerm
            ? _value.currentTerm
            : currentTerm // ignore: cast_nullable_to_non_nullable
                  as String,
        currentWeek: null == currentWeek
            ? _value.currentWeek
            : currentWeek // ignore: cast_nullable_to_non_nullable
                  as String,
        academicYear: null == academicYear
            ? _value.academicYear
            : academicYear // ignore: cast_nullable_to_non_nullable
                  as String,
        isActive: null == isActive
            ? _value.isActive
            : isActive // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SystemSettingsImpl implements _SystemSettings {
  const _$SystemSettingsImpl({
    this.currentTerm = 'الفصل الدراسي الثاني',
    this.currentWeek = 'الأسبوع 1',
    this.academicYear = '1446',
    this.isActive = true,
  });

  factory _$SystemSettingsImpl.fromJson(Map<String, dynamic> json) =>
      _$$SystemSettingsImplFromJson(json);

  @override
  @JsonKey()
  final String currentTerm;
  @override
  @JsonKey()
  final String currentWeek;
  @override
  @JsonKey()
  final String academicYear;
  @override
  @JsonKey()
  final bool isActive;

  @override
  String toString() {
    return 'SystemSettings(currentTerm: $currentTerm, currentWeek: $currentWeek, academicYear: $academicYear, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SystemSettingsImpl &&
            (identical(other.currentTerm, currentTerm) ||
                other.currentTerm == currentTerm) &&
            (identical(other.currentWeek, currentWeek) ||
                other.currentWeek == currentWeek) &&
            (identical(other.academicYear, academicYear) ||
                other.academicYear == academicYear) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    currentTerm,
    currentWeek,
    academicYear,
    isActive,
  );

  /// Create a copy of SystemSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SystemSettingsImplCopyWith<_$SystemSettingsImpl> get copyWith =>
      __$$SystemSettingsImplCopyWithImpl<_$SystemSettingsImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$SystemSettingsImplToJson(this);
  }
}

abstract class _SystemSettings implements SystemSettings {
  const factory _SystemSettings({
    final String currentTerm,
    final String currentWeek,
    final String academicYear,
    final bool isActive,
  }) = _$SystemSettingsImpl;

  factory _SystemSettings.fromJson(Map<String, dynamic> json) =
      _$SystemSettingsImpl.fromJson;

  @override
  String get currentTerm;
  @override
  String get currentWeek;
  @override
  String get academicYear;
  @override
  bool get isActive;

  /// Create a copy of SystemSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SystemSettingsImplCopyWith<_$SystemSettingsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
