import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class PinManagementScreen extends StatefulWidget {
  const PinManagementScreen({super.key});

  @override
  State<PinManagementScreen> createState() => _PinManagementScreenState();
}

class _PinManagementScreenState extends State<PinManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User\'s PIN'),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          if (!authProvider.isAdmin) {
            return const Center(
              child: Text('Restricted Access: Admins Only'),
            );
          }

          final pins = authProvider.validPins;

          return pins.isEmpty
              ? const Center(
                  child: Text('No user PIN codes'),
                )
              : ListView.builder(
                  itemCount: pins.length,
                  itemBuilder: (context, index) {
                    final pin = pins[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.pin),
                      ),
                      title: Text(
                        pin,
                        style: const TextStyle(
                          fontSize: 24,
                          letterSpacing: 4,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        authProvider.pinToUsername[pin] ?? 'unknown',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removePin(pin),
                      ),
                    );
                  },
                );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addPin,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _addPin() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const _AddPinDialog(),
    );

    if (result != null && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.addPin(
        result['pin']!,
        result['username']!,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'PIN code added successfully'
                  : 'Error: invalid or duplicate PIN code',
            ),
          ),
        );
      }
    }
  }

  Future<void> _removePin(String pin) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete PIN Code'),
        content: Text('Are you sure you want to delete PIN code $pin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.removePin(pin);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN code deleted')),
        );
      }
    }
  }
}

class _AddPinDialog extends StatefulWidget {
  const _AddPinDialog();

  @override
  State<_AddPinDialog> createState() => _AddPinDialogState();
}

class _AddPinDialogState extends State<_AddPinDialog> {
  final _pinController = TextEditingController();
  final _usernameController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add PIN Code'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
              hintText: 'e.g., John Doe',
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            decoration: const InputDecoration(
              labelText: 'PIN Code (6 digits)',
              counterText: '',
            ),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              letterSpacing: 4,
              fontWeight: FontWeight.bold,
            ),
            maxLength: 6,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_pinController.text.length == 6 && _usernameController.text.isNotEmpty) {
              Navigator.of(context).pop({
                'pin': _pinController.text,
                'username': _usernameController.text,
              });
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
