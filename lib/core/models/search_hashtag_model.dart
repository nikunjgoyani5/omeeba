/// Hashtag result from explore/search API (type=hashtag).
class SearchHashtagData {
  final String? tag;
  final int? contentCount;

  SearchHashtagData({this.tag, this.contentCount});

  factory SearchHashtagData.fromJson(Map<String, dynamic> json) => SearchHashtagData(
        tag: json["tag"]?.toString(),
        contentCount: json["contentCount"],
      );

  Map<String, dynamic> toJson() => {
        "tag": tag,
        "contentCount": contentCount,
      };
}
