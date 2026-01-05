import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

import 'models/task.dart';
import 'models/condition.dart';
import 'models/sms_log.dart';
import 'platform/native_bridge.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmsForwarderApp());
}

class SmsForwarderApp extends StatelessWidget {
  const SmsForwarderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SMS Forwarder',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late final TabController _tab;

  List<Task> _tasks = const [];
  List<SmsLog> _logs = const [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _init();
  }

  Future<void> _init() async {
    await _ensurePermissions();
    await _refreshAll();
  }

  Future<void> _ensurePermissions() async {
    final st = await Permission.sms.status;
    if (st.isDenied || st.isRestricted) {
      await Permission.sms.request();
    }
  }

  Future<void> _refreshAll() async {
    final tasks = await NativeBridge.getTasks();
    final logs = await NativeBridge.getLogs(limit: 200);
    setState(() {
      _tasks = tasks..sort((a, b) => b.id.compareTo(a.id));
      _logs = logs;
    });
  }

  Future<void> _refreshTasks() async {
    final tasks = await NativeBridge.getTasks();
    setState(() => _tasks = tasks..sort((a, b) => b.id.compareTo(a.id)));
  }

  Future<void> _refreshLogs() async {
    final logs = await NativeBridge.getLogs(limit: 200);
    setState(() => _logs = logs);
  }

  Future<void> _openTaskEditor({Task? task}) async {
    final result = await Navigator.of(context).push<Task>(
      MaterialPageRoute(builder: (_) => TaskEditorPage(task: task)),
    );
    if (result != null) {
      await NativeBridge.saveTask(result);
      await _refreshAll();
    }
  }

  Future<void> _toggleTask(Task task, bool enabled) async {
    await NativeBridge.saveTask(task.copyWith(enabled: enabled));
    await _refreshTasks();
  }

  Future<void> _deleteTask(Task task) async {
    await NativeBridge.deleteTask(task.id);
    await _refreshTasks();
  }

