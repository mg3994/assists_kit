/// Warning rules for DartNative behaviours that fail silently or crash at
/// mount. Each rule encodes one fact from the DartNative widget reference or
/// from on-device observation; the rule's description says which.
library;

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../dartnative_widgets.dart';
import 'rule_support.dart';

/// `Scaffold.floatingActionButton` renders on Android only.
class FabSlotAndroidOnly extends AnalysisRule {
  static final LintCode code = warning(
    'dartnative_fab_slot_android_only',
    "'Scaffold.floatingActionButton' renders on Android only; on iOS the "
        'button does not appear.',
    correction:
        'Gate it as Platform.isAndroid ? fab : null and give iOS its own '
        'placement, or put the button in a Stack inside the body.',
  );

  FabSlotAndroidOnly()
    : super(
        name: 'dartnative_fab_slot_android_only',
        description:
            'The floatingActionButton slot renders on Android and shows '
            'nothing on iOS (observed on device, DartNative 1.0.0).',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addInstanceCreationExpression(this, _FabVisitor(this, context));
  }
}

class _FabVisitor extends CreationVisitor {
  _FabVisitor(super.rule, super.context) : super(className: 'Scaffold');

  @override
  void check(InstanceCreationExpression node) {
    final argument = namedArgument(node, 'floatingActionButton');
    if (argument == null) return;
    // `Platform.isAndroid ? fab : null` shows the author has handled iOS
    // deliberately; that is the recommended pattern, so stay quiet.
    if (_isPlatformGated(argument.argumentExpression)) return;
    rule.reportAtNode(argument);
  }

  static bool _isPlatformGated(Expression expression) {
    if (expression is! ConditionalExpression) return false;
    final condition = expression.condition.toSource();
    return condition.contains('Platform.isAndroid') ||
        condition.contains('Platform.isIOS') ||
        condition.contains('isIOS26');
  }
}

/// A `BarButtonItem` with `menu:` must be the only `AppBar.actions` entry.
class MenuActionMustBeAlone extends AnalysisRule {
  static final LintCode code = warning(
    'dartnative_menu_action_must_be_alone',
    "A 'BarButtonItem' with 'menu:' must be the only AppBar action; the app "
        'asserts at mount otherwise.',
    correction: 'Move the other actions into the menu as MenuAction entries.',
  );

  MenuActionMustBeAlone()
    : super(
        name: 'dartnative_menu_action_must_be_alone',
        description:
            'AppBar.actions containing a menu BarButtonItem beside other '
            'actions fails an assertion when the screen mounts.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addInstanceCreationExpression(this, _MenuVisitor(this, context));
  }
}

class _MenuVisitor extends CreationVisitor {
  _MenuVisitor(super.rule, super.context) : super(className: 'AppBar');

  @override
  void check(InstanceCreationExpression node) {
    final actions = namedArgument(node, 'actions')?.argumentExpression;
    if (actions is! ListLiteral || actions.elements.length < 2) return;
    for (final element in actions.elements) {
      if (element is InstanceCreationExpression &&
          isDartNativeCreation(element, 'BarButtonItem') &&
          namedArgument(element, 'menu') != null) {
        rule.reportAtNode(element);
      }
    }
  }
}

/// Only a uniform `Border` renders; per-side values are ignored.
class UniformBorderOnly extends AnalysisRule {
  static final LintCode code = warning(
    'dartnative_uniform_border_only',
    "Only a uniform 'Border' renders; DartNative reads 'top' and applies it "
        'to all four sides.',
    correction:
        "Use Border.all, or draw a single edge with a thin Positioned "
        'Container.',
  );

  UniformBorderOnly()
    : super(
        name: 'dartnative_uniform_border_only',
        description:
            'Border(top:, right:, bottom:, left:) with fewer than four '
            'identical sides does not render the way Flutter draws it.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addInstanceCreationExpression(this, _BorderVisitor(this, context));
  }
}

class _BorderVisitor extends CreationVisitor {
  static const _sides = ['top', 'right', 'bottom', 'left'];

