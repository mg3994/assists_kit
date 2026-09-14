// ignore_for_file: non_constant_identifier_names

import 'package:assists_kit/src/rules/rules.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../support/test_bases.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(FabSlotAndroidOnlyTest);
    defineReflectiveTests(MenuActionMustBeAloneTest);
    defineReflectiveTests(UniformBorderOnlyTest);
    defineReflectiveTests(MirrorTextControllerTest);
    defineReflectiveTests(CustomPaintFiniteSizeTest);
    defineReflectiveTests(PositionedMustBeOutermostTest);
    defineReflectiveTests(SnackBarActionNotWiredTest);
    defineReflectiveTests(OffstageLosesStateTest);
    defineReflectiveTests(RawTextEscapeFalseTest);
    defineReflectiveTests(BSectionUniqueIdTest);
    defineReflectiveTests(BWidgetTypeRequiredTest);
    defineReflectiveTests(BLoopRequiredArgsTest);
    defineReflectiveTests(AmpImgDimensionsRequiredTest);
    defineReflectiveTests(BEvalExprRequiredTest);
    defineReflectiveTests(BIncludableIdRequiredTest);
    defineReflectiveTests(AmpAudioSrcRequiredTest);
    defineReflectiveTests(AmpYoutubeVideoidRequiredTest);
    defineReflectiveTests(AmpSocialEmbedIdRequiredTest);
    defineReflectiveTests(BSkinEmptyCssAmpRuleTest);
  });
}

@reflectiveTest
class FabSlotAndroidOnlyTest extends RuleTest {
  @override
  void setUp() {
    rule = FabSlotAndroidOnly();
    super.setUp();
  }

  Future<void> test_reportsTheSlot() => assertWarning(
    '''
Widget build() => Scaffold(
  floatingActionButton: FloatingActionButton(child: Icon(CupertinoIcons.plus)),
);
''',
    'floatingActionButton: FloatingActionButton(child: '
        'Icon(CupertinoIcons.plus))',
  );

  Future<void> test_quietWithoutTheSlot() =>
      assertClean("Widget build() => Scaffold(body: Text('x'));");

  Future<void> test_quietWhenGatedOnPlatform() => assertClean('''
// Stands in for dart:io, whose members the test SDK marks deprecated.
class Platform {
  static bool get isAndroid => true;
}

Widget build() => Scaffold(
  floatingActionButton: Platform.isAndroid
      ? FloatingActionButton(child: Icon(CupertinoIcons.plus))
      : null,
);
''');
}

@reflectiveTest
class MenuActionMustBeAloneTest extends RuleTest {
  @override
  void setUp() {
    rule = MenuActionMustBeAlone();
    super.setUp();
  }

  Future<void> test_reportsAMenuItemWithSiblings() => assertWarning(
    '''
Widget build() => AppBar(actions: [
  BarButtonItem(title: 'Info', onPressed: () {}),
  BarButtonItem(icon: 'ellipsis', menu: [MenuAction(title: 'A', onTap: () {})]),
]);
''',
    "BarButtonItem(icon: 'ellipsis', menu: [MenuAction(title: 'A', "
        'onTap: () {})])',
  );

  Future<void> test_quietWhenTheMenuItemIsAlone() => assertClean('''
Widget build() => AppBar(actions: [
  BarButtonItem(icon: 'ellipsis', menu: [MenuAction(title: 'A', onTap: () {})]),
]);
''');
}

@reflectiveTest
class UniformBorderOnlyTest extends RuleTest {
  @override
  void setUp() {
    rule = UniformBorderOnly();
    super.setUp();
  }

  Future<void> test_reportsASingleSide() => assertWarning(
    'final d = BoxDecoration(border: Border(bottom: BorderSide(width: 1)));',
    'Border',
  );

  Future<void> test_quietForBorderAll() =>
      assertClean('final d = BoxDecoration(border: Border.all(width: 1));');

