part of flutter_base;

/// http缓存容器，如果你要使用http缓存拦截器，请先使用[LazyLocalStorage]初始化它。
/// ```dart
/// void main() async {
///   await initMyFlutter();
///   httpLocalStorage = await LazyLocalStorage.init('http_cache');
/// }
/// ```
LazyLocalStorage? httpLocalStorage;

/// 基础Http请求类，包含重试请求、错误拦截、请求缓存、数据mock拦截等功能。
/// 扩展示例：
/// ```dart
/// class Http extends BaseHttp {
///   Http() {
///     // 设置服务接口地址
///     instance.options.baseUrl = 'https://jsonplaceholder.typicode.com';
///     // 自定义拦截器，使用..级联运算符可以覆盖父类添加的拦截器
///     instance.interceptors
///     ..add(BaseHttp.retryInterceptor(instance))
///     ..add(BaseHttp.errorInterceptor());
///   }
///
///   /// 自定义响应模型
///   @override
///   Future<ResponseModel> get(
///     String url, {
///     Object? data,
///     Map<String, dynamic>? params,
///     Options? options,
///     GetRequestExtra? getRequestExtra,
///   }) async {
///     // 复用BaseHttp的逻辑
///     var data = await super.get(url, data: data, params: params, options: options, getRequestExtra: getRequestExtra);
///     // 获得响应数据将其转换成自定义模型
///     return ResponseModel.fromJson(data);
///   }
/// }
///   @override
///   Future<ResponseModel> post(
///     String url, {
///     Object? data,
///     Map<String, dynamic>? params,
///     Options? options,
///     PostRequestExtra? postRequestExtra,
///   }) async {
///     // 复用BaseHttp的逻辑
///     var resData = await super.post(url, data: data, params: params, options: options, postRequestExtra: postRequestExtra);
///     // 获得响应数据将其转换成自定义模型
///     return ResponseModel.fromJson(resData);
///   }
/// ```
class BaseHttp {
  /// http请求实例，基于[Dio]
  late Dio instance;

  BaseHttp({
    int timeout = DartUtil.isRelease ? 10000 : 5000,
    bool addRetryInterceptor = true,
    bool addErrorInterceptor = true,
  }) {
    instance = createDio(timeout: timeout);
    instance.interceptors.addIf(addRetryInterceptor, retryInterceptor(instance));
    instance.interceptors.addIf(addErrorInterceptor, errorInterceptor());
  }

  /// 创建一个通用的dio实例
  static Dio createDio({
    // 超时时间
    int timeout = DartUtil.isRelease ? 10000 : 5000,
  }) {
    Dio dio = Dio(
      BaseOptions(
        // 连接服务器超时时间
        connectTimeout: Duration(milliseconds: timeout),
        // 两次数据流数据接收的最长间隔时间
        receiveTimeout: Duration(milliseconds: timeout),
      ),
    );
    return dio;
  }

  /// 重试请求拦截器
  static Interceptor retryInterceptor(Dio http) {
    return RetryInterceptor(
      dio: http,
      logPrint: print,
      retries: 3,
      retryDelays: const [
        Duration(seconds: 1),
        Duration(seconds: 2),
        Duration(seconds: 3),
      ],
    );
  }

