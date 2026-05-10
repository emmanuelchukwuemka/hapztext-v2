class UserModel {
  int? id;
  String? firstname;
  String? lastname;
  String? image;
  String? bio;
  String? birthday;
  String? role;
  String? height;
  String? weight;
  String? ethnicity;
  String? relationshipStatus;
  String? user;
  String? tagname;
  List? following;
  List? followers;
  // List? friends;

  UserModel(
      {this.firstname,
      this.lastname,
      this.birthday,
      this.role,
      this.height,
      this.weight,
      this.ethnicity,
      this.relationshipStatus,
      this.user,
      this.tagname,
      this.id,
      this.followers,
      this.following,
      this.image,
      this.bio});

  UserModel.fromJson(Map<String, dynamic> json) {
    id = json["id"];
    firstname = json["first_name"];
    lastname = json["last_name"];
    image = json["profile_picture"];
    bio = json["bio"];
    birthday = json["birth_date"];
    role = json["occupation"];
    height = json["height"];
    weight = json["weight"];
    ethnicity = json["ethnicity"];
    relationshipStatus = json["relationship_status"];
    user = json["user"];
    tagname = json["username"];
    following = json["following"];
    followers = json["followers"];
  }

  Map<String, dynamic> toJson() {
    final _data = <String, dynamic>{};
    _data['id'] = id;
    _data['first_name'] = firstname;
    _data['last_name'] = lastname;
    _data['profile_picture'] = image;
    _data['bio'] = bio;
    _data['birth_date'] = birthday;
    _data['occupation'] = role;
    _data['height'] = height;
    _data['weight'] = weight;
    _data['ethnicity'] = ethnicity;
    _data['relationship_status'] = relationshipStatus;
    _data['user'] = user;
    _data['username'] = tagname;
    _data['following'] = following;
    _data['followers'] = followers;

    return _data;
  }
}
