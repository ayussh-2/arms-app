import 'dart:async';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'debug_service.dart';

/// Custom HTTP Link with built-in logging for network requests and responses
class LoggingHttpLink extends HttpLink {
  final DebugService debugService;

  LoggingHttpLink(
    super.uri, {
    required this.debugService,
  });

  @override
  Stream<Response> request(
    Request request, [
    NextLink? forward,
  ]) {
    final startTime = DateTime.now();
    final operationName = request.operation.operationName ?? 'Unknown';
    final urlString = uri.toString();

    // Log the request
    debugService.logNetworkRequest(
      method: operationName,
      url: urlString,
      timestamp: startTime,
      variables: request.variables,
    );

    // Delegate to the base HttpLink for the actual network call
    final responseStream = super.request(request, forward);

    return responseStream.transform(
      StreamTransformer<Response, Response>.fromHandlers(
        handleData: (response, sink) {
          final duration = DateTime.now().difference(startTime);

          // Check if there are errors in the response
          if (response.errors != null && response.errors!.isNotEmpty) {
            for (var error in response.errors!) {
              debugService.logError(
                error: error.toString(),
                timestamp: DateTime.now(),
                url: urlString,
              );
            }
          } else {
            // Log successful response
            debugService.logNetworkResponse(
              method: operationName,
              url: urlString,
              timestamp: DateTime.now(),
              duration: duration,
              statusCode: 200,
              responseData: response.data,
            );
          }

          sink.add(response);
        },
        handleError: (error, stackTrace, sink) {
          debugService.logError(
            error: error.toString(),
            timestamp: DateTime.now(),
            url: urlString,
            stackTrace: stackTrace,
          );
          sink.addError(error, stackTrace);
        },
      ),
    );
  }
}