  _BorderVisitor(super.rule, super.context) : super(className: 'Border');

  @override
  void check(InstanceCreationExpression node) {
    // Named constructors (Border.all, Border.fromBorderSide) are uniform.
    if (node.constructorName.name != null) return;
    final given = [
      for (final side in _sides)
        if (namedArgument(node, side) != null) side,
    ];
    if (given.isEmpty || given.length == _sides.length) return;
    rule.reportAtNode(node.constructorName);
  }
}

/// A `TextField` with a controller needs `onChanged` to mirror input back.
class MirrorTextController extends AnalysisRule {
  static final LintCode code = warning(
    'dartnative_mirror_text_controller',
    "'TextEditingController' is one-way in DartNative; typed text never "
        "reaches 'controller.text' without an 'onChanged' mirror.",
    correction: "Add 'onChanged: (value) => controller.text = value'.",
  );

  MirrorTextController()
    : super(
        name: 'dartnative_mirror_text_controller',
        description:
            'A TextField with a controller but no onChanged leaves the '
            'controller stale, so clear() and text= can no-op.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addInstanceCreationExpression(
      this,
      _TextFieldVisitor(this, context),
    );
  }
}

class _TextFieldVisitor extends CreationVisitor {
  _TextFieldVisitor(super.rule, super.context) : super(className: 'TextField');

  @override
  void check(InstanceCreationExpression node) {
    final controller = namedArgument(node, 'controller');
    if (controller == null || namedArgument(node, 'onChanged') != null) return;
    rule.reportAtNode(controller);
  }
}

/// `CustomPaint.size` must be finite.
class CustomPaintFiniteSize extends AnalysisRule {
  static final LintCode code = warning(
    'dartnative_custom_paint_finite_size',
    "'CustomPaint' paints once at mount against 'size'; an infinite "
        'dimension lands off-screen and the painter never re-runs.',
    correction: 'Use a concrete size, for example from MediaQuery.',
  );

  CustomPaintFiniteSize()
    : super(
        name: 'dartnative_custom_paint_finite_size',
        description:
            'CustomPaint(size: Size(double.infinity, …)) draws nothing '
            'visible in DartNative.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addInstanceCreationExpression(
      this,
      _CustomPaintVisitor(this, context),
    );
  }
}

class _CustomPaintVisitor extends CreationVisitor {
  _CustomPaintVisitor(super.rule, super.context)
    : super(className: 'CustomPaint');

  @override
  void check(InstanceCreationExpression node) {
    final size = namedArgument(node, 'size');
    if (size == null) return;
    final finder = _InfinityFinder();
    size.argumentExpression.accept(finder);
    if (finder.found != null) rule.reportAtNode(finder.found!);
  }
}

/// Records the first `double.infinity` reference in a subtree.
class _InfinityFinder extends RecursiveAstVisitor<void> {
  AstNode? found;

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (found == null &&
        node.prefix.name == 'double' &&
        node.identifier.name == 'infinity') {
      found = node;
    }
    super.visitPrefixedIdentifier(node);
  }
}

/// `Positioned` must be the outermost wrapper of a `Stack` child.
class PositionedMustBeOutermost extends AnalysisRule {
  static final LintCode code = warning(
    'dartnative_positioned_must_be_outermost',
    "'Positioned' must be the outermost wrapper of a Stack child; this "
        'wrapper above it is dropped.',
    correction: 'Move the wrapper inside the Positioned child.',
  );

  PositionedMustBeOutermost()
    : super(
        name: 'dartnative_positioned_must_be_outermost',
        description:
            'A widget wrapping a Positioned inside Stack.children is '
            'discarded by the DartNative Stack.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addInstanceCreationExpression(this, _StackVisitor(this, context));
  }
}

class _StackVisitor extends CreationVisitor {
  _StackVisitor(super.rule, super.context) : super(className: 'Stack');

