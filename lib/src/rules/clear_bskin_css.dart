/// Quick fix for `blogger_theme_bskin_empty_css_amp`: clears first string argument of `BSkin(...)`.
library;

import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

class ClearBSkinCss extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'blogger_theme.fix.clearBSkinCss',
    DartFixKindPriority.standard,
    "Clear BSkin CSS parameter to ''",
  );

  ClearBSkinCss({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final target = node;
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(range.node(target), "''");
    });
  }
}
