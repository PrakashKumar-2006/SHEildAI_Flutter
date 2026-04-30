import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/crowd_density_service.dart';
import '../../providers/providers.dart';

class CrowdRiskIndicator extends StatefulWidget {
  const CrowdRiskIndicator({super.key});

  @override
  State<CrowdRiskIndicator> createState() => _CrowdRiskIndicatorState();
}

class _CrowdRiskIndicatorState extends State<CrowdRiskIndicator> {
  final CrowdDensityService _service = CrowdDensityService();
  CrowdDensityResult? _result;
  bool _isLoading = false;
  double? _lastLat;
  double? _lastLon;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final safety = context.watch<SafetyProvider>();
    final lat = safety.latitude;
    final lon = safety.longitude;

    if (lat != null && lon != null) {
      if (_lastLat == null || _lastLon == null || 
          (lat - _lastLat!).abs() > 0.001 || (lon - _lastLon!).abs() > 0.001) {
        _lastLat = lat;
        _lastLon = lon;
        _fetchDensity(lat, lon);
      }
    }
  }

  Future<void> _fetchDensity(double lat, double lon) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final result = await _service.getDensityScore(lat, lon);

      if (mounted) {
        setState(() {
          _result = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[CrowdRisk] Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(color: theme.accent),
              const SizedBox(height: 8),
              Text(
                "Analyzing nearby activity...",
                style: TextStyle(color: theme.textSecondary, fontSize: 10),
              ),
            ],
          ),
        ),
      );
    }

    if (_result == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.border.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Icon(Icons.location_searching, color: theme.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Waiting for location and safety data...",
                style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    if (_result!.densityLevel == 'API Error') {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.isDarkMode ? const Color(0xFF2D1B1B) : const Color(0xFFFFF1F1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Safety Data Unavailable: ${_result!.errorMessage ?? 'Check connection'}",
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      final safety = context.read<SafetyProvider>();
                      if (safety.latitude != null && safety.longitude != null) {
                        _fetchDensity(safety.latitude!, safety.longitude!);
                      }
                    },
                    child: const Text(
                      "TAP TO RETRY",
                      style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.w900, decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final bool isSafe = _result!.riskScore < 30;
    final bool isWarning = _result!.riskScore >= 30 && _result!.riskScore < 60;
    final Color statusColor = isSafe 
        ? const Color(0xFF43A047) 
        : (isWarning ? const Color(0xFFFBC02D) : const Color(0xFFD32F2F));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: statusColor.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSafe ? Icons.shield_rounded : Icons.warning_rounded,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSafe ? "AREA IS SAFE" : "HIGH RISK AREA",
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      isSafe ? "People & Activity Detected" : "Isolated Environment Detected",
                      style: TextStyle(color: theme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "${_result!.riskScore.toInt()}% Risk",
                  style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          if (_result!.detectedPlaces.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            Text(
              "NEARBY ACTIVITY POINTS:",
              style: TextStyle(
                color: theme.textSecondary.withOpacity(0.7),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _result!.detectedPlaces.take(8).map((place) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on, size: 12, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        place,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          color: theme.textPrimary.withOpacity(0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ] else ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: theme.textSecondary.withOpacity(0.5)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "No major activity points found in this immediate area.",
                    style: TextStyle(
                      color: theme.textSecondary.withOpacity(0.6),
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
