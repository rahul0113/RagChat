import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Global error handler that shows error popups across the entire app.
class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._();
  factory ErrorHandler() => _instance;
  ErrorHandler._();

  /// Show an error popup with title, message, and stack trace.
  static void showError(BuildContext context, {
    required String title,
    required String message,
    String? details,
    String? stackTrace,
    VoidCallback? onRetry,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final subtextColor = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final bgColor = isDark ? AppTheme.card : AppTheme.lightCard;
    final borderColor = isDark ? AppTheme.border : AppTheme.lightBorder;
    final surfaceBg = isDark ? AppTheme.surface : AppTheme.lightSurface;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.error.withOpacity(0.3)),
        ),
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, style: TextStyle(color: textColor, fontSize: 14)),
              if (details != null && details.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                  ),
                  child: Text(details, style: TextStyle(color: subtextColor, fontSize: 12, fontFamily: 'monospace')),
                ),
              ],
              if (stackTrace != null && stackTrace.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Stack Trace:', style: TextStyle(color: subtextColor, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 150),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.error.withOpacity(0.2)),
                  ),
                  child: SingleChildScrollView(
                    child: Text(stackTrace, style: TextStyle(color: subtextColor, fontSize: 10, fontFamily: 'monospace')),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () { Navigator.pop(ctx); onRetry(); },
              child: const Text('Retry'),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show a network error popup.
  static void showNetworkError(BuildContext context, {String? details, VoidCallback? onRetry}) {
    showError(
      context,
      title: 'Network Error',
      message: 'Could not connect to the server. Please check your internet connection and try again.',
      details: details,
      onRetry: onRetry,
    );
  }

  /// Show a server error popup.
  static void showServerError(BuildContext context, {String? details, VoidCallback? onRetry}) {
    showError(
      context,
      title: 'Server Error',
      message: 'The server encountered an error. Please try again later.',
      details: details,
      onRetry: onRetry,
    );
  }

  /// Show a validation error popup.
  static void showValidationError(BuildContext context, {required String field, required String message}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final surfaceBg = isDark ? AppTheme.surface : AppTheme.lightSurface;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$field: $message'),
        backgroundColor: AppTheme.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Wrap an async operation with error handling.
  static Future<T?> safeCall<T>(
    BuildContext context,
    Future<T> Function() operation, {
    String? title,
    VoidCallback? onRetry,
  }) async {
    try {
      return await operation();
    } catch (e, stackTrace) {
      if (context.mounted) {
        String errorMsg = e.toString();
        String errorTitle = title ?? 'Error';

        if (errorMsg.contains('SocketException') || errorMsg.contains('Connection refused')) {
          showNetworkError(context, details: errorMsg, onRetry: onRetry);
        } else if (errorMsg.contains('TimeoutException')) {
          showError(
            context,
            title: 'Timeout',
            message: 'The request took too long. Please try again.',
            details: errorMsg,
            onRetry: onRetry,
          );
        } else {
          showError(
            context,
            title: errorTitle,
            message: errorMsg,
            stackTrace: stackTrace.toString(),
            onRetry: onRetry,
          );
        }
      }
      return null;
    }
  }
}
