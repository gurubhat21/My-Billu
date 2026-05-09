/// Validation utilities for My Billu app

class Validators {
  /// Validate Indian GSTIN format
  /// Format: 2-digit state code + 10-char PAN + 1 entity code + 1 'Z' + 1 checksum
  /// Example: 29ABCDE1234F1Z5
  static String? validateGstin(String? value) {
    if (value == null || value.trim().isEmpty) return null; // Optional field
    final gstin = value.trim().toUpperCase();
    if (gstin.length != 15) {
      return 'GSTIN must be exactly 15 characters';
    }
    // Regex: 2 digits (state) + 5 alpha + 4 digits + 1 alpha + 1 alphanumeric + 1 'Z' + 1 alphanumeric
    final regex = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[A-Z0-9]{1}Z[A-Z0-9]{1}$');
    if (!regex.hasMatch(gstin)) {
      return 'Invalid GSTIN format (e.g. 29ABCDE1234F1Z5)';
    }
    // Validate state code (01-37)
    final stateCode = int.tryParse(gstin.substring(0, 2)) ?? 0;
    if (stateCode < 1 || stateCode > 37) {
      return 'Invalid state code in GSTIN';
    }
    return null; // Valid
  }

  /// Check for duplicate item name
  static String? checkDuplicateItem(String name, List<String> existingNames, {String? editingId}) {
    if (name.trim().isEmpty) return null;
    final lower = name.trim().toLowerCase();
    final hasDuplicate = existingNames.any((n) => n.toLowerCase() == lower);
    if (hasDuplicate) {
      return 'An item named "$name" already exists';
    }
    return null;
  }

  /// Check for duplicate customer name/phone
  static String? checkDuplicateCustomer(String name, String phone, List<Map<String, String>> existing) {
    if (name.trim().isEmpty) return null;
    final lower = name.trim().toLowerCase();
    for (final c in existing) {
      if (c['name']?.toLowerCase() == lower) {
        return 'A customer named "$name" already exists';
      }
      if (phone.trim().isNotEmpty && c['phone'] == phone.trim()) {
        return 'A customer with phone "$phone" already exists';
      }
    }
    return null;
  }

  /// Check for duplicate supplier name
  static String? checkDuplicateSupplier(String name, List<String> existingNames) {
    if (name.trim().isEmpty) return null;
    final lower = name.trim().toLowerCase();
    final hasDuplicate = existingNames.any((n) => n.toLowerCase() == lower);
    if (hasDuplicate) {
      return 'A supplier named "$name" already exists';
    }
    return null;
  }

  /// Validate phone number (Indian 10-digit)
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return null; // Optional
    final phone = value.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.length != 10) {
      return 'Phone number must be 10 digits';
    }
    return null;
  }

  /// Validate email format
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null; // Optional
    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!regex.hasMatch(value.trim())) {
      return 'Invalid email format';
    }
    return null;
  }
}
