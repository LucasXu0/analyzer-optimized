// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';

import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/src/context/packages.dart';
import 'package:analyzer/src/dart/analysis/analysis_options_map.dart';
import 'package:analyzer/src/dart/analysis/byte_store.dart';
import 'package:analyzer/src/dart/analysis/driver.dart';
import 'package:analyzer/src/dart/analysis/performance_logger.dart';
import 'package:analyzer/src/dart/sdk/sdk.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/summary2/package_bundle_format.dart';
import 'package:yaml/yaml.dart';

/// Build summary for SDK at the given [sdkPath].
///
/// If [embedderYamlPath] is provided, then libraries from this file are
/// appended to the libraries of the specified SDK.
Future<Uint8List> buildSdkSummary({
  required ResourceProvider resourceProvider,
  required String sdkPath,
  String? embedderYamlPath,
}) async {
  final _perfStart = DateTime.now();
  print('[PERF-SDK] buildSdkSummary started at ${_perfStart.toIso8601String()}');

  final _sdkCreateStart = DateTime.now();
  var sdk = FolderBasedDartSdk(
    resourceProvider,
    resourceProvider.getFolder(sdkPath),
  );
  print('[PERF-SDK] FolderBasedDartSdk created in ${DateTime.now().difference(_sdkCreateStart).inMilliseconds}ms');
  print('[PERF-SDK] SDK has ${sdk.uris.length} libraries');

  // Append libraries from the embedder.
  if (embedderYamlPath != null) {
    final _embedderStart = DateTime.now();
    var file = resourceProvider.getFile(embedderYamlPath);
    var content = file.readAsStringSync();
    var map = loadYaml(content) as YamlMap;
    var embedderSdk = EmbedderSdk(
      resourceProvider,
      {file.parent: map},
      languageVersion: sdk.languageVersion,
    );
    var addedLibs = 0;
    for (var library in embedderSdk.sdkLibraries) {
      var uriStr = library.shortName;
      if (sdk.libraryMap.getLibrary(uriStr) == null) {
        sdk.libraryMap.setLibrary(uriStr, library);
        addedLibs++;
      }
    }
    print('[PERF-SDK] Embedder processing completed in ${DateTime.now().difference(_embedderStart).inMilliseconds}ms, added $addedLibs libraries');
  }

  final _driverSetupStart = DateTime.now();
  var logger = PerformanceLog(StringBuffer());
  var scheduler = AnalysisDriverScheduler(logger);
  var optionsMap = AnalysisOptionsMap.forSharedOptions(AnalysisOptionsImpl());
  var analysisDriver = AnalysisDriver(
    scheduler: scheduler,
    logger: logger,
    resourceProvider: resourceProvider,
    byteStore: MemoryByteStore(),
    sourceFactory: SourceFactory([
      DartUriResolver(sdk),
    ]),
    analysisOptionsMap: optionsMap,
    packages: Packages({}),
  );
  scheduler.start();
  print('[PERF-SDK] AnalysisDriver setup completed in ${DateTime.now().difference(_driverSetupStart).inMilliseconds}ms');

  var libraryUriList = sdk.uris.map(Uri.parse).toList();
  print('[PERF-SDK] Processing ${libraryUriList.length} SDK libraries');

  final _buildBundleStart = DateTime.now();
  print('[PERF-SDK] Calling analysisDriver.buildPackageBundle at ${_buildBundleStart.toIso8601String()}');
  final result = await analysisDriver.buildPackageBundle(
    uriList: libraryUriList,
    packageBundleSdk: PackageBundleSdk(
      languageVersionMajor: sdk.languageVersion.major,
      languageVersionMinor: sdk.languageVersion.minor,
      allowedExperimentsJson: sdk.allowedExperimentsJson,
    ),
  );
  print('[PERF-SDK] analysisDriver.buildPackageBundle completed in ${DateTime.now().difference(_buildBundleStart).inMilliseconds}ms');
  print('[PERF-SDK] Result bundle size: ${result.length} bytes');

  print('[PERF-SDK] buildSdkSummary total time: ${DateTime.now().difference(_perfStart).inMilliseconds}ms');
  return result;
}

/// Build summary for SDK at the given [sdkPath].
///
/// If [embedderYamlPath] is provided, then libraries from this file are
/// appended to the libraries of the specified SDK.
@Deprecated('Use buildSdkSummary() instead')
Future<Uint8List> buildSdkSummary2({
  required ResourceProvider resourceProvider,
  required String sdkPath,
  String? embedderYamlPath,
}) async {
  return buildSdkSummary(
    resourceProvider: resourceProvider,
    sdkPath: sdkPath,
  );
}
