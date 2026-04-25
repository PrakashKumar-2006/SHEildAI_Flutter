import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// SmsTestScreen — Isolated smoke-test UI for SmsHelper.
///
/// Calls the native "testSMS" method on the [_channel] MethodChannel.
/// Zero SOSManager involvement — purely tests [SmsHelper.sendSMS] in isolation.
///
/// Usage:
///   Navigator.push(context, MaterialPageRoute(builder: (_) => const SmsTestScreen()));
///
/// Remove or gate this screen behind a debug flag before production release.
class SmsTestScreen extends StatefulWidget {
  const SmsTestScreen({super.key});

  @override
  State<SmsTestScreen> createState() => _SmsTestScreenState();
}

class _SmsTestScreenState extends State<SmsTestScreen> {
  static const MethodChannel _channel =
      MethodChannel('com.nexus.sheildai/sms_test');

  /// Optional overrides — leave empty to use SMSTestConfig defaults on Android side.
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();

  String _status = 'Idle — tap the button to send a test SMS';
  bool _isSending = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // ─── Channel call ─────────────────────────────────────────────────────────

  Future<void> _sendTestSms() async {
    setState(() {
      _isSending = true;
      _status = 'Sending...';
    });

    try {
      // Pass optional overrides — Android defaults to SMSTestConfig if empty.
      final args = <String, String>{};
      if (_phoneController.text.trim().isNotEmpty) {
        args['phone'] = _phoneController.text.trim();
      }
      if (_messageController.text.trim().isNotEmpty) {
        args['message'] = _messageController.text.trim();
      }

      final result = await _channel.invokeMethod<String>('testSMS', args);

      setState(() {
        _status = result == 'sent'
            ? '✅ SMS dispatched — check logcat for delivery confirmation'
            : '❌ SMS failed — check logcat (permission missing or invalid number)';
      });
    } on PlatformException catch (e) {
      setState(() {
        _status = '❌ PlatformException: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Unexpected error: $e';
      });
    } finally {
      setState(() => _isSending = false);
    }
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Smoke Test'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Info banner ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                border: Border.all(color: Colors.deepPurple.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'This screen tests SmsHelper.sendSMS() directly.\n'
                'SOSManager is NOT involved.\n'
                'Leave fields empty to use the defaults in SMSTestConfig.kt.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
            const SizedBox(height: 24),

            // ── Phone number override ──────────────────────────────────────
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number (optional override)',
                hintText: '+91XXXXXXXXXX',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // ── Message override ───────────────────────────────────────────
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message (optional override)',
                hintText: 'Leave blank to use default test message',
                prefixIcon: Icon(Icons.message),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),

            // ── Send button ────────────────────────────────────────────────
            ElevatedButton.icon(
              onPressed: _isSending ? null : _sendTestSms,
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
              label: Text(_isSending ? 'Sending...' : 'Send Test SMS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),

            // ── Status display ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _statusColor().withOpacity(0.08),
                border: Border.all(color: _statusColor().withOpacity(0.4)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_statusIcon(), color: _statusColor(), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _status,
                      style: TextStyle(
                        fontSize: 14,
                        color: _statusColor(),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Logcat hint ────────────────────────────────────────────────
            Text(
              'Monitor logcat with:\nadb logcat -s SmsHelper MainActivity',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor() {
    if (_status.startsWith('✅')) return Colors.green.shade700;
    if (_status.startsWith('❌')) return Colors.red.shade700;
    if (_status.startsWith('Sending')) return Colors.orange.shade700;
    return Colors.grey.shade700;
  }

  IconData _statusIcon() {
    if (_status.startsWith('✅')) return Icons.check_circle_outline;
    if (_status.startsWith('❌')) return Icons.error_outline;
    if (_status.startsWith('Sending')) return Icons.hourglass_top;
    return Icons.info_outline;
  }
}
