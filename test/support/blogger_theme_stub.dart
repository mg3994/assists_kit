/// A minimal stand-in for `package:blogger_theme` so tests resolve blogger_theme
/// types without requiring the real package as a dependency.
library;

const bloggerThemeStub = r'''
library blogger_theme;

import 'package:dartnative/dartnative.dart';

abstract class Component extends Widget {
  const Component({super.key});
  Iterable<Component> build() => const [];
}

class DomComponent extends Component {
  final String tag;
  final Map<String, String>? attributes;
  final List<Component>? children;
  const DomComponent(this.tag, {this.attributes, this.children});
}

class BloggerText extends Component {
  final String text;
  final bool escape;
  const BloggerText(this.text, {this.escape = true});
}

class RawText extends Component {
  final String text;
  const RawText(this.text);
}

class Fragment extends Component {
  final List<Component> children;
  const Fragment(this.children);
}

class BSection extends Component {
  final String? id;
  final String? className;
  final int? maxwidgets;
  final bool? showaddelement;
  final List<Component> children;
  const BSection({
    this.id,
    this.className,
    this.maxwidgets,
    this.showaddelement,
    this.children = const [],
  });
}

class BWidget extends Component {
  final String? id;
  final String? type;
  final String? title;
  final List<Component> children;
  const BWidget({
    this.id,
    this.type,
    this.title,
    this.children = const [],
  });
}

class BIf extends Component {
  final String cond;
  final List<Component> children;
  const BIf(this.cond, [this.children = const []]);
}

class BLoop extends Component {
  final String? values;
  final String? varName;
  final String? var;
  final List<Component> children;
  const BLoop({
    this.values,
    this.varName,
    this.var,
    this.children = const [],
  });
}

class BIncludable extends Component {
  final String? id;
  final List<Component> children;
  const BIncludable({this.id, this.children = const []});
}

DomComponent div([dynamic arg1, dynamic arg2]) => DomComponent('div');
DomComponent h1([dynamic arg1, dynamic arg2]) => DomComponent('h1');
''';
