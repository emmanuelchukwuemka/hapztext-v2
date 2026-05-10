import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:haptext_api/common/theme/custom_theme_extension.dart';

class SeeAll extends StatefulWidget {
  const SeeAll({super.key});

  @override
  State<SeeAll> createState() => _SeeAllState();
}

class _SeeAllState extends State<SeeAll> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: context.theme.bgColor,
        appBar: AppBar(
          backgroundColor: context.theme.bgColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          title: Text(
            '@Roman Fortune',
            style: GoogleFonts.roboto(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom:
                      BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                ),
              ),
              child: TabBar(
                isScrollable: true,
                indicator: const UnderlineTabIndicator(
                  borderSide: BorderSide(width: 3, color: Color(0xFF8B5CF6)),
                  insets: EdgeInsets.symmetric(horizontal: 16),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                labelStyle: GoogleFonts.roboto(
                    fontWeight: FontWeight.bold, fontSize: 13),
                unselectedLabelStyle: GoogleFonts.roboto(
                    fontWeight: FontWeight.w500, fontSize: 13),
                tabs: const [
                  Tab(text: 'Photos'),
                  Tab(text: 'Videos'),
                  Tab(text: 'Audios'),
                  Tab(text: 'Texts'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            buildContainer(size),
            buildContainer(size),
            _buildAudioGrid(size),
            buildText(size, context),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioGrid(Size size) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 13,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12.0,
        mainAxisSpacing: 12.0,
        childAspectRatio: 1.0,
      ),
      itemBuilder: (context, index) => Container(
        decoration: BoxDecoration(
          color: context.theme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: const Center(
          child: Icon(Icons.audiotrack, color: Color(0xFF8B5CF6), size: 32),
        ),
      ),
    );
  }
}

Widget buildContainer(Size size) {
  return GridView.builder(
    padding: const EdgeInsets.all(12),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      crossAxisSpacing: 8.0,
      mainAxisSpacing: 8.0,
      childAspectRatio: 1.0,
    ),
    itemCount: 17,
    itemBuilder: (context, index) => ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: const Image(
        image: AssetImage('assets/images/placeholder.jpg'),
        fit: BoxFit.cover,
      ),
    ),
  );
}

Widget buildText(Size size, BuildContext context) {
  return ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: 24,
    itemBuilder: (context, index) => Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.theme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Fortune',
                style: GoogleFonts.roboto(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Text(
                '@paramount • 03 Feb',
                style: GoogleFonts.roboto(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'This is a modern text post with premium styling. It fits perfectly within the new design system of SocialConnect.',
            style: GoogleFonts.roboto(
                color: Colors.white70, fontSize: 14, height: 1.5),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetric(Icons.favorite_border, '26k'),
              _buildMetric(Icons.chat_bubble_outline, '5.2k'),
              _buildMetric(Icons.share_outlined, '2k'),
              _buildMetric(Icons.download_outlined, '1.2k'),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _buildMetric(IconData icon, String value) {
  return Row(
    children: [
      Icon(icon, color: Colors.white38, size: 16),
      const SizedBox(width: 4),
      Text(
        value,
        style: GoogleFonts.roboto(color: Colors.white38, fontSize: 12),
      ),
    ],
  );
}
