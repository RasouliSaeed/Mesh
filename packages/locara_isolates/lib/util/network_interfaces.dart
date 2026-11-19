import 'dart:io';

import 'package:logging/logging.dart';

final _logger = Logger('NetworkInterface');

/// Returns a list of network interfaces respecting the whitelist and blacklist.
Future<List<NetworkInterface>> getNetworkInterfaces({
  required List<String>? whitelist,
  required List<String>? blacklist,
}) async {
  final result = <NetworkInterface>[];
  final digestedWhitelist = whitelist?.map(buildRegExpFromIpFilter).toList();
  final digestedBlacklist = blacklist?.map(buildRegExpFromIpFilter).toList();

  for (final interface in await NetworkInterface.list()) {
    if (isNetworkIgnored(
      networkWhitelist: digestedWhitelist,
      networkBlacklist: digestedBlacklist,
      interface: interface.addresses.map((a) => a.address).toList(),
    )) {
      _logger.info('Ignore network interface ${interface.name} (${interface.addresses.map((a) => a.address).toList()})');
      continue;
    }
    result.add(interface);
  }

  // Preserve all valid interfaces without arbitrary name discrimination (allowing Hyper-V, WSL, Docker, VPNs)
  // Filter out completely dead adapters (no assigned addresses) and prioritize active routable ones
  result.sort((a, b) {
    final aHasRoutable = a.addresses.any((addr) => !addr.isLinkLocal && !addr.isLoopback);
    final bHasRoutable = b.addresses.any((addr) => !addr.isLinkLocal && !addr.isLoopback);
    if (aHasRoutable != bHasRoutable) {
      return aHasRoutable ? -1 : 1;
    }
    return a.name.compareTo(b.name);
  });

  return result;
}

/// Converts an IPv4 string into a 32-bit unsigned integer.
int? ipv4ToInt(String ip) {
  final parts = ip.split('.');
  if (parts.length != 4) return null;
  int result = 0;
  for (final part in parts) {
    final octet = int.tryParse(part);
    if (octet == null || octet < 0 || octet > 255) return null;
    result = (result << 8) | octet;
  }
  return result;
}

/// Calculates the length of the common bit prefix between two IPv4 addresses.
/// (Longest Prefix Match / Subnet common bits for destination routing).
int commonPrefixLength(String ipA, String ipB) {
  final a = ipv4ToInt(ipA);
  final b = ipv4ToInt(ipB);
  if (a == null || b == null) return 0;
  final diff = a ^ b;
  if (diff == 0) return 32;
  return 32 - diff.bitLength;
}

/// Selects the best local IP from [availableIps] to communicate with [destinationIp].
/// Uses longest prefix match to pick the interface on the matching subnet (LAN, WSL, Docker, VPN).
String? selectBestLocalIpForDestination(String destinationIp, List<String> availableIps) {
  if (availableIps.isEmpty) return null;
  if (availableIps.length == 1) return availableIps.first;

  String? bestIp;
  int bestScore = -1000;

  for (final ip in availableIps) {
    int score = 0;
    if (ip.startsWith('169.254.') || ip == '0.0.0.0') {
      score = -500; // APIPA / Unbound
    } else if (ip.startsWith('127.')) {
      score = destinationIp.startsWith('127.') ? 500 : -200;
    } else {
      final prefixLen = commonPrefixLength(ip, destinationIp);
      score = prefixLen * 10;
      if (prefixLen >= 24) {
        score += 100; // Direct /24 subnet match
      } else if (prefixLen >= 16) {
        score += 50; // Direct /16 subnet match
      }
    }

    if (score > bestScore) {
      bestScore = score;
      bestIp = ip;
    }
  }

  return bestIp ?? availableIps.first;
}

/// Returns true if the given IP should be ignored.
/// - When the IP is not in the whitelist (if the whitelist is not null)
/// - When the IP is in the blacklist (if the blacklist is not null)
bool isNetworkIgnoredRaw({
  required List<String>? networkWhitelist,
  required List<String>? networkBlacklist,
  required List<String> interface,
}) {
  return isNetworkIgnored(
    networkWhitelist: networkWhitelist?.map(buildRegExpFromIpFilter).toList(),
    networkBlacklist: networkBlacklist?.map(buildRegExpFromIpFilter).toList(),
    interface: interface,
  );
}

/// Builds a regular expression from the given IP.
/// - '123.123.124.*' -> '^123\.123\.124\.[^.]+$'
/// - '1::1:*:3' -> '^1::1:[^.]+:3$'
RegExp buildRegExpFromIpFilter(String ip) {
  return RegExp('^${ip.replaceAll('.', '\\.').replaceAll('*', '[^.]+')}\$');
}

/// Returns true if the given IP should be ignored.
/// - When the IP is not in the whitelist (if the whitelist is not null)
/// - When the IP is in the blacklist (if the blacklist is not null)
bool isNetworkIgnored({
  required List<RegExp>? networkWhitelist,
  required List<RegExp>? networkBlacklist,
  required List<String> interface,
}) {
  if (networkWhitelist != null && !interface.any((a) => networkWhitelist.any((w) => w.hasMatch(a)))) {
    return true;
  }
  if (networkBlacklist != null && interface.any((a) => networkBlacklist.any((b) => b.hasMatch(a)))) {
    return true;
  }
  return false;
}
