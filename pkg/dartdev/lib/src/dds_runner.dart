// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';

import 'sdk.dart';

class DDSRunner {
  Uri? ddsUri;

  Future<bool> start({
    required Uri vmServiceUri,
    required String ddsHost,
    required String ddsPort,
    required bool disableServiceAuthCodes,
    required bool enableDevTools,
    required bool debugDds,
    required bool enableServicePortFallback,
  }) async {
    final sdkDir = dirname(sdk.dart);
    final fullSdk = sdkDir.endsWith('bin');
    String snapshotName = fullSdk
        ? sdk.ddsAotSnapshot
        : absolute(sdkDir, 'dds_aot.dart.snapshot');
    String execName = sdk.dartAotRuntime;
    // Check to see if the AOT snapshot and dartaotruntime are available.
    // If not, fall back to running from the AppJIT snapshot.
    //
    // This can happen if:
    //  - The SDK is built for IA32 which doesn't support AOT compilation
    //  - We only have artifacts available from the 'runtime' build
    //    configuration, which the VM SDK build bots frequently run from
    if (!Sdk.checkArtifactExists(snapshotName, logError: false) ||
        !Sdk.checkArtifactExists(sdk.dartAotRuntime, logError: false)) {
      snapshotName =
          fullSdk ? sdk.ddsSnapshot : absolute(sdkDir, 'dds.dart.snapshot');
      if (!Sdk.checkArtifactExists(snapshotName)) {
        return false;
      }
      execName = sdk.dart;
    }

    final process = await Process.start(
      execName,
      [
        if (debugDds) '--enable-vm-service=0',
        snapshotName,
        '--vm-service-uri=$vmServiceUri',
        '--bind-address=$ddsHost',
        '--bind-port=$ddsPort',
        if (disableServiceAuthCodes) '--disable-service-auth-codes',
        if (enableDevTools) '--serve-devtools',
        if (debugDds) '--enable-logging',
        if (enableServicePortFallback) '--enable-service-port-fallback',
      ],
      mode: ProcessStartMode.detachedWithStdio,
    );
    final completer = Completer<void>();
    const devToolsMessagePrefix =
        'The Dart DevTools debugger and profiler is available at:';
    if (debugDds) {
      late StreamSubscription stdoutSub;
      stdoutSub = process.stdout.transform(utf8.decoder).listen((event) {
        if (event.startsWith(devToolsMessagePrefix)) {
          final ddsDebuggingUri = event.split(' ').last;
          print(
            'A DevTools debugger for DDS is available at: $ddsDebuggingUri',
          );
          stdoutSub.cancel();
        }
      });
    }
    late StreamSubscription stderrSub;
    stderrSub = process.stderr.transform(utf8.decoder).listen((event) {
      final result = json.decode(event) as Map<String, dynamic>;
      final state = result['state'];
      if (state == 'started') {
        if (result.containsKey('devToolsUri')) {
          final devToolsUri = result['devToolsUri'];
          print('$devToolsMessagePrefix $devToolsUri');
        }
        ddsUri = Uri.parse(result['ddsUri']);
        stderrSub.cancel();
        completer.complete();
      } else {
        stderrSub.cancel();
        final error = result['error'] ?? event;
        final stacktrace = result['stacktrace'] ?? '';
        String message = 'Could not start the VM service: ';
        if (error.contains('Failed to create server socket')) {
          message += '$ddsHost:$ddsPort is already in use.\n';
        } else {
          message += '$error\n$stacktrace\n';
        }
        completer.completeError(message);
      }
    });
    try {
      await completer.future;
      return true;
    } catch (e) {
      stderr.write(e);
      return false;
    }
  }
}
