import 'global.dart';

HttpBase httpBase = HttpBase();
Http http = Http();

class Http extends HttpBase {
  Http() {
    instance.options.baseUrl = 'https://jsonplaceholder.typicode.com';
  }

  @override
  Future<dynamic> get(
    String url, {
    Object? data,
    Map<String, dynamic>? params,
    Options? options,
    GetRequestExtra? getRequestExtra,
  }) async {
    return await super.get(url, data: data, params: params, options: options, getRequestExtra: getRequestExtra);
  }

  @override
  Future<dynamic> post(
    String url, {
    Object? data,
    Map<String, dynamic>? params,
    Options? options,
    PostRequestExtra? postRequestExtra,
  }) async {
    return await super.post(url, data: data, params: params, options: options, postRequestExtra: postRequestExtra);
  }

  @override
  Future<dynamic> put(
    String url, {
    Object? data,
    Map<String, dynamic>? params,
    Options? options,
    PutRequestExtra? putRequestExtra,
  }) async {
    return await super.put(url, data: data, params: params, options: options, putRequestExtra: putRequestExtra);
  }

  @override
  Future<dynamic> patch(
    String url, {
    Object? data,
    Map<String, dynamic>? params,
    Options? options,
    PatchRequestExtra? patchRequestExtra,
  }) async {
    return await super.patch(url, data: data, params: params, options: options, patchRequestExtra: patchRequestExtra);
  }

  @override
  Future<dynamic> delete(
    String url, {
    Object? data,
    Map<String, dynamic>? params,
    Options? options,
    DeleteRequestExtra? deleteRequestExtra,
  }) async {
    return await super.delete(url, data: data, params: params, options: options, deleteRequestExtra: deleteRequestExtra);
  }

  Future<dynamic> test(String url) async {
    var resData = await get(url);
    return resData;
  }
}
