import re

with open('app/lib/pages/progress_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Make sure imports are there
if 'import \'package:mesh_app/provider/chat_provider.dart\';' not in content:
    content = content.replace('import \'package:refena_flutter/refena_flutter.dart\';', 
                              'import \'package:refena_flutter/refena_flutter.dart\';\nimport \'package:mesh_app/provider/chat_provider.dart\';\nimport \'dart:convert\';\nimport \'package:mesh_app/model/cross_file.dart\';\nimport \'package:mesh_isolates/model/file_type.dart\';')

# Find the start of the SafeArea footer
start_idx = content.find('            SafeArea(\n              child: Align(\n                alignment: Alignment.bottomCenter')

if start_idx != -1:
    # Find the end of the Stack's children array
    # The SafeArea is the last child of the Stack
    end_idx = content.find('            ),\n          ],\n        ),', start_idx)
    
    if end_idx != -1:
        chat_ui = '''
            // CHAT OVERLAY
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Chat Messages Area
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Consumer(
                        builder: (context, ref) {
                          final chatState = ref.watch(chatProvider);
                          if (chatState.messages.isEmpty) return const SizedBox.shrink();
                          
                          final recentMessages = chatState.messages.reversed.take(3).toList().reversed.toList();
                          
                          return Container(
                            constraints: const BoxConstraints(maxHeight: 150),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              padding: const EdgeInsets.all(8),
                              itemCount: recentMessages.length,
                              itemBuilder: (context, index) {
                                final msg = recentMessages[index];
                                return Align(
                                  alignment: msg.isMine ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(vertical: 2),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: msg.isMine ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      msg.text,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: msg.isMine ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    
                    // Original Progress Card + Chat Input Combined
                    Padding(
                      padding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 15, right: 15, bottom: 15, top: 15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                status.getLabel(
                                  remainingTime: _remainingTime ?? '-',
                                ),
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                              ),
                              const SizedBox(height: 10),
                              TweenAnimationBuilder(
                                tween: Tween<double>(begin: 0, end: _totalBytes == 0 ? 0 : currBytes / _totalBytes),
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                                builder: (context, value, child) {
                                  return CustomProgressBar(
                                    progress: value,
                                    borderRadius: 8,
                                    color: Theme.of(context).colorScheme.primary,
                                  );
                                },
                              ),
                              const SizedBox(height: 15),
                              // Chat Input Box
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      decoration: InputDecoration(
                                        hintText: 'Chat during transfer...',
                                        filled: true,
                                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(20),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                      onSubmitted: (text) async {
                                        if (text.trim().isEmpty) return;
                                        
                                        final target = ref.read(chatProvider).currentTarget;
                                        if (target != null) {
                                          final bytes = utf8.encode(text);
                                          final file = CrossFile(
                                            name: text,
                                            fileType: FileType.text,
                                            size: bytes.length,
                                            thumbnail: null,
                                            asset: null,
                                            path: null,
                                            bytes: bytes,
                                            lastModified: null,
                                            lastAccessed: null,
                                          );

                                          ref.notifier(chatProvider).addMessage(text, isMine: true);
                                          await ref
                                              .notifier(sendProvider)
                                              .startSession(
                                                target: target,
                                                files: [file],
                                                background: true,
                                              );
                                        } else {
                                          ref.notifier(chatProvider).addMessage(text, isMine: true);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
'''
        content = content[:start_idx] + chat_ui + content[end_idx:]

with open('app/lib/pages/progress_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print('Updated progress_page.dart accurately')
