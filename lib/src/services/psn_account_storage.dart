import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Service for storing and retrieving PSN Account ID
class PSNAccountStorage {
  static const String _keyPsnAccountId = 'psn_account_id';

  /// Save PSN Account ID to storage
  /// The account ID should be Base64 encoded (8 bytes)
  static Future<void> savePSNAccountId(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPsnAccountId, accountId);
  }

  /// Get PSN Account ID from storage
  /// Returns null if not found
  static Future<String?> getPSNAccountId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPsnAccountId);
  }

  /// Clear stored PSN Account ID
  static Future<void> clearPSNAccountId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPsnAccountId);
  }

  /// Validate PSN Account ID format
  /// PSN Account ID should be Base64 encoded (represents 8 bytes of data)
  /// Valid Base64 for 8 bytes should be either 11 or 12 characters
  /// (depending on padding)
  static bool isValidPSNAccountId(String accountId) {
    if (accountId.isEmpty) {
      return false;
    }

    // Try to decode as Base64
    try {
      final decoded = base64.decode(accountId);
      // PSN Account ID should be exactly 8 bytes
      return decoded.length == 8;
    } catch (e) {
      return false;
    }
  }

  /// Get default/placeholder PSN Account ID
  /// This is used when no account ID is configured
  /// Returns Base64 encoded 8 bytes of zeros: AAAAAAAAAAA=
  static String getDefaultAccountId() {
    // 8 bytes of zeros, Base64 encoded
    return base64.encode(List.filled(8, 0));
  }
}
