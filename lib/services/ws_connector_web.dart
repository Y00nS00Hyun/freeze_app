import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/html.dart';

WebSocketChannel platformConnectWs(Uri uri) {
  return HtmlWebSocketChannel.connect(uri.toString());
}
