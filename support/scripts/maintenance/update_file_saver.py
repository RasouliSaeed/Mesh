with open('packages/mesh_isolates/lib/src/task/server/file_saver.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add finalPath to FileSaveTarget
old_class = '''class FileSaveTarget {
  /// The path to write the file to. `null` when [fileDescriptor] is used.
  final String? path;

  /// A writable file descriptor (Android SAF). `null` when [path] is used.
  final int? fileDescriptor;

  /// The path or content URI of the destination, used for the history
  /// and to locate the file after it has been written.
  final String displayPath;

  FileSaveTarget({
    required this.path,
    required this.fileDescriptor,
    required this.displayPath,
  });
}'''

new_class = '''class FileSaveTarget {
  /// The path to write the file to (may have .mesh.part). `null` when [fileDescriptor] is used.
  final String? path;
  
  /// The final path to rename the file to after completion. `null` when SAF is used.
  final String? finalPath;

  /// A writable file descriptor (Android SAF). `null` when [path] is used.
  final int? fileDescriptor;

  /// The path or content URI of the destination, used for the history
  /// and to locate the file after it has been written.
  final String displayPath;

  FileSaveTarget({
    required this.path,
    this.finalPath,
    required this.fileDescriptor,
    required this.displayPath,
  });
}'''

content = content.replace(old_class, new_class)

# Update return values
old_saf = '''      return FileSaveTarget(
        path: null,
        fileDescriptor: createdFile.fileDescriptor,
        displayPath: createdFile.uri,
      );'''

new_saf = '''      return FileSaveTarget(
        path: null,
        finalPath: null,
        fileDescriptor: createdFile.fileDescriptor,
        displayPath: createdFile.uri,
      );'''

content = content.replace(old_saf, new_saf)

old_return = '''  return FileSaveTarget(
    path: destinationPath,
    fileDescriptor: null,
    displayPath: destinationPath,
  );'''

new_return = '''  return FileSaveTarget(
    path: destinationPath + '.mesh.part',
    finalPath: destinationPath,
    fileDescriptor: null,
    displayPath: destinationPath,
  );'''

content = content.replace(old_return, new_return)

with open('packages/mesh_isolates/lib/src/task/server/file_saver.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("file_saver updated")
