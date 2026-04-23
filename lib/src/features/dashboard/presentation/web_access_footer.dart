import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class WebAccessFooter extends StatelessWidget {
  const WebAccessFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      color: Colors.grey.shade50,
      child: Column(
        children: [
          const Divider(),
          const SizedBox(height: 20),
          const Text(
            'بإمكانك استخدام الموقع الإلكتروني أيضاً',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => launchUrl(Uri.parse('https://getmanar.com/')),
            child: const Text(
              'https://getmanar.com/',
              style: TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          const SizedBox(height: 10),
          QrImageView(
            data: 'https://getmanar.com/',
            version: QrVersions.auto,
            size: 100.0,
            backgroundColor: Colors.white,
          ),
          const SizedBox(height: 20),
          if (kDebugMode) ...[
            const Divider(),
            TextButton.icon(
              onPressed: () => context.push('/dev-progress'),
              icon: const Icon(Icons.developer_mode, color: Colors.red),
              label: const Text(
                'Dev Progress (Debug Only)',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
