class MessageModel {
  final String type;
  final String sender;
  final String? message;
  final String? file;
  final double? lat;
  final double? lng;

  MessageModel({
    required this.type,
    required this.sender,
    this.message,
    this.file,
    this.lat,
    this.lng,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      type: json["type"],
      sender: json["sender"] ?? "",
      message: json["message"],
      file: json["file"],
      lat: json["lat"]?.toDouble(),
      lng: json["lng"]?.toDouble(),
    );
  }
}