  Future<void> test_quietWhenAllFourSidesAreGiven() => assertClean('''
final s = BorderSide(width: 1);
final d = BoxDecoration(border: Border(top: s, right: s, bottom: s, left: s));
''');
}

@reflectiveTest
class MirrorTextControllerTest extends RuleTest {
  @override
  void setUp() {
    rule = MirrorTextController();
    super.setUp();
  }

  Future<void> test_reportsControllerWithoutOnChanged() => assertWarning('''
final c = TextEditingController();
Widget build() => TextField(controller: c);
''', 'controller: c');

  Future<void> test_quietWithOnChanged() => assertClean('''
final c = TextEditingController();
Widget build() => TextField(controller: c, onChanged: (v) => c.text = v);
''');
}

@reflectiveTest
class CustomPaintFiniteSizeTest extends RuleTest {
  @override
  void setUp() {
    rule = CustomPaintFiniteSize();
    super.setUp();
  }

  Future<void> test_reportsInfinity() => assertWarning(
    'Widget build() => CustomPaint(size: Size(double.infinity, 200));',
    'double.infinity',
  );

  Future<void> test_quietForConcreteSize() =>
      assertClean('Widget build() => CustomPaint(size: Size(300, 200));');
}

@reflectiveTest
class PositionedMustBeOutermostTest extends RuleTest {
  @override
  void setUp() {
    rule = PositionedMustBeOutermost();
    super.setUp();
  }

  Future<void> test_reportsAWrapperAbovePositioned() => assertWarning('''
Widget build() => Stack(children: [
  Text('base'),
  Padding(padding: EdgeInsets.all(8), child: Positioned(top: 0, child: Text('x'))),
]);
''', 'Padding');

  Future<void> test_quietWhenPositionedIsOutermost() => assertClean('''
Widget build() => Stack(children: [
  Text('base'),
  Positioned(top: 0, child: Padding(padding: EdgeInsets.all(8), child: Text('x'))),
]);
''');
}

@reflectiveTest
class SnackBarActionNotWiredTest extends RuleTest {
  @override
  void setUp() {
    rule = SnackBarActionNotWired();
    super.setUp();
  }

  Future<void> test_reportsOnPressed() => assertWarning(
    "final a = SnackBarAction(label: 'Undo', onPressed: () {});",
    'onPressed: () {}',
  );
}

@reflectiveTest
class OffstageLosesStateTest extends RuleTest {
  @override
  void setUp() {
    rule = OffstageLosesState();
    super.setUp();
  }

  Future<void> test_reportsOffstage() => assertWarning(
    "Widget build() => Offstage(child: Text('x'));",
    'Offstage',
  );
}

@reflectiveTest
class RawTextEscapeFalseTest extends RuleTest {
  @override
  void setUp() {
    rule = RawTextEscapeFalse();
    super.setUp();
  }

  Future<void> test_reportsUnescapedBloggerTagInText() => assertWarning(
    "Component build() => BloggerText('<data:skin.vars.keycolor/>');",
    "'<data:skin.vars.keycolor/>'",
  );

  Future<void> test_quietWithEscapeFalse() => assertClean(
    "Component build() => BloggerText('<data:skin.vars.keycolor/>', escape: false);",
  );
}

@reflectiveTest
class BSectionUniqueIdTest extends RuleTest {
  @override
  void setUp() {
    rule = BSectionUniqueId();
    super.setUp();
  }

  Future<void> test_reportsDuplicateBSectionId() => assertWarning(
    '''
Component build() => div([
  BSection(id: 'header'),
  BSection(id: 'header'),
]);
''',
    "id: 'header'",
    occurrence: 2,
  );

  Future<void> test_quietWithUniqueIds() => assertClean('''
Component build() => div([
  BSection(id: 'header'),
  BSection(id: 'footer'),
]);
''');
}

@reflectiveTest
class BWidgetTypeRequiredTest extends RuleTest {
  @override
  void setUp() {
    rule = BWidgetTypeRequired();
    super.setUp();
  }

  Future<void> test_reportsMissingType() => assertWarning(
    "Component build() => BWidget(id: 'main');",
    'BWidget',
  );

