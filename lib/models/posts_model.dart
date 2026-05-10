class PostModel {
  List<ResultPostModel>? result;
  dynamic previousPostsData;
  dynamic nextPostsData;

  PostModel({this.result, this.previousPostsData, this.nextPostsData});

  PostModel.fromJson(Map<String, dynamic> json) {
    if (json['result'] != null) {
      result = <ResultPostModel>[];
      json['result'].forEach((v) {
        result!.add(ResultPostModel.fromJson(v));
      });
    }
    previousPostsData = json['previous_posts_data'];
    nextPostsData = json['next_posts_data'];
  }
}

// class ResultPostModel {
//   String? senderId;
//   String? postFormat;
//   String? textContent;
//   String? senderName;
//   dynamic imageContent;
//   dynamic audioContent;
//   dynamic videoContent;
//   bool? isReply;
//   dynamic previousPostId;
//   String? id;
//   List taggedUserIds = [];
//   String? createdAt;
//   String? updatedAt;
//   List<CommentModel> comments = [];

//   ResultPostModel(
//       {this.senderId,
//       this.postFormat,
//       this.textContent,
//       this.imageContent,
//       this.audioContent,
//       this.videoContent,
//       this.senderName,
//       this.isReply,
//       this.previousPostId,
//       this.id,
//       this.comments = const [],
//       this.taggedUserIds = const [],
//       this.createdAt,
//       this.updatedAt});

//   ResultPostModel.fromJson(Map<String, dynamic> json) {
//     senderId = json['sender_id'];
//     postFormat = json['post_format'];
//     textContent = json['text_content'];
//     imageContent = json['image_content'];
//     audioContent = json['audio_content'];
//     videoContent = json['video_content'];
//     senderName = json['sender_username'];
//     isReply = json['is_reply'];
//     previousPostId = json['previous_post_id'];
//     taggedUserIds = json['tagged_user_ids'];
//     id = json['id'];
//     createdAt = json['created_at'];
//     updatedAt = json['updated_at'];
//   }
// }

class CommentModel {
  String? senderId;
  String? senderName;
  String? postFormat;
  String? textContent;
  String? imageContent;
  String? audioContent;
  String? videoContent;
  bool? isReply;
  String? previousPostId;
  String? senderUsername;
  bool? isPublished;
  // Null? scheduledAt;
  // List<Null>? taggedUserIds;
  String? id;
  String? createdAt;
  String? updatedAt;
  int? reactionsCount;
  int? shareCount;
  String? currentUserReaction;
  List<CommentModel> replies = [];

  CommentModel(
      {this.senderId,
      this.postFormat,
      this.textContent,
      this.imageContent,
      this.audioContent,
      this.videoContent,
      this.isReply,
      this.senderName,
      this.previousPostId,
      this.senderUsername,
      this.isPublished,
      this.id,
      this.createdAt,
      this.updatedAt,
      this.reactionsCount,
      this.shareCount,
      this.replies = const [],
      this.currentUserReaction});

  CommentModel.fromJson(Map<String, dynamic> json) {
    senderId = json['sender_id'];

    postFormat = json['post_format'];
    textContent = json['text_content'];
    imageContent = json['image_content'];
    audioContent = json['audio_content'];
    videoContent = json['video_content'];
    isReply = json['is_reply'];
    previousPostId = json['previous_post_id'];
    senderUsername = json['sender_username'];
    isPublished = json['is_published'];
    id = json['id'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    reactionsCount = json['reaction_count'] ?? json['reactions_count'];
    shareCount = json['share_count'];
    if (json['replies'] != null) {
      replies = <CommentModel>[];
      json['replies'].forEach((v) {
        replies.add(CommentModel.fromJson(v));
      });
    }
    currentUserReaction = json['current_user_reaction'];
  }
}

class ResultPostModel {
  String? senderId;
  String? postFormat;

  String? textContent;
  String? backgroundColor;
  String? imageContent;
  String? audioContent;
  String? videoContent;
  bool? isReply;
  String? previousPostId;
  String? senderUsername;
  bool? isPublished;
  String? scheduledAt;
  int? replyCount;
  List<void>? taggedUserIds;
  String? id;
  String? createdAt;
  String? senderName;
  String? updatedAt;
  // ReactionCounts? reactionCounts;
  int? shareCount;
  int? likeCount;
  String? currentUserReaction;
  List<MediaFiles>? mediaFiles;
  List<CommentModel> comments = [];
  // Replies? comments;

  ResultPostModel(
      {this.senderId,
      this.postFormat,
      this.senderName,
      this.textContent,
      this.backgroundColor,
      this.imageContent,
      this.audioContent,
      this.videoContent,
      this.isReply,
      this.previousPostId,
      this.senderUsername,
      this.isPublished,
      this.scheduledAt,
      this.replyCount,
      this.taggedUserIds,
      this.id,
      this.createdAt,
      this.updatedAt,
      this.shareCount,
      this.likeCount,
      this.currentUserReaction,
      this.mediaFiles,
      this.comments = const []});

  ResultPostModel.fromJson(Map<String, dynamic> json) {
    senderId = json['sender_id'];
    postFormat = json['post_format'];
    senderName = json['sender_name'];
    textContent = json['text_content'];
    backgroundColor = json['background_color'];
    imageContent = json['image_content'];
    audioContent = json['audio_content'];
    videoContent = json['video_content'];
    isReply = json['is_reply'];
    previousPostId = json['previous_post_id'];
    senderUsername = json['sender_username'];
    isPublished = json['is_published'];
    scheduledAt = json['scheduled_at'];
    replyCount = json['reply_count'];
    // if (json['tagged_user_ids'] != null) {
    // 	taggedUserIds = <Null>[];
    // 	json['tagged_user_ids'].forEach((v) { taggedUserIds!.add(String?.fromJson(v)); });
    // }
    id = json['id'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    // reactionCounts = json['reaction_counts'] != null ? ReactionCounts.fromJson(json['reaction_counts']) : null;
    shareCount = json['share_count'];
    likeCount = json['like_count'] ?? json['reaction_count'];
    currentUserReaction = json['current_user_reaction'];
    if (json['media_files'] != null) {
      mediaFiles = <MediaFiles>[];
      json['media_files'].forEach((v) {
        mediaFiles!.add(MediaFiles.fromJson(v));
      });
    }
    // comments =
    //     json['replies'] != null ? Replies.fromJson(json['replies']) : null;
  }
}

// class ReactionCounts {

// 	ReactionCounts({});

// 	ReactionCounts.fromJson(Map<String, dynamic> json);

// }

class MediaFiles {
  String? id;
  String? mediaType;
  String? imageFile;
  String? audioFile;
  String? videoFile;
  String? createdAt;
  String? updatedAt;

  MediaFiles(
      {this.id,
      this.mediaType,
      this.imageFile,
      this.audioFile,
      this.videoFile,
      this.createdAt,
      this.updatedAt});

  MediaFiles.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    mediaType = json['media_type'];
    imageFile = json['image_file'];
    audioFile = json['audio_file'];
    videoFile = json['video_file'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
  }
}

class Replies {
  List<String>? result;
  dynamic previousRepliesData;
  dynamic nextRepliesData;

  Replies({this.result, this.previousRepliesData, this.nextRepliesData});

  Replies.fromJson(Map<String, dynamic> json) {
    // if (json['result'] != null) {
    // 	result = <String>[];
    // 	json['result'].forEach((v) { result!.add(new Null.fromJson(v)); });
    // }
    previousRepliesData = json['previous_replies_data'];
    nextRepliesData = json['next_replies_data'];
  }
}
