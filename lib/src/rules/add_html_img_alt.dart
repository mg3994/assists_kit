/// Quick fix for `blogger_theme_html_img_alt_required`: adds `'alt': ''` to `img({...})`.
library;

import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

class AddHtmlImgAlt extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'blogger_theme.fix.addHtmlImgAlt',
    DartFixKindPriority.standard,
    "Add 'alt' attribute entry",
  );

  AddHtmlImgAlt({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    AstNode? target = node;
    while (target != null && target is! MethodInvocation) {
      target = target.parent;
    }
    if (target is! MethodInvocation) return;
    final args = target.argumentList;
    if (args.arguments.isEmpty) return;
    final mapArg = args.arguments.first;

    await builder.addDartFileEdit(file, (builder) {
      if (mapArg is SetOrMapLiteral) {
        if (mapArg.elements.isEmpty) {
          builder.addSimpleInsertion(mapArg.leftBracket.offset + 1, "'alt': ''");
        } else {
          builder.addSimpleInsertion(mapArg.elements.last.end, ", 'alt': ''");
        }
      }
    });
  }
}
