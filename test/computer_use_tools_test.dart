import 'package:codexter/models/downstream_mcp_entry.dart';
import 'package:codexter/models/global_config.dart';
import 'package:codexter/services/computer_use_tools.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Computer Use is a built-in downstream MCP with a persisted toggle only', () {
    final entry = DownstreamMcpEntry.builtinComputerUse(enabled: true);

    expect(entry.name, computerUseMcpName);
    expect(entry.displayName, computerUseMcpDisplayName);
    expect(entry.isBuiltin, isTrue);
    expect(entry.isBuiltinComputerUse, isTrue);
    expect(entry.isStdio, isFalse);
    expect(entry.isUrl, isFalse);
    expect(entry.enabled, isTrue);
    expect(GlobalConfig().computerUseEnabled, isFalse);
  });

  test('Computer Use exposes desktop control tools and explicit end_turn lifecycle', () {
    expect(computerUseToolDefinitions.map((tool) => tool['name']).toSet(), {
      'list_windows',
      'get_window',
      'list_apps',
      'launch_app',
      'get_window_state',
      'click',
      'press_key',
      'type_text',
      'scroll',
      'set_value',
      'drag',
      'perform_secondary_action',
      'activate_window',
      'end_turn',
    });
    expect(computerUseToolDefinitions, hasLength(14));
  });
}
