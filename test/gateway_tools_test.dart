import 'dart:convert';
import 'dart:io';

import 'package:codexter/mcp/tools/tool_bundle.dart';
import 'package:codexter/mcp/tools/tool_context.dart';
import 'package:codexter/models/downstream_mcp_entry.dart';
import 'package:codexter/models/workspace.dart';
import 'package:codexter/services/capability_runtime.dart';
import 'package:codexter/services/process_session_manager.dart';
import 'package:codexter/stores/log_store.dart';
import 'package:codexter/utils/path_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reconnect fails explicitly when downstream MCP is not active', () async {
    final capabilities = CapabilityRuntime();
    try {
      expect(capabilities.reconnect('missing'), throwsA(isA<StateError>()));
    } finally {
      await capabilities.shutdown();
      capabilities.dispose();
    }
  });

  test('mcp_call preserves rich content and keeps required text output concise', () async {
    final temp = await Directory.systemTemp.createTemp('codex_gateway_tools_');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final processManager = ProcessSessionManager();
    final capabilities = CapabilityRuntime();
    final logStore = LogStore();

    final serverTask = server.forEach((request) async {
      final body = await utf8.decoder.bind(request).join();
      final payload = jsonDecode(body) as Map<String, dynamic>;
      final method = '${payload['method'] ?? ''}';
      final result = switch (method) {
        'initialize' => {
          'protocolVersion': '2025-06-18',
          'serverInfo': {'name': 'mock-rich-mcp', 'version': '1.0.0'},
          'capabilities': <String, dynamic>{},
        },
        'tools/list' => {
          'tools': [
            {
              'name': 'capture',
              'description': 'Return a mock image',
              'inputSchema': {'type': 'object', 'properties': <String, dynamic>{}},
            },
          ],
        },
        'tools/call' => {
          'content': [
            {'type': 'image', 'data': 'AAAA', 'mimeType': 'image/png'},
          ],
          'structuredContent': {'kind': 'screenshot'},
        },
        _ => <String, dynamic>{},
      };
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'jsonrpc': '2.0',
          if (payload['id'] != null) 'id': payload['id'],
          'result': result,
        }),
      );
      await request.response.close();
    });

    final entry = DownstreamMcpEntry(
      name: 'mock-rich',
      transportJson: DownstreamMcpEntry.buildUrlJson(url: 'http://127.0.0.1:${server.port}/mcp'),
      source: 'manual',
    );
    final now = DateTime.now();
    final workspace = Workspace(
      uuid: '11111111-1111-4111-8111-111111111112',
      name: 'gateway-test',
      projectRoot: temp.path,
      createdAt: now,
      lastActiveAt: now,
    );

    try {
      await capabilities.syncMcps([entry]);
      final context = ToolContext(
        workspace: workspace,
        pathGuard: PathGuard(temp.path),
        processManager: processManager,
        capabilities: capabilities,
        logStore: logStore,
      );
      final registry = ToolBundle.build(context);

      final result = await registry.invoke('mcp_call', {
        'purpose': '读取下游截图',
        'server': entry.name,
        'tool': 'capture',
        'arguments': <String, dynamic>{},
      });

      expect(result.isError, isFalse);
      expect(result.content, hasLength(1));
      expect(result.content.single['type'], 'image');
      expect(result.content.single['data'], 'AAAA');
      expect(result.structuredContent?['kind'], 'screenshot');
      expect(result.structuredContent?['text'], '[image: image/png]');
      expect('${result.structuredContent?['text']}', isNot(contains('AAAA')));
    } finally {
      await capabilities.shutdown();
      capabilities.dispose();
      await processManager.shutdown();
      processManager.dispose();
      logStore.dispose();
      await server.close(force: true);
      await serverTask;
      await temp.delete(recursive: true);
    }
  });
}
