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

/// `BElseIf` and `BElse` should only be placed inside `BIf` components.
class BElseIfParentMustBeBIf extends AnalysisRule {
  static final LintCode code = warning(
    'blogger_theme_belseif_parent_must_be_bif',
    "BElseIf and BElse should be placed inside a BIf component.",
    correction: "Move BElseIf / BElse inside a BIf children list.",
  );

  BElseIfParentMustBeBIf()
    : super(
        name: 'blogger_theme_belseif_parent_must_be_bif',
        description:
            'BElseIf and BElse components render <b:elseif> and <b:else> tags which require an enclosing <b:if> block.',
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
      _BElseIfParentVisitor(this, context),
    );
  }
}

class _BElseIfParentVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _BElseIfParentVisitor(this.rule, this.context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!isBloggerThemeCreation(node, 'BElseIf') &&
        !isBloggerThemeCreation(node, 'BElse')) {
      return;
    }
    AstNode? current = node.parent;
    bool foundBIf = false;
    while (current != null) {
      if (current is InstanceCreationExpression &&
          (isBloggerThemeCreation(current, 'BIf') ||
           isBloggerThemeCreation(current, 'BElseIf'))) {
        foundBIf = true;
        break;
      }
      if (current is FunctionBody || current is Statement) break;
      current = current.parent;
    }
    if (!foundBIf) {
      rule.reportAtNode(node.constructorName);
    }
  }
}

/// `BAttr` requires a `name` parameter.
class BAttrNameRequired extends AnalysisRule {
  static final LintCode code = warning(
    'blogger_theme_battr_name_required',
    "BAttr requires a 'name' attribute.",
    correction: "Provide a 'name:' argument for BAttr.",
  );

  BAttrNameRequired()
    : super(
        name: 'blogger_theme_battr_name_required',
        description:
            'BAttr generates <b:attr name="..."> so the name parameter is required.',
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
      _BAttrNameVisitor(this, context),
    );
  }
}

class _BAttrNameVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _BAttrNameVisitor(this.rule, this.context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!isBloggerThemeCreation(node, 'BAttr')) return;
    if (namedArgument(node, 'name') == null) {
      rule.reportAtNode(node.constructorName);
    }
  }
}

/// `BClass` requires either `name` or `exprName` parameter.
class BClassExprOrNameRequired extends AnalysisRule {
  static final LintCode code = warning(
    'blogger_theme_bclass_expr_or_name_required',
    "BClass requires either a 'name' or 'exprName' attribute.",
    correction: "Add 'name:' or 'exprName:' parameter to BClass.",
  );

  BClassExprOrNameRequired()
    : super(
        name: 'blogger_theme_bclass_expr_or_name_required',
        description:
            'BClass generates <b:class name="..." expr:name="..."/> so at least one name attribute is required.',
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
      _BClassArgsVisitor(this, context),
    );
  }
}

class _BClassArgsVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _BClassArgsVisitor(this.rule, this.context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!isBloggerThemeCreation(node, 'BClass')) return;
    final hasName = namedArgument(node, 'name') != null;
    final hasExprName = namedArgument(node, 'exprName') != null;
    if (!hasName && !hasExprName) {
      rule.reportAtNode(node.constructorName);
    }
  }
}

/// `BVariable` requires `name` and `type` attributes.
class BVariableRequiredArgs extends AnalysisRule {
  static final LintCode code = warning(
    'blogger_theme_bvariable_required_args',
    "BVariable requires 'name' and 'type' attributes.",
    correction: "Add missing 'name:' or 'type:' parameter.",
  );

  BVariableRequiredArgs()
    : super(
        name: 'blogger_theme_bvariable_required_args',
        description:
            'BVariable defines Blogger theme designer variables so name and type are required.',
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
      _BVariableArgsVisitor(this, context),
    );
  }
}

class _BVariableArgsVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _BVariableArgsVisitor(this.rule, this.context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!isBloggerThemeCreation(node, 'BVariable')) return;
    final hasName = namedArgument(node, 'name') != null;
    final hasType = namedArgument(node, 'type') != null;
    if (!hasName || !hasType) {
      rule.reportAtNode(node.constructorName);
    }
  }
}

