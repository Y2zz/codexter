import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/skill_entry.dart';
import '../services/downstream_client.dart';

/// 生成 initialize/server-discover 返回给 ChatGPT 的工作区说明。
class ServerInstructions {
  const ServerInstructions._();

  static String build({
    required String projectRoot,
    required List<SkillEntry> skills,
    required List<DownstreamClient> downstream,
    required int toolCount,
    String agentsMode = 'auto',
    String customAgents = '',
  }) {
    final shell = Platform.isWindows ? 'powershell' : 'bash';
    final sections = <String>[
      _environment(projectRoot, shell, toolCount),
      '',
      'This MCP server exposes local coding tools for the current workspace.',
      'For every tools/call request, include `purpose`: a concise user-visible summary (max 80 characters) of what the immediate call will obtain, verify, or change. `purpose` is used by the desktop app for activity UI and is never forwarded to downstream MCP tools.',
      'Mandatory terminal-summary rule: one round means one user message through one final assistant response. If you use any tool from this MCP server during that round, call `summary` once and only once, after ALL other tool calls are finished and immediately before the final response. `summary` is the terminal marker for the round: never call it for intermediate milestones, individual subtasks, retries, progress updates, or individual Computer Use actions; never call it more than once in the same user turn. After calling `summary`, do not call any other tool from this MCP server in that user turn. If more tool work remains, do not call `summary` yet. The summary must be one short user-facing paragraph only: no bullets, numbered lists, detail lists, or line breaks. File changes are tracked automatically, so do not repeat them unless essential to the outcome.',
    ];

    final agents = _resolveAgents(projectRoot: projectRoot, mode: agentsMode, custom: customAgents);
    if (agents != null) {
      sections
        ..add('')
        ..add('<project_instructions>')
        ..add(agents)
        ..add('</project_instructions>');
    }

    sections
      ..add('')
      ..addAll(_toolMap())
      ..add('')
      ..addAll(_playbook());

    if (skills.isNotEmpty) {
      sections
        ..add('')
        ..add('Available Skills (metadata only; use skill_read for the current SKILL.md body):');
      for (final skill in skills) {
        sections.add('- ${skill.name}: ${skill.description}');
      }
      sections.add(
        'Skills can change while the desktop app is running; use skills_list when current availability matters.',
      );
    }

    if (downstream.isNotEmpty) {
      sections
        ..add('')
        ..add('Downstream MCP servers (discover with mcp_tools, invoke with mcp_call):');
      for (final client in downstream) {
        final description = client.description?.trim();
        sections.add(
          '- ${client.name} [${client.state.name}] ${client.tools.length} tools'
          '${description == null || description.isEmpty ? '' : ': $description'}',
        );
      }
    }

    return sections.join('\n');
  }

  static String _environment(String projectRoot, String shell, int toolCount) {
    return [
      '<environment_context>',
      '  <project_root>$projectRoot</project_root>',
      '  <shell>$shell</shell>',
      '  <tool_count>$toolCount</tool_count>',
      '  <paths>relative to project_root unless stated otherwise</paths>',
      '</environment_context>',
    ].join('\n');
  }

  static String? _resolveAgents({
    required String projectRoot,
    required String mode,
    required String custom,
  }) {
    if (mode == 'disabled') return null;
    if (mode == 'custom') {
      final text = custom.trim();
      return text.isEmpty ? null : text;
    }
    return _loadRootAgents(projectRoot);
  }

  /// 工作区级 MCP 端点把项目根目录视为 Agent 的当前工作目录。
  /// 同一目录下优先读取 AGENTS.override.md，其次 AGENTS.md，与 Codex 的优先级一致。
  static String? _loadRootAgents(String projectRoot) {
    for (final name in const ['AGENTS.override.md', 'AGENTS.md']) {
      final file = File(p.join(projectRoot, name));
      try {
        if (file.existsSync()) return file.readAsStringSync();
      } catch (_) {}
    }
    return null;
  }

  static List<String> _toolMap() {
    return const [
      'Tool map (pick by goal):',
      '- read — read one file or several files with numbered lines before changing code.',
      '- apply_patch — exact replacements, create/overwrite, or delete files atomically.',
      '- ls — inspect one directory quickly.',
      '- grep / glob — structured content and path search without shell syntax differences.',
      '- code_explore — quickly outline source files and top-level symbols.',
      '- exec_command — run shell commands; long-running commands return session_id.',
      '- write_stdin — poll a running command or send stdin/Ctrl+C using session_id.',
      '- skills_list / skill_read — discover dynamic local Skills and load SKILL.md on demand.',
      '- mcp_tools / mcp_call — discover and invoke tools from enabled downstream MCP servers.',
      '- summary — terminal tool for the current user turn; call once only after all other work is complete, then send the final response.',
    ];
  }

  static List<String> _playbook() {
    return const [
      'Working order:',
      '1. Use ls / glob / code_explore / grep to locate relevant code efficiently.',
      '2. Read the relevant files before changing them.',
      '3. Use apply_patch for all source/text file changes; compose related edits there and avoid rewriting unrelated content.',
      '4. Use exec_command for tests, builds, git, package managers, adb, and other installed CLI tools. Do not edit source/text files through shell redirection or shell file IO helpers (Windows Get-Content/Set-Content, or Unix cat/tee rewrites).',
      '5. If exec_command returns session_id, continue with write_stdin; send \\u0003 to stop an interactive/long-running command when appropriate.',
      '6. Use skill_read only when a listed Skill is relevant; use mcp_tools before mcp_call when downstream capabilities are unknown.',
      '7. When all work for the current user message is complete, call summary exactly once as the final MCP tool call. Do not call summary earlier, do not call it after each subtask, and do not call any MCP tool after it in the same user turn.',
    ];
  }
}