  /// http状态错误码拦截器，当遇到请求错误时，它会在页面弹出错误提示
  static errorInterceptor() {
    return InterceptorsWrapper(
      onResponse: (Response response, ResponseInterceptorHandler handler) async {
        if (response.requestOptions.extra['closeLoading'] == true) {
          await LoadingUtil.close();
        }
        return handler.resolve(response);
      },
      onError: (DioException e, ErrorInterceptorHandler handler) async {
        logger.e(e, '全局Http请求异常：${e.requestOptions.uri}');
        if (e.requestOptions.extra['closeLoading'] == true) {
          await LoadingUtil.close();
        }
        String errorMsg = '';
        switch (e.type) {
          case DioExceptionType.sendTimeout:
          case DioExceptionType.connectionTimeout:
            errorMsg = '服务器连接超时，请稍后重试！';
            break;
          case DioExceptionType.receiveTimeout:
            errorMsg = '服务器响应超时，请稍后重试！';
            break;
          case DioExceptionType.badResponse:
            if (e.message != null && e.message!.contains('404')) {
              errorMsg = '请求接口404';
            } else {
              errorMsg = '无效请求';
            }
            break;
          case DioExceptionType.connectionError:
            errorMsg = '服务器连接错误';
            break;
          case DioExceptionType.badCertificate:
            errorMsg = '服务证书错误';
            break;
          case DioExceptionType.cancel:
            break;
          case DioExceptionType.unknown:
            if (e.error is SocketException) {
              errorMsg = '网络连接错误，请检查网络连接！';
            } else {
              errorMsg = '网络连接出现未知错误！';
            }
            break;
        }
        if (e.requestOptions.extra['showGlobalException'] == true) {
          if (errorMsg != '') ToastUtil.showErrorToast(errorMsg);
        }
        return handler.reject(e);
      },
    );
  }

