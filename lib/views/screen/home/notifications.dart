import 'package:flutter/material.dart';
import 'package:haptext_api/common/theme/custom_theme_extension.dart';

class Notifications extends StatefulWidget {
  const Notifications({Key? key}) : super(key: key);

  @override
  State<Notifications> createState() => _NotificationsState();
}

class _NotificationsState extends State<Notifications> {
  List<String> not = [
    'followed you back, view their post.',
    'mentioned you.',
    'Fortune came to your DM',
    'feels sad for your comment',
    'feels happy for your comment',
    'feels confused for your comment',
    'feels excited for your comment',
    'booked your livestream',
    'shared your post',
    'unfollowed you',
    'is live now!',
    'listened to your post',
    're-hapz your post',
    'feels sad for your video',
    'Uche says "He really loves that event and he wishes he was there to witness it" ',
    'roman says "wishes it was him" ',
    'Lorem ipsum sjapojsdlkjflsalbfjka sfd lkfnlhpfnan asvhdojAV FV;KJABDLH ',
    'Uche says He really loves that event and he wishes he was there to witness it',
    'Fortune',
  ];

  List<String> im = [
    'assets/images/vegeta.jpg',
    'assets/images/me.jpg',
    'assets/images/asta.jpg',
    'assets/images/chukwuchi.jpg',
    'assets/images/vegeta.jpg',
    'assets/images/me.jpg',
    'assets/images/asta.jpg',
    'assets/images/chukwuchi.jpg',
    'assets/images/vegeta.jpg',
    'assets/images/me.jpg',
    'assets/images/asta.jpg',
    'assets/images/chukwuchi.jpg',
    'assets/images/vegeta.jpg',
    'assets/images/me.jpg',
    'assets/images/asta.jpg',
    'assets/images/chukwuchi.jpg',
    'assets/images/vegeta.jpg',
    'assets/images/me.jpg',
    'assets/images/asta',
  ];

