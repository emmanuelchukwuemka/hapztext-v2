import 'package:flutter/material.dart';
import 'package:haptext_api/common/coloors.dart';
import 'package:haptext_api/common/theme/custom_theme_extension.dart';

class PostAnalyticsPanel extends StatelessWidget {
  const PostAnalyticsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: context.theme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "📊 Post Analytics",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Coloors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.circle, color: Coloors.error, size: 8),
                    const SizedBox(width: 4),
                    const Text("15 LIVE",
                        style: TextStyle(
                            color: Coloors.error,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Performance Score
          const Align(
            alignment: Alignment.centerLeft,
            child: Text("Performance Score: 87%",
                style: TextStyle(color: Colors.white70, fontSize: 14)),
          ),
          const SizedBox(height: 8),
          _buildProgressBar(0.87),
          const SizedBox(height: 4),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text("🔥 Viral content!",
                style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 24),

          // Metrics Grid
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            childAspectRatio: 1.5,
            children: const [
              _MetricCard(
                  icon: Icons.remove_red_eye_outlined,
                  count: "0",
                  label: "Views",
                  trend: ""),
              _MetricCard(
                  icon: Icons.favorite_border,
                  count: "0",
                  label: "Likes",
                  trend: ""),
              _MetricCard(
                  icon: Icons.repeat, count: "0", label: "Shares", trend: ""),
              _MetricCard(
                  icon: Icons.chat_bubble_outline,
                  count: "0",
                  label: "Comments",
                  trend: ""),
              _MetricCard(
                  icon: Icons.mic_none, count: "0", label: "Voice", trend: ""),
              _MetricCard(
                  icon: Icons.tag, count: "-", label: "Top Tag", trend: ""),
            ],
          ),
          const SizedBox(height: 24),

          // Live Activity
          const Align(
            alignment: Alignment.centerLeft,
            child: Text("⚡ Live Activity:",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          _buildActivityItem("Someone liked", "now"),
          _buildActivityItem("Someone shared", "now"),
          _buildActivityItem("Someone sent voice note", "now"),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildProgressBar(double value) {
    return Container(
      height: 8,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(4),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Coloors.primaryStart, Coloors.primaryEnd]),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityItem(String text, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const CircleAvatar(radius: 3, backgroundColor: Coloors.primaryStart),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const Spacer(),
          Text(time,
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String count;
  final String label;
  final String trend;

  const _MetricCard(
      {required this.icon,
      required this.count,
      required this.label,
      required this.trend});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white38, size: 16),
            const SizedBox(width: 4),
            Text(count,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
        Text(trend,
            style: const TextStyle(
                color: Coloors.success,
                fontSize: 10,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}