/// `BInclude` requires `name` attribute.
class BIncludeNameRequired extends AnalysisRule {
  static final LintCode code = warning(
    'blogger_theme_binclude_name_required',
    "BInclude requires a 'name' attribute.",
    correction: "Provide a 'name:' parameter with the includable identifier.",
  );

  BIncludeNameRequired()
    : super(
        name: 'blogger_theme_binclude_name_required',
        description:
            'BInclude includes a BIncludable macro so the name attribute is mandatory.',
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
      _BIncludeNameVisitor(this, context),
    );
  }
}

class _BIncludeNameVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _BIncludeNameVisitor(this.rule, this.context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!isBloggerThemeCreation(node, 'BInclude')) return;
    if (namedArgument(node, 'name') == null) {
      rule.reportAtNode(node.constructorName);
    }
  }
}

/// `BClientScript` requires script callback or source.
class BClientScriptContentRequired extends AnalysisRule {
  static final LintCode code = warning(
    'blogger_theme_bclient_script_content_required',
    "BClientScript requires a script function or source parameter.",
    correction: "Provide a function or script parameter for BClientScript.",
  );

  BClientScriptContentRequired()
    : super(
        name: 'blogger_theme_bclient_script_content_required',
        description:
            'BClientScript compiles Dart-to-JS client scripts so script source is required.',
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
      _BClientScriptContentVisitor(this, context),
    );
  }
}

class _BClientScriptContentVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _BClientScriptContentVisitor(this.rule, this.context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!isBloggerThemeCreation(node, 'BClientScript')) return;
    if (node.argumentList.arguments.isEmpty) {
      rule.reportAtNode(node.constructorName);
    }
  }
}

/// `img(...)` helper requires an `alt` attribute for accessibility.
class HtmlImgAltRequired extends AnalysisRule {
  static final LintCode code = warning(
    'blogger_theme_html_img_alt_required',
    "img(...) helper requires an 'alt' attribute for accessibility.",
    correction: "Add 'alt:' key to the img attribute map.",
  );

  HtmlImgAltRequired()
    : super(
        name: 'blogger_theme_html_img_alt_required',
        description:
            'HTML img tags require an alt attribute for accessibility and valid markup.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addMethodInvocation(
      this,
      _HtmlImgAltVisitor(this, context),
    );
  }
}

class _HtmlImgAltVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _HtmlImgAltVisitor(this.rule, this.context);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name != 'img') return;
    final element = node.methodName.element;
    if (element != null && !isBloggerThemeElement(element)) return;
    bool hasAlt = false;
    for (final arg in node.argumentList.arguments) {
      if (arg is SetOrMapLiteral) {
        for (final element in arg.elements) {
          if (element is MapLiteralEntry) {
            final keySrc = element.key.toSource();
            if (keySrc.contains('alt') || keySrc.contains('expr:alt')) {
              hasAlt = true;
              break;
            }
          }
        }
      }
    }
    if (!hasAlt) {
      rule.reportAtNode(node.methodName);
    }
  }
}

/// `a(...)` helper requires an `href` or `expr:href` attribute.
class HtmlAnchorHrefRequired extends AnalysisRule {
  static final LintCode code = warning(
    'blogger_theme_html_anchor_href_required',
    "a(...) helper requires an 'href' or 'expr:href' attribute.",
    correction: "Add 'href:' or 'expr:href:' key to the a attribute map.",
  );

  HtmlAnchorHrefRequired()
    : super(
        name: 'blogger_theme_html_anchor_href_required',
        description:
            'HTML anchor tags require an href or expr:href attribute.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addMethodInvocation(
      this,
      _HtmlAnchorHrefVisitor(this, context),
    );
  }
}

class _HtmlAnchorHrefVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _HtmlAnchorHrefVisitor(this.rule, this.context);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name != 'a') return;
    final element = node.methodName.element;
    if (element != null && !isBloggerThemeElement(element)) return;
    bool hasHref = false;
    for (final arg in node.argumentList.arguments) {
      if (arg is SetOrMapLiteral) {
        for (final element in arg.elements) {
          if (element is MapLiteralEntry) {
            final keySrc = element.key.toSource();
            if (keySrc.contains('href') || keySrc.contains('expr:href')) {
              hasHref = true;
              break;
            }
          }
        }
      }
    }
    if (!hasHref) {
      rule.reportAtNode(node.methodName);
    }
  }
}

