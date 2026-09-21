import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutcraft_protocol/flutcraft_protocol.dart';

/// A real socket behind the client's channel.
///
/// This adapter is the only thing between `RemoteGameSession` and the wire,
/// and the app's own is the same twenty lines. Keeping it here as well means
/// the end-to-end tests exercise the whole path without the app in it.
class SocketChannel implements MessageChannel {
  SocketChannel(this.socket, {this.codec = const JsonMessageCodec()}) {
    socket.listen(
      // A frame can already be on its way in when the socket is closed; the
      // listener still fires, and adding to a closed controller throws where
      // nobody is waiting to catch it.
      (raw) => _incoming.isClosed
          ? null
          : _incoming.add(codec.decodeServer(_bytes(raw))),
      onDone: () {
        if (!_incoming.isClosed) _incoming.close();
      },
    );
  }

  static Future<SocketChannel> connect(int port, {String host = '127.0.0.1'}) =>
      WebSocket.connect('ws://$host:$port').then(SocketChannel.new);

  static Uint8List _bytes(Object? raw) => switch (raw) {
    final Uint8List bytes => bytes,
    final List<int> bytes => Uint8List.fromList(bytes),
    _ => utf8.encode(raw! as String),
  };

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
    if (!_incoming.isClosed) await _incoming.close();
  }
}

/// Waits for something a server does in its own time.
Future<bool> eventually(bool Function() until, {int tries = 300}) async {
  for (var i = 0; i < tries; i++) {
    if (until()) return true;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return until();
}
