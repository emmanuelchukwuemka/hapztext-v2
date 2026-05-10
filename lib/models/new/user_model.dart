// import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String name;
  final String email;
  final String firstname;
  final String lastname;
  final String uid;
  final bool isOnline;
  // final String profilePhoto;
  // final String phoneNumber;
  // final List<String> groupId;

  UserModel({
    required this.name,
    required this.email,
    required this.firstname,
    required this.lastname,
    required this.uid,
    required this.isOnline,
    // required this.profilePhoto,
    // required this.phoneNumber,
    // required this.groupId,
  });

  Map<String, dynamic> toJson() => {
        "name": name,
        "email": email,
        "uid": uid,
        "isOnline": isOnline,
        "firstname": firstname,
        "lastname": lastname,
        // "profilePhoto": profilePhoto,
        // "phoneNumber": phoneNumber,
        // "groupId": groupId,
      };

  // static UserModel fromSnap(DocumentSnapshot snap) {
  //   var snapshot = snap.data() as Map<String, dynamic>;
  //   return UserModel(
  //     email: snapshot['email'],
  //     name: snapshot['name'],
  //     firstname: snapshot['firstname'],
  //     lastname: snapshot['lastname'],
  //     uid: snapshot['uid'],
  //     isOnline: true,
  // profilePhoto: snapshot['profilePhoto'],
  // phoneNumber: snapshot['phoneNumber'],
  // groupId: List<String>.from(map['groupId']),
  //   );
  // }

// factory UserModel.fromMap(Map<String, dynamic> map) {
//   return UserModel(
//     name: map['name'] ?? '',
//     email: map['email'] ?? '',
//     uid: map['uid'] ?? '',
//     isOnline: map['isOnline'] ?? false,
//     phoneNumber: map['phoneNumber'],
//     groupId: List<String>.from(map['groupId']),
//   );
// }
}
