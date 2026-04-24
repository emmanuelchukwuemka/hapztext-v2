import 'package:haptext_api/models/searched_user_model.dart';

class UserInfoModel {
  String? id;
  String? email;
  String? username;
  Tokens? tokens;
  SearchedUserProfile? profile;

  UserInfoModel(
      {this.id, this.profile, this.email, this.username, this.tokens});

  UserInfoModel.fromJson(Map<String, dynamic> json) {
    id = json['id'].toString();
    email = json['email'];
    username = json['username'];
    tokens = json['tokens'] != null ? Tokens.fromJson(json['tokens']) : null;
    profile = json['profile'] != null ? SearchedUserProfile.fromJson(json['profile']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['email'] = email;
    data['username'] = username;
    if (profile != null) {
      data['profile'] = profile!.toJson();
    }
    return data;
  }
}

class Tokens {
  String? auth;

  Tokens({this.auth});

  Tokens.fromJson(Map<String, dynamic> json) {
    auth = json['auth'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['auth'] = auth;
    return data;
  }
}
