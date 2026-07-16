import 'package:mason_logger/mason_logger.dart';
import 'validation.dart';

/// Answers interactive questions without a terminal.
///
/// GUI embedders (flow_studio) implement this with dialogs/forms — or with
/// fixed default answers — so engine code paths that ask questions (e.g. the
/// CocoaPods repair flow) never block on stdin inside a desktop app.
abstract class AppLoggerInteraction {
  String prompt(String message, {String? defaultValue});
  bool confirm(String message, {bool defaultValue = false});
  String chooseOne(
    String message, {
    required List<String> choices,
    String? defaultValue,
  });
  List<String> chooseAny(
    String message, {
    required List<String> choices,
    List<String>? defaultValues,
  });
}

class AppLogger {
  AppLogger({this.interaction, this.messageSink});

  /// Non-terminal answers for GUI embedders. `null` (the CLI) keeps the
  /// mason terminal prompts exactly as before.
  final AppLoggerInteraction? interaction;

  /// When set, every log line is ALSO forwarded here so embedders can show
  /// engine progress in their own UI. Terminal output is unchanged.
  final void Function(String message)? messageSink;

  final Logger _logger = Logger();

  void info(String message) {
    messageSink?.call(message);
    _logger.info(message);
  }

  void success(String message) {
    messageSink?.call(message);
    _logger.success(message);
  }

  void error(String message) {
    messageSink?.call(message);
    _logger.err(message);
  }

  void warn(String message) {
    messageSink?.call(message);
    _logger.warn(message);
  }

  String prompt(String message, {String? defaultValue}) {
    final interaction = this.interaction;
    if (interaction != null) {
      return interaction.prompt(message, defaultValue: defaultValue);
    }
    while (true) {
      final input = _logger.prompt(message, defaultValue: defaultValue);
      if (ValidationUtils.hasArabic(input)) {
        error('❌ Error: Arabic input is not allowed in this tool.');
        info('   Please enter the value using Latin characters.');
        continue;
      }
      return input;
    }
  }

  bool confirm(String message, {bool defaultValue = false}) {
    final interaction = this.interaction;
    if (interaction != null) {
      return interaction.confirm(message, defaultValue: defaultValue);
    }
    final selection = _logger.chooseOne(
      message,
      choices: ['Yes', 'No'],
      defaultValue: defaultValue ? 'Yes' : 'No',
    );
    return selection == 'Yes';
  }

  String chooseOne(
    String message, {
    required List<String> choices,
    String? defaultValue,
  }) {
    final interaction = this.interaction;
    if (interaction != null) {
      return interaction.chooseOne(
        message,
        choices: choices,
        defaultValue: defaultValue,
      );
    }
    return _logger.chooseOne(message, choices: choices, defaultValue: defaultValue);
  }

  List<String> chooseAny(
    String message, {
    required List<String> choices,
    List<String>? defaultValues,
  }) {
    final interaction = this.interaction;
    if (interaction != null) {
      return interaction.chooseAny(
        message,
        choices: choices,
        defaultValues: defaultValues,
      );
    }
    return _logger.chooseAny(
      message,
      choices: choices,
      defaultValues: defaultValues,
    );
  }
}
