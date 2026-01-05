class SmsLog {
  final int id;
  final int taskId;
  final String taskName;
  final String sender;
  final String body;
  final int receivedAt;

  final String status; // PENDING/SUCCESS/FAILED
  final String? errorMsg;

  final int? responseCode;
  final String? sentHeadersJson;
  final String? sentBody;

  const SmsLog({
    required this.id,
    required this.taskId,
    required this.taskName,
    required this.sender,
    required this.body,
    required this.receivedAt,
    required this.status,
    this.errorMsg,
    this.responseCode,
    this.sentHeadersJson,
    this.sentBody,
  });

  static SmsLog fromJson(Map<String, dynamic> json) => SmsLog(
        id: (json["id"] as num).toInt(),
        taskId: (json["taskId"] as num).toInt(),
        taskName: (json["taskName"] ?? "") as String,
        sender: (json["sender"] ?? "") as String,
        body: (json["body"] ?? "") as String,
        receivedAt: (json["receivedAt"] as num).toInt(),
        status: (json["status"] ?? "PENDING") as String,
        errorMsg: json["errorMsg"] as String?,
        responseCode: (json["responseCode"] as num?)?.toInt(),
        sentHeadersJson: json["sentHeadersJson"] as String?,
        sentBody: json["sentBody"] as String?,
      );
}
