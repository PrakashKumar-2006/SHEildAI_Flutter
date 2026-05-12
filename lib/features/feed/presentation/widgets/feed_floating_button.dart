import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/providers.dart';
import '../providers/feed_provider.dart';
import '../../data/models/feed_models.dart';
import 'video_card.dart';
import 'safety_tip_card.dart';
import 'campaign_card.dart';

class FeedFloatingButton extends StatefulWidget {
  const FeedFloatingButton({super.key});

  @override
  State<FeedFloatingButton> createState() => _FeedFloatingButtonState();
}

class _FeedFloatingButtonState extends State<FeedFloatingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _openFeed(BuildContext context) {
    // Refresh data on each open
    context.read<FeedProvider>().refresh();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const FeedSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 140,
      right: 18,
      child: ScaleTransition(
        scale: _pulseAnimation,
        child: GestureDetector(
          onTap: () => _openFeed(context),
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFF00CEC9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C5CE7).withOpacity(0.45),
                  blurRadius: 16,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.newspaper_rounded, color: Colors.white, size: 24),
                // Notification dot
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Public: used by both the floating button and the Explore Feed card on Home screen.
class FeedSheet extends StatefulWidget {
  const FeedSheet();

  @override
  State<FeedSheet> createState() => FeedSheetState();
}

class FeedSheetState extends State<FeedSheet> {
  int _videoIndex = 0;
  Timer? _autoSwipeTimer;
  final PageController _videoPageController = PageController(viewportFraction: 0.9);

  @override
  void initState() {
    super.initState();
    // Auto-swipe videos every 5 seconds
    _autoSwipeTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final feed = context.read<FeedProvider>();
      if (feed.videos.isEmpty) return;
      setState(() {
        _videoIndex = (_videoIndex + 1) % feed.videos.length;
      });
      _videoPageController.animateToPage(
        _videoIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoSwipeTimer?.cancel();
    _videoPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final feed = context.watch<FeedProvider>();

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      snap: true,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle + Header
              _buildSheetHeader(context, theme),
              // Content
              Expanded(
                child: feed.isLoading
                    ? Center(
                        child: CircularProgressIndicator(color: theme.accent),
                      )
                    : SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.only(bottom: 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Today's Top Awareness Videos (auto-swiping)
                            _buildVideosSection(theme, feed),
                            const SizedBox(height: 8),
                            // 2. General Safety Alerts
                            _buildAlertsSection(theme, feed),
                            // 3. Daily Safety Tips
                            _buildTipsSection(theme, feed),
                            // 4. Local Campaigns & Events
                            _buildCampaignsSection(theme, feed),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetHeader(BuildContext context, ThemeProvider theme) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: theme.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C5CE7), Color(0xFF00CEC9)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.newspaper_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Safety Feed',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'Stay informed & stay safe',
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close_rounded,
                      color: theme.textSecondary, size: 20),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Divider(color: theme.border, height: 1),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildVideosSection(ThemeProvider theme, FeedProvider feed) {
    if (feed.videos.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C5CE7), Color(0xFF00CEC9)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "Today's Top Awareness Videos",
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              // Page indicator
              Row(
                children: List.generate(feed.videos.length > 5 ? 5 : feed.videos.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(left: 4),
                    width: _videoIndex == i ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _videoIndex == i
                          ? const Color(0xFF6C5CE7)
                          : theme.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 230,
          child: PageView.builder(
            controller: _videoPageController,
            itemCount: feed.videos.length,
            onPageChanged: (i) => setState(() => _videoIndex = i),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: VideoCard(video: feed.videos[index], theme: theme),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAlertsSection(ThemeProvider theme, FeedProvider feed) {
    if (feed.alerts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('General Safety Alerts', theme),
          const SizedBox(height: 12),
          ...feed.alerts.map<Widget>((StaticSafetyAlert alert) {
            final Color severityColor = alert.severity == 'high'
                ? const Color(0xFFC62828)
                : (alert.severity == 'medium'
                    ? Colors.orange
                    : Colors.amber);
            return GestureDetector(
              onTap: () => _showAlertDetail(alert, severityColor, theme),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border(
                      left: BorderSide(color: severityColor, width: 4)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4)
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: severityColor, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(alert.title,
                              style: TextStyle(
                                  color: theme.textPrimary,
                                  fontWeight: FontWeight.w700)),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: theme.textSecondary, size: 18),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(alert.description,
                        style: TextStyle(
                            color: theme.textSecondary, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 12, color: theme.textSecondary),
                        const SizedBox(width: 4),
                        Text(alert.location,
                            style: TextStyle(
                                color: theme.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  void _showAlertDetail(
      StaticSafetyAlert alert, Color color, ThemeProvider theme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: color),
            const SizedBox(width: 8),
            Expanded(
                child: Text(alert.title,
                    style: TextStyle(
                        color: theme.textPrimary,
                        fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on_rounded,
                    size: 16, color: theme.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(alert.location,
                        style: TextStyle(
                            color: theme.textSecondary,
                            fontWeight: FontWeight.w600))),
              ],
            ),
            const SizedBox(height: 12),
            Text(alert.description,
                style: TextStyle(color: theme.textPrimary, fontSize: 14)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Close', style: TextStyle(color: theme.accent)),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsSection(ThemeProvider theme, FeedProvider feed) {
    if (feed.tips.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: _sectionTitle('Daily Safety Tips', theme),
        ),
        SizedBox(
          height: 165,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: feed.tips.length,
            itemBuilder: (context, index) {
              return SafetyTipCard(tip: feed.tips[index], theme: theme);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCampaignsSection(ThemeProvider theme, FeedProvider feed) {
    if (feed.campaigns.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Local Campaigns & Events', theme),
          const SizedBox(height: 12),
          ...feed.campaigns.map<Widget>(
            (SafetyCampaign campaign) =>
                CampaignCard(campaign: campaign, theme: theme),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, ThemeProvider theme) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C5CE7), Color(0xFF00CEC9)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
