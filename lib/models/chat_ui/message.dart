class Message {
  final String id;
  final String text;
  final bool me;
  final bool isVoice;
  final DateTime timestamp;
  final bool viewOnce;
  final bool viewed;
  final bool isFeedLink;
  final bool disappearing;
  final bool isEmoji;
  final String? audioPath;
  final bool isImage;
  final String? imageUrl;
  final bool isVideo;
  final String? videoUrl;
  final bool isReply;
  final String? previousMessageId;
  final String? previousMessageContent;
  final String? previousMessageSenderId;

  Message({
    required this.id,
    required this.text,
    required this.me,
    this.isVoice = false,
    required this.timestamp,
    this.viewOnce = false,
    this.viewed = false,
    this.isFeedLink = false,
    this.disappearing = false,
    this.isEmoji = false,
    this.audioPath,
    this.isImage = false,
    this.imageUrl,
    this.isVideo = false,
    this.videoUrl,
    this.isReply = false,
    this.previousMessageId,
    this.previousMessageContent,
    this.previousMessageSenderId,
  });

  Message copyWith({
    String? id,
    String? text,
    bool? me,
    bool? isVoice,
    DateTime? timestamp,
    bool? viewOnce,
    bool? viewed,
    bool? isFeedLink,
    bool? disappearing,
    bool? isEmoji,
    String? audioPath,
    bool? isImage,
    String? imageUrl,
    bool? isVideo,
    String? videoUrl,
    bool? isReply,
    String? previousMessageId,
    String? previousMessageContent,
    String? previousMessageSenderId,
  }) {
    return Message(
      id: id ?? this.id,
      text: text ?? this.text,
      me: me ?? this.me,
      isVoice: isVoice ?? this.isVoice,
      timestamp: timestamp ?? this.timestamp,
      viewOnce: viewOnce ?? this.viewOnce,
      viewed: viewed ?? this.viewed,
      isFeedLink: isFeedLink ?? this.isFeedLink,
      disappearing: disappearing ?? this.disappearing,
      isEmoji: isEmoji ?? this.isEmoji,
      audioPath: audioPath ?? this.audioPath,
      isImage: isImage ?? this.isImage,
      imageUrl: imageUrl ?? this.imageUrl,
      isVideo: isVideo ?? this.isVideo,
      videoUrl: videoUrl ?? this.videoUrl,
      isReply: isReply ?? this.isReply,
      previousMessageId: previousMessageId ?? this.previousMessageId,
      previousMessageContent:
          previousMessageContent ?? this.previousMessageContent,
      previousMessageSenderId:
          previousMessageSenderId ?? this.previousMessageSenderId,
    );
  }
}
