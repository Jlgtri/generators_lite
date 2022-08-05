<div align="center">
  <img src="./logo.png?raw=true" width="100%" alt="Logo" />
</div>

---

Start coding with multiple generators working at once powered by [`package:build_runner`][].

Currently includes ready-to-use generators for Assets, [I18N][i18n-link],
Data Classes and Icon Fonts.

- [Getting Started](#getting-started)
- [Installation](#installation)
- [Usage](#usage)
  - [Assets Generator](#assets-generator)
  - [I18N Generator](#i18n-generator)
  - [Data Class Generator](#data-class-generator)
  - [Icon Fonts Generator](#icon-fonts-generator)
- [Contributing](#contributing)
- [FAQ](#faq)

## Getting Started

This package relies on Dart [`package:analyzer`][] to format generated code.

It provides a unified way to use all of the featured generators. Currently
featuring:

1. **Assets generator.**
   Used for utilizing autocompletion of the native file structure.

2. **I18N generator.**
   Primarily used for utilizing autocompletion of the files with translations,
   but can also be used for any type of Dart code conversion from strings.

3. **Data Class generator.**
   Used for generating all-in-one Dart classes from provided class fields.

4. **Icon Fonts generator.**
   Used for real-time generation of a webfont from `.svg` files.
   Also utilizes autocompletion of the nested icons like an assets generator.

## Installation

This package is intended to support the development of Dart projects with
[`package:build_runner`][]. In general, put it under [dev_dependencies][] in
your [`pubspec.yaml`][].

```yaml
dev_dependencies:
  build_runner: any
  generators:
```

Alternatively, you can use plain console commands to do all the same things.
Enable the package globally and use it as a console tool.

```ps
flutter pub global activate generators

generate <command> [arguments]
```

Command is pointing to a generator to be used and arguments are passed directly
to that generator. For example:

```ps
generate assets --import-path source/assets --export-path lib/assets.g.dart
generate i18n -i source/i18n -e lib/i18n.g.dart
generate models -i models.json -e lib/models.g.dart
generate icons -i source/icons -e lib/icons.g.dart
```

## Usage

This package is configured using a `build.yaml` file. See the
[`package:build_config`][] README for more information on this file.

To use all files under your current package and not only files in `lib`,
set `build.yaml` sources section as following. See also `Example` tab for a
complete example on `build.yaml` file.

```yaml
# yaml-language-server: $schema=./build.yaml
targets:
  $default:
    sources:
      include:
        - '**'
        - lib/$lib$
        - $package$
      exclude:
        - .dart_tool/**
```

> NOTE: Because of the limitations on the [`package:build_runner`][], there can
> only be one predefined generated file when using aggregate builders. So, in
> terms of straightforwardness, every generator generates only one single file.
> This behavior may change in the future.

To run the generator, you want to run the following command:

```ps
flutter pub run build_runner build --delete-conflicting-outputs
```

To make things even easier, you can also setup [VS Code task][vs-code-task-link]
for [`package:build_runner`][]. This task can also be automatically run if you
allow the `Tasks: Manage Automatic Tasks in Folder` command.
See this example on `tasks.json` for a convenient way to setup such task.

```json
{
  // See https://go.microsoft.com/fwlink/?LinkId=733558
  // for the documentation about the tasks.json format
  "version": "2.0.0",
  "tasks": [
    {
      "type": "shell",
      "label": "build_runner",
      "command": "flutter",
      "args": [
        "pub",
        "run",
        "build_runner",
        "watch",
        "--delete-conflicting-outputs",
        "--low-resources-mode"
      ],
      "isBackground": true,
      "presentation": {
        "echo": true,
        "reveal": "silent",
        "focus": false,
        "panel": "shared",
        "showReuseMessage": true,
        "clear": false
      },
      "problemMatcher": ["$dart-build_runner"],
      "runOptions": {
        "runOn": "folderOpen"
      }
    }
  ]
}
```

The rest of this section provides detailed instructions on how to use each
generator from this package.

### Assets Generator

All this generator does is migrate a file structure from the provided
`import_path` to the nested Dart classes.

By default it omits any extension in the file name, but if there are two or
more files with the same name and different extensions, the extensions are also
added to the group keys.

To use this generator, you also need to specify fetched assets in your
[`pubspec.yaml`][].

```yaml
flutter:
  assets:
    - assets/
    - assets/nested_folder/
```

The Assets generator may also have the following keys:

- **import_path**: The path that leads to the directory to migrate file
  structure from. Defaults to `assets`.
- **export_path**: The path that leads to the file that is being generated.
  Defaults to `lib/assets.g.dart`.
- **export_encoding**: The encoding used for writing the `.dart` files.
  Defaults to `utf-8`.
- **base_name**: The name of the generated class. Defaults to `Assets`.
- **convert**: If the file names should be converted to
  [camel case][camel-case-link]. Disabling this option will prevent any changes
  to be made to the file names. Be certain to pass valid Dart names or the
  generation will be likely to fail. Defaults to `true`.

### I18N Generator

This generator grounds on an abstract locale, which extends a global abstract
base, just like it's nested groups. Optionally, each group can also be modified
in a default (unnamed) locale. If there is no default locale, the abstract
locale is automatically resolved with all locales provided.

Each locale can be accessed through initialized constant class instance, or the
through call to a special generated `Enum` values. This `Enum` also has a method
to return the `current` locale powered by [`package:intl`][] matched in the
generated ones.

So, if you would like to return the current active locale, you would write
something like this:

```dart
enum I18NLocale { ... }

final I18NLocale currentLocale = I18NLocale.current;
final I18N currentLocaleInstance = currentLocale();
```

To use this generator, you also need to put [`package:intl`][] and
[`package:l10n`][] under [dependencies][] in your [`pubspec.yaml`][].

```yaml
dependencies:
  intl:
  l10n:
```

To start, we need to mention a few points on groups:

1. Each group can be nested indefinitely using getters.
2. Each group entry can be a getter or a method, which is derived from the
   entry key itself. By default, all entries are getters, but if an entry key
   ends with brackets, it will be rendered as a method.
3. If a group entry is a method, it can have any amount of parameters specified.
   But it is important to match these parameters between locales, including the
   abstract one.
4. If a group entry key has a type specified, this type will override the
   possible automatically derived return type.
5. If a group entry value is multiline, it will be rendered within the function
   body. And because of that, it will require a return type specified.
6. If you want to access the parent group from within the nested group, you can
   do that by using the `$` key.

The algorithm for fetching files under `import_path` directory:

1. Treat the part in the file name after the last underscore as a locale.

   - If only one file name of all doesn't have an underscore it is treated as a
     part of an abstract locale and other ones are treated regularly.
   - If more than one file name doesn't have an underscore, all file names are
     treated as locales. And the one without name is treated as an abstract one.

2. Process the tree structure for each fetched locale, including abstract one.

   - If there is only one file for a locale at a directory, file's parent
     directories stay present, but the file name is omitted, and the grouping
     starts inside this file.
   - If there is more than one file for a locale at a directory, file's parent
     directories, as well as the name of the file, stay present, and grouping
     starts one layer up from inside of the file.

3. Check that all of the locales match keys, including abstract one.

   - There is an error thrown, if actual locale has keys that neither the other
     locales have, nor the abstract one.
   - The keys, that are not present in the abstract locale, are automatically
     resolved from the actual locales and added as abstract getters.

4. Check the returning types in the abstract locale.
   - Each locale can have its own returning types for group getters, but the
     abstract locale will always be [covariant](variance-link).

The I18N generator may also have the following keys:

- **import_path**: The path that leads to the directory with localizations to
  be generated. Defaults to `i18n`.
- **export_path**: The path that leads to the file that is being generated.
  Defaults to `lib/i18n.g.dart`.
- **export_encoding**: The encoding used for writing the `.dart` files.
  Defaults to `utf-8`.
- **encoding**: The encoding used for reading the `.json` and `.yaml` files.
  Defaults to `utf-8`.
- **base_name**: The name of the generated class. Defaults to `I18N`.
- **base_class_name**: The name of the class, that will be used as an abstract
  base for generated groups. You may also specify any necessary `imports`
  needed to import that class. Defaults to `L10N` from [`package:l10n`][].
- **enum_class_name**: The name of the generated `Enum`.
  Defaults to `I18NLocale`.
- **imports**: An iterable or a single string to add as import to the
  generated file. Defaults to import [`package:l10n`][].
- **convert**: If the group keys should be converted to
  [camel case][camel-case-link]. Disabling this option will prevent any changes
  to be made to the key names. Be certain to pass valid Dart names or the
  generation will be likely to fail. Defaults to `true`.

### Data Class Generator

This generator creates all-in-one classes directly from field descriptions in
the predefined config.

To use this generator, you also need to put [`package:json_converters_lite`][]
under [dependencies][] in your [`pubspec.yaml`][].

```yaml
dependencies:
  json_converters:
```

The config example is the following:

```json
{
  // The name of the data class.
  "address_model": {
    // The properties of the class itself.
    "": {
      "name": "AddressModel",
      "doc": "The model of an address."
    },
    // The properties of each field.
    "id": {
      "type": "int",
      "default": null,
      "doc": "The identificator of this address.",
      "nullable": true,
      "compare": true
    },
    "postal_code": {
      // The dart name will be this value instead of the field key.
      "name": "postCode",
      "type": "int",
      "default": null,
      "doc": null,
      "nullable": false,
      "compare": false
    },
    "companies": {
      // Implementation of the one-to-many relationship.
      "type": "company_model[]",
      "default": [],
      "doc": null,
      "nullable": false
    }
  },

  "company_model": {
    "": {
      "name": "CompanyModel",
      "doc": null
    },
    "registry_number": {
      "type": "int",
      "default": null,
      "doc": null,
      "nullable": false,
      "compare": true
    },
    "address_id": {
      "type": "int",
      "default": null,
      "doc": null,
      "nullable": false,
      "compare": false
    },
    "address": {
      // Implementation of the many-to-one relationship.
      "type": "address_model",
      "default": null,
      "doc": null,
      "nullable": true
    }
  }
}
```

The structure of the config basically has three layers:

- The outer layer contains the names of the classes to be generated.
- The middle layer contains the the class field names and, optionally, an
  unnamed field with the properties of the class itself.
- The inner layer describes the properties of each field and the class itself.

The properties of the class may optionally specify:

- **name**: The custom Dart name for the generated class. Defaults to the key
  of the class in the outer layer. If generator `convert` option is also true,
  formats the key to [camel case][camel-case-link], otherwise be sure to pass
  valid Dart name or the generation will be likely to fail.
- **doc**: The documentation for the generated class. If none is specified,
  uses the mock up one.
- **to_json**: If `toJson` and `fromJson` serialization methods should also be
  created for each model. Defaults to `true`.

The properties of each field may optionally specify:

- **type**: The type of the field, works like `Enum`. If specified a square
  brackets at the end, will be an `Iterable` of the same type. For, example:

  ```json
  "type": "int" // will be an integer
  "type": "int[]" // will be an iterable of integers

  "type": "enum" // will raise an error
  "type": "enum[a,b,c]" // will be an Enum
  "type": "flag[a,b,c]" // will be an iterable of Enums
  ```

  Currently, type can be one of the following:

  - _object_,
  - _enum_, which is later generated from it's values in square brackets,
  - _bool_,
  - _int_,
  - _float_, which is converted to `double`,
  - _str_, which is converted to `String`,
  - _datetime_, which is converted to `DateTime`,
  - _timedelta_, which is converted to `Duration`,
  - or other **_data class_** that is being currently generated.

- **name**: The custom Dart name for the generated field. Defaults to the key
  of the field in the middle layer. If generator `convert` option is also true,
  formats the key to [camel case][camel-case-link], otherwise be sure to pass
  valid Dart name or the generation will be likely to fail.
- **doc**: The documentation for the generated field. If none is specified,
  uses the mock up one.
- **default**: The default value of this field. This value should be a
  serialized value of this field's type, which is then deserialized and
  rendered correctly during generation proccess.
- **nullable**: If the field can be nullable. Defaults to `true`.
- **required**: If the field is required. Defaults to `true`, if field has no
  `default` value specified and field is `nullable`.
- **copy**: If the field should be included in `copyWith` or `copyWithNull`
  methods. Defaults to `true`.
- **serialize**: If the field should be included in serialization, thus `toMap`
  and `fromMap` methods. Defaults to `true`.
- **compare**: If the field should participate in `compareTo` method
  implementaion. Defaults to `false`.

Each of the generated classes has the following parts:

1. **constructor**
2. **fields**
3. **copyWith**, if any of the class fields has `copy` property set to `true`.
4. **copyWithNull**, if any of the class fields has `copy` and `nullable`
   properties set to `true`.
5. **toMap**, if any of the class fields has `serialize` property set to `true`.
6. **fromMap**, if any of the class fields has `serialize` property set to
   `true`.
7. **comparable**, if any of the class fields has `compare` property set to
   `true`.
8. **== operator**
9. **hashCode**
10. **toString**

The way serialization works is by using the [`package:json_converters_lite`][]
for handling serialization of basic fields and custom generated converters for
fields with other data classes. Thus, each generated data class has it's own
converter generated.

Also, if class has had any `Enum` fields specified, these fields are rendered
on their own at the top of the generated file.

The Data Class generator may also have the following keys:

- **import_path**: The path that leads to the file or directory to get the
  info about generated classes from. Defaults to `models`.
- **export_path**: The path that leads to the file that is being generated.
  Defaults to `lib/models.g.dart`.
- **export_encoding**: The encoding used for writing the `.dart` files.
  Defaults to `utf-8`.
- **encoding**: The encoding used for reading the `.json` and `.yaml` files.
  Defaults to `utf-8`.
- **convert_field_names**: If the field names should be converted to
  [camel case][camel-case-link]. Disabling this option will prevent any changes
  to be made to the field names. Be certain to pass valid Dart names or the
  generation will be likely to fail. Defaults to `true`.
- **convert_class_names**: If the class names should be converted to
  [camel case][camel-case-link]. Disabling this option will prevent any changes
  to be made to the class names. Be certain to pass valid Dart names or the
  generation will be likely to fail. Defaults to `true`.
- **assign_field_types**: If the unknown field types should be resolved from
  default values. Defaults to `true`.
- **include_null_fields**: If the fields with null values should be added in
  `toMap`. Defaults to `true`.
- **empty-required-iterables**: If the required iterable fields with null values
  should be replaced with empty iterable in `fromMap`. Defaults to `true`.
- **imports**: An iterable or a single string to add as an import to the
  generated file. By default, imports [`package:json_converters_lite`][].

### Icon Fonts Generator

This generator depends on the [fantasticon][fantasticon-link] js package to
generate a [webfont][webfont-link] itself. So, to use this generator, you need
to have [Node.JS][node-js-link] installed on your machine. Apart from that,
it's all the same as the previous ones.

The `.svg` icons are taken recursively from the specified `import_path`. The
initial file structure is preserved and generated as nested classes later.

> NOTE: `.svg` files should be normalized before processing with this generator.
> To do this, you can use tools like [**svgo**][svgo-link]. Unnormalized `.svg`
> may lead to unexpected results including crashes.

To use this generator, you also need to specify generated font in your
[`pubspec.yaml`][].

```yaml
flutter:
  fonts:
    - family: Icons
      fonts:
        - asset: lib/icons.ttf
```

You can also reduce the size of your application by removing support for flutter
material icons from your [`pubspec.yaml`][].

```yaml
flutter:
  uses-material-design: false # or remove the line
```

The Icon Fonts generator may also have the following keys:

- **import_path**: The path that leads to the directory to get the `.svg` files
  to generate a webfont from. Defaults to `icons`.
- **export_path**: The path that leads to the file that is being generated.
  Defaults to `lib/icons.g.dart`.
- **font_export_path**: The path that leads to the [`.ttf`][webfont-link] file
  that is being generated. Defaults to `lib/icons.ttf`.
- **export_encoding**: The encoding used for writing the `.dart` files.
  Defaults to `utf-8`.
- **encoding**: The encoding used for reading the `.json` and `.yaml` files.
  Defaults to `utf-8`.
- **base_name**: The name of the generated class. Defaults to `Icons`.
- **font_family**: The name of the font family specified in the flutter section
  of the [`pubspec.yaml`][]. Defaults to `Icons`.
- **base_code_point**: The number to start listing icons from in the generated
  font. This does not change the font generation, rather the dispayed
  values themselves. Defaults to `0xf101`.
- **height**: The height of the heighest icon. Learn more at the
  [fantasticon][fantasticon-link] options section.
- **descent**: The descent is usefull to fix the font baseline. Learn more at
  the [fantasticon][fantasticon-link] options section. Defaults to `0`.
- **normalize**: If the icons should be normalized by scaling them to the
  height of the highest icon. Learn more at the [fantasticon][fantasticon-link]
  options section. Defaults to `false`.
- **convert**: If the icon names should be converted to
  [camel case][camel-case-link]. Disabling this option will prevent any changes
  to be made to the icon names. Be certain to pass valid Dart names or the
  generation will be likely to fail. Defaults to `true`.
- **package**: The js package to run `npm install` or `yarn install` with.
  Should be a valid path to a file with a package if running this generator
  from console. Defaults to package with `fantasticon: ^1.2.3`.
- **yarn**: If `yarn` should be used instead of `npm`. Defaults to `false`.
- **force**: If the `package` should be installed forcefully. Otherwise, if
  `fantasticon` executable is present, installation is ommited.
  Defaults to `false`.

## Contributing

Contributions are welcomed!

Here is a curated list of how you can help:

- Report bugs and scenarios that are difficult to implement.
- Report parts of the documentation that are unclear.
- Fix typos/grammar mistakes.
- Update the documentation / add examples.
- Implement new features by making a pull-request.

## FAQ

### Why another project when all of these generators already exist?

While there are many different projects with the same goal of generating Dart
code, there is none of them, that feature all mainly used generators in the
same package, codebase, unified usage and resulting code.

That's why this is an attempt to make things easier, more convenient and better
quality for the end user.

### Is it safe to use in production?

Yes, but with caution. Some use-cases may not be as simple as they could be.

But overall, you should be able to use these generators without any trouble.

### Will a new generators be added over time?

Of course they will!

Leave your suggestions at the official [issue tracker][issue-tracker-link].

[`package:analyzer`]: https://pub.dev/packages/analyzer
[`package:build_config`]: https://pub.dev/packages/build_config
[`package:build_runner`]: https://pub.dev/packages/build_runner
[`package:intl`]: https://pub.dev/packages/intl
[`package:json_converters_lite`]: https://pub.dev/packages/json_converters_lite
[`pubspec.yaml`]: https://dart.dev/tools/pub/pubspec
[camel-case-link]: https://en.wikipedia.org/wiki/Camel_case
[dependencies]: https://dart.dev/tools/pub/dependencies
[dev_dependencies]: https://dart.dev/tools/pub/dependencies#dev-dependencies
[fantasticon-link]: https://www.npmjs.com/package/fantasticon
[i18n-link]: https://en.wikipedia.org/wiki/Internationalization_and_localization
[issue-tracker-link]: https://github.com/Jlgtri/generators/issues
[node-js-link]: https://nodejs.org/
[svgo-link]: https://github.com/svg/svgo
[variance-link]: https://en.wikipedia.org/wiki/covariance_and_contravariance_(computer_science)
[vs-code-task-link]: https://code.visualstudio.com/docs/editor/tasks
[webfont-link]: https://en.wikipedia.org/wiki/TrueType
