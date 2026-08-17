import 'dart:async';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../services/app_logger.dart';

/// Custom GraphQL Link that automatically retries network & server failure requests
/// up to [maxRetries] times with linear/exponential delay.
class RetryLink extends Link {
  final int maxRetries;
  final Duration delay;

  RetryLink({
    this.maxRetries = 3,
    this.delay = const Duration(seconds: 1),
  });

  @override
  Stream<Response> request(Request request, [NextLink? forward]) {
    if (forward == null) {
      throw Exception('RetryLink must be followed by another Link in the GraphQL link chain.');
    }

    final controller = StreamController<Response>();
    int attempt = 0;
    StreamSubscription<Response>? subscription;

    void executeAttempt() {
      attempt++;
      subscription?.cancel();

      subscription = forward(request).listen(
        (response) {
          // If response has GraphQL server errors, check if network related and retry
          if (response.errors != null && response.errors!.isNotEmpty && attempt < maxRetries) {
            final hasNetworkError = response.errors!.any((e) {
              final msg = e.message.toLowerCase();
              return msg.contains('network') ||
                  msg.contains('connect') ||
                  msg.contains('socketexception') ||
                  msg.contains('timeout') ||
                  msg.contains('failed to fetch');
            });

            if (hasNetworkError) {
              AppLogger.logError(
                'GraphQL transient error on ${request.operation.operationName} (Attempt $attempt/$maxRetries). Retrying...',
                context: 'RetryLink',
              );
              Future.delayed(delay * attempt, executeAttempt);
              return;
            }
          }

          controller.add(response);
          controller.close();
        },
        onError: (error, stackTrace) {
          if (attempt < maxRetries) {
            AppLogger.logError(
              'Network Exception on ${request.operation.operationName} (Attempt $attempt/$maxRetries): $error',
              context: 'RetryLink Automatic Retry',
            );
            Future.delayed(delay * attempt, executeAttempt);
          } else {
            AppLogger.logError(
              'All $maxRetries retry attempts failed for ${request.operation.operationName}: $error',
              stackTrace: stackTrace,
              context: 'RetryLink Final Failure',
            );
            controller.addError(error, stackTrace);
            controller.close();
          }
        },
        onDone: () {
          // Stream complete
        },
      );
    }

    executeAttempt();

    controller.onCancel = () {
      subscription?.cancel();
    };

    return controller.stream;
  }
}