  @override
  void check(InstanceCreationExpression node) {
    final list = childrenList(node);
    if (list == null) return;
    for (final element in list.elements) {
      if (element is! InstanceCreationExpression) continue;
      if (isDartNativeCreation(element, 'Positioned')) continue;
      final inner = childArgument(element)?.argumentExpression;
      if (inner is InstanceCreationExpression &&
          isDartNativeCreation(inner, 'Positioned')) {
        rule.reportAtNode(element.constructorName);
      }
    }
  }
}

/// `SnackBarAction.onPressed` is not wired.
class SnackBarActionNotWired extends AnalysisRule {
  static final LintCode code = warning(
    'dartnative_snackbar_action_not_wired',
    "'SnackBarAction.onPressed' is not wired in DartNative; the label shows "
        'but tapping it does nothing.',
    correction: 'Use showToast, or a Button in your own overlay.',
  );

  SnackBarActionNotWired()
    : super(
        name: 'dartnative_snackbar_action_not_wired',
        description:
            'SnackBar lowers to a native toast whose action callback is not '
            'connected.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addInstanceCreationExpression(
      this,
      _SnackBarActionVisitor(this, context),
    );
  }
}

class _SnackBarActionVisitor extends CreationVisitor {
  _SnackBarActionVisitor(super.rule, super.context)
    : super(className: 'SnackBarAction');

  @override
  void check(InstanceCreationExpression node) {
    final onPressed = namedArgument(node, 'onPressed');
    if (onPressed != null) rule.reportAtNode(onPressed);
  }
}

/// `Offstage` unmounts its child; opt-in lint because it is sometimes wanted.
class OffstageLosesState extends AnalysisRule {
  static const LintCode code = LintCode(
    'dartnative_offstage_loses_state',
    "'Offstage' unmounts its child in DartNative, so the child's State is "
        'lost.',
    correctionMessage:
        'Use IndexedStack or Visibility(maintainState: true) '
        'to keep the state.',
  );

  OffstageLosesState()
    : super(
        name: 'dartnative_offstage_loses_state',
        description:
            'Flutter keeps an offstage child mounted at zero size; DartNative '
            'unmounts it.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addInstanceCreationExpression(
      this,
      _OffstageVisitor(this, context),
    );
  }
}

class _OffstageVisitor extends CreationVisitor {
  _OffstageVisitor(super.rule, super.context) : super(className: 'Offstage');

  @override
  void check(InstanceCreationExpression node) {
    rule.reportAtNode(node.constructorName);
  }
}

/// `Text` containing Blogger XML tags needs `escape: false`.
class RawTextEscapeFalse extends AnalysisRule {
  static final LintCode code = warning(
    'blogger_theme_raw_text_escape_false',
    "Text containing Blogger XML tags will be XML-escaped unless 'escape: false' is specified.",
    correction: "Add 'escape: false' or use BEval / RawText.",
  );

  RawTextEscapeFalse()
    : super(
        name: 'blogger_theme_raw_text_escape_false',
        description:
            'Passing Blogger XML expressions like <data:.../> inside Text without escape: false results in escaped XML entities in generated templates.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addInstanceCreationExpression(
      this,
      _RawTextEscapeVisitor(this, context),
    );
  }
}

class _RawTextEscapeVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _RawTextEscapeVisitor(this.rule, this.context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!isBloggerThemeCreation(node, 'Text') && !isBloggerThemeCreation(node, 'BloggerText')) return;
    final args = node.argumentList.arguments;
    if (args.isEmpty) return;
    final firstArg = args.first;
    final argSource = firstArg.toSource();
    if (!argSource.contains('<data:') &&
        !argSource.contains('<b:') &&
        !argSource.contains('</b:')) {
      return;
    }
    final escapeArg = namedArgument(node, 'escape');
    if (escapeArg == null || escapeArg.argumentExpression.toSource() != 'false') {
      rule.reportAtNode(firstArg);
    }
  }
}

/// `BSection` or `BWidget` requires a unique `id` attribute.
class BSectionUniqueId extends AnalysisRule {
  static final LintCode code = warning(
    'blogger_theme_bsection_unique_id',
    "BSection and BWidget require a unique 'id' attribute.",
    correction: "Provide a unique 'id' string parameter.",
  );

