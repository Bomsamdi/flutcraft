import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutcraft_protocol/flutcraft_protocol.dart';

/// A [MessageChannel] made of a real socket.
///
/// The whole of the networked client lives in `flutcraft_protocol`, which has
/// no `dart:io` in it at all; this is the twenty lines that bridge the two,
/// and it sits beside the save file adapter because it is the same kind of
/// thing — the composition root's business, not the game's.
class WebSocketChannel implements MessageChannel {
  WebSocketChannel(this.socket, {this.codec = const JsonMessageCodec()}) {
    socket.listen(
      (raw) => _incoming.add(codec.decodeServer(_bytes(raw))),
      onDone: _closeIncoming,
      onError: (Object _) => _closeIncoming(),
    );
  }

  /// Opens a connection to a server.
  static Future<WebSocketChannel> connect(Uri address) async =>
      WebSocketChannel(await WebSocket.connect(address.toString()));

  final WebSocket socket;
  final MessageCodec codec;
  final _incoming = StreamController<ServerMessage>.broadcast();

  @override
  Stream<ServerMessage> get incoming => _incoming.stream;

  @override
  void send(ClientMessage message) => socket.add(codec.encodeClient(message));

  @override
  Future<void> close() async {
    await socket.close();
    _closeIncoming();
  }

  void _closeIncoming() {
    if (!_incoming.isClosed) _incoming.close();
  }

  /// A frame arrives as bytes or as text; the codec only reads bytes.
  static Uint8List _bytes(Object? raw) => switch (raw) {
    final Uint8List bytes => bytes,
    final List<int> bytes => Uint8List.fromList(bytes),
    _ => utf8.encode(raw! as String),
  };
}
