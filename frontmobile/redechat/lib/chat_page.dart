import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:geolocator/geolocator.dart';

import 'models/message_model.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {

  final TextEditingController controller = TextEditingController();

  late WebSocketChannel channel;

  final List<MessageModel> messages = [];

  final int clientId = Random().nextInt(999999);

  @override
  void initState() {
    super.initState();

    // ============================================
    // ALTERE O IP
    // ============================================

    channel = WebSocketChannel.connect(
      Uri.parse(
        "ws://192.168.43.179:8000/ws/$clientId",
      ),
    );

    channel.stream.listen((event) {

      final data = jsonDecode(event);

      setState(() {
        messages.add(MessageModel.fromJson(data));
      });
    });
  }

  // ============================================
  // ENVIAR TEXTO
  // ============================================

  void sendText() {

    if (controller.text.trim().isEmpty) return;

    channel.sink.add(
      jsonEncode({
        "type": "text",
        "message": controller.text,
      }),
    );

    controller.clear();
  }

  // ============================================
  // ENVIAR IMAGEM
  // ============================================

  Future<void> sendImage() async {

    final picker = ImagePicker();

    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image == null) return;

    final bytes = await File(image.path).readAsBytes();

    final base64Image = base64Encode(bytes);

    final mimeType = image.path.endsWith(".png")
        ? "image/png"
        : "image/jpeg";

    channel.sink.add(
      jsonEncode({
        "type": mimeType,
        "file": "data:$mimeType;base64,$base64Image",
      }),
    );
  }

  // ============================================
  // ENVIAR VIDEO
  // ============================================

  Future<void> sendVideo() async {

    final picker = ImagePicker();

    final video = await picker.pickVideo(
      source: ImageSource.gallery,
    );

    if (video == null) return;

    final bytes = await File(video.path).readAsBytes();

    final base64Video = base64Encode(bytes);

    channel.sink.add(
      jsonEncode({
        "type": "video/mp4",
        "file": "data:video/mp4;base64,$base64Video",
      }),
    );
  }

  // ============================================
  // ENVIAR LOCALIZAÇÃO
  // ============================================

  Future<void> sendLocation() async {

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {

      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition();

    channel.sink.add(
      jsonEncode({
        "type": "location",
        "lat": position.latitude,
        "lng": position.longitude,
      }),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xff0F172A),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xff111827),
        title: const Text(
          "Khoza Chat",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: Column(
        children: [

          // ============================================
          // LISTA
          // ============================================

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {

                final msg = messages[index];

                return Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xff1E293B),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [

                        Text(
                          msg.sender,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),

                        const SizedBox(height: 10),

                        // ============================================
                        // TEXTO
                        // ============================================

                        if (msg.type == "text")
                          Text(
                            msg.message ?? "",
                            style: const TextStyle(
                              fontSize: 16,
                            ),
                          ),

                        // ============================================
                        // IMAGEM
                        // ============================================

                        if (msg.type == "image")
                          ClipRRect(
                            borderRadius:
                                BorderRadius.circular(14),
                            child: Image.memory(
                              base64Decode(
                                msg.file!
                                    .split(",")
                                    .last,
                              ),
                              width: 250,
                              fit: BoxFit.cover,
                            ),
                          ),

                        // ============================================
                        // VIDEO
                        // ============================================

                        if (msg.type == "video")
                          Container(
                            width: 250,
                            height: 150,
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(14),
                              color: Colors.black26,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.play_circle_fill,
                                size: 60,
                              ),
                            ),
                          ),

                        // ============================================
                        // MAPA
                        // ============================================

                        if (msg.type == "location")
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [

                              const Icon(
                                Icons.location_pin,
                                color: Colors.red,
                              ),

                              Text(
                                "Latitude: ${msg.lat}",
                              ),

                              Text(
                                "Longitude: ${msg.lng}",
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ============================================
          // INPUT
          // ============================================

          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xff111827),
            ),
            child: SafeArea(
              child: Row(
                children: [

                  // imagem
                  IconButton(
                    onPressed: sendImage,
                    icon: const Icon(Icons.image),
                  ),

                  // video
                  IconButton(
                    onPressed: sendVideo,
                    icon: const Icon(Icons.videocam),
                  ),

                  // localização
                  IconButton(
                    onPressed: sendLocation,
                    icon: const Icon(Icons.location_on),
                  ),

                  // input
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xff1E293B),
                        borderRadius:
                            BorderRadius.circular(16),
                      ),
                      child: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          hintText: "Mensagem...",
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // enviar
                  GestureDetector(
                    onTap: sendText,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius:
                            BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.send),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}