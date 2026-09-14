/// assists_kit: analysis-server plugin entry point.
///
/// The Dart analysis server ships "Wrap with Container", "Convert to
/// StatefulWidget" and friends, but gates every one of them on the widget
/// class living in `package:flutter/src/widgets/framework.dart`. DartNative's
/// `Widget` lives in `package:dartnative/src/core.dart`, so none of those
/// assists appear in a DartNative project. This plugin re-implements them
/// against DartNative's types and adds warning rules for DartNative
/// behaviours that fail silently or crash at mount.
///
/// Enable it per project in `analysis_options.yaml` (top-level key):
///
/// ```yaml
/// plugins:
///   assists_kit:
///     hosted: https://dartpub.dev
///     version: ^0.1.1
/// ```
///
/// then restart the Dart Analysis Server in the IDE.
library;

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/child_children.dart';
import 'src/convert_to_stateful.dart';
import 'src/convert_to_stateless.dart';
import 'src/move_widget.dart';
import 'src/remove_widget.dart';
import 'src/rules/add_amp_iframe_sandbox.dart';
import 'src/rules/add_amp_img_dimensions.dart';
import 'src/rules/add_barg_name.dart';
import 'src/rules/add_battr_name.dart';
import 'src/rules/add_bdata_expr.dart';
import 'src/rules/add_beval_expr.dart';
import 'src/rules/add_bincludable_id.dart';
import 'src/rules/add_binclude_name.dart';
import 'src/rules/add_bloop_args.dart';
import 'src/rules/add_bvariable_args.dart';
import 'src/rules/add_bwidget_type.dart';
import 'src/rules/add_controller_mirror.dart';
import 'src/rules/add_escape_false.dart';
import 'src/rules/add_html_img_alt.dart';
import 'src/rules/clear_bskin_css.dart';
import 'src/rules/rules.dart';
import 'src/swap_with_child.dart';
import 'src/wrap_with.dart';

final plugin = AssistsKitPlugin();

class AssistsKitPlugin extends Plugin {
  @override
  String get name => 'Assists Kit';

  @override
  void register(PluginRegistry registry) {
    registerAssists(registry);
    registerRules(registry);
  }

  /// Registers the widget assists only. Split out so tests can load them
  /// without also enabling the warning rules.
  void registerAssists(PluginRegistry registry) {
    for (final generator in wrapProducerGenerators) {
      registry.registerAssist(generator);
    }
    registry.registerAssist(WrapWithWidget.new);
    registry.registerAssist(RemoveWidget.new);
    registry.registerAssist(SwapWithChild.new);
    registry.registerAssist(SwapWithParent.new);
    registry.registerAssist(ConvertChildToChildren.new);
    registry.registerAssist(ConvertChildrenToChild.new);
    registry.registerAssist(MoveWidgetUp.new);
    registry.registerAssist(MoveWidgetDown.new);
    registry.registerAssist(ConvertToStatefulWidget.new);
    registry.registerAssist(ConvertToStatelessWidget.new);
  }

  /// Registers the warning rules, the opt-in lint rules, and their fixes.
  void registerRules(PluginRegistry registry) {
    for (final rule in warningRules) {
      registry.registerWarningRule(rule);
    }
    for (final rule in lintRules) {
      registry.registerLintRule(rule);
    }
    registry.registerFixForRule(
      MirrorTextController.code,
      AddControllerMirror.new,
    );
    registry.registerFixForRule(
      RawTextEscapeFalse.code,
      AddEscapeFalse.new,
    );
    registry.registerFixForRule(
      AmpImgDimensionsRequired.code,
      AddAmpImgDimensions.new,
    );
    registry.registerFixForRule(
      BWidgetTypeRequired.code,
      AddBWidgetType.new,
    );
    registry.registerFixForRule(
      AmpIframeSandboxRequired.code,
      AddAmpIframeSandbox.new,
    );
    registry.registerFixForRule(
      BSkinEmptyCssAmpRule.code,
      ClearBSkinCss.new,
    );
    registry.registerFixForRule(
      HtmlImgAltRequired.code,
      AddHtmlImgAlt.new,
    );
    registry.registerFixForRule(
      BEvalExprRequired.code,
      AddBEvalExpr.new,
    );
    registry.registerFixForRule(
      BLoopRequiredArgs.code,
      AddBLoopArgs.new,
    );
    registry.registerFixForRule(
      BIncludeNameRequired.code,
      AddBIncludeName.new,
    );
    registry.registerFixForRule(
      BAttrNameRequired.code,
      AddBAttrName.new,
    );
    registry.registerFixForRule(
      BVariableRequiredArgs.code,
      AddBVariableArgs.new,
    );
    registry.registerFixForRule(
      BIncludableIdRequired.code,
      AddBIncludableId.new,
    );
    registry.registerFixForRule(
      BArgNameRequired.code,
      AddBArgName.new,
    );
    registry.registerFixForRule(
      BDataExprRequired.code,
      AddBDataExpr.new,
    );
  }
}