/// `form(...)` helper requires an `action` or `expr:action` attribute.
class HtmlFormActionRequired extends AnalysisRule {
  static final LintCode code = warning(
    'blogger_theme_html_form_action_required',
    "form(...) helper requires an 'action' or 'expr:action' attribute.",
    correction: "Add 'action:' or 'expr:action:' key to the form attribute map.",
  );

  HtmlFormActionRequired()
    : super(
        name: 'blogger_theme_html_form_action_required',
        description:
            'HTML form elements require an action or expr:action attribute.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addMethodInvocation(
      this,
      _HtmlFormActionVisitor(this, context),
    );
  }
}

class _HtmlFormActionVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _HtmlFormActionVisitor(this.rule, this.context);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name != 'form') return;
    final element = node.methodName.element;
    if (element != null && !isBloggerThemeElement(element)) return;
    bool hasAction = false;
    for (final arg in node.argumentList.arguments) {
      if (arg is SetOrMapLiteral) {
        for (final element in arg.elements) {
          if (element is MapLiteralEntry) {
            final keySrc = element.key.toSource();
            if (keySrc.contains('action') || keySrc.contains('expr:action')) {
              hasAction = true;
              break;
            }
          }
        }
      }
    }
    if (!hasAction) {
      rule.reportAtNode(node.methodName);
    }
  }
}

/// `AmpIframe` requires a `sandbox` attribute.
class AmpIframeSandboxRequired extends AnalysisRule {
  static final LintCode code = warning(
    'blogger_theme_amp_iframe_sandbox_required',
    "AmpIframe requires a 'sandbox' attribute for AMP security validation.",
    correction: "Add 'sandbox:' parameter (e.g. 'allow-scripts allow-same-origin').",
  );

  AmpIframeSandboxRequired()
    : super(
        name: 'blogger_theme_amp_iframe_sandbox_required',
        description:
            'AMP requires explicit sandbox attributes on amp-iframe elements.',
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
      _AmpIframeSandboxVisitor(this, context),
    );
  }
}

class _AmpIframeSandboxVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _AmpIframeSandboxVisitor(this.rule, this.context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!isBloggerThemeCreation(node, 'AmpIframe')) return;
    if (namedArgument(node, 'sandbox') == null) {
      rule.reportAtNode(node.constructorName);
    }
  }
}

/// `AmpSocialShare` requires a `type` attribute.
class AmpSocialShareTypeRequired extends AnalysisRule {
  static final LintCode code = warning(
    'blogger_theme_amp_social_share_type_required',
    "AmpSocialShare requires a 'type' attribute (e.g. 'twitter', 'facebook', 'linkedin').",
    correction: "Provide a 'type:' parameter for AmpSocialShare.",
  );

  AmpSocialShareTypeRequired()
    : super(
        name: 'blogger_theme_amp_social_share_type_required',
        description:
            'AmpSocialShare specifies the target provider via the type attribute.',
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
      _AmpSocialShareTypeVisitor(this, context),
    );
  }
}

class _AmpSocialShareTypeVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _AmpSocialShareTypeVisitor(this.rule, this.context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!isBloggerThemeCreation(node, 'AmpSocialShare')) return;
    if (namedArgument(node, 'type') == null) {
      rule.reportAtNode(node.constructorName);
    }
  }
}

/// `AmpList` requires a `src` attribute.
class AmpListSrcRequired extends AnalysisRule {
  static final LintCode code = warning(
    'blogger_theme_amp_list_src_required',
    "AmpList requires a 'src' attribute pointing to dynamic JSON data.",
    correction: "Provide a 'src:' parameter with the JSON endpoint URL.",
  );