  Future<void> test_quietWithType() => assertClean(
    "Component build() => BWidget(id: 'main', type: 'Blog');",
  );
}

@reflectiveTest
class BLoopRequiredArgsTest extends RuleTest {
  @override
  void setUp() {
    rule = BLoopRequiredArgs();
    super.setUp();
  }

  Future<void> test_reportsMissingValues() => assertWarning(
    "Component build() => BLoop(varName: 'post');",
    'BLoop',
  );

  Future<void> test_quietWithValuesAndVarName() => assertClean(
    "Component build() => BLoop(values: 'data:posts', varName: 'post');",
  );
}

@reflectiveTest
class AmpImgDimensionsRequiredTest extends RuleTest {
  @override
  void setUp() {
    rule = AmpImgDimensionsRequired();
    super.setUp();
  }

  Future<void> test_reportsMissingWidthOrHeight() => assertWarning(
    "Component build() => AmpImg(src: 'img.jpg', width: '100');",
    'AmpImg',
  );

  Future<void> test_quietWithWidthAndHeight() => assertClean(
    "Component build() => AmpImg(src: 'img.jpg', width: '100', height: '100');",
  );
}

@reflectiveTest
class BEvalExprRequiredTest extends RuleTest {
  @override
  void setUp() {
    rule = BEvalExprRequired();
    super.setUp();
  }

  Future<void> test_reportsMissingExpr() => assertWarning(
    'Component build() => BEval();',
    'BEval',
  );

  Future<void> test_quietWithExpr() => assertClean(
    "Component build() => BEval(expr: 'data:blog.title');",
  );
}

@reflectiveTest
class BIncludableIdRequiredTest extends RuleTest {
  @override
  void setUp() {
    rule = BIncludableIdRequired();
    super.setUp();
  }

  Future<void> test_reportsMissingId() => assertWarning(
    'Component build() => BIncludable();',
    'BIncludable',
  );

  Future<void> test_quietWithId() => assertClean(
    "Component build() => BIncludable(id: 'main');",
  );
}

@reflectiveTest
class AmpAudioSrcRequiredTest extends RuleTest {
  @override
  void setUp() {
    rule = AmpAudioSrcRequired();
    super.setUp();
  }

  Future<void> test_reportsMissingSrc() => assertWarning(
    'Component build() => AmpAudio();',
    'AmpAudio',
  );

  Future<void> test_quietWithSrc() => assertClean(
    "Component build() => AmpAudio(src: 'audio.mp3');",
  );
}

@reflectiveTest
class AmpYoutubeVideoidRequiredTest extends RuleTest {
  @override
  void setUp() {
    rule = AmpYoutubeVideoidRequired();
    super.setUp();
  }

  Future<void> test_reportsMissingVideoid() => assertWarning(
    'Component build() => AmpYoutube();',
    'AmpYoutube',
  );

  Future<void> test_quietWithVideoid() => assertClean(
    "Component build() => AmpYoutube(videoid: 'xyz123');",
  );
}

@reflectiveTest
class AmpSocialEmbedIdRequiredTest extends RuleTest {
  @override
  void setUp() {
    rule = AmpSocialEmbedIdRequired();
    super.setUp();
  }

  Future<void> test_reportsMissingInstagramShortcode() => assertWarning(
    'Component build() => AmpInstagram();',
    'AmpInstagram',
  );

  Future<void> test_quietWithShortcode() => assertClean(
    "Component build() => AmpInstagram(shortcode: 'abc123');",
  );
}

@reflectiveTest
class BSkinEmptyCssAmpRuleTest extends RuleTest {
  @override
  void setUp() {
    rule = BSkinEmptyCssAmpRule();
    super.setUp();
  }

  Future<void> test_reportsNonEmptyCss() => assertWarning(
    "Component build() => BSkin('body { color: red; }');",
    "'body { color: red; }'",
  );

  Future<void> test_quietWithEmptyCss() => assertClean(
    "Component build() => BSkin('');",
  );
}
