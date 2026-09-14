/// Quick fix for `blogger_theme_bincludable_id_required`: adds `id: 'main'` parameter to `BIncludable(...)`.
library;

import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

class AddBIncludableId extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'blogger_theme.fix.addBIncludableId',
    DartFixKindPriority.standard,
    "Add 'id' attribute",
  );

  AddBIncludableId({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    AstNode? target = node;
    while (target != null && target is! InstanceCreationExpression) {
      target = target.parent;
    }
    if (target is! InstanceCreationExpression) return;
    final args = target.argumentList;

    await builder.addDartFileEdit(file, (builder) {
      if (args.arguments.isEmpty) {
        builder.addSimpleInsertion(args.leftParenthesis.offset + 1, "id: 'main'");
      } else {
        builder.addSimpleInsertion(args.arguments.last.end, ", id: 'main'");
      }
    });
  }
}
