class BaseResponse<T> {
  const BaseResponse({
    required this.code,
    required this.message,
    this.data,
    this.success = false,
  });

  final int code;
  final String message;
  final T? data;
  final bool success;

  factory BaseResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json)? fromJsonT,
  ) {
    final code = json['code'] as int? ?? -1;
    final rawData = json['data'];
    return BaseResponse<T>(
      code: code,
      message: json['message'] as String? ?? json['msg'] as String? ?? '',
      data: rawData == null
          ? null
          : fromJsonT == null
              ? rawData as T?
              : fromJsonT(rawData),
      success: json['success'] as bool? ?? code == 200 || code == 0,
    );
  }

  Map<String, dynamic> toJson(Object? Function(T? value)? toJsonT) {
    return {
      'code': code,
      'message': message,
      'data': toJsonT == null ? data : toJsonT(data),
      'success': success,
    };
  }
}

class PageResult<T> {
  const PageResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<T> items;
  final int total;
  final int page;
  final int pageSize;

  factory PageResult.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) itemBuilder,
  ) {
    final rawItems = json['items'] ?? json['records'] ?? json['content'] ?? [];
    return PageResult<T>(
      items: (rawItems as List<dynamic>).map(itemBuilder).toList(),
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? json['current'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? json['size'] as int? ?? 20,
    );
  }
}
