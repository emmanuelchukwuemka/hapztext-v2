import 'package:haptext_api/bloc/auth/cubit/auth_cubit.dart';
import 'package:haptext_api/common/utils.dart';
import 'package:haptext_api/exports.dart';

class ProfileTextTab extends StatelessWidget {
  const ProfileTextTab({super.key, required this.textPosts});
  final List<ResultPostModel> textPosts;
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: textPosts.length,
        itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.start, children: [
                    AppText(
                        text:
                            '@${context.watch<AuthCubit>().useInfo.username ?? ""}',
                        color: Colors.white),
                    const SizedBox(width: 5),
                    AppText(
                        text:
                            ' ${UsefulMethods.formatDate(textPosts[index].createdAt ?? DateTime.now().toString())}',
                        color: Colors.grey),
                  ]),
                  const SizedBox(height: 5),
                  AppText(
                      text: textPosts[index].textContent ?? '',
                      color: Colors.grey,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                  30.verticalSpace,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.favorite_border,
                            // color: context.theme.greyColor,
                          ),
                          AppText(
                              text: ' ${textPosts[index].likeCount ?? 0}',
                              color: Colors.white),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.chat,
                            // color: context.theme.greyColor,
                          ),
                          AppText(
                              text: ' ${textPosts[index].replyCount ?? 0}',
                              color: Colors.white),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.share,
                            // color: context.theme.greyColor,
                          ),
                          AppText(
                              text: ' ${textPosts[index].shareCount ?? 0}',
                              color: Colors.white),
                        ],
                      ),
                      // Row(
                      //   children: [
                      //     Icon(Icons.download),
                      //     AppText(text: '1', color: Colors.white),
                      //   ],
                      // ),
                    ],
                  ),
                ],
              ),
            ));
  }
}

// Widget buildText(Size size) {
//   return ListView.builder(
//       itemCount: 24,
//       itemBuilder: (context, index) => Container(
//         padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 10.0),
//         height: size.height * .22,
//         width: size.width,
//         decoration: BoxDecoration(
//           color: Colors.grey[100],
//           border: Border(
//             // top: BorderSide(color: Colors.grey.shade400, width: 0.5),
//             bottom: BorderSide(color: Colors.orange, width: 0.5),
//           ),
//         ),
//         child: Center(
//           child: Column(
//             children: [
//               SizedBox(height: 5),
//               Container(
//                 width: size.width * .9,
//                 height: size.height * .15,
//                 // color: Colors.black12,
//                 child: Column(
//                   children: [
//                     Row(
//                         mainAxisAlignment: MainAxisAlignment.start,
//                         children: [
//                           Text('Roman', style: TextStyle(color: Colors.black,),),
//                           SizedBox(width: 3.5),
//                           Text('@melody_boy1 . 17 Jul', style: TextStyle(color: Colors.grey,),),
//                         ]
//                     ),
//                     SizedBox(height: 3.5),
//                     SizedBox(
//                       child: Text(
//                         'slhsla;ihdlfhw;oeihr ssfhnskjfsfskjfks skfjskfksfns   sfjbskjfhksherne  skjkfhs ksjfhksf ksjhskjrb fksjs slshfldsjo soalsfnd shdohdof soihfshfsj oshfsiuhsjkfnsd fsukhfkls;lfhs osuhfshf suhfkd fosuhfls oshfoushf shufoshfl siosjfslih sohlsjbvihcis subslnxbv xbv,xnvl sddsf',
//                         style: TextStyle(color: Colors.grey),
//                         maxLines: 3,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               Container(
//                 width: size.width * .9,
//                 height: size.height * .03,
//                 // color: Colors.white70,
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Row(
//                       children: [
//                         Icon(Icons.favorite_border, color: Colors.grey,),
//                         Text('76', style: TextStyle(color: Colors.grey,),),
//                       ],
//                     ),
//                     Row(
//                       children: [
//                         Icon(Icons.chat, color: Colors.grey,),
//                         Text('17', style: TextStyle(color: Colors.grey,),),
//                       ],
//                     ),
//                     Row(
//                       children: [
//                         Icon(Icons.share, color: Colors.grey,),
//                         Text('5', style: TextStyle(color: Colors.grey,),),
//                       ],
//                     ),
//                     Row(
//                       children: [
//                         Icon(Icons.download, color: Colors.grey,),
//                         Text('1', style: TextStyle(color: Colors.grey,),),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       )
//   );
// }
