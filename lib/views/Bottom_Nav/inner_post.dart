import 'package:flutter/material.dart';

class InnerPost extends StatefulWidget {
  const InnerPost({Key? key}) : super(key: key);

  @override
  State<InnerPost> createState() => _InnerPostState();
}

class _InnerPostState extends State<InnerPost> {
  @override
  Widget build(BuildContext context) {
    return buildPost('assets/images/landscape1.jpg');
  }

  Container buildPost(String imgPath) {
    final currentWidth = MediaQuery.of(context).size.width;
    final currentHeight = MediaQuery.of(context).size.height;
    return Container(
      height: currentHeight - 105,
      width: currentWidth,
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          image:
              DecorationImage(image: AssetImage(imgPath), fit: BoxFit.contain)),
      child: Stack(children: [
        // Align(
        //   alignment: Alignment.center,
        //   child: Container(
        //     height: double.infinity,
        //     width: double.infinity,
        //     child: const Center(
        //       child: Image(
        //         image: AssetImage('assets/images/chukwuchi.jpg'),
        //         fit: BoxFit.cover,
        //       ),
        //     ),
        //   ),
        // ),
        Positioned(
          bottom: 20.0,
          right: 7.0,
          child: Container(
              child: Row(
            children: [
              Column(
                children: const [
                  Icon(Icons.heart_broken_rounded,
                      color: Colors.orange, size: 23),
                  Text('885',
                      style: TextStyle(color: Colors.orange, fontSize: 11)),
                  SizedBox(height: 10.0),
                  Icon(Icons.download, color: Colors.orange, size: 23),
                  Text('85',
                      style: TextStyle(color: Colors.orange, fontSize: 11)),
                ],
              ),
              SizedBox(width: 20),
              Column(
                children: const [
                  Icon(Icons.chat_rounded, color: Colors.orange, size: 22),
                  Text('379',
                      style: TextStyle(color: Colors.orange, fontSize: 11)),
                  SizedBox(height: 10),
                  Icon(Icons.share, color: Colors.orange, size: 22),
                  Text('Share',
                      style: TextStyle(color: Colors.orange, fontSize: 11)),
                ],
              ),
            ],
          )),
        ),
        Positioned(
          left: 10,
          bottom: 7.5,
          child: Center(
            child: Container(
              width: currentWidth * 0.60,
              height: currentHeight * 0.12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      width: 75.0,
                      height: 25,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Center(
                          child: Text('Your friend',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)))),
                  SizedBox(height: 5),
                  const Text('PrimeOnTiktok',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.black,
                          fontWeight: FontWeight.w500)),
                  SizedBox(height: 5),
                  const Text(
                      'Who be the clan master abeg? cause omooooo this is total annihilation #cod #codm #codmobile #callofdutymobile',
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w100,
                          fontSize: 10))
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 20,
          left: 20,
          child: Row(
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundImage: AssetImage('assets/images/me.jpg'),
              ),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Fortune',
                      style: TextStyle(
                          color: Colors.orange,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  Text('52 mins ago',
                      style: TextStyle(color: Colors.orange, fontSize: 12)),
                ],
              )
            ],
          ),
        )
      ]),
    );
  }
}
