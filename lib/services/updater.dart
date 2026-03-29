import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const String _repoOwner = 'LoggeL';
const String _repoName = 'dieseldusel-app';
const String _currentVersion = '1.2.2';

class AppUpdater {
  static Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      final res = await http.get(
        Uri.parse('https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest'),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body);
      final tagName = (data['tag_name'] ?? '').toString().replaceAll('v', '');
      final assets = data['assets'] as List? ?? [];

      String? apkUrl;
      for (final asset in assets) {
        final name = asset['name']?.toString() ?? '';
        if (name.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'];
          break;
        }
      }

      if (apkUrl == null) return null;
      if (tagName == _currentVersion) return null;

      if (_isNewer(tagName, _currentVersion)) {
        return {
          'version': tagName,
          'url': apkUrl,
          'body': data['body'] ?? '',
          'name': data['name'] ?? 'Update verfügbar',
        };
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  static bool _isNewer(String remote, String local) {
    final r = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final l = local.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    while (r.length < 3) r.add(0);
    while (l.length < 3) l.add(0);
    for (int i = 0; i < 3; i++) {
      if (r[i] > l[i]) return true;
      if (r[i] < l[i]) return false;
    }
    return false;
  }

  static Future<void> showUpdateDialog(BuildContext context, Map<String, dynamic> update) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getString('dismissed_update');
    if (dismissed == update['version']) return;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update ${update['version']}'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(update['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
          if (update['body'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(update['body'], maxLines: 5, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
          ],
        ]),
        actions: [
          TextButton(
            onPressed: () {
              prefs.setString('dismissed_update', update['version']);
              Navigator.pop(ctx);
            },
            child: const Text('Später'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openDownloadUrl(context, update['url']);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50)),
            child: const Text('Jetzt updaten'),
          ),
        ],
      ),
    );
  }

  /// Opens the APK download URL in the browser — Android handles the download + install prompt
  static Future<void> _openDownloadUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: try without check
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Konnte Browser nicht öffnen: $e')),
        );
      }
    }
  }
}
