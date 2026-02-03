import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttTestScreen extends StatefulWidget {
  const MqttTestScreen({super.key});

  @override
  State<MqttTestScreen> createState() => _MqttTestScreenState();
}

class _MqttTestScreenState extends State<MqttTestScreen> {
  final List<String> _logs = [];
  MqttServerClient? _client;
  bool _isConnected = false;
  bool _isConnecting = false;

  void _addLog(String message) {
    setState(() {
      _logs.insert(0, '${DateTime.now().toString().substring(11, 19)} - $message');
    });
    print(message);
  }

  Future<void> _testConnection() async {
    setState(() {
      _isConnecting = true;
      _logs.clear();
    });

    try {
      final clientId = 'test_${DateTime.now().millisecondsSinceEpoch}';

      _client = MqttServerClient('broker.hivemq.com', clientId);
      _client!.port = 1883;
      _client!.keepAlivePeriod = 20;
      _client!.logging(on: false);
      _client!.setProtocolV311();

      _client!.onConnected = () {
        setState(() {
          _isConnected = true;
          _isConnecting = false;
        });
      };

      _client!.onDisconnected = () {
        setState(() {
          _isConnected = false;
        });
      };

      final connMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean()
          .withWillQos(MqttQos.atMostOnce);
      _client!.connectionMessage = connMessage;

      await _client!.connect();

      if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
        setState(() {
          _isConnected = true;
          _isConnecting = false;
        });
      } else {
        setState(() {
          _isConnecting = false;
        });
      }
    } catch (e) {
      _addLog('ERROR TEST MQTT: $e');
      setState(() {
        _isConnecting = false;
      });
    }
  }

  void _disconnect() {
    _client?.disconnect();
    setState(() {
      _isConnected = false;
    });
    _addLog('Disconnected');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MQTT Test'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _isConnecting ? null : _testConnection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: _isConnecting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Connect'),
                    ),
                    ElevatedButton(
                      onPressed: _isConnected ? _disconnect : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Disconnect'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isConnected ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _isConnected ? '✅ CONNECTED' : '⚪ DISCONNECTED',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'LOGS',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.black87,
              child: _logs.isEmpty
                  ? const Center(
                      child: Text(
                        'Appuyez sur Connect',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 2.0,
                          ),
                          child: Text(
                            _logs[index],
                            style: TextStyle(
                              color: _logs[index].contains('✅')
                                  ? Colors.greenAccent
                                  : _logs[index].contains('❌')
                                      ? Colors.redAccent
                                      : Colors.white,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _client?.disconnect();
    super.dispose();
  }
}
