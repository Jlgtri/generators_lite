import 'package:args/command_runner.dart';
import 'package:generators_lite/assets_generator.dart';
import 'package:generators_lite/i18n_generator.dart';
import 'package:generators_lite/icons_generator.dart';
import 'package:generators_lite/models_generator.dart';

Future<void> main([
  final Iterable<String> arguments = const Iterable<String>.empty(),
]) {
  final CommandRunner<void> runner = CommandRunner<void>(
    'generate',
    'Use the power of automatic code generation for Dart.',
  )
    ..addCommand(AssetsCommand())
    ..addCommand(I18NCommand())
    ..addCommand(ModelsCommand())
    ..addCommand(IconsCommand());
  return runner.run(arguments);
}
