import 'package:dio/dio.dart';

import '../auth/session.dart';
import '../config/environment.dart';

class ApiClient {
  final Dio dio;
  ApiClient(SessionStore session, {Dio? transport})
    : dio =
          transport ??
          Dio(
            BaseOptions(
              baseUrl: Environment.apiUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 150),
              sendTimeout: const Duration(seconds: 30),
            ),
          ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await session.read();
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
      ),
    );
  }
  Future<dynamic> get(String path) async =>
      (await dio.get('/api/v1$path')).data;
  Future<dynamic> post(
    String path, [
    dynamic data,
    CancelToken? cancel,
  ]) async =>
      (await dio.post('/api/v1$path', data: data, cancelToken: cancel)).data;
  Future<void> delete(String path) async => dio.delete('/api/v1$path');
  Future<dynamic> put(String path, dynamic data) async =>
      (await dio.put('/api/v1$path', data: data)).data;
}

String friendlyError(Object error) {
  if (error is DioException) {
    if (CancelToken.isCancel(error)) return 'تلغى الطلب';
    switch (error.response?.statusCode) {
      case 401:
        return 'خاصك تدخل من جديد';
      case 413:
        return 'الملف كبير بزاف';
      case 422:
        return 'ما قدرناش نقراو التسجيل. عاود بصوت واضح';
      case 429:
        return 'وصلتي للحد ديال الاستعمال. جرب من بعد';
      case 503:
        return 'خدمة الذكاء الاصطناعي ما متوفراش دابا';
    }
    if (error.response == null) return 'تأكد من الإنترنت والاتصال بالخادم';
  }
  return 'وقع مشكل. عاود المحاولة';
}
