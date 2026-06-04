import 'package:flutter/foundation.dart';

/// Custom logger function that prefixes logs with [ARMS_LOGS]
/// to make filtering in the flooded Android/system terminal easy.
void armsLog(Object? message) {
  debugPrint('[ARMS_LOGS] $message');
}