  BSectionUniqueId()
    : super(
        name: 'blogger_theme_bsection_unique_id',
        description:
            'Blogger layout engines require every BSection and BWidget to have a distinct id.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addCompilationUnit(
      this,
      _BSectionUniqueIdVisitor(this, context),
    );
  }
}

class _BSectionUniqueIdVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _BSectionUniqueIdVisitor(this.rule, this.context);

  @override
  void visitCompilationUnit(CompilationUnit node) {
    final seenIds = <String, InstanceCreationExpression>{};
    node.accept(_BSectionFinder((creation, idArg) {
      if (idArg == null) {
        rule.reportAtNode(creation.constructorName);
        return;
      }
      final idValue = idArg.argumentExpression.toSource();
      if (seenIds.containsKey(idValue)) {
        rule.reportAtNode(idArg);
      } else {
        seenIds[idValue] = creation;
      }
    }));
  }
}

class _BSectionFinder extends RecursiveAstVisitor<void> {
  final void Function(InstanceCreationExpression creation, NamedArgument? idArg) callback;

  _BSectionFinder(this.callback);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (isBloggerThemeCreation(node, 'BSection') ||
        isBloggerThemeCreation(node, 'BWidget')) {
      callback(node, namedArgument(node, 'id'));
    }
    super.visitInstanceCreationExpression(node);
  }
}

/// `BWidget` requires a `type` attribute.
class BWidgetTypeRequired extends AnalysisRule {
  static final LintCode code = warning(
    'blogger_theme_bwidget_type_required',
    "BWidget requires a 'type' attribute (e.g., 'Header', 'Blog', 'HTML').",
    correction: "Add 'type: \"Blog\"' or appropriate widget type.",
  );

  BWidgetTypeRequired()
    : super(
        name: 'blogger_theme_bwidget_type_required',
        description:
            'Blogger widgets must specify a type for proper template rendering.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addInstanceCreationExpression(
      this,
      _BWidgetTypeVisitor(this, context),
    );
  }
}

class _BWidgetTypeVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _BWidgetTypeVisitor(this.rule, this.context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!isBloggerThemeCreation(node, 'BWidget')) return;
    if (namedArgument(node, 'type') == null) {
      rule.reportAtNode(node.constructorName);
    }
  }
}

/// `BLoop` requires both `values` and `varName` attributes.
class BLoopRequiredArgs extends AnalysisRule {
  static final LintCode code = warning(
    'blogger_theme_bloop_required_args',
    "BLoop requires both 'values' and 'varName' attributes.",
    correction: "Add missing 'values:' or 'varName:' parameter.",
  );

  BLoopRequiredArgs()
    : super(
        name: 'blogger_theme_bloop_required_args',
        description:
            'BLoop renders <b:loop values="..." var="..."> so both attributes are required.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addInstanceCreationExpression(
      this,
      _BLoopArgsVisitor(this, context),
    );
  }
}

class _BLoopArgsVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _BLoopArgsVisitor(this.rule, this.context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!isBloggerThemeCreation(node, 'BLoop')) return;
    final hasValues = namedArgument(node, 'values') != null;
    final hasVar = namedArgument(node, 'varName') != null || namedArgument(node, 'var') != null;
    if (!hasValues || !hasVar) {
      rule.reportAtNode(node.constructorName);
    }
  }
}

/// `AmpImg` requires both `width` and `height` attributes for AMP layout calculation.
class AmpImgDimensionsRequired extends AnalysisRule {
  static final LintCode code = warning(
    'blogger_theme_amp_img_dimensions_required',
    "AmpImg requires both 'width' and 'height' attributes for AMP compliance.",
    correction: "Add missing 'width' or 'height' parameter.",
  );