  AmpListSrcRequired()
    : super(
        name: 'blogger_theme_amp_list_src_required',
        description:
            'AmpList fetches dynamic content from a JSON endpoint so src is mandatory.',
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
      _AmpListSrcVisitor(this, context),
    );
  }
}

class _AmpListSrcVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _AmpListSrcVisitor(this.rule, this.context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!isBloggerThemeCreation(node, 'AmpList')) return;
    if (namedArgument(node, 'src') == null) {
      rule.reportAtNode(node.constructorName);
    }
  }
}

/// `BSkin` without variables or CSS definition.
class BSkinVariablesRequired extends AnalysisRule {
  static final LintCode code = warning(
    'blogger_theme_bskin_variables_required',
    "BSkin should declare custom variables or CSS rules.",
    correction: "Provide 'variables:' list or CSS string parameter.",
  );

  BSkinVariablesRequired()
    : super(
        name: 'blogger_theme_bskin_variables_required',
        description:
            'BSkin defines theme skin variables so providing variables or CSS content is recommended.',
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
      _BSkinVarsVisitor(this, context),
    );
  }
}

class _BSkinVarsVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _BSkinVarsVisitor(this.rule, this.context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!isBloggerThemeCreation(node, 'BSkin')) return;
    final args = node.argumentList.arguments;
    final hasVars = namedArgument(node, 'variables') != null;
    bool hasNonEmptyCss = false;
    if (args.isNotEmpty && args.first is StringLiteral) {
      final value = (args.first as StringLiteral).stringValue;
      if (value != null && value.trim().isNotEmpty) hasNonEmptyCss = true;
    }
    if (!hasVars && !hasNonEmptyCss) {
      rule.reportAtNode(node.constructorName);
    }
  }
}

/// `BTag` requires a `name` attribute.
class BTagMissingName extends AnalysisRule {
  static final LintCode code = warning(
    'blogger_theme_btag_missing_name',
    "BTag requires a 'name' attribute.",
    correction: "Provide a 'name:' parameter for BTag.",
  );

  BTagMissingName()
    : super(
        name: 'blogger_theme_btag_missing_name',
        description:
            'BTag renders custom Blogger dynamic tags so the name attribute is mandatory.',
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
      _BTagVisitor(this, context),
    );
  }
}

class _BTagVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _BTagVisitor(this.rule, this.context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!isBloggerThemeCreation(node, 'BTag')) return;
    if (namedArgument(node, 'name') == null) {
      rule.reportAtNode(node.constructorName);
    }
  }
}

/// `BArg` requires a `name` attribute.
class BArgNameRequired extends AnalysisRule {
  static final LintCode code = warning(
    'blogger_theme_barg_name_required',
    "BArg requires a 'name' attribute.",
    correction: "Provide a 'name:' parameter for BArg.",
  );

  BArgNameRequired()
    : super(
        name: 'blogger_theme_barg_name_required',
        description:
            'BArg passes macro parameters to BInclude so the name attribute is mandatory.',
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
      _BArgNameVisitor(this, context),
    );
  }
}

class _BArgNameVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _BArgNameVisitor(this.rule, this.context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!isBloggerThemeCreation(node, 'BArg')) return;
    if (namedArgument(node, 'name') == null) {
      rule.reportAtNode(node.constructorName);
    }
  }
}

/// `BData` requires an `expr` or `name` attribute.
class BDataExprRequired extends AnalysisRule {
  static final LintCode code = warning(
    'blogger_theme_bdata_expr_required',
    "BData requires an 'expr' or 'name' attribute.",
    correction: "Add 'expr:' parameter to BData.",
  );

  BDataExprRequired()
    : super(
        name: 'blogger_theme_bdata_expr_required',
        description:
            'BData renders <b:data expr="..."/> so the expr attribute is mandatory.',
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
      _BDataExprVisitor(this, context),
    );
  }
}

class _BDataExprVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _BDataExprVisitor(this.rule, this.context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!isBloggerThemeCreation(node, 'BData')) return;
    final hasExpr = namedArgument(node, 'expr') != null;
    final hasName = namedArgument(node, 'name') != null;
    if (!hasExpr && !hasName) {
      rule.reportAtNode(node.constructorName);
    }
  }
}

