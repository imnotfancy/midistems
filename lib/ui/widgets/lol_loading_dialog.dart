import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/lol_taglines.dart';

class LolLoadingDialog extends StatefulWidget {
  final String title;
  final Duration messageInterval;
  final List<String> messages;
  final String? errorMessage;
  final VoidCallback? onClose;

  const LolLoadingDialog({
    super.key,
    required this.title,
    required this.messages,
    this.messageInterval = const Duration(seconds: 3),
    this.errorMessage,
    this.onClose,
  });

  @override
  _LolLoadingDialogState createState() => _LolLoadingDialogState();
}

class _LolLoadingDialogState extends State<LolLoadingDialog> {
  late Timer _timer;
  int _currentMessageIndex = 0;

  @override
  void initState() {
    super.initState();
    // Cycle through the messages periodically
    _timer = Timer.periodic(widget.messageInterval, (timer) {
      setState(() {
        _currentMessageIndex = (_currentMessageIndex + 1) % widget.messages.length;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _launchUrl(String domain) async {
    final url = Uri.parse('https://$domain');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $domain')),
        );
      }
    }
  }

  Widget _buildMessage(String message, ThemeData theme) {
    if (message.contains('=>')) {
      final domain = getDomain(message);
      final text = getMessage(message);
      
      return RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          children: [
            TextSpan(
              text: domain,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.lightBlueAccent,
                decoration: TextDecoration.underline,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => _launchUrl(domain),
            ),
            TextSpan(
              text: ' => $text',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white70,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return Text(
      message,
      textAlign: TextAlign.center,
      style: theme.textTheme.titleMedium?.copyWith(
        color: Colors.white70,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = widget.errorMessage != null;

    return Dialog(
      elevation: 10,
      backgroundColor: Colors.black87,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: IntrinsicHeight(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 16),
              if (!hasError) ...[
                // Custom progress indicator
                const _LolProgressIndicator(),
                const SizedBox(height: 16),
                // The rotating message with clickable domain
                _buildMessage(widget.messages[_currentMessageIndex], theme),
              ] else ...[
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.errorMessage!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: widget.onClose ?? () => Navigator.of(context).pop(),
                  child: Text(
                    'Close',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              if (!hasError) ...[
                const SizedBox(height: 16),
                Text(
                  'A proud product of the lol multiverse!',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
                ),
                TextButton(
                  onPressed: () => _launchUrl('loltiverse.com/lol'),
                  child: Text(
                    'Visit loltiverse.com/lol',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.lightBlueAccent,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A custom progress indicator that stands out visually.
class _LolProgressIndicator extends StatelessWidget {
  const _LolProgressIndicator();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      width: 50,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 6,
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.pinkAccent,
            ),
            backgroundColor: Colors.white24,
          ),
          const Icon(
            Icons.tag_faces,
            color: Colors.pinkAccent,
            size: 24,
          ),
        ],
      ),
    );
  }
}