import 'condition.dart';

enum LogicMode { all, any }

class Task {
  final int id; // millisecondsSinceEpoch
  final String name;
  final bool enabled;
  final String endpointUrl;

  final LogicMode logicMode;
  final List<Condition> conditions;

  /// JSON string, e.g. {"Authorization":"Bearer xxx","X-App":"demo"}
  final String headersJson;

  /// Template placeholders:
  /// {{taskId}}, {{taskName}}, {{sender}}, {{body}}, {{receivedAt}}
  final String bodyTemplate;

  const Task({
    required this.id,
    required this.name,
    required this.enabled,
    required this.endpointUrl,
    required this.logicMode,
    required this.conditions,
    required this.headersJson,
    required this.bodyTemplate,
  });

  Task copyWith({
    int? id,
    String? name,
    bool? enabled,
    String? endpointUrl,
    LogicMode? logicMode,
    List<Condition>? conditions,
    String? headersJson,
    String? bodyTemplate,
  }) {
    return Task(
      id: id ?? this.id,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      endpointUrl: endpointUrl ?? this.endpointUrl,
      logicMode: logicMode ?? this.logicMode,
      conditions: conditions ?? this.conditions,
      headersJson: headersJson ?? this.headersJson,
      bodyTemplate: bodyTemplate ?? this.bodyTemplate,
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "enabled": enabled,
        "endpointUrl": endpointUrl,
        "logicMode": logicMode.name,
        "conditions": conditions.map((e) => e.toJson()).toList(),
        "headersJson": headersJson,
        "bodyTemplate": bodyTemplate,
      };

  static Task fromJson(Map<String, dynamic> json) {
    // Backward compatibility (v1): ruleType/ruleValue
    List<Condition> conds = [];
    final rawConds = json["conditions"];
    if (rawConds is List) {
      conds = rawConds
          .map((e) => Condition.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    }
    if (conds.isEmpty) {
      final rtStr = (json["ruleType"] ?? "bodyContains") as String;
      final rv = (json["ruleValue"] ?? "") as String;
      final ct = ConditionType.values.firstWhere(
        (e) => e.name == rtStr,
        orElse: () => ConditionType.bodyContains,
      );
      conds = [Condition(type: ct, value: rv)];
    }

    final lmStr = (json["logicMode"] ?? "all") as String;
    final lm = LogicMode.values.firstWhere(
      (e) => e.name == lmStr,
      orElse: () => LogicMode.all,
    );

    return Task(
      id: (json["id"] as num).toInt(),
      name: (json["name"] ?? "") as String,
      enabled: (json["enabled"] ?? true) as bool,
      endpointUrl: (json["endpointUrl"] ?? "") as String,
      logicMode: lm,
      conditions: conds,
      headersJson: (json["headersJson"] ?? "{}") as String,
      bodyTemplate: (json["bodyTemplate"] ?? "") as String,
    );
  }
}
