import 'package:path/path.dart' as p;

/// Security exceptions thrown by [FileSecurityGuard].
class FileSecurityException implements Exception {
  final String message;
  const FileSecurityException(this.message);

  @override
  String toString() => 'FileSecurityException: $message';
}

/// Comprehensive File Receive Security Guard for MESH.
/// Provides defenses against:
/// 1. Path traversal attacks (relative `..`, URL-encoded `%2e%2e`, `%2f`, `%5c`, Windows drive letters).
/// 2. Dangerous double extensions (`.pdf.exe`, `.jpg.vbs`, `.png.bat`, etc.).
/// 3. Directional spoofing / RTLO (Right-to-Left Override) attacks.
/// 4. Boundary jail breakout.
/// 5. Executable MIME spoofing (Magic bytes check).
/// 6. Zip bomb and excessive compression ratio attacks.
class FileSecurityGuard {
  const FileSecurityGuard._();

  static const List<String> _directionalSpoofingChars = [
    '\u202E', // Right-to-Left Override (RLO)
    '\u202D', // Left-to-Right Override (LRO)
    '\u202B', // Right-to-Left Embedding (RLE)
    '\u202A', // Left-to-Right Embedding (LRE)
    '\u202C', // Pop Directional Formatting (PDF)
    '\u2066', // Left-to-Right Isolate (LRI)
    '\u2067', // Right-to-Left Isolate (RLI)
    '\u2068', // First Strong Isolate (FSI)
    '\u2069', // Pop Directional Isolate (PDI)
    '\u200E', // Left-to-Right Mark (LRM)
    '\u200F', // Right-to-Left Mark (RLM)
  ];

  static const Set<String> _dangerousExecExtensions = {
    'exe', 'bat', 'cmd', 'msi', 'vbs', 'vbe', 'js', 'jse', 'wsf', 'wsh',
    'ps1', 'scr', 'sh', 'com', 'pif', 'jar', 'gadget', 'hta', 'cpl', 'apk'
  };

  static const Set<String> _benignDocumentExtensions = {
    'pdf', 'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'mp3', 'mp4',
    'mkv', 'avi', 'mov', 'txt', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'zip'
  };

  /// Inspects [fileName] for any traversal sequences, encoded payloads,
  /// directional spoofing or dangerous double extensions.
  /// Throws [FileSecurityException] if an attack vector is detected.
  static void validateFileName(String fileName) {
    if (fileName.isEmpty) {
      return;
    }

    final lower = fileName.toLowerCase();

    // 1. URL-encoded path traversal sequences
    if (lower.contains('%2e%2e') ||
        lower.contains('%2f') ||
        lower.contains('%5c') ||
        lower.contains('%252e')) {
      throw const FileSecurityException('Path traversal detected: URL-encoded traversal sequence');
    }

    // 2. Windows drive letters (e.g. C:, D:\, etc.)
    if (RegExp(r'^[a-zA-Z]:').hasMatch(fileName) || fileName.contains(':\\') || fileName.contains(':/')) {
      throw const FileSecurityException('Path traversal detected: Absolute drive letter');
    }

    // 3. Directional spoofing / RTLO characters
    for (final char in _directionalSpoofingChars) {
      if (fileName.contains(char)) {
        throw const FileSecurityException('Malicious filename detected: RTLO / directional spoofing character');
      }
    }

    // 4. Double extensions disguised as benign media/documents
    final baseName = p.basename(fileName).toLowerCase();
    final parts = baseName.split('.');
    if (parts.length >= 3) {
      final lastExt = parts.last;
      final secondLastExt = parts[parts.length - 2];
      if (_dangerousExecExtensions.contains(lastExt) && _benignDocumentExtensions.contains(secondLastExt)) {
        throw FileSecurityException('Dangerous double extension detected: .$secondLastExt.$lastExt');
      }
    }
  }

  /// Verifies that [destinationPath] resides strictly within [parentDirectory] (Boundary Jail).
  /// Throws [FileSecurityException] if boundary breakout is attempted.
  static void validateBoundaryJail({
    required String parentDirectory,
    required String destinationPath,
  }) {
    if (parentDirectory.startsWith('content://')) {
      return; // Android Storage Access Framework handled via DocumentUri
    }

    final canonicalParent = p.canonicalize(parentDirectory);
    final canonicalDest = p.canonicalize(destinationPath);

    if (!p.isWithin(canonicalParent, canonicalDest) && canonicalParent != canonicalDest) {
      throw const FileSecurityException('Path traversal detected: Target escapes destination boundary jail');
    }
  }