  AmpImgDimensionsRequired()
    : super(
        name: 'blogger_theme_amp_img_dimensions_required',
        description:
            'AMP requires explicit width and height attributes on amp-img elements.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addInstanceCreationExpression(
      this,
      _AmpImgDimensionsVisitor(this, context),
    );
  }
}

class _AmpImgDimensionsVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _AmpImgDimensionsVisitor(this.rule, this.context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!isBloggerThemeCreation(node, 'AmpImg')) return;
    final hasWidth = namedArgument(node, 'width') != null;
    final hasHeight = namedArgument(node, 'height') != null;
    if (!hasWidth || !hasHeight) {
      rule.reportAtNode(node.constructorName);
    }
  }
}

/// `BEval` requires `expr` attribute.
class BEvalExprRequired extends AnalysisRule {
  static final LintCode code = warning(
    'blogger_theme_beval_expr_required',
    "BEval requires an 'expr' attribute.",
    correction: "Provide a non-empty 'expr:' argument.",
  );

  BEvalExprRequired()
    : super(
        name: 'blogger_theme_beval_expr_required',
        description:
            'BEval renders <b:eval expr="..."/> so the expr attribute is mandatory.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addInstanceCreationExpression(
      this,
      _BEvalExprVisitor(this, context),
    );
  }
}

class _BEvalExprVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _BEvalExprVisitor(this.rule, this.context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!isBloggerThemeCreation(node, 'BEval')) return;
    final exprArg = namedArgument(node, 'expr');
    if (exprArg == null) {
      rule.reportAtNode(node.constructorName);
    }
  }
}

/// `BIncludable` requires `id` attribute.
class BIncludableIdRequired extends AnalysisRule {
  static final LintCode code = warning(
    'blogger_theme_bincludable_id_required',
    "BIncludable requires an 'id' attribute.",
    correction: "Provide an 'id:' argument for BIncludable.",
  );

  BIncludableIdRequired()
    : super(
        name: 'blogger_theme_bincludable_id_required',
        description:
            'BIncludable defines reusable template macros so the id attribute is required.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addInstanceCreationExpression(
      this,
      _BIncludableIdVisitor(this, context),
    );
  }
}

class _BIncludableIdVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _BIncludableIdVisitor(this.rule, this.context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!isBloggerThemeCreation(node, 'BIncludable')) return;
    if (namedArgument(node, 'id') == null) {
      rule.reportAtNode(node.constructorName);
    }
  }
}

/// `AmpAudio` and `AmpVideo` require a `src` attribute.
class AmpAudioSrcRequired extends AnalysisRule {
  static final LintCode code = warning(
    'blogger_theme_amp_audio_src_required',
    "AmpAudio and AmpVideo require a 'src' attribute.",
    correction: "Provide a 'src:' parameter with the media URL.",
  );

  AmpAudioSrcRequired()
    : super(
        name: 'blogger_theme_amp_audio_src_required',
        description:
            'AMP media elements require a src attribute to specify media location.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addInstanceCreationExpression(
      this,
      _AmpAudioSrcVisitor(this, context),
    );
  }
}

class _AmpAudioSrcVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _AmpAudioSrcVisitor(this.rule, this.context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!isBloggerThemeCreation(node, 'AmpAudio') &&
        !isBloggerThemeCreation(node, 'AmpVideo')) {
      return;
    }
    if (namedArgument(node, 'src') == null) {
      rule.reportAtNode(node.constructorName);
    }
  }
}

/// `AmpYoutube` requires a `videoid` attribute.
class AmpYoutubeVideoidRequired extends AnalysisRule {
  static final LintCode code = warning(
    'blogger_theme_amp_youtube_videoid_required',
    "AmpYoutube requires a 'videoid' attribute.",
    correction: "Provide a 'videoid:' parameter with the YouTube video ID.",
  );

  AmpYoutubeVideoidRequired()
    : super(
        name: 'blogger_theme_amp_youtube_videoid_required',
        description:
            'AmpYoutube embeds require a videoid attribute to locate the YouTube video.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addInstanceCreationExpression(
      this,
      _AmpYoutubeVideoidVisitor(this, context),
    );
  }
}

class _AmpYoutubeVideoidVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _AmpYoutubeVideoidVisitor(this.rule, this.context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!isBloggerThemeCreation(node, 'AmpYoutube')) return;
    if (namedArgument(node, 'videoid') == null) {
      rule.reportAtNode(node.constructorName);
    }
  }
}

/// `AmpInstagram` and `AmpTwitter` social embeds require identifier attributes.
class AmpSocialEmbedIdRequired extends AnalysisRule {
  static final LintCode code = warning(
    'blogger_theme_amp_social_embed_id_required',
    "Social embeds (AmpInstagram/AmpTwitter) require an identifier attribute ('shortcode' or 'tweetid').",
    correction: "Add 'shortcode:' or 'tweetid:' attribute.",
  );

  AmpSocialEmbedIdRequired()
    : super(
        name: 'blogger_theme_amp_social_embed_id_required',
        description:
            'Social embeds require specific post/tweet identifier attributes.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addInstanceCreationExpression(
      this,
      _AmpSocialEmbedVisitor(this, context),
    );
  }
}

class _AmpSocialEmbedVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _AmpSocialEmbedVisitor(this.rule, this.context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (isBloggerThemeCreation(node, 'AmpInstagram')) {
      final hasShortcode = namedArgument(node, 'shortcode') != null ||
          namedArgument(node, 'dataShortcode') != null;
      if (!hasShortcode) rule.reportAtNode(node.constructorName);
    } else if (isBloggerThemeCreation(node, 'AmpTwitter')) {
      final hasTweetId = namedArgument(node, 'tweetid') != null ||
          namedArgument(node, 'tweetId') != null;
      if (!hasTweetId) rule.reportAtNode(node.constructorName);
    }
  }
}

/// For AMP compliance, `BSkin` should keep CSS string empty `""` and put custom CSS in `<style amp-custom>`.
class BSkinEmptyCssAmpRule extends AnalysisRule {
  static final LintCode code = warning(
    'blogger_theme_bskin_empty_css_amp',
    "For AMP themes, keep the BSkin CSS string empty (\"\") and put custom CSS in <style amp-custom>.",
    correction: "Change first parameter of BSkin to \"\" and move CSS to style({'amp-custom': 'amp-custom'}, [...]).",
  );

  BSkinEmptyCssAmpRule()
    : super(
        name: 'blogger_theme_bskin_empty_css_amp',
        description:
            'AMP validation requires b:skin CSS output to be empty to prevent default Blogger skin CSS injection.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addInstanceCreationExpression(
      this,
      _BSkinCssVisitor(this, context),
    );
  }
}

class _BSkinCssVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _BSkinCssVisitor(this.rule, this.context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!isBloggerThemeCreation(node, 'BSkin')) return;
    final args = node.argumentList.arguments;
    if (args.isEmpty) return;
    final firstArg = args.first;
    if (firstArg is StringLiteral) {
      final value = firstArg.stringValue;
      if (value != null && value.trim().isNotEmpty) {
        rule.reportAtNode(firstArg);
      }
    }
  }
}

/// Every rule that is on by default.
List<AnalysisRule> get warningRules => [
  FabSlotAndroidOnly(),
  MenuActionMustBeAlone(),
  UniformBorderOnly(),
  MirrorTextController(),
  CustomPaintFiniteSize(),
  PositionedMustBeOutermost(),
  SnackBarActionNotWired(),
  RawTextEscapeFalse(),
  BSectionUniqueId(),
  BWidgetTypeRequired(),
  BLoopRequiredArgs(),
  AmpImgDimensionsRequired(),
  BEvalExprRequired(),
  BIncludableIdRequired(),
  AmpAudioSrcRequired(),
  AmpYoutubeVideoidRequired(),
  AmpSocialEmbedIdRequired(),
  BSkinEmptyCssAmpRule(),
];

/// Rules that must be enabled in analysis_options.yaml.
List<AnalysisRule> get lintRules => [OffstageLosesState()];
