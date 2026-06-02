/// API Response Model
/// Handles standard API response structure:
/// {
///   "success": true,
///   "status": 200,
///   "message": "Request successful.",
///   "data": { ... }
/// }
class ApiResponse {
  final bool success;
  final int? status;
  final String? message;
  final dynamic data;
  final Pagination? pagination;

  ApiResponse({required this.success, this.status, this.message, this.data, this.pagination});

  /// Parse from JSON response
  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      success: json['success'] ?? json['isSuccess'] ?? false,
      status: json['status'] ?? json['statusCode'],
      message: json['message'] ?? json['msg'] ?? json['error'],
      data: json['data'],
      pagination: json["pagination"] == null ? null : Pagination.fromJson(json["pagination"]),
    );
  }

  /// Check if response is successful
  bool get isSuccess => success == true;

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {'success': success, 'status': status, 'message': message, 'data': data};
  }
}

class Pagination {
  int? page;
  int? limit;
  int? total;
  int? pages;
  bool? hasNext;
  bool? hasPrev;
  /// Cursor for next page (cursor-based pagination)
  String? nextCursor;

  Pagination({
    this.page,
    this.limit,
    this.total,
    this.pages,
    this.hasNext,
    this.hasPrev,
    this.nextCursor,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) => Pagination(
    page: json["page"],
    limit: json["limit"],
    total: json["total"],
    pages: json["pages"],
    hasNext: json["hasNext"],
    hasPrev: json["hasPrev"],
    nextCursor: json["nextCursor"],
  );

  Map<String, dynamic> toJson() => {
    "page": page,
    "limit": limit,
    "total": total,
    "pages": pages,
    "hasNext": hasNext,
    "hasPrev": hasPrev,
    "nextCursor": nextCursor,
  };
}
