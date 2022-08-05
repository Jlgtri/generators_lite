The complete example of the `build.yaml` file is layed here.

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

    builders:
      generators|assets:
        enabled: true
        options:
          import_path: source/assets
          export_path: lib/src/generated/assets.g.dart
          base_name: CustomAssets

      generators|i18n:
        enabled: true
        options:
          import_path: source/i18n
          export_path: lib/src/generated/i18n.g.dart
          encoding: utf-8
          imports:
            - ../custom_l10n.dart
          base_name: CustomI18N
          base_class_name: CustomL10N
          enum_class_name: I18NLocaleCustom

      generators|models:
        enabled: true
        options:
          import_path: source/models.json
          export_path: lib/src/generated/models.g.dart
          imports:
            - ../custom_json_converters.dart

      generators|icons:
        enabled: true
        options:
          import_path: source/icons
          export_path: lib/src/generated/icons.g.dart
          font_export_path: source/icons.ttf
          base_name: CustomIcons
          font_family: IconsFont
          height: 24
          descent: 8
          normalize: true
          npm_package:
            private: true
            devDependencies:
              fantasticon: ^1.2.3
          base_code_point: 0xf101
```
