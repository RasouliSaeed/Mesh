import re

with open('app/lib/pages/tabs/receive_tab.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add the E2E Encryption badge
badge = '''
              // Status Indicator (Pill)
              InitialFadeTransition(
                duration: const Duration(milliseconds: 300),
                delay: const Duration(milliseconds: 400),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: serverState == null 
                            ? colorScheme.error.withValues(alpha: 0.1) 
                            : colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: serverState == null 
                              ? colorScheme.error.withValues(alpha: 0.3) 
                              : colorScheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: serverState == null ? colorScheme.error : colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            serverState == null ? t.general.offline : "Ready to receive",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: serverState == null ? colorScheme.error : colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // E2E Encryption Badge
                    Tooltip(
                      message: 'End-to-End Encrypted (TLS 1.3)',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A36A).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF16A36A).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_outline, size: 16, color: Color(0xFF16A36A)),
                            const SizedBox(width: 8),
                            const Text(
                              "Secured",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF16A36A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),'''

content = re.sub(r'              // Status Indicator \(Pill\)\n              InitialFadeTransition\(.*?                    \],\n                  \),\n                \),\n              \),', badge, content, flags=re.DOTALL)

with open('app/lib/pages/tabs/receive_tab.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print('Updated receive_tab.dart with Security Badge')
