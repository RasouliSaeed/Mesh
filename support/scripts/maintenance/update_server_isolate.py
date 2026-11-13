with open('packages/mesh_isolates/lib/src/isolate/child/server_isolate.dart', 'r', encoding='utf-8') as f:
    content = f.read()

old_post_process = '''    try {
      String? filePath;
      bool savedToGallery = false;
      if (shouldSaveToGallery) {
        (savedToGallery, filePath) = await saveCachedFileToGallery(
          cachedPath: target.displayPath,
          destinationDirectory: config.destinationDirectory,
          fileName: desiredName,
          isImage: isImage,
          createdDirectories: session.createdDirectories,
        );
      } else {
        filePath = target.displayPath;
      }

      _logger.info('Saved ${dartFile.fileName}.');'''

new_post_process = '''    try {
      String? filePath;
      bool savedToGallery = false;
      if (shouldSaveToGallery) {
        (savedToGallery, filePath) = await saveCachedFileToGallery(
          cachedPath: target.displayPath,
          destinationDirectory: config.destinationDirectory,
          fileName: desiredName,
          isImage: isImage,
          createdDirectories: session.createdDirectories,
        );
      } else {
        // Atomic File Commit: Rename .mesh.part to final file
        if (target.path != null && target.finalPath != null && target.path!.endsWith('.mesh.part')) {
          final partFile = File(target.path!);
          if (await partFile.exists()) {
            await partFile.rename(target.finalPath!);
          }
        }
        filePath = target.displayPath;
      }

      _logger.info('Saved ${dartFile.fileName}.');'''

content = content.replace(old_post_process, new_post_process)

with open('packages/mesh_isolates/lib/src/isolate/child/server_isolate.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("server_isolate updated")
