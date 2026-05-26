import 'package:flutter/material.dart';
import 'package:haptext_api/views/Bottom_Nav/exports.dart';
import 'package:haptext_api/common/theme/custom_theme_extension.dart';
import 'package:haptext_api/widgets/app_text.dart';
import '../../../common/search.dart';

class Explore extends StatelessWidget {
  const Explore({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
        length: 3,
        child: Scaffold(
            backgroundColor: context.theme.bgColor,
            appBar: AppBar(
                automaticallyImplyLeading: false,
                iconTheme: IconThemeData(color: context.theme.primaryColor),
                title: AppText(
                    text: '  Explore',
                    fontSize: 18,
                    color: context.theme.primaryColor,
                    fontWeight: FontWeight.bold),
                backgroundColor: context.theme.appBarColor,
                elevation: 0,
                actions: [
                  IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const Search()),
                        );
                      },
                      icon: const Icon(Icons.search, size: 28),
                      color: context.theme.primaryColor),
                  IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const Live()),
                        );
                      },
                      icon: const Icon(Icons.sensors, size: 28),
                      tooltip: 'Go Live',
                      color: Colors.redAccent),
                  const SizedBox(width: 8.0),
                ],
                bottom: TabBar(
                    indicatorColor: context.theme.primaryColor,
                    labelColor: context.theme.primaryColor,
                    unselectedLabelColor: context.theme.greyColor,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: const [
                      Tab(text: 'Explore'),
                      Tab(text: 'Livestream'),
                      Tab(text: 'Discover')
                    ])),
            body: const TabBarView(
                children: [XploreTab1(), LiveStreamApp(), XploreTab3()])));
  }
}
