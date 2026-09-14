/// Quick fix for `blogger_theme_raw_text_escape_false`: adds `escape: false` argument to `Text(...)`.
library;

import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

class AddEscapeFalse extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'blogger_theme.fix.addEscapeFalse',
    DartFixKindPriority.standard,
    "Add 'escape: false'",
  );

  AddEscapeFalse({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final argument = node;
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(argument.end, ', escape: false');
    });
  }
}
