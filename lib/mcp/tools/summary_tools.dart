import '../../models/summary_notice.dart';
import 'registry.dart';
import 'tool_context.dart';

/// 汇总当前用户轮次，并通知桌面端本轮处理已经结束。
class SummaryTools {
  const SummaryTools._();

  static void register(ToolRegistry registry, ToolContext context) {
    registry.register(_summarySchema, (raw) async {
      final args = ToolArgs(raw);
      final title = args.text('title') ?? '本轮处理结束';
      final summary = args.requireText('summary').replaceAll(RegExp(r'\s+'), ' ').trim();
      final endedAt = DateTime.now();
      final fileChanges = context.roundChanges.takeAndReset();

      context.onSummary?.call(
        SummaryNotice(
          workspaceUuid: context.workspace.uuid,
          workspaceName: context.workspace.name,
          title: title,
          summary: summary,
          endedAt: endedAt,
        ),
      );

      return ToolResult.text(
        summary,
        structured: {
          'title': title,
          'summary': summary,
          'endedAt': endedAt.toIso8601String(),
          'workspace': context.workspace.name,
          'fileChanges': fileChanges.toJson(),
        },
      );
    });
  }

  static const _summarySchema = ToolSchema(
    name: 'summary',
    title: 'Round summary',
    description:
        'Terminal tool for one user turn. One round means one user message through one final assistant response. '
        'If you used any tool from this MCP server in that round, call `summary` once and only once, only after every other tool call and subtask is finished, immediately before the final response. '
        'Do NOT call it for intermediate progress, after individual subtasks, after retries, or after individual Computer Use actions. Do NOT call it twice in the same user turn. '
        'After calling `summary`, do not call any other tool from this MCP server in that user turn. If more tool work remains, do not call `summary` yet. '
        'The summary must be one short user-facing paragraph only: no bullet points, numbered lists, detail lists, or line breaks.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'title': {
          'type': 'string',
          'maxLength': 80,
          'description': 'Optional short heading for this round summary.',
        },
        'summary': {
          'type': 'string',
          'maxLength': 600,
          'description':
              'Final one-paragraph summary for the entire current user turn, not for an intermediate step or subtask. Call this tool only once, after all other work is complete. Do not use bullets, numbered lists, detail lists, or line breaks. File changes are tracked separately and should not be repeated unless essential to the outcome.',
        },
      },
      'required': ['summary'],
    },
    outputSchema: {
      'type': 'object',
      'properties': {
        'title': {'type': 'string'},
        'summary': {'type': 'string'},
        'endedAt': {'type': 'string'},
        'workspace': {'type': 'string'},
        'fileChanges': {
          'type': 'object',
          'properties': {
            'count': {'type': 'integer'},
            'additions': {'type': 'integer'},
            'deletions': {'type': 'integer'},
            'files': {
              'type': 'array',
              'items': {
                'type': 'object',
                'properties': {
                  'path': {'type': 'string'},
                  'status': {'type': 'string'},
                  'additions': {'type': 'integer'},
                  'deletions': {'type': 'integer'},
                },
                'required': ['path', 'status', 'additions', 'deletions'],
              },
            },
          },
          'required': ['count', 'additions', 'deletions', 'files'],
        },
        'text': {'type': 'string'},
      },
      'required': ['title', 'summary', 'endedAt', 'workspace', 'text'],
    },
    annotations: ToolAnnotations.readOnly,
    meta: {
      'openai/toolInvocation/invoking': '正在整理本轮摘要…',
      'openai/toolInvocation/invoked': '本轮处理已结束',
    },
  );
}
