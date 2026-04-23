import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../router.dart'; // Direct access to router

final sessionTimeoutPausedNotifier = ValueNotifier<bool>(false);

class SessionTimeoutManager extends ConsumerStatefulWidget {
  final Widget child;
  final Duration duration;

  const SessionTimeoutManager({
    super.key,
    required this.child,
    this.duration = const Duration(minutes: 10),
  });

  @override
  ConsumerState<SessionTimeoutManager> createState() =>
      _SessionTimeoutManagerState();
}

class _SessionTimeoutManagerState extends ConsumerState<SessionTimeoutManager> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    sessionTimeoutPausedNotifier.addListener(_handlePauseChanged);
    _resetTimer();
  }

  void _handlePauseChanged() {
    if (sessionTimeoutPausedNotifier.value == true) {
      _timer?.cancel();
      return;
    }
    _resetTimer();
  }

  void _resetTimer() {
    _timer?.cancel();

    // Only set timer if user is authenticated
    final authState = ref.read(authStateProvider);
    if (authState.value != null &&
        sessionTimeoutPausedNotifier.value == false) {
      _timer = Timer(widget.duration, _handleTimeout);
    }
  }

  void _handleTimeout() {
    final authState = ref.read(authStateProvider);
    if (authState.value != null) {
      ref.read(authStateProvider.notifier).logout();
      router.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auth state changes to start/stop timer
    ref.listen(authStateProvider, (previous, next) {
      if (next.value != null) {
        _resetTimer();
      } else {
        _timer?.cancel();
      }
    });

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetTimer(),
      onPointerMove: (_) => _resetTimer(),
      onPointerUp: (_) => _resetTimer(),
      onPointerHover: (_) => _resetTimer(),
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    sessionTimeoutPausedNotifier.removeListener(_handlePauseChanged);
    super.dispose();
  }
}