  Widget buildText(Size size) {
    return ListView.builder(
      itemCount: not.length,
      itemBuilder: (context, index) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 10.0),
        height: size.height * .14,
        width: size.width,
        decoration: BoxDecoration(
          color: context.theme.bgColor,
          border: Border(
            // top: BorderSide(color: Colors.grey.shade400, width: 0.5),
            bottom: BorderSide(color: context.theme.primaryColor!, width: 0.5),
          ),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: size.height * .042,
            backgroundImage: AssetImage(im[index]),
          ),
          SizedBox(width: 7.5),
          Expanded(
            // width: size.width * .6,
            // height: size.height * .15,
            // color: Colors.black12,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.start, children: [
                      Text(
                        'Roman',
                        style: TextStyle(
                          color: context.theme.textColor,
                        ),
                      ),
                      SizedBox(width: 3.5),
                      Text(
                        '@remedy_boy1 . 17 Jul',
                        style: TextStyle(
                          color: context.theme.greyColor,
                          fontSize: 12,
                        ),
                      ),
                    ]),
                    Icon(
                      Icons.more_horiz,
                      color: context.theme.greyColor,
                    ),
                  ],
                ),
                SizedBox(height: 3.5),
                Container(
                  padding: const EdgeInsets.only(right: 7.5),
                  child: Text(
                    not[index],
                    style: TextStyle(
                      color: context.theme.greyColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: context.theme.bgColor,
      appBar: AppBar(
        iconTheme: IconThemeData(
          color: context.theme.primaryColor,
        ),
        backgroundColor: context.theme.appBarColor,
        title: Text('Notifications',
            style: TextStyle(
                color: context.theme.primaryColor,
                fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton(
            position: PopupMenuPosition.under,
            color: context.theme.bgColor,
            icon: Icon(
              Icons.more_vert,
              size: 22,
              color: context.theme.primaryColor,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(0.0),
                bottomRight: Radius.circular(30),
                bottomLeft: Radius.circular(30),
              ),
            ),
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                child: InkWell(
                  onTap: () {
                    // Navigator.push(context, MaterialPageRoute(builder: (_) => Blocked(),));
                  },
                  child: Text('Clear'),
                ),
              ),
              PopupMenuItem(
                child: InkWell(
                  onTap: () {
                    // Navigator.push(context, MaterialPageRoute(builder: (_) => Blocked(),));
                  },
                  child: Text('Mark all as read'),
                ),
              ),
              PopupMenuItem(
                child: InkWell(
                  onTap: () {
                    // Navigator.push(context, MaterialPageRoute(builder: (_) => Blocked(),));
                  },
                  child: Text('Delete'),
                ),
              ),
            ],
          ),
          // Icon(Icons.search, color: Colors.orange),
          // Icon(Icons.more_vert, color: context.theme.primaryColor,),
          SizedBox(width: 3.5),
        ],
        elevation: 1.0,
      ),
      body: Container(
        width: size.width,
        height: size.height,
        child: buildText(size),
      ),
      // body: ListView(
      //   children: [
      //     Container(
      //       width: double.infinity,
      //       height: 70,
      //       margin: const EdgeInsets.all(5),
      //       padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
      //       decoration: const BoxDecoration(
      //           color: Colors.white,
      //           boxShadow: [BoxShadow(
      //               blurRadius: 5,
      //               color: Colors.black38,
      //               offset: Offset(1, 1)
      //           )]
      //       ),
      //       child: Row(
      //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
      //         children: [
      //           Row(
      //             children: [
      //               CircleAvatar(
      //                 radius: 30,
      //                 backgroundImage: AssetImage('assets/images/me.jpg'),
      //               ),
      //               SizedBox(width: 5),
      //               Container(
      //                 width: size.width * .35,
      //                 child: Text(
      //                   'Event taking place #CODM_contest',
      //                   overflow: TextOverflow.ellipsis,
      //                   maxLines: 2,
      //                 ),
      //               ),
      //             ],
      //           ),
      //           Row(
      //             children: [
      //               Container(
      //                 height: 30,
      //                 width: size.width * .18,
      //                 decoration: BoxDecoration(
      //                   color: Colors.green,
      //                   borderRadius: BorderRadius.circular(5),
      //                 ),
      //                 child: const Center(
      //                   child: Text(
      //                     'Accept',
      //                     style: TextStyle(
      //                       color: Colors.white,
      //                       fontSize: 12,
      //                       fontWeight: FontWeight.w500,
      //                     ),
      //                   ),
      //                 ),
      //               ),
      //               SizedBox(width: 5),
      //               Container(
      //                 height: 30,
      //                 width: size.width * .18,
      //                 decoration: BoxDecoration(
      //                   color: Colors.red.shade800,
      //                   borderRadius: BorderRadius.circular(5),
      //                 ),
      //                 child: const Center(
      //                   child: Text(
      //                     'Decline',
      //                     style: TextStyle(
      //                       color: Colors.white,
      //                       fontSize: 12,
      //                       fontWeight: FontWeight.w500,
      //                     ),
      //                   ),
      //                 ),
      //               ),
      //             ],
      //           ),
      //         ],
      //       ),
      //     ),
      //     Container(width: double.infinity, height: size.height * .4, child: buildText(size),),
      //     Container(
      //       height: 1210,
      //       width: double.infinity,
      //       child: ListView.builder(
      //           itemCount: not.length,
      //           itemBuilder: (BuildContext context, int index) => Container(
      //             width: double.infinity,
      //             height: 70,
      //             margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.0),
      //             padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
      //             decoration: const BoxDecoration(
      //               color: Colors.white,
      //               boxShadow: [BoxShadow(
      //                 blurRadius: 5,
      //                 color: Colors.black38,
      //                 offset: Offset(1, 1)
      //               )]
      //             ),
      //             child: Row(
      //               mainAxisAlignment: MainAxisAlignment.spaceBetween,
      //               children: [
      //                 Row(
      //                   children: [
      //                     CircleAvatar(
      //                       radius: 30,
      //                       backgroundImage: AssetImage(im[index]),
      //                     ),
      //                     SizedBox(width: 5),
      //                     Container(
      //                       width: size.width * .42,
      //                       child: Text(not[index], overflow: TextOverflow.ellipsis, maxLines: 2,),
      //                     ),
      //                   ],
      //                 ),
      //                 SizedBox(width: size.width * .03),
      //                 Container(
      //                   height: 30,
      //                   width: size.width * .25,
      //                   decoration: BoxDecoration(
      //                     color: Colors.orange,
      //                     borderRadius: BorderRadius.circular(5),
      //                   ),
      //                   child: const Center(
      //                     child: Text(
      //                       'Follow',
      //                       style: TextStyle(
      //                         color: Colors.white,
      //                         fontSize: 12,
      //                         fontWeight: FontWeight.w500,
      //                       ),
      //                     ),
      //                   ),
      //                 )
      //               ],
      //             )
      //           ),
      //       ),
      //     ),
      //   ],
      // ),
    );
  }
}
