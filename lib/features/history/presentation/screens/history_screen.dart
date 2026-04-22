import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/card_widget.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  // Mock data for SOS history
  final List<SOSHistoryItem> _historyItems = const [
    SOSHistoryItem(
      date: 'Apr 22, 2026',
      time: '2:30 PM',
      location: 'Connaught Place, New Delhi',
      status: 'Cancelled',
      latitude: 28.6315,
      longitude: 77.2167,
    ),
    SOSHistoryItem(
      date: 'Apr 15, 2026',
      time: '10:45 AM',
      location: 'Sector 18, Noida',
      status: 'Resolved',
      latitude: 28.5707,
      longitude: 77.3279,
    ),
    SOSHistoryItem(
      date: 'Apr 10, 2026',
      time: '8:15 PM',
      location: 'Rajouri Garden, Delhi',
      status: 'Cancelled',
      latitude: 28.6452,
      longitude: 77.1158,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: const CustomAppBar(
        title: 'SOS History',
      ),
      body: _historyItems.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              itemCount: _historyItems.length,
              itemBuilder: (context, index) {
                return _buildHistoryCard(_historyItems[index]);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: AppColors.grey300,
          ),
          const SizedBox(height: AppTheme.spacingL),
          Text(
            'No SOS History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Your SOS alerts will appear here',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(SOSHistoryItem item) {
    final statusColor = item.status == 'Resolved'
        ? AppColors.success
        : AppColors.textSecondary;
    final statusBgColor = item.status == 'Resolved'
        ? AppColors.successContainer
        : AppColors.grey200;

    return CardWidget(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date and Time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.date,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                item.time,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),
          // Location
          Row(
            children: [
              const Icon(
                Icons.location_on,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppTheme.spacingXS),
              Expanded(
                child: Text(
                  item.location,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),
          // Coordinates
          Row(
            children: [
              const Icon(
                Icons.place,
                size: 16,
                color: AppColors.textHint,
              ),
              const SizedBox(width: AppTheme.spacingXS),
              Text(
                '${item.latitude.toStringAsFixed(4)}, ${item.longitude.toStringAsFixed(4)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),
          // Status
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingM,
              vertical: AppTheme.spacingXS,
            ),
            decoration: BoxDecoration(
              color: statusBgColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            child: Text(
              item.status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SOSHistoryItem {
  final String date;
  final String time;
  final String location;
  final String status;
  final double latitude;
  final double longitude;

  const SOSHistoryItem({
    required this.date,
    required this.time,
    required this.location,
    required this.status,
    required this.latitude,
    required this.longitude,
  });
}