  String _fmtTs(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateFormat('MM-dd HH:mm:ss').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Forwarder'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Tasks'),
            Tab(text: 'Logs'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: _tab.index == 0
          ? FloatingActionButton(
              onPressed: () => _openTaskEditor(),
              child: const Icon(Icons.add),
            )
          : null,
      body: TabBarView(
        controller: _tab,
        children: [
          // Tasks
          ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _tasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final t = _tasks[i];
              final condTxt = t.conditions
                  .map((c) => '${c.type.name}="${c.value}"')
                  .join(t.logicMode == LogicMode.all ? ' AND ' : ' OR ');
              return Card(
                child: ListTile(
                  title: Text(t.name),
                  subtitle: Text('$condTxt\n→ ${t.endpointUrl}'),
                  isThreeLine: true,
                  trailing: Switch(
                    value: t.enabled,
                    onChanged: (v) => _toggleTask(t, v),
                  ),
                  onTap: () => _openTaskEditor(task: t),
                  onLongPress: () => showModalBottomSheet(
                    context: context,
                    builder: (_) => SafeArea(
                      child: Wrap(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.delete),
                            title: const Text('Delete'),
                            onTap: () async {
                              Navigator.pop(context);
                              await _deleteTask(t);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Logs
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        await NativeBridge.clearLogs();
                        await _refreshLogs();
                      },
                      icon: const Icon(Icons.delete_sweep),
                      label: const Text('Clear'),
                    ),
                    const SizedBox(width: 12),
                    Text('Latest ${_logs.length} logs'),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _logs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final l = _logs[i];
                    final rc = l.responseCode == null ? '' : ' HTTP ${l.responseCode}';
                    return Card(
                      child: ListTile(
                        title: Text('[${l.status}$rc] ${l.taskName}'),
                        subtitle: Text(
                          '${_fmtTs(l.receivedAt)}  from: ${l.sender}\n${l.body}${l.errorMsg == null ? '' : '\nERR: ${l.errorMsg}'}',
                        ),
                        isThreeLine: true,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => LogDetailPage(log: l)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class LogDetailPage extends StatelessWidget {
  final SmsLog log;
  const LogDetailPage({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    String pretty(String? s) {
      if (s == null || s.trim().isEmpty) return '';
      try {
        final obj = jsonDecode(s);
        return const JsonEncoder.withIndent('  ').convert(obj);
      } catch (_) {
        return s;
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text('Log #${log.id}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Task: ${log.taskName}  (taskId=${log.taskId})'),
          const SizedBox(height: 8),
          Text('Status: ${log.status}  responseCode=${log.responseCode ?? '-'}'),
          const SizedBox(height: 8),
          Text('From: ${log.sender}'),
          const SizedBox(height: 8),
          const Text('SMS Body:'),
          const SizedBox(height: 6),
          SelectableText(log.body),
          const SizedBox(height: 12),
          if (log.sentHeadersJson != null && log.sentHeadersJson!.isNotEmpty) ...[
            const Text('Sent Headers (json):'),
            const SizedBox(height: 6),
            SelectableText(pretty(log.sentHeadersJson)),
            const SizedBox(height: 12),
          ],
          if (log.sentBody != null && log.sentBody!.isNotEmpty) ...[
            const Text('Sent Body:'),
            const SizedBox(height: 6),
            SelectableText(pretty(log.sentBody)),
            const SizedBox(height: 12),
          ],
          if (log.errorMsg != null && log.errorMsg!.isNotEmpty) ...[
            const Text('Error:'),
            const SizedBox(height: 6),
            SelectableText(log.errorMsg!),
          ],
        ],
      ),
    );
  }
}

class TaskEditorPage extends StatefulWidget {
  final Task? task;
  const TaskEditorPage({super.key, this.task});

  @override
  State<TaskEditorPage> createState() => _TaskEditorPageState();
}

class _TaskEditorPageState extends State<TaskEditorPage> {
  late final TextEditingController _name;
  late final TextEditingController _endpoint;
  late final TextEditingController _headersJson;
  late final TextEditingController _bodyTpl;

  late LogicMode _logicMode;
  late bool _enabled;
  late List<Condition> _conditions;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _name = TextEditingController(text: t?.name ?? 'New Task');
    _endpoint = TextEditingController(text: t?.endpointUrl ?? 'https://httpbin.org/post');
    _headersJson = TextEditingController(text: t?.headersJson ?? '{"Content-Type":"application/json"}');
    _bodyTpl = TextEditingController(text: t?.bodyTemplate ?? _defaultTpl());
    _logicMode = t?.logicMode ?? LogicMode.all;
    _enabled = t?.enabled ?? true;
    _conditions = (t?.conditions ?? [const Condition(type: ConditionType.bodyContains, value: '验证码')]).toList();
  }

  String _defaultTpl() {
    return '''{
  "taskId": "{{taskId}}",
  "taskName": "{{taskName}}",
  "receivedAt": "{{receivedAt}}",
  "sender": "{{sender}}",
  "body": "{{body}}"
}''';
  }

  @override
  void dispose() {
    _name.dispose();
    _endpoint.dispose();
    _headersJson.dispose();
    _bodyTpl.dispose();
    super.dispose();
  }

  Task _buildResult() {
    final id = widget.task?.id ?? DateTime.now().millisecondsSinceEpoch;
    final conds = _conditions
        .where((c) => c.value.trim().isNotEmpty)
        .map((c) => Condition(type: c.type, value: c.value.trim()))
        .toList();
    return Task(
      id: id,
      name: _name.text.trim().isEmpty ? 'Task $id' : _name.text.trim(),
      enabled: _enabled,
      endpointUrl: _endpoint.text.trim(),
      logicMode: _logicMode,
      conditions: conds.isEmpty ? [const Condition(type: ConditionType.bodyContains, value: '')] : conds,
      headersJson: _headersJson.text.trim().isEmpty ? "{}" : _headersJson.text.trim(),
      bodyTemplate: _bodyTpl.text,
    );
  }

  void _addCondition() {
    setState(() => _conditions.add(const Condition(type: ConditionType.bodyContains, value: '')));
  }

  void _removeCondition(int idx) {
    setState(() => _conditions.removeAt(idx));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? 'New Task' : 'Edit Task'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _buildResult()),
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Task Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _endpoint,
            decoration: const InputDecoration(labelText: 'Endpoint URL (POST)'),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
            title: const Text('Enabled'),
          ),
          const Divider(height: 24),

          Row(
            children: [
              const Text('Logic: '),
              const SizedBox(width: 12),
              DropdownButton<LogicMode>(
                value: _logicMode,
                items: LogicMode.values
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.name.toUpperCase())))
                    .toList(),
                onChanged: (v) => setState(() => _logicMode = v ?? LogicMode.all),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _addCondition,
                icon: const Icon(Icons.add),
                label: const Text('Add condition'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          ...List.generate(_conditions.length, (i) {
            final c = _conditions[i];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<ConditionType>(
                            value: c.type,
                            items: ConditionType.values
                                .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                                .toList(),
                            onChanged: (v) => setState(() {
                              _conditions[i] = Condition(type: v ?? ConditionType.bodyContains, value: c.value);
                            }),
                            decoration: const InputDecoration(labelText: 'Condition Type'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: _conditions.length <= 1 ? null : () => _removeCondition(i),
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Remove',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: TextEditingController(text: c.value),
                      decoration: const InputDecoration(labelText: 'Value'),
                      onChanged: (v) => _conditions[i] = Condition(type: c.type, value: v),
                    ),
                  ],
                ),
              ),
            );
          }),

          const Divider(height: 24),
          TextField(
            controller: _headersJson,
            decoration: const InputDecoration(
              labelText: 'Headers JSON',
              helperText: '例如: {"Authorization":"Bearer xxx","Content-Type":"application/json"}',
            ),
            minLines: 3,
            maxLines: 8,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyTpl,
            decoration: const InputDecoration(
              labelText: 'Body Template',
              helperText: '占位符: {{taskId}} {{taskName}} {{sender}} {{body}} {{receivedAt}}',
            ),
            minLines: 6,
            maxLines: 18,
          ),
          const SizedBox(height: 12),
          const Text(
            '说明：原生转发会先替换模板占位符；如果结果是合法 JSON 会直接发送，否则会包一层 JSON envelope。',
          ),
        ],
      ),
    );
  }
}
