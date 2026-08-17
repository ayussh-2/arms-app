import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../services/app_logger.dart';
import '../../widgets/arms_snackbar.dart';

/// Centralized utility for handling application errors.
/// Converts technical exceptions & raw stack traces into user-friendly error messages
/// while writing detailed technical logs into the app log file.
class AppErrorHandler {
  AppErrorHandler._();

  /// Converts raw technical errors into a clean, user-friendly message
  /// while logging technical details with timestamp to app_errors.log.
  static String parseAndLogError(
    dynamic error, {
    StackTrace? stackTrace,
    String? contextMessage,
  }) {
    // Log raw error to log file
    AppLogger.logError(
      error,
      stackTrace: stackTrace,
      context: contextMessage,
    );

    final String errorStr = error.toString().toLowerCase();

    // 1. Network Connection Failures
    if (error is SocketException ||
        errorStr.contains('socketexception') ||
        errorStr.contains('failed host lookup') ||
        errorStr.contains('connection refused') ||
        errorStr.contains('network is unreachable')) {
      return 'Network connection failed. Please check your internet connection and try again.';
    }

    // 2. Timeout Failures
    if (error is TimeoutException || errorStr.contains('timeout')) {
      return 'The request timed out. Please try again later.';
    }

    // 3. GraphQL / Server Exceptions
    if (error is OperationException) {
      if (error.linkException != null) {
        final netError = error.linkException.toString().toLowerCase();
        if (netError.contains('socketexception') || netError.contains('host lookup')) {
          return 'Network error. Please check your internet connection.';
        }
        return 'Server connection failed. Please try again later.';
      }
      if (error.graphqlErrors.isNotEmpty) {
        final firstMsg = error.graphqlErrors.first.message;
        if (firstMsg.isNotEmpty &&
            !firstMsg.contains('Exception') &&
            !firstMsg.contains('Error:') &&
            !firstMsg.contains('{') &&
            firstMsg.length < 120) {
          return firstMsg;
        }
      }
    }

    // 4. Auth & Session Failures
    if (errorStr.contains('unauthorized') || errorStr.contains('forbidden')) {
      return 'Session expired or unauthorized. Please log in again.';
    }

    // 5. Default Generic Message
    return 'Something went wrong. Please try again later.';
  }

  /// Displays a user-friendly error snackbar and logs the technical error.
  static void showErrorSnackbar(
    BuildContext context,
    dynamic error, {
    StackTrace? stackTrace,
    String? contextMessage,
  }) {
    final friendlyMessage = parseAndLogError(
      error,
      stackTrace: stackTrace,
      contextMessage: contextMessage,
    );
    if (context.mounted) {
      ArmsSnackbar.showError(context, friendlyMessage);
    }
  }
}
