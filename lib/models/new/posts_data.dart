import 'package:flutter/material.dart';

class PostChoice {
  List<Color> col;
  String desc;
  IconData icon;

  PostChoice({required this.col, required this.desc, required this.icon});
}

List<PostChoice> choice = [
  PostChoice(
      col: [Colors.purple, Colors.purpleAccent, Colors.pinkAccent, Colors.pink],
      desc: 'Text',
      icon: Icons.abc),
  PostChoice(col: [
    Colors.green,
    Colors.greenAccent,
    Colors.grey,
    Colors.blueGrey,
    Colors.blueAccent,
    Colors.blue
  ], desc: 'Audio', icon: Icons.music_note),
  PostChoice(col: [
    Colors.red,
    Colors.redAccent,
    Colors.orangeAccent,
    Colors.orange,
    Colors.deepOrangeAccent,
    Colors.deepOrange
  ], desc: 'Photo', icon: Icons.image),
  PostChoice(col: [
    Colors.black12,
    Colors.black38,
    Colors.black54,
    Colors.black87,
    Colors.white
  ], desc: 'Video', icon: Icons.video_library_sharp),
];
