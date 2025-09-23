import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

WebSocketChannel platformConnectWs(Uri uri) {
  return IOWebSocketChannel.connect(
    uri,
    pingInterval: const Duration(seconds: 15),
  );
}
