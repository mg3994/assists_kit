/// Quick fix for `blogger_theme_amp_img_dimensions_required`: adds `width` and `height` parameters to `AmpImg(...)`.
library;

import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

class AddAmpImgDimensions extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'blogger_theme.fix.addAmpImgDimensions',
    DartFixKindPriority.standard,
    "Add 'width' and 'height' attributes",
  );

  AddAmpImgDimensions({required super.context});

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
        builder.addSimpleInsertion(args.leftParenthesis.offset + 1, "width: '300', height: '200'");
      } else {
        builder.addSimpleInsertion(args.arguments.last.end, ", width: '300', height: '200'");
      }
    });
  }
}
