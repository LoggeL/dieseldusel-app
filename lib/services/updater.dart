import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

const String _repoOwner = 'LoggeL';
const String _repoName = 'dieseldusel-app';
const String currentVersion = '1.9.1';

enum UpdateCheckStatus {
  upToDate,
  updateAvailable,
  networkError,
  noRelease,
}

class UpdateCheckResult {
  final UpdateCheckStatus status;
  final Map<String, dynamic>? update;
  final String? latestVersion;
  final String? errorMessage;

  const UpdateCheckResult({
    required this.status,
    this.update,
    this.latestVersion,
    this.errorMessage,
  });
}

class AppUpdater {
  static Future<UpdateCheckResult> checkForUpdate() async {
    try {
      final res = await http
          .get(
            Uri.parse(
                'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest'),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 404) {
        return const UpdateCheckResult(
          status: UpdateCheckStatus.noRelease,
          errorMessage: 'Kein Release auf GitHub gefunden',
        );
      }

      if (res.statusCode != 200) {
        return UpdateCheckResult(
          status: UpdateCheckStatus.networkError,
          errorMessage: 'GitHub API Fehler (${res.statusCode})',
        );
      }

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

      if (apkUrl == null) {
        return UpdateCheckResult(
          status: UpdateCheckStatus.noRelease,
          latestVersion: tagName,
          errorMessage: 'Keine APK in neuestem Release gefunden',
        );
      }

      if (_isNewer(tagName, currentVersion)) {
        return UpdateCheckResult(
          status: UpdateCheckStatus.updateAvailable,
          latestVersion: tagName,
          update: {
            'version': tagName,
            'url': apkUrl,
            'body': data['body'] ?? '',
            'name': data['name'] ?? 'Update verfügbar',
          },
        );
      }

      return UpdateCheckResult(
        status: UpdateCheckStatus.upToDate,
        latestVersion: tagName,
      );
    } on SocketException {
      return const UpdateCheckResult(
        status: UpdateCheckStatus.networkError,
        errorMessage: 'Keine Internetverbindung',
      );
    } catch (e) {
      return UpdateCheckResult(
        status: UpdateCheckStatus.networkError,
        errorMessage: 'Fehler: $e',
      );
    }
  }

  static bool _isNewer(String remote, String local) {
    final r = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final l = local.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    while (r.length < 3) { r.add(0); }
    while (l.length < 3) { l.add(0); }
    for (int i = 0; i < 3; i++) {
      if (r[i] > l[i]) return true;
      if (r[i] < l[i]) return false;
    }
    return false;
  }

  static Future<void> showUpdateDialog(
      BuildContext context, Map<String, dynamic> update) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getString('dismissed_update');
    if (dismissed == update['version']) return;
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update ${update['version']}'),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(update['name'],
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              if (update['body'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(update['body'],
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13)),
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
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openBrowserDownload(context, update['url']);
            },
            child: const Text('APK im Browser'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _downloadAndInstall(context, update['url'], update['version']);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50)),
            child: const Text('Jetzt updaten'),
          ),
        ],
      ),
    );
  }

  static Future<void> _downloadAndInstall(
      BuildContext context, String url, String version) async {
    if (!context.mounted) return;

    final progressNotifier = ValueNotifier<double>(0);
    final statusNotifier = ValueNotifier<String>('Verbinde...');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Update wird geladen'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          ValueListenableBuilder<String>(
            valueListenable: statusNotifier,
            builder: (_, status, __) =>
                Text(status, style: const TextStyle(color: Colors.white70)),
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<double>(
            valueListenable: progressNotifier,
            builder: (_, progress, __) => Column(children: [
              LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  color: const Color(0xFF4CAF50)),
              const SizedBox(height: 8),
              Text(progress > 0 ? '${(progress * 100).toInt()}%' : '...',
                  style: const TextStyle(fontSize: 12)),
            ]),
          ),
        ]),
      ),
    );

    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await http.Client().send(request);
      final totalBytes = response.contentLength ?? 0;
      final bytes = <int>[];
      int received = 0;

      statusNotifier.value = 'Lade APK herunter...';

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        received += chunk.length;
        if (totalBytes > 0) {
          progressNotifier.value = received / totalBytes;
        }
        statusNotifier.value =
            '${(received / 1024 / 1024).toStringAsFixed(1)} MB geladen';
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/dieseldusel-$version.apk');
      await file.writeAsBytes(bytes);

      statusNotifier.value = 'Installiere...';

      if (context.mounted) Navigator.pop(context);

      final result = await OpenFilex.open(file.path,
          type: 'application/vnd.android.package-archive');

      if (result.type != ResultType.done && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Installation: ${result.message}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download fehlgeschlagen: $e')),
        );
      }
    }
  }

  static Future<void> _openBrowserDownload(
      BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('APK-Link ist ungültig')),
        );
      }
      return;
    }

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Browser konnte nicht geöffnet werden')),
      );
    }
  }
}
