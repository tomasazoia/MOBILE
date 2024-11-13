/*import 'package:flutter/material.dart';
import 'package:flutter_offline/flutter_offline.dart';

class ConnectivityStatus extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OfflineBuilder(
      connectivityBuilder: (
        BuildContext context,
        ConnectivityResult connectivity,
        Widget child,
      ) {
        final bool connected = connectivity != ConnectivityResult.none;
        if (!connected) {
          return Positioned(
            height: 24.0,
            left: 0.0,
            right: 0.0,
            child: Container(
              color: const Color(0xFFEE4400),
              child: const Center(
                child: Text("OFFLINE"),
              ),
            ),
          );
        } else {
          return const SizedBox.shrink();
        }
      },
      child: const SizedBox.shrink(),
    );
  }
}*/

import 'package:flutter/material.dart';
import 'package:flutter_offline/flutter_offline.dart';

class ConnectivityStatus extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OfflineBuilder(
      connectivityBuilder: (
        BuildContext context,
        List<ConnectivityResult> connectivity,
        Widget child,
      ) {
        final bool connected =
            connectivity.contains(ConnectivityResult.none) == false;
        if (!connected) {
          return Positioned(
            height: 24.0,
            left: 0.0,
            right: 0.0,
            child: Container(
              color: const Color(0xFFEE4400),
              child: const Center(
                child: Text("OFFLINE"),
              ),
            ),
          );
        } else {
          return const SizedBox.shrink();
        }
      },
      child: const SizedBox.shrink(),
    );
  }
}