import 'package:haptext_api/exports.dart';

class Message {
  Usr sender;
  String time;
  String text;
  bool isLiked;
  bool unread;

  Message(
      {required this.sender,
      required this.time,
      required this.text,
      required this.isLiked,
      required this.unread});
}

List<Message> chats = [
  Message(
    sender: uche,
    time: '5:30 PM',
    text: 'Hey, how\'s it going? What did you do today?',
    isLiked: false,
    unread: true,
  ),
  Message(
    sender: asta,
    time: '9:25 AM',
    text: 'Xup, where\'s Yuno at?',
    isLiked: true,
    unread: true,
  ),
  Message(
    sender: sasuke,
    time: '1:54 PM',
    text: 'Hey, how\'s it going? What did you do today?',
    isLiked: true,
    unread: false,
  ),
  Message(
    sender: currentUser,
    time: '3:07 AM',
    text: 'Hey, how\'s it going? What did you do today?',
    isLiked: false,
    unread: false,
  ),
  Message(
    sender: yuno,
    time: '12:43 PM',
    text: 'Hey, how\'s it going? What did you do today?',
    isLiked: false,
    unread: true,
  ),
  Message(
    sender: currentUser,
    time: '7:19 PM',
    text: 'Hey, how\'s it going? What did you do today?',
    isLiked: true,
    unread: true,
  ),
  Message(
    sender: glory,
    time: '5:30 PM',
    text: 'Hey, how\'s it going? What did you do today?',
    isLiked: false,
    unread: true,
  ),
];