/// `AmpAnalytics` requires `type` or `config` attribute.
class AmpAnalyticsTypeOrConfigRequired extends AnalysisRule {
  static final LintCode code = warning(
    'blogger_theme_amp_analytics_type_or_config_required',
    "AmpAnalytics requires either a 'type' or 'config' attribute.",
    correction: "Add 'type:' or 'config:' parameter to AmpAnalytics.",
  );

  AmpAnalyticsTypeOrConfigRequired()
    : super(
        name: 'blogger_theme_amp_analytics_type_or_config_required',
        description:
            'AmpAnalytics requires a provider type or JSON configuration source.',
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
      _AmpAnalyticsVisitor(this, context),
    );
  }
}

class _AmpAnalyticsVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _AmpAnalyticsVisitor(this.rule, this.context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!isBloggerThemeCreation(node, 'AmpAnalytics')) return;
    final hasType = namedArgument(node, 'type') != null;
    final hasConfig = namedArgument(node, 'config') != null;
    if (!hasType && !hasConfig) {
      rule.reportAtNode(node.constructorName);
    }
  }
}

/// `AmpAd` requires `type`, `width`, and `height` attributes.
class AmpAdRequiredArgs extends AnalysisRule {
  static final LintCode code = warning(
    'blogger_theme_amp_ad_required_args',
    "AmpAd requires 'type', 'width', and 'height' attributes.",
    correction: "Add missing 'type:', 'width:', or 'height:' parameters.",
  );

  AmpAdRequiredArgs()
    : super(
        name: 'blogger_theme_amp_ad_required_args',
        description:
            'AMP ad elements require ad network type along with layout dimensions.',
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
      _AmpAdVisitor(this, context),
    );
  }
}

class _AmpAdVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _AmpAdVisitor(this.rule, this.context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!isBloggerThemeCreation(node, 'AmpAd')) return;
    final hasType = namedArgument(node, 'type') != null;
    final hasWidth = namedArgument(node, 'width') != null;
    final hasHeight = namedArgument(node, 'height') != null;
    if (!hasType || !hasWidth || !hasHeight) {
      rule.reportAtNode(node.constructorName);
    }
  }
}

/// `AmpFitText` requires `width` and `height` attributes.
class AmpFitTextDimensionsRequired extends AnalysisRule {
  static final LintCode code = warning(
    'blogger_theme_amp_fit_text_dimensions_required',
    "AmpFitText requires both 'width' and 'height' attributes.",
    correction: "Add missing 'width:' or 'height:' parameters.",
  );

  AmpFitTextDimensionsRequired()
    : super(
        name: 'blogger_theme_amp_fit_text_dimensions_required',
        description:
            'AmpFitText requires fixed layout dimensions for responsive font scaling.',
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
      _AmpFitTextVisitor(this, context),
    );
  }
}

class _AmpFitTextVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _AmpFitTextVisitor(this.rule, this.context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!isBloggerThemeCreation(node, 'AmpFitText')) return;
    final hasWidth = namedArgument(node, 'width') != null;
    final hasHeight = namedArgument(node, 'height') != null;
    if (!hasWidth || !hasHeight) {
      rule.reportAtNode(node.constructorName);
    }
  }
}

/// `AmpTwitter` requires `tweetid` or `tweetId` attribute.
class AmpTwitterTweetidRequired extends AnalysisRule {
  static final LintCode code = warning(
    'blogger_theme_amp_twitter_tweetid_required',
    "AmpTwitter requires a 'tweetid' or 'tweetId' attribute.",
    correction: "Provide a 'tweetid:' parameter.",
  );

  AmpTwitterTweetidRequired()
    : super(
        name: 'blogger_theme_amp_twitter_tweetid_required',
        description:
            'AmpTwitter requires a tweet ID to render the embedded tweet.',
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
      _AmpTwitterVisitor(this, context),
    );
  }
}

class _AmpTwitterVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _AmpTwitterVisitor(this.rule, this.context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!isBloggerThemeCreation(node, 'AmpTwitter')) return;
    final hasTweetId = namedArgument(node, 'tweetid') != null ||
        namedArgument(node, 'tweetId') != null;
    if (!hasTweetId) {
      rule.reportAtNode(node.constructorName);
    }
  }
}

