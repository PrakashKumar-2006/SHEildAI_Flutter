import 'package:flutter/material.dart';
import '../../../../providers/providers.dart';
import '../../data/models/feed_models.dart';

class CampaignCard extends StatelessWidget {
  final SafetyCampaign campaign;
  final ThemeProvider theme;

  const CampaignCard({
    super.key,
    required this.campaign,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: theme.surface,
            title: Row(
              children: [
                const Icon(Icons.event_available_rounded, color: Color(0xFF2E7D32)),
                const SizedBox(width: 8),
                Expanded(child: Text(campaign.title, style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold))),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 16, color: theme.textSecondary),
                    const SizedBox(width: 4),
                    Text(campaign.date, style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on_rounded, size: 16, color: theme.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(child: Text(campaign.venue, style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.w600))),
                  ],
                ),
                const SizedBox(height: 16),
                Text(campaign.description, style: TextStyle(color: theme.textPrimary, fontSize: 14)),
                const SizedBox(height: 16),
                Text("Join this community campaign to stay aware and contribute to safety.", style: TextStyle(color: theme.textSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: TextStyle(color: theme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Registered for ${campaign.title}')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Register', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: theme.border.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(
                    Icons.event_available_rounded,
                    color: Color(0xFF2E7D32),
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      campaign.title,
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 12, color: theme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          campaign.date,
                          style: TextStyle(color: theme.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.location_on_rounded, size: 12, color: theme.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            campaign.venue,
                            style: TextStyle(color: theme.textSecondary, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            campaign.description,
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Registered for ${campaign.title}')),
                );
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.accent, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                'I\'m Interested',
                style: TextStyle(color: theme.accent, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}
