import 'dart:async';

import 'package:collection/collection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:locara_app/model/state/network_state.dart';
import 'package:locara_app/provider/settings_provider.dart';
import 'package:locara_app/util/native/platform_check.dart';
import 'package:locara_isolates/util/network_interfaces.dart';
import 'package:logging/logging.dart';
import 'package:network_info_plus/network_info_plus.dart' as plugin;
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('NetworkInfo');

final localIpProvider = ReduxProvider<LocalIpService, NetworkState>((ref) {
  return LocalIpService(
    ref.notifier(settingsProvider),
  );
});

StreamSubscription? _subscription;

class LocalIpService extends ReduxNotifier<NetworkState> {
  final SettingsService _settingsService;

  LocalIpService(this._settingsService);

  @override
  NetworkState init() {
    return const NetworkState(
      localIps: [],
      initialized: false,
    );
  }

  @override
  get initialAction => InitLocalIpAction();
}

/// Fetches the local IP address and registers a listener to update the IP address
class InitLocalIpAction extends ReduxAction<LocalIpService, NetworkState> {
  @override
  NetworkState reduce() {
    if (!kIsWeb) {
      // ignore: discarded_futures
      _subscription?.cancel();

      if (checkPlatform([TargetPlatform.windows])) {
        // https://github.com/Locara/Locara/issues/12
        // https://github.com/Locara/Locara/issues/78
      } else {
        _subscription = Connectivity().onConnectivityChanged.listen((_) async {
          await dispatchAsync(FetchLocalIpAction());
        });
      }
    }

    return state;
  }

  @override
  void after() {
    // ignore: discarded_futures
    dispatchAsync(FetchLocalIpAction());
  }
}

class FetchLocalIpAction extends AsyncReduxAction<LocalIpService, NetworkState> {
  @override
  Future<NetworkState> reduce() async {
    return NetworkState(
      localIps: await _getIp(
        whitelist: notifier._settingsService.state.networkWhitelist,
        blacklist: notifier._settingsService.state.networkBlacklist,
      ),
      initialized: true,
    );
  }
}

Future<List<String>> _getIp({
  required List<String>? whitelist,
  required List<String>? blacklist,
}) async {
  final info = plugin.NetworkInfo();
  String? ip;
  try {
    ip = await info.getWifiIP();
  } catch (e) {
    _logger.warning('Failed to get wifi IP', e);
  }

  final nativeResult =
      (await getNetworkInterfaces(
            whitelist: whitelist,
            blacklist: blacklist,
          ))
          .map((interface) => interface.addresses.map((a) => a.address).toList())
          .expand((ip) => ip)
          .where((ip) => !ip.contains(':')) // ignore IPv6 for now
          .toList();

  final addresses = rankIpAddresses(nativeResult, ip);
  _logger.info('Network state: $addresses');
  return addresses;
}

List<String> rankIpAddresses(List<String> nativeResult, String? thirdPartyResult) {
  if (thirdPartyResult == null) {
    // only take the list
    return nativeResult._rankIpAddresses(null);
  } else if (nativeResult.isEmpty) {
    // only take the first IP from third party library
    return [thirdPartyResult];
  } else if (thirdPartyResult.endsWith('.1')) {
    // merge
    return {thirdPartyResult, ...nativeResult}.toList()._rankIpAddresses(null);
  } else {
    // merge but prefer result from third party library
    return {thirdPartyResult, ...nativeResult}.toList()._rankIpAddresses(thirdPartyResult);
  }
}

/// Sorts IP addresses with first being the most likely primary local address
/// Supports destination-aware subnet matching (longest prefix match) to ensure
/// Hyper-V, WSL, Docker, and VPNs (Tailscale/WireGuard) are prioritized when reaching
/// peers residing on those specific networks.
extension ListIpExt on List<String> {
  int _scoreIp(String ip, String? primary, [String? destination]) {
    if (ip == primary) return 100;
    if (ip.startsWith('169.254.') || ip == '0.0.0.0') return -100;
    if (ip.startsWith('127.')) return (destination?.startsWith('127.') ?? false) ? 95 : -90;

    if (destination != null) {
      final prefixLen = commonPrefixLength(ip, destination);
      if (prefixLen >= 24) return 80 + prefixLen;
      if (prefixLen >= 16) return 50 + prefixLen;
      if (prefixLen >= 8) return 30 + prefixLen;
    }

    if (ip.endsWith('.1')) return 2; // Gateway-like address
    if (ip.startsWith('192.168.')) return 30; // Home/LAN
    if (ip.startsWith('10.')) return 25; // Enterprise/LAN
    if (ip.startsWith('100.')) return 22; // Tailscale / CGNAT
    if (ip.startsWith('172.')) {
      final secondOctet = int.tryParse(ip.split('.').elementAtOrNull(1) ?? '') ?? 0;
      if (secondOctet >= 16 && secondOctet <= 31) {
        return 18; // Private Class B / WSL / Docker
      }
    }
    return 15;
  }

  List<String> _rankIpAddresses(String? primary, [String? destination]) {
    return sorted((a, b) {
      final scoreA = _scoreIp(a, primary, destination);
      final scoreB = _scoreIp(b, primary, destination);
      return scoreB.compareTo(scoreA);
    });
  }
}
