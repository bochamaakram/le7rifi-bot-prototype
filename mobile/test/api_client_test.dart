import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le7rayfi_ai/core/api/api_client.dart';
import 'package:le7rayfi_ai/core/auth/session.dart';

class TestSession extends SessionStore {
  @override
  Future<String?> read() async => 'test-token';
}

class CaptureAdapter implements HttpClientAdapter {
  RequestOptions? captured;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captured = options;
    return ResponseBody.fromString(
      '{"user_id":"artisan"}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('client sends securely loaded bearer token to versioned API', () async {
    final adapter = CaptureAdapter();
    final transport = Dio(BaseOptions(baseUrl: 'https://test.invalid'))
      ..httpClientAdapter = adapter;
    final client = ApiClient(TestSession(), transport: transport);
    final response = await client.get('/me');
    expect(response['user_id'], 'artisan');
    expect(adapter.captured!.path, '/api/v1/me');
    expect(adapter.captured!.headers['Authorization'], 'Bearer test-token');
  });
  test('quota and offline errors are actionable', () {
    expect(
      friendlyError(
        DioException(
          requestOptions: RequestOptions(),
          response: Response(requestOptions: RequestOptions(), statusCode: 429),
        ),
      ),
      contains('للحد'),
    );
    expect(
      friendlyError(DioException(requestOptions: RequestOptions())),
      contains('الإنترنت'),
    );
  });
}
