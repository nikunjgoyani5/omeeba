// To parse this JSON data, do
//
//     final postByIdModel = postByIdModelFromJson(jsonString);

import 'dart:convert';

import 'package:omeeba_new/presentation/main/zeals/models/post_model.dart';





PostByIdModel postByIdModelFromJson(String str) =>
    PostByIdModel.fromJson(json.decode(str));

String postByIdModelToJson(PostByIdModel data) => json.encode(data.toJson());

class PostByIdModel {
  bool? status;
  String? message;
  PostByIdData? data;

  PostByIdModel({
    this.status,
    this.message,
    this.data,
  });

  factory PostByIdModel.fromJson(Map<String, dynamic> json) => PostByIdModel(
        status: json["status"],
        message: json["message"],
        data: json["data"] == null ? null : PostByIdData.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {
        "status": status,
        "message": message,
        "data": data?.toJson(),
      };
}

class PostByIdData {
  Post? post;


  PostByIdData({
    this.post,

  });

  factory PostByIdData.fromJson(Map<String, dynamic> json) => PostByIdData(
        post: json["post"] == null ? null : Post.fromJson(json["post"]),

      );

  Map<String, dynamic> toJson() => {
        "post": post?.toJson(),

      };
}
