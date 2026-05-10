class Video {
  final String username;
  final String uid;
  final String id;
  final List<String> likes;
  final int commentCount;
  final int shareCount;
  final String title;
  final String caption;
  final String videoUrl; // We use ? to allow null values
  final String? thumbnail; // We use ? to allow null values
  final String profilePhoto;

  Video({
    required this.username,
    required this.uid,
    required this.id,
    required this.likes,
    required this.commentCount,
    required this.shareCount,
    required this.title,
    required this.caption,
    required this.videoUrl,
    this.thumbnail,
    required this.profilePhoto,
  });

  Map<String, dynamic> toJson() => {
        "username": username,
        "uid": uid,
        "id": id,
        "likes": likes,
        "commentCount": commentCount,
        "shareCount": shareCount,
        "title": title,
        "caption": caption,
        "videoUrl": videoUrl,
        "thumbnail": thumbnail,
        "profilePhoto": profilePhoto,
      };

  // static Video fromSnap(DocumentSnapshot snap) {
  //   var snapshot = snap.data() as Map<String, dynamic>;
  //
  //   return Video(
  //     username: snapshot['username'],
  //     uid: snapshot['uid'],
  //     id: snapshot['id'],
  //     likes: snapshot['likes'],
  //     commentCount: snapshot['commentCounts'],
  //     shareCount: snapshot['shareCounts'],
  //     title: snapshot['title'],
  //     caption: snapshot['caption'],
  //     videoUrl: snapshot['videoUrl'],
  //     profilePhoto: snapshot['profilePhoto'],
  //     thumbnail: snapshot['thumbnail'],
  //   );
  // }
}

enum MediaSource { video, image }
