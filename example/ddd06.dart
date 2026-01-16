import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/src/dart/analysis/analysis_context_collection.dart';
import 'package:collection/collection.dart';
import 'package:linter/src/rules.dart';

void main() async {
  var resourceProvider = OverlayResourceProvider(
    PhysicalResourceProvider.INSTANCE,
  );
  var co19 = '/Users/scheglov/Source/Dart/sdk.git/sdk/tests/co19';
  resourceProvider.setOverlay(
    '$co19/src/LanguageFeatures/Parts-with-imports/analysis_options.yaml',
    content: r'''
analyzer:
  enable-experiment:
    - macros
    - enhanced-parts
''',
    modificationStamp: 0,
  );

  registerLintRules();

  var collection = AnalysisContextCollectionImpl(
    resourceProvider: resourceProvider,
    includedPaths: [
      // '/Users/scheglov/tmp/2024-07-17/issue56247/lib/large_library.dart',
      // '/Users/scheglov/dart/issue55931/scratchpad/macros_playground',
      // '/Users/scheglov/tmp/2024-06-12/scratchpad/macros_playground/lib/main.dart',
      // '/Users/scheglov/Source/Dart/sdk.git/sdk/pkg/analysis_server',
      '/Users/scheglov/Source/Dart/sdk.git/sdk/tests/co19/src/LanguageFeatures/Parts-with-imports/grammar_A04_t01.dart',
    ],
  );

  var timer = Stopwatch()..start();
  for (var analysisContext in collection.contexts) {
    print(analysisContext.contextRoot.root.path);
    var analysisSession = analysisContext.currentSession;
    for (var path in analysisContext.contextRoot.analyzedFiles().sorted()) {
      if (path.endsWith('.dart')) {
        var libResult = await analysisSession.getResolvedLibrary(path);
        if (libResult is ResolvedLibraryResult) {
          // for (var unitResult in libResult.units) {
          //   if (!unitResult.errors
          //       .map((e) => e.message)
          //       .join('\n')
          //       .contains('This code uses the old analyzer element model.')) {
          //     print(unitResult.path);
          //   }
          // }
          for (var unitResult in libResult.units) {
            print('    ${unitResult.path}');
            var ep = '\n        ';
            print('      errors:$ep${unitResult.errors.join(ep)}');
            // print('---');
            // print(unitResult.content);
            // print('---');
          }
        }
      }
    }
  }
  print('[time: ${timer.elapsedMilliseconds} ms]');

  await collection.dispose();
}
