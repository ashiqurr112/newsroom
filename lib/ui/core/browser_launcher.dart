import 'dart:io';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class BrowserLauncher {
  static const MethodChannel _channel = MethodChannel('newsroom/browser_launcher');

  /// Launches a URL using Quetta Browser package on Android,
  /// falling back to the default browser if not installed or on other platforms.
  static Future<void> launchArticle(String urlString) async {
    final uri = Uri.parse(urlString);

    // Guard Platform checks for testing environments where dart:io Platform can throw or behave differently
    bool isAndroid = false;
    try {
      isAndroid = Platform.isAndroid;
    } catch (_) {
      // Fallback if Platform is not available
    }

    if (isAndroid) {
      try {
        final bool? success = await _channel.invokeMethod<bool>('launchQuetta', {'url': urlString});
        if (success == true) {
          return; // Successfully opened with Quetta Browser
        }
      } catch (e) {
        // Fallback on exception
      }
    }

    // Fallback: Open with default browser
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      try {
        await launchUrl(uri);
      } catch (e2) {
        print('Error launching URL: $e2');
      }
    }
  }
}
