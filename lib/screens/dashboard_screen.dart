import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/garage_provider.dart';
import '../services/geofence_service.dart';
import '../services/notification_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final GeofenceService _geofenceService = GeofenceService();
  bool _geofencingEnabled = false;

  @override
  void initState() {
    super.initState();
    _initServices();
    // Initialize notification service context after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().setContext(context);
    });
  }

  Future<void> _initServices() async {
    // Get MQTT service from provider
    final garageProvider = context.read<GarageProvider>();
    final authProvider = context.read<AuthProvider>();
    
    // Initial status refresh
    await garageProvider.refreshStatus();
    // GeofenceService doesn't need to initialize MQTT again (already done in main)
    await _geofenceService.init();
    
    // Configure callback to get garage status
    _geofenceService.setGarageStatusCallback(() {
      return garageProvider.status?.isOpen ?? false;
    });
    
    // Configure callback to get current username
    _geofenceService.setUsernameCallback(() {
      return authProvider.currentUsername ?? 'unknown';
    });
  }

  @override
  void dispose() {
    context.read<GarageProvider>().stopAutoRefresh();
    _geofenceService.stopMonitoring();
    super.dispose();
  }

  Future<void> _toggleGeofencing() async {
    if (_geofencingEnabled) {
      _geofenceService.stopMonitoring();
      setState(() {
        _geofencingEnabled = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geofencing disabled')),
      );
    } else {
      final hasPermission = await _geofenceService.checkPermissions();
      
      if (hasPermission) {
        await _geofenceService.startMonitoring();
        setState(() {
          _geofencingEnabled = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geofencing enabled')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions required'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Garage'),
        actions: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              if (authProvider.isAdmin) {
                return IconButton(
                  icon: const Icon(Icons.admin_panel_settings),
                  onPressed: () {
                    Navigator.of(context).pushNamed('/pin-management');
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<GarageProvider>().refreshStatus();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Card
              _buildStatusCard(),
              const SizedBox(height: 16),
              
              // Control Buttons
              _buildControlButtons(),
              const SizedBox(height: 16),
              
              // Geofencing Toggle
              _buildGeofencingToggle(),
              const SizedBox(height: 16),
              
              // Test Coordinates Button
              _buildTestCoordinatesButton(),
              const SizedBox(height: 16),
              
              // MQTT Status
              _buildMqttStatus(),
              const SizedBox(height: 24),
              
              // Activity Logs
              _buildActivityLogs(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Consumer<GarageProvider>(
      builder: (context, garageProvider, child) {
        final status = garageProvider.status;
        final isOpen = status?.isOpen ?? false;
        
        return SizedBox(
          width: double.infinity,
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Icon(
                    isOpen ? Icons.garage_outlined : Icons.garage,
                    size: 80,
                    color: isOpen ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Status',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    status?.status.toUpperCase() ?? 'UNKNOWN',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isOpen ? Colors.green : Colors.grey[700],
                        ),
                  ),
                  if (status != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Last updated: ${DateFormat('HH:mm:ss').format(status.lastUpdated)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlButtons() {
    return Consumer2<GarageProvider, AuthProvider>(
      builder: (context, garageProvider, authProvider, child) {
        final username = authProvider.currentUsername ?? 'unknown';
        
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: garageProvider.isLoading
                        ? null
                        : () async {
                            await garageProvider.openGarage(username: username);
                          },
                    icon: const Icon(Icons.arrow_upward),
                    label: const Text('OPEN'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: garageProvider.isLoading
                        ? null
                        : () async {
                            await garageProvider.closeGarage(username: username);
                          },
                    icon: const Icon(Icons.arrow_downward),
                    label: const Text('CLOSE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            if (garageProvider.isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: LinearProgressIndicator(),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTestCoordinatesButton() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  _geofenceService.setTestCoordinates(20.0, 20.0);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Coordinates AWAY'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
                icon: const Icon(Icons.flight),
                label: const Text('Set AWAY coordinates'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  _geofenceService.clearTestCoordinates();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Coordinates HOME'),
                      backgroundColor: Colors.blue,
                    ),
                  );
                },
                icon: const Icon(Icons.home),
                label: const Text('Set HOME coordinates'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGeofencingToggle() {
    return Card(
      child: SwitchListTile(
        title: const Text('Geofencing'),        
        value: _geofencingEnabled,
        onChanged: (value) => _toggleGeofencing(),
        secondary: Icon(
          _geofencingEnabled ? Icons.location_on : Icons.location_off,
          color: _geofencingEnabled ? Colors.green : Colors.grey,
        ),
      ),
    );
  }

  Widget _buildMqttStatus() {
    return Consumer<GarageProvider>(
      builder: (context, garageProvider, child) {
        final isConnected = garageProvider.isMqttConnected;
        
        return Card(
          child: ListTile(
            leading: Icon(
              isConnected ? Icons.cloud_done : Icons.cloud_off,
              color: isConnected ? Colors.green : Colors.grey,
            ),
            title: const Text('MQTT Status'),
            subtitle: Text(
              isConnected ? 'Connected' : 'Disconnected',
            ),
            trailing: isConnected
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.error_outline, color: Colors.grey),
          ),
        );
      },
    );
  }

  Widget _buildActivityLogs() {
    return Consumer<GarageProvider>(
      builder: (context, garageProvider, child) {
        final logs = garageProvider.logs;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Activity Logs',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (logs.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text('No activity logs yet'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: log.message.toLowerCase().contains('open')
                            ? Colors.green
                            : Colors.red,
                        child: Icon(
                          log.message.toLowerCase().contains('open')
                              ? Icons.door_front_door_outlined
                              : Icons.door_front_door,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Text(log.message),
                      subtitle: Text(
                        '${log.source} • ${DateFormat('MMM dd HH:mm').format(log.timestamp)}',
                      ),
                      trailing: Chip(
                        label: Text(
                          log.type,
                          style: const TextStyle(fontSize: 10),
                        ),
                        backgroundColor: log.type == 'auto' ? Colors.orange[100] : Colors.blue[100],
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
