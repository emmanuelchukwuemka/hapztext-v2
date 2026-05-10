import 'package:flutter/material.dart';

class Tab5 extends StatefulWidget {
  const Tab5({Key? key}) : super(key: key);

  @override
  State<Tab5> createState() => _Tab5State();
}

class _Tab5State extends State<Tab5> {
  List<String> myPictures = [
    'assets/images/me.jpg',
    'assets/images/asta.jpg',
    'assets/images/sasuke.jpg',
    'assets/images/yuno.jpg',
    'assets/images/vegeta.jpg',
    'assets/images/me.jpg',
    'assets/images/me.jpg',
    'assets/images/sasuke.jpg',
    'assets/images/asta.jpg',
    'assets/images/yuno.jpg',
    'assets/images/vegeta.jpg',
    'assets/images/me.jpg',
    'assets/images/me.jpg',
    'assets/images/sasuke.jpg',
    'assets/images/asta.jpg',
    'assets/images/yuno.jpg',
    'assets/images/vegeta.jpg',
    'assets/images/me.jpg',
    'assets/images/me.jpg',
    'assets/images/sasuke.jpg',
    'assets/images/asta.jpg',
    'assets/images/yuno.jpg',
    'assets/images/vegeta.jpg',
    'assets/images/me.jpg',
    'assets/images/me.jpg',
    'assets/images/asta.jpg',
    'assets/images/sasuke.jpg',
    'assets/images/yuno.jpg',
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1,
        crossAxisSpacing: 1.2,
        mainAxisSpacing: 1.2,
      ),
      itemCount: myPictures.length,
      itemBuilder: (BuildContext context, int index) => Container(
        // height: 185,
        // width: 158,
        child: Image(
          image: AssetImage(myPictures[index]),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