  /// http缓存拦截器，仅限Get请求
  /// * cacheTime 缓存时间，默认1小时
  /// * showLog   打印请求缓存数据的接口地址日志
  static cacheInterceptor({
    int cacheTime = 1000 * 60 * 60,
    bool showLog = true,
  }) {
    assert(httpLocalStorage != null, '使用缓存拦截器前请初始化 httpLocalStorage');
    return InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) async {
        String url = options.uri.toString();
        // 判断请求选项中是否配置了useCache，如果为true则根据url地址尝试获取本地数据，
        // 本地有数据就直接返回，否则继续请求接口。
        if (options.extra['useCache'] == true) {
          var data = await httpLocalStorage!.getItem(CryptoUtil.md5(url));
          if (data == null) {
            return handler.next(options);
          } else {
            if (showLog) logger.i(url, '请求接口缓存数据');
            // 直接关闭loading，handler.resolve将直接结束拦截器链，不再执行后续的请求拦截和响应拦截。
            if (options.extra['closeLoading'] == true) {
              await LoadingUtil.close();
            }
            handler.resolve(Response(requestOptions: options, data: data));
          }
        } else {
          return handler.next(options);
        }
      },
      onResponse: (Response res, ResponseInterceptorHandler handler) {
        // 判断请求选项是否配置了enableCache，如果为true则将结果保存到本地
        if (res.requestOptions.extra['enableCache'] == true) {
          httpLocalStorage!.setItem(
            CryptoUtil.md5(res.requestOptions.uri.toString()),
            res.data,
            duration: DartUtil.safeInt(res.requestOptions.extra['cacheTime'], defaultValue: cacheTime),
          );
        }
        return handler.next(res);
      },
    );
  }

  /// 清除http缓存数据
  static Future<void> clearHttpCache() async {
    assert(httpLocalStorage != null, '使用缓存拦截器前请初始化 httpLocalStorage');
    await httpLocalStorage!.clear();
  }

  Future<dynamic> get(
    String url, {
    Object? data,
    Map<String, dynamic>? params,
    Options? options,
    GetRequestExtra? getRequestExtra,
  }) async {
    Options requestOptions;
    if (options != null) {
      options.extra ??= {};
      requestOptions = options;
    } else {
      requestOptions = Options(extra: {});
    }
    getRequestExtra ??= GetRequestExtra();
    requestOptions.extra!['apiUrl'] = url;
    requestOptions.extra!['useCache'] = getRequestExtra.useCache;
    requestOptions.extra!['enableCache'] = getRequestExtra.enableCache;
    requestOptions.extra!['showGlobalException'] = getRequestExtra.showGlobalException;
    requestOptions.extra!['showServerException'] = getRequestExtra.showServerException;
    requestOptions.extra!['closeLoading'] = getRequestExtra.closeLoading;
    requestOptions.extra!['useMockData'] = getRequestExtra.useMockData;
    requestOptions.extra!['cacheTime'] = getRequestExtra.cacheTime;
    try {
      var res = await instance.get(
        url,
        data: data,
        queryParameters: params,
        options: requestOptions,
        cancelToken: getRequestExtra.cancelToken,
        onReceiveProgress: getRequestExtra.onReceiveProgress,
      );
      return res.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> post(
    String url, {
    Object? data,
    Map<String, dynamic>? params,
    Options? options,
    PostRequestExtra? postRequestExtra,
  }) async {
    Options requestOptions;
    if (options != null) {
      options.extra ??= {};
      requestOptions = options;
    } else {
      requestOptions = Options(extra: {});
    }
    postRequestExtra ??= PostRequestExtra();
    requestOptions.extra!['apiUrl'] = url;
    requestOptions.extra!['showGlobalException'] = postRequestExtra.showGlobalException;
    requestOptions.extra!['showServerException'] = postRequestExtra.showServerException;
    requestOptions.extra!['closeLoading'] = postRequestExtra.closeLoading;
    requestOptions.extra!['useMockData'] = postRequestExtra.useMockData;
    try {
      var res = await instance.post(
        url,
        data: data,
        queryParameters: params,
        options: requestOptions,
        cancelToken: postRequestExtra.cancelToken,
        onSendProgress: postRequestExtra.onSendProgress,
        onReceiveProgress: postRequestExtra.onReceiveProgress,
      );
      return res.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> put(
    String url, {
    Object? data,
    Map<String, dynamic>? params,
    Options? options,
    PutRequestExtra? putRequestExtra,
  }) async {
    Options requestOptions;
    if (options != null) {
      options.extra ??= {};
      requestOptions = options;
    } else {
      requestOptions = Options(extra: {});
    }
    putRequestExtra ??= PutRequestExtra();
    requestOptions.extra!['apiUrl'] = url;
    requestOptions.extra!['showGlobalException'] = putRequestExtra.showGlobalException;
    requestOptions.extra!['showServerException'] = putRequestExtra.showServerException;
    requestOptions.extra!['closeLoading'] = putRequestExtra.closeLoading;
    requestOptions.extra!['useMockData'] = putRequestExtra.useMockData;
    try {
      var res = await instance.put(
        url,
        data: data,
        queryParameters: params,
        options: requestOptions,
        cancelToken: putRequestExtra.cancelToken,
        onSendProgress: putRequestExtra.onSendProgress,
        onReceiveProgress: putRequestExtra.onReceiveProgress,
      );
      return res.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> patch(
    String url, {
    Object? data,
    Map<String, dynamic>? params,
    Options? options,
    PatchRequestExtra? patchRequestExtra,
  }) async {
    Options requestOptions;
    if (options != null) {
      options.extra ??= {};
      requestOptions = options;
    } else {
      requestOptions = Options(extra: {});
    }
    patchRequestExtra ??= PatchRequestExtra();
    requestOptions.extra!['apiUrl'] = url;
    requestOptions.extra!['showGlobalException'] = patchRequestExtra.showGlobalException;
    requestOptions.extra!['showServerException'] = patchRequestExtra.showServerException;
    requestOptions.extra!['closeLoading'] = patchRequestExtra.closeLoading;
    requestOptions.extra!['useMockData'] = patchRequestExtra.useMockData;
    try {
      var res = await instance.patch(
        url,
        data: data,
        queryParameters: params,
        options: requestOptions,
        cancelToken: patchRequestExtra.cancelToken,
        onSendProgress: patchRequestExtra.onSendProgress,
        onReceiveProgress: patchRequestExtra.onReceiveProgress,
      );
      return res.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> delete(
    String url, {
    Object? data,
    Map<String, dynamic>? params,
    Options? options,
    DeleteRequestExtra? deleteRequestExtra,
  }) async {
    Options requestOptions;
    if (options != null) {
      options.extra ??= {};
      requestOptions = options;
    } else {
      requestOptions = Options(extra: {});
    }
    deleteRequestExtra ??= DeleteRequestExtra();
    requestOptions.extra!['apiUrl'] = url;
    requestOptions.extra!['showGlobalException'] = deleteRequestExtra.showGlobalException;
    requestOptions.extra!['showServerException'] = deleteRequestExtra.showServerException;
    requestOptions.extra!['closeLoading'] = deleteRequestExtra.closeLoading;
    requestOptions.extra!['useMockData'] = deleteRequestExtra.useMockData;
    try {
      var res = await instance.delete(
        url,
        data: data,
        queryParameters: params,
        options: requestOptions,
        cancelToken: deleteRequestExtra.cancelToken,
      );
      return res.data;
    } catch (e) {
      rethrow;
    }
  }
}

class RequestExtra {
  /// 取消请求token，如果未传入，则使用默认的cancelToken
  CancelToken? cancelToken;

  /// 请求进度监听
  ProgressCallback? onReceiveProgress;

  /// 是否显示全局异常消息，如果为true，last_interceptor拦截器将会显示网络错误
  bool showGlobalException;

  /// 是否显示服务器接口异常消息，如果为true，注意：此选项需要你自己根据业务去实现，例如判断接口返回的状态码，显示接口返回的错误信息等等...
  bool showServerException;

  /// 接口请求完成后是否关闭全局loading（必须使用[LoadingUtil]，如果页面没有loading弹窗，则不做任何操作），
  /// 如果你需要执行多个请求，同时又希望它们共用一个Loading弹窗，那么你应该将它设为false。
  ///
  /// 它由某些拦截器控制：[cacheInterceptor]、[errorInterceptor],
  bool closeLoading;

  /// 强制使用mock数据，注意：你需要在mock文件中声明此接口的数据
  bool useMockData;

  RequestExtra({
    this.cancelToken,
    this.onReceiveProgress,
    this.showGlobalException = true,
    this.showServerException = true,
    this.closeLoading = true,
    this.useMockData = false,
  });
}

class GetRequestExtra extends RequestExtra {
  /// 是否开启缓存，若为true，接口响应成功后数据将会保存于本地，key为url
  bool enableCache;

  /// 是否使用缓存数据，如果本地存在数据，则直接返回本地数据，不会发送请求，
  /// 你可以在缓存拦截器中自定义缓存时间，如果用户处于无网络状态，则直接响应缓存数据。
  bool useCache;

  /// 缓存时间，若指定则会覆盖缓存拦截器默认的时间
  int? cacheTime;

  GetRequestExtra({
    super.cancelToken,
    super.onReceiveProgress,
    super.showGlobalException,
    super.showServerException,
    super.closeLoading,
    this.enableCache = false,
    this.useCache = false,
    this.cacheTime,
  });
}

class PostRequestExtra extends RequestExtra {
  /// 监听上传进度
  ProgressCallback? onSendProgress;

  PostRequestExtra({
    super.cancelToken,
    super.onReceiveProgress,
    super.showGlobalException,
    super.showServerException,
    super.closeLoading,
    this.onSendProgress,
  });
}

class PutRequestExtra extends RequestExtra {
  /// 监听上传进度
  ProgressCallback? onSendProgress;

  PutRequestExtra({
    super.cancelToken,
    super.onReceiveProgress,
    super.showGlobalException,
    super.showServerException,
    super.closeLoading,
    this.onSendProgress,
  });
}

class PatchRequestExtra extends RequestExtra {
  /// 监听上传进度
  ProgressCallback? onSendProgress;

  PatchRequestExtra({
    super.cancelToken,
    super.onReceiveProgress,
    super.showGlobalException,
    super.showServerException,
    super.closeLoading,
    this.onSendProgress,
  });
}

class DeleteRequestExtra extends RequestExtra {
  DeleteRequestExtra({
    super.cancelToken,
    super.showGlobalException,
    super.showServerException,
    super.closeLoading,
  });
}
