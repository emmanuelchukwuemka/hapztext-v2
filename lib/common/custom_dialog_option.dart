import 'package:flutter/material.dart';
import '../widgets/chats_mssgs_data.dart';

class CustomDialogWidget extends StatelessWidget {
  const CustomDialogWidget({Key? key, required this.trailingIcon})
      : super(key: key);

  final Widget trailingIcon;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * .50,
        padding: const EdgeInsets.only(top: 15, bottom: 5.0),
        decoration: BoxDecoration(
          // color: Color(0xFFAA303E),
          color: Color(0xFF2A303E),
          borderRadius: BorderRadius.circular(15),
        ),
        child: ListView.builder(
          itemCount: chats.length,
          itemBuilder: (BuildContext context, int index) {
            final chat = chats[index];
            return Container(
              height: 55.0,
              padding: const EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 20,
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 17.50,
                          backgroundImage: AssetImage(chat.sender.imgUrl),
                        ),
                        SizedBox(width: 15),
                        Container(
                          width: MediaQuery.of(context).size.width * .25,
                          // color: Colors.black87,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                chat.sender.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                chat.time,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    trailingIcon,
                  ]),
            );
          },
        ),
      ),
    );
  }
}
