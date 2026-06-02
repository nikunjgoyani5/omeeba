// To parse this JSON data, do
//
//     final reportsCategoriesModel = reportsCategoriesModelFromJson(jsonString);

import 'dart:convert';

ReportsCategoriesModel reportsCategoriesModelFromJson(String str) => ReportsCategoriesModel.fromJson(json.decode(str));

String reportsCategoriesModelToJson(ReportsCategoriesModel data) => json.encode(data.toJson());

class ReportsCategoriesModel {
  bool? success;
  String? message;
  CategoryData? data;

  ReportsCategoriesModel({this.success, this.message, this.data});

  factory ReportsCategoriesModel.fromJson(Map<String, dynamic> json) => ReportsCategoriesModel(
    success: json["success"],
    message: json["message"],
    data: json["data"] == null ? null : CategoryData.fromJson(json["data"]),
  );

  Map<String, dynamic> toJson() => {"success": success, "message": message, "data": data?.toJson()};
}

class CategoryData {
  List<ReportsCategory>? categories;

  CategoryData({this.categories});

  factory CategoryData.fromJson(Map<String, dynamic> json) => CategoryData(
    categories: json["categories"] == null
        ? []
        : List<ReportsCategory>.from(json["categories"]!.map((x) => ReportsCategory.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "categories": categories == null ? [] : List<dynamic>.from(categories!.map((x) => x.toJson())),
  };
}

class ReportsCategory {
  String? id;
  String? name;
  String? description;
  int? displayOrder;
  List<ReportsCategory>? subCategories;

  ReportsCategory({this.id, this.name, this.description, this.displayOrder, this.subCategories});

  factory ReportsCategory.fromJson(Map<String, dynamic> json) => ReportsCategory(
    id: json["id"],
    name: json["name"],
    description: json["description"],
    displayOrder: json["displayOrder"],
    subCategories: json["subCategories"] == null
        ? []
        : List<ReportsCategory>.from(json["subCategories"]!.map((x) => ReportsCategory.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "description": description,
    "displayOrder": displayOrder,
    "subCategories": subCategories == null ? [] : List<dynamic>.from(subCategories!.map((x) => x.toJson())),
  };
}
