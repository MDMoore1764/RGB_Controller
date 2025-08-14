// Function throttleTrailing(Function func, Duration delay) {
//   DateTime? lastCall;
//   bool timeoutScheduled = false;
//   dynamic lastArgs;

//   void invoke() {
//     lastCall = DateTime.now();
//     timeoutScheduled = false;
//     func(lastArgs);
//     lastArgs = null;
//   }

//   return ([dynamic args]) {
//     lastArgs = args;
//     final now = DateTime.now();

//     if (lastCall == null || now.difference(lastCall!) >= delay) {
//       // Leading edge
//       invoke();
//     } else if (!timeoutScheduled) {
//       // Schedule trailing call
//       timeoutScheduled = true;
//       final remaining = delay - now.difference(lastCall!);
//       Future.delayed(remaining, invoke);
//     }
//   };
// }

import 'dart:async';

void Function(TArgs args) throttle<TArgs>(
  void Function(TArgs args) func,
  Duration delay,
) {
  ThrottleArgs throttleArgs = ThrottleArgs();
  throttleArgs.remainingTime = delay;

  void returnFunction(TArgs args) {
    if (throttleArgs.lastCalled != null) {
      var timePassedSinceLastCalled = DateTime.now().difference(
        throttleArgs.lastCalled!,
      );

      if (timePassedSinceLastCalled <= Duration.zero) {
        throttleArgs.remainingTime = Duration.zero;
      } else {
        throttleArgs.remainingTime = delay - timePassedSinceLastCalled;
      }
    } else {
      throttleArgs.lastCalled = DateTime.now();
      func(args);
      return;
    }

    throttleArgs.timer?.cancel();
    throttleArgs.timer = Timer(throttleArgs.remainingTime!, () {
      throttleArgs.lastCalled = DateTime.now();
      func(args);
    });
  }

  return returnFunction;
}

class ThrottleArgs {
  Timer? timer;
  DateTime? lastCalled;
  Duration? remainingTime;
}