  /// Inspects initial file [headerBytes] against advertised [extension]
  /// to prevent executable MIME spoofing.
  static void validateMagicBytes({
    required List<int> headerBytes,
    required String extension,
  }) {
    if (headerBytes.length < 4) {
      return; // Too short to verify reliably
    }

    final ext = extension.toLowerCase().replaceAll('.', '');

    // Check for MZ (Windows PE executable / DLL / CPL) header: 0x4D, 0x5A
    final isMzExecutable = headerBytes[0] == 0x4D && headerBytes[1] == 0x5A;

    // Check for ELF (Linux binary) header: 0x7F, 0x45, 0x4C, 0x46
    final isElfBinary = headerBytes[0] == 0x7F &&
        headerBytes[1] == 0x45 &&
        headerBytes[2] == 0x4C &&
        headerBytes[3] == 0x46;

    // Check for Script shebang: #! (0x23, 0x21)
    final isScriptShebang = headerBytes[0] == 0x23 && headerBytes[1] == 0x21;

    final isAdvertisedAsNonExec = _benignDocumentExtensions.contains(ext);

    if (isAdvertisedAsNonExec) {
      if (isMzExecutable) {
        throw const FileSecurityException('MIME spoofing detected: Executable PE header disguised as media/document');
      }
      if (isElfBinary) {
        throw const FileSecurityException('MIME spoofing detected: ELF executable header disguised as media/document');
      }
      if (isScriptShebang && (ext == 'jpg' || ext == 'png' || ext == 'pdf' || ext == 'mp4')) {
        throw const FileSecurityException('MIME spoofing detected: Script shebang disguised as media/document');
      }
    }

    // Format specific magic byte integrity check:
    if (ext == 'png' && headerBytes.length >= 8) {
      final isPng = headerBytes[0] == 0x89 &&
          headerBytes[1] == 0x50 &&
          headerBytes[2] == 0x4E &&
          headerBytes[3] == 0x47 &&
          headerBytes[4] == 0x0D &&
          headerBytes[5] == 0x0A &&
          headerBytes[6] == 0x1A &&
          headerBytes[7] == 0x0A;
      if (!isPng) {
        throw const FileSecurityException('File signature mismatch: Invalid PNG header');
      }
    } else if (ext == 'jpg' || ext == 'jpeg') {
      final isJpg = headerBytes[0] == 0xFF && headerBytes[1] == 0xD8 && headerBytes[2] == 0xFF;
      if (!isJpg) {
        throw const FileSecurityException('File signature mismatch: Invalid JPEG header');
      }
    } else if (ext == 'pdf') {
      final isPdf = headerBytes[0] == 0x25 &&
          headerBytes[1] == 0x50 &&
          headerBytes[2] == 0x44 &&
          headerBytes[3] == 0x46; // %PDF
      if (!isPdf) {
        throw const FileSecurityException('File signature mismatch: Invalid PDF header');
      }
    }
  }

  /// Verifies safety parameters for archive decompression against Zip Bombs.
  static void validateArchiveSafety({
    required int uncompressedSize,
    required int compressedSize,
    int maxUncompressedBytes = 10 * 1024 * 1024 * 1024, // 10 GB limit
    double maxCompressionRatio = 100.0,
  }) {
    if (uncompressedSize > maxUncompressedBytes) {
      throw FileSecurityException(
        'Zip bomb detected: Uncompressed size exceeds limit (${(uncompressedSize / (1024 * 1024)).toStringAsFixed(1)} MB)',
      );
    }

    if (compressedSize > 0) {
      final ratio = uncompressedSize / compressedSize;
      if (ratio > maxCompressionRatio && uncompressedSize > 50 * 1024 * 1024) {
        throw FileSecurityException(
          'Zip bomb detected: Anomalous compression ratio (${ratio.toStringAsFixed(1)}:1)',
        );
      }
    }
  }
}
