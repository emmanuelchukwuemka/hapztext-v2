import 'package:flutter/material.dart';
import 'package:haptext_api/exports.dart';

class MyImageView extends StatefulWidget {
  const MyImageView({Key? key}) : super(key: key);

  @override
  State<MyImageView> createState() => _MyImageViewState();
}

class _MyImageViewState extends State<MyImageView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: context.theme.bgColor,
      body: PageView(scrollDirection: Axis.horizontal, children: const [
        Center(
          child: Image(
            image: AssetImage('assets/images/me.jpg'),
            fit: BoxFit.contain,
          ),
        ),
        Center(
          child: Image(
            image: AssetImage('assets/images/landscape3.jpg'),
            fit: BoxFit.contain,
          ),
        ),
      ]),
    );
  }
}
