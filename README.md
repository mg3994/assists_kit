# assists_kit

Option+Enter widget assists and DartNative-specific warnings for
[DartNative](https://dartnative.com) projects. Runs inside the Dart Analysis
Server, so it works the same in Android Studio, IntelliJ and VS Code.

## Why

The analysis server ships "Wrap with Container", "Convert to StatefulWidget"
and the rest of the Flutter assists, but each one checks that the widget
class comes from `package:flutter/src/widgets/framework.dart`. DartNative's
`Widget` lives in `package:dartnative`, so in a DartNative file those assists
never appear. This plugin re-implements them against DartNative's types.

It also turns the DartNative behaviours that fail silently or crash at mount
into analyzer warnings, so they are caught while typing instead of on a
device.

## Setup

The package is published on dartpub.dev, DartNative's registry. The analysis
server resolves plugins with plain `dart pub`, which only knows pub.dev, so
the `hosted` line is required. In the `analysis_options.yaml` at the root of
your project:

```yaml
plugins:
  assists_kit:
    hosted: https://dartpub.dev
    version: ^0.1.4
```

Restart the Dart Analysis Server once (Android Studio: Tools › Dart › Restart
Dart Analysis Server; VS Code: "Dart: Restart Analysis Server"). The first
restart after enabling builds the plugin isolate and takes a few seconds.

Requires Dart 3.11 or later; the DartNative `dn` toolchain ships a newer SDK.

## Assists

With the cursor on a widget (a constructor call, or any expression of a
widget type such as a `child` parameter):

| Assist | Result |
|---|---|
| Wrap with Center / Container / SizedBox / Expanded / Flexible / SafeArea / GestureDetector / GlassEffectContainer | `Name(child: …)` |
| Wrap with div / header / footer / section / article / aside / nav / main / p / span / h1 / h2 / h3 / ul / ol / li / a / button / form / label / figure / figcaption / table / tr / BIf / BElseIf / Fragment | positional `Name([ … ])` for `blogger_theme` components |
| Wrap with BSection / BLoop / BIncludable / BSkin / BWidget / AmpCarousel / AmpSidebar / AmpAccordion / AmpLightbox / AmpState / AmpVideo / AmpStory | `Name(…, children: [ … ])` for `blogger_theme` components |
| Wrap with Padding | `Padding(padding: const EdgeInsets.all(8.0), child: …)` |
| Wrap with Column / Row / Stack | multi-line `children: [ … ]`; with a selection spanning several siblings in a `children:` list, wraps them together |
| Wrap with Builder | `Builder(builder: (context) => …)` |
| Wrap with FutureBuilder / StreamBuilder / ValueListenableBuilder | `…builder: (context, snapshot) => …` |
| Wrap with widget… | a wrapper name you type |
| Remove this widget | replaces a wrapper with its single child |
| Swap with child / Swap with parent | exchanges two single-`child:` widgets, keeping their other arguments |
| Convert to children: / Convert to child: | switches between the two slots |
| Move widget up / down | reorders inside a `children:` list |

With the cursor on a class header line:

| Assist | Result |
|---|---|
| Convert to StatefulWidget | constructors and final fields stay on the widget; other members move to `_XState`; field references become `widget.x`, statics become `X.y`, `$x` interpolations become `${widget.x}` |
| Convert to StatelessWidget | merges the State back; offered only when the State has no lifecycle overrides, mixins, or `setState` calls |

## Warnings (on by default)

| Rule | What it catches |
|---|---|
| `dartnative_fab_slot_android_only` | `Scaffold.floatingActionButton`, which renders on Android and shows nothing on iOS |
| `dartnative_menu_action_must_be_alone` | a `BarButtonItem` with `menu:` beside other actions, which asserts at mount |
| `dartnative_uniform_border_only` | per-side `Border(...)`, which DartNative ignores in favour of `top` |
| `dartnative_mirror_text_controller` | a `TextField` with a controller and no `onChanged`; the controller is one-way. Quick fix adds the mirror |
| `dartnative_custom_paint_finite_size` | `CustomPaint(size: Size(double.infinity, …))`, which paints off-screen |
| `dartnative_positioned_must_be_outermost` | a wrapper above `Positioned` in a `Stack`, which is dropped |
| `dartnative_snackbar_action_not_wired` | `SnackBarAction.onPressed`, which never fires |
| `blogger_theme_raw_text_escape_false` | `Text(...)` containing Blogger XML tags without `escape: false` |
| `blogger_theme_bsection_unique_id` | `BSection` or `BWidget` with duplicate or missing `id` attribute |
| `blogger_theme_bwidget_type_required` | `BWidget` missing `type:` attribute |
| `blogger_theme_bloop_required_args` | `BLoop` missing `values:` or `varName:` attribute |
| `blogger_theme_amp_img_dimensions_required` | `AmpImg` missing required `width:` or `height:` for AMP |
| `blogger_theme_beval_expr_required` | `BEval` missing required `expr:` attribute |
| `blogger_theme_bincludable_id_required` | `BIncludable` missing required `id:` attribute |
| `blogger_theme_amp_audio_src_required` | `AmpAudio` or `AmpVideo` missing `src:` attribute |
| `blogger_theme_amp_youtube_videoid_required` | `AmpYoutube` missing `videoid:` attribute |
| `blogger_theme_amp_social_embed_id_required` | `AmpInstagram` or `AmpTwitter` missing shortcode/tweetid attribute |
| `blogger_theme_bskin_empty_css_amp` | `BSkin` with non-empty CSS string in AMP themes |
| `blogger_theme_belseif_parent_must_be_bif` | `BElseIf` or `BElse` used outside a `BIf` component |
| `blogger_theme_battr_name_required` | `BAttr` missing `name:` attribute |
| `blogger_theme_bclass_expr_or_name_required` | `BClass` missing both `name:` and `exprName:` attributes |
| `blogger_theme_bvariable_required_args` | `BVariable` missing `name:` or `type:` attribute |
| `blogger_theme_binclude_name_required` | `BInclude` missing `name:` attribute |
| `blogger_theme_bclient_script_content_required` | `BClientScript` missing script callback or source |
| `blogger_theme_html_img_alt_required` | `img(...)` helper call missing `alt:` attribute |
| `blogger_theme_html_anchor_href_required` | `a(...)` helper call missing `href:` attribute |
| `blogger_theme_html_form_action_required` | `form(...)` helper call missing `action:` attribute |
| `blogger_theme_amp_iframe_sandbox_required` | `AmpIframe` missing `sandbox:` attribute |
| `blogger_theme_amp_social_share_type_required` | `AmpSocialShare` missing `type:` attribute |
| `blogger_theme_amp_list_src_required` | `AmpList` missing `src:` attribute |

Opt-in lint:

| Rule | What it catches |
|---|---|
| `dartnative_offstage_loses_state` | `Offstage`, which unmounts its child in DartNative |

Enable it under the plugin entry:

```yaml
plugins:
  assists_kit:
    hosted: https://dartpub.dev
    version: ^0.1.1
    diagnostics:
      dartnative_offstage_loses_state: true
```

Suppress any rule on a line with `// ignore: assists_kit/<rule>`.

## Development

```sh
dart pub get
dart test          # resolves against a stub package:dartnative, no SDK needed
dart analyze
```

`tool/try_assists.dart` runs the assists against a real file inside a
DartNative project:

```sh
dart run tool/try_assists.dart path/to/app/lib/main.dart --find "Text(" --apply 1
```

The `analysis_server_plugin` and `analyzer` dependencies move in lockstep
with the Dart SDK. After a `dn upgrade`, run `dart pub upgrade` and the tests.

When the plugin is enabled from a local `path:` and you change its source,
the analysis server keeps running the isolate it already compiled. Delete
`~/.dartServer/.plugin_manager` and restart the server to pick up the change.
An "error occurred while executing an analyzer plugin" line during
`dn analyze` after an edit is that stale isolate, not a bug in the change.

## Sources of the rules

Each warning encodes one fact from the DartNative widget reference or from
on-device testing on DartNative 1.0.0 (September 2026). The rule's
`description` names which. If DartNative changes a behaviour, the rule should
be retired rather than kept as folklore.
