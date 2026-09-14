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

class AmpInstagram extends Component {
  final String? shortcode;
  final String? dataShortcode;
  const AmpInstagram({this.shortcode, this.dataShortcode});
}

class AmpTwitter extends Component {
  final String? tweetid;
  final String? tweetId;
  const AmpTwitter({this.tweetid, this.tweetId});
}

class AmpLightbox extends Component {
  final String? id;
  final String? layout;
  final List<Component> children;
  const AmpLightbox({this.id, this.layout, this.children = const []});
}

class AmpState extends Component {
  final String? id;
  final List<Component> children;
  const AmpState({this.id, this.children = const []});
}

class BSkin extends Component {
  final String css;
  const BSkin(this.css);
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

class BElseIf extends Component {
  final String cond;
  final List<Component> children;
  const BElseIf(this.cond, [this.children = const []]);
}

class BElse extends Component {
  final List<Component> children;
  const BElse([this.children = const []]);
}

class BAttr extends Component {
  final String? name;
  final String? value;
  final String? cond;
  const BAttr({this.name, this.value, this.cond});
}

class BClass extends Component {
  final String? name;
  final String? exprName;
  const BClass({this.name, this.exprName});
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

class BEval extends Component {
  final String? expr;
  const BEval({this.expr});
}

class AmpImg extends Component {
  final String? src;
  final String? width;
  final String? height;
  final String? layout;
  final String? alt;
  const AmpImg({this.src, this.width, this.height, this.layout, this.alt});
}

class AmpCarousel extends Component {
  final String? width;
  final String? height;
  final String? layout;
  final String? type;
  final List<Component> children;
  const AmpCarousel({
    this.width,
    this.height,
    this.layout,
    this.type,
    this.children = const [],
  });
}

class AmpSidebar extends Component {
  final String? id;
  final String? layout;
  final List<Component> children;
  const AmpSidebar({this.id, this.layout, this.children = const []});
}

class AmpAccordion extends Component {
  final List<Component> children;
  const AmpAccordion({this.children = const []});
}

class AmpAudio extends Component {
  final String? src;
  const AmpAudio({this.src});
}

class AmpVideo extends Component {
  final String? src;
  final String? width;
  final String? height;
  final String? layout;
  final List<Component> children;
  const AmpVideo({
    this.src,
    this.width,
    this.height,
    this.layout,
    this.children = const [],
  });
}

class AmpYoutube extends Component {
  final String? videoid;
  final String? width;
  final String? height;
  final String? layout;
  const AmpYoutube({this.videoid, this.width, this.height, this.layout});
}

class AmpStory extends Component {
  final String? title;
  final String? publisher;
  final String? publisherLogoSrc;
  final String? posterPortraitSrc;
  final List<Component> children;
  const AmpStory({
    this.title,
    this.publisher,
    this.publisherLogoSrc,
    this.posterPortraitSrc,
    this.children = const [],
  });
}

DomComponent div([dynamic arg1, dynamic arg2]) => DomComponent('div');
DomComponent h1([dynamic arg1, dynamic arg2]) => DomComponent('h1');
''';
