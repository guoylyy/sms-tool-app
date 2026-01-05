enum ConditionType { senderContains, bodyContains, bodyRegex }

class Condition {
  final ConditionType type;
  final String value;

  const Condition({required this.type, required this.value});

  Map<String, dynamic> toJson() => {
        "type": type.name,
        "value": value,
      };

  static Condition fromJson(Map<String, dynamic> json) {
    final t = (json["type"] ?? "bodyContains") as String;
    final type = ConditionType.values.firstWhere(
      (e) => e.name == t,
      orElse: () => ConditionType.bodyContains,
    );
    return Condition(
      type: type,
      value: (json["value"] ?? "") as String,
    );
  }
}
