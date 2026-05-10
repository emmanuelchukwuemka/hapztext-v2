import 'package:json_annotation/json_annotation.dart';

part 'profileModel.g.dart';

@JsonSerializable()
class ProfileModel {
  int? id;
  String? email;
  String? password;
  String? userName;
  String? firstName;
  String? lastName;
  String? phone;
  String? birthday;
  String? tagName;
  String? role;
  String? height;
  String? weight;
  String? lookingFor;
  String? ethnicity;
  String? relationshipStatus;
  String? biography;
  String? location;
  String? visited;

  ProfileModel(
      {this.id,
      this.email,
      this.password,
      this.userName,
      this.firstName,
      this.lastName,
      this.birthday,
      this.tagName,
      this.phone,
      this.role,
      this.height,
      this.weight,
      this.lookingFor,
      this.ethnicity,
      this.relationshipStatus,
      this.biography,
      this.location,
      this.visited});

  factory ProfileModel.fromJson(Map<String, dynamic> json) =>
      _$ProfileModelFromJson(json);
  // factory ProfileModel.fromJson(Map<String, dynamic> json) => ProfileModel(
  //   id: json['id'],
  //   birthday: json['birthday'],
  //   name: json['name'],
  //   tagName: json['tagName'],
  //   role: json['role'],
  //   height: json['height'],
  //   weight: json['weight'],
  //   lookingFor: json['lookingFor'],
  //   ethnicity: json['ethnicity'],
  //   relationshipStatus: json['relationshipStatus'],
  //   biography: json['biography'],
  // );

  Map<String, dynamic> toJson() => _$ProfileModelToJson(this);
  // Map<String, dynamic> toJson() => {
  //   "id" : id,
  //   'name': name,
  //   'birthday': birthday,
  //   'tagName': tagName,
  //   'role': role,
  //   'weight': weight,
  //   'height': height,
  //   'lookingFor': lookingFor,
  //   'ethnicity': ethnicity,
  //   'relationshipStatus': relationshipStatus,
  //   'biography': biography,
  // };
}