/// `AmpStory` requires metadata attributes.
class AmpStoryRequiredArgs extends AnalysisRule {
  static final LintCode code = warning(
    'blogger_theme_amp_story_required_args',
    "AmpStory requires 'title', 'publisher', 'publisherLogoSrc', and 'posterPortraitSrc' attributes.",
    correction: "Provide all required AmpStory metadata parameters.",
  );

  AmpStoryRequiredArgs()
    : super(
        name: 'blogger_theme_amp_story_required_args',
        description:
            'AMP Stories require full metadata attributes for standard validation.',
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
      _AmpStoryVisitor(this, context),
    );
  }
}

class _AmpStoryVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _AmpStoryVisitor(this.rule, this.context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!isBloggerThemeCreation(node, 'AmpStory')) return;
    final hasTitle = namedArgument(node, 'title') != null;
    final hasPublisher = namedArgument(node, 'publisher') != null;
    final hasLogo = namedArgument(node, 'publisherLogoSrc') != null;
    final hasPoster = namedArgument(node, 'posterPortraitSrc') != null;
    if (!hasTitle || !hasPublisher || !hasLogo || !hasPoster) {
      rule.reportAtNode(node.constructorName);
    }
  }
}

/// `AmpStoryPage` requires `id` attribute.
class AmpStoryPageIdRequired extends AnalysisRule {
  static final LintCode code = warning(
    'blogger_theme_amp_story_page_id_required',
    "AmpStoryPage requires an 'id' attribute.",
    correction: "Provide an 'id:' parameter for AmpStoryPage.",
  );

  AmpStoryPageIdRequired()
    : super(
        name: 'blogger_theme_amp_story_page_id_required',
        description:
            'AMP Story pages require unique id attributes for story navigation.',
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
      _AmpStoryPageVisitor(this, context),
    );
  }
}

class _AmpStoryPageVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _AmpStoryPageVisitor(this.rule, this.context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!isBloggerThemeCreation(node, 'AmpStoryPage')) return;
    if (namedArgument(node, 'id') == null) {
      rule.reportAtNode(node.constructorName);
    }
  }
}

/// `AmpConsent` requires `id` attribute.
class AmpConsentIdRequired extends AnalysisRule {
  static final LintCode code = warning(
    'blogger_theme_amp_consent_id_required',
    "AmpConsent requires an 'id' attribute.",
    correction: "Provide an 'id:' parameter for AmpConsent.",
  );

  AmpConsentIdRequired()
    : super(
        name: 'blogger_theme_amp_consent_id_required',
        description:
            'AMP Consent component requires a unique element ID attribute.',
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
      _AmpConsentVisitor(this, context),
    );
  }
}

class _AmpConsentVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _AmpConsentVisitor(this.rule, this.context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!isBloggerThemeCreation(node, 'AmpConsent')) return;
    if (namedArgument(node, 'id') == null) {
      rule.reportAtNode(node.constructorName);
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
  BElseIfParentMustBeBIf(),
  BAttrNameRequired(),
  BClassExprOrNameRequired(),
  BVariableRequiredArgs(),
  BIncludeNameRequired(),
  BClientScriptContentRequired(),
  HtmlImgAltRequired(),
  HtmlAnchorHrefRequired(),
  HtmlFormActionRequired(),
  AmpIframeSandboxRequired(),
  AmpSocialShareTypeRequired(),
  AmpListSrcRequired(),
  BSkinVariablesRequired(),
  BTagMissingName(),
  BArgNameRequired(),
  BDataExprRequired(),
  AmpAnalyticsTypeOrConfigRequired(),
  AmpAdRequiredArgs(),
  AmpFitTextDimensionsRequired(),
  AmpTwitterTweetidRequired(),
  AmpStoryRequiredArgs(),
  AmpStoryPageIdRequired(),
  AmpConsentIdRequired(),
];

/// Rules that must be enabled in analysis_options.yaml.
List<AnalysisRule> get lintRules => [OffstageLosesState()];
