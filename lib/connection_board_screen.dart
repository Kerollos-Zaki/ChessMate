import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:io';

class ConnectionBoardScreen extends StatefulWidget {
  const ConnectionBoardScreen({super.key});

  @override
  State<ConnectionBoardScreen> createState() => _ConnectionBoardScreenState();
}

class _ConnectionBoardScreenState extends State<ConnectionBoardScreen> {
  List<ScanResult> scanResults = [];
  bool isScanning = false;
  StreamSubscription<List<ScanResult>>? scanSubscription;
  BluetoothDevice? connectedDevice;
  bool isConnecting = false;

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    if (Platform.isAndroid) {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();
    }
    
    // 1. Check currently connected devices
    List<BluetoothDevice> connected = FlutterBluePlus.connectedDevices;
    if (connected.isNotEmpty) {
      for (var device in connected) {
        if (device.platformName.toLowerCase().contains('chessmate')) {
          setState(() => connectedDevice = device);
          return;
        }
      }
    }

    // 2. Check system-paired devices (Crucial if already paired in Android settings)
    try {
      // FIX: Added '([])' to invoke the method correctly
      List<BluetoothDevice> systemDevices = await FlutterBluePlus.systemDevices([]);
      for (var device in systemDevices) {
        if (device.platformName.toLowerCase().contains('chessmate')) {
          debugPrint("Found ChessMate in system paired devices: ${device.remoteId}");
          // If found in system but not scanning, we can still try to connect to it
          // For now, let's just log it. You might want to add it to scanResults manually.
        }
      }
    } catch (e) {
      debugPrint("Error checking system devices: $e");
    }
    
    startScan();
  }

  void startScan() async {
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please turn on Bluetooth")),
        );
      }
      return;
    }

    setState(() {
      scanResults.clear();
      isScanning = true;
    });

    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: true,
      );

      scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (mounted) {
          setState(() {
            scanResults = results.where((r) {
              final pName = r.device.platformName.trim().toLowerCase();
              final aName = r.advertisementData.advName.trim().toLowerCase();
              
              if (pName.isNotEmpty || aName.isNotEmpty) {
                debugPrint("Device Found: ID: ${r.device.remoteId} | PlatformName: '$pName' | AdvName: '$aName'");
              }

              return pName.contains('chessmate') || aName.contains('chessmate');
            }).toList();
          });
        }
      });
    } catch (e) {
      debugPrint("Scan Error: $e");
    }

    await Future.delayed(const Duration(seconds: 15));
    if (mounted) {
      setState(() => isScanning = false);
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    setState(() => isConnecting = true);

    try {
      await FlutterBluePlus.stopScan();
      await device.connect(timeout: const Duration(seconds: 10));
      
      setState(() {
        connectedDevice = device;
        isConnecting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Connected to ${device.platformName}"),
            backgroundColor: Colors.greenAccent.withOpacity(0.8),
          ),
        );
      }
    } catch (e) {
      setState(() => isConnecting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Connection Failed: $e")),
        );
      }
    }
  }

  Future<void> disconnectDevice() async {
    if (connectedDevice != null) {
      await connectedDevice!.disconnect();
      setState(() => connectedDevice = null);
    }
  }

  @override
  void dispose() {
    scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.03)),
            ),
          ),
          Column(
            children: [
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      _buildRoundButton(icon: Icons.arrow_back_ios_new, onPressed: () => Navigator.pop(context)),
                      const SizedBox(width: 20),
                      const Text('Connect Board', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          if (isScanning || isConnecting) _buildPulseCircle(200, 0.02),
                          if (isScanning || isConnecting) _buildPulseCircle(160, 0.05),
                          Container(
                            width: 110, height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: connectedDevice != null ? Colors.greenAccent.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                              border: Border.all(color: connectedDevice != null ? Colors.greenAccent.withOpacity(0.3) : Colors.white.withOpacity(0.1)),
                            ),
                            child: Icon(
                              connectedDevice != null ? Icons.bluetooth_connected : (isScanning ? Icons.bluetooth_searching : Icons.bluetooth),
                              color: connectedDevice != null ? Colors.greenAccent : Colors.white,
                              size: 48,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Text(
                        connectedDevice != null ? 'Board Connected' : (isConnecting ? 'Connecting...' : (isScanning ? 'Searching for Board...' : 'Scan Complete')),
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        connectedDevice != null ? 'Your ChessMate board is ready' : 'Only ChessMate boards will appear here',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                      ),
                      const SizedBox(height: 30),

                      Expanded(
                        child: connectedDevice != null 
                            ? _buildConnectedCard()
                            : (scanResults.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.grid_4x4, color: Colors.white.withOpacity(0.2), size: 48),
                                        const SizedBox(height: 16),
                                        Text(isScanning ? "Looking for your board..." : "ChessMate board not found", style: TextStyle(color: Colors.white.withOpacity(0.5))),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: scanResults.length,
                                    itemBuilder: (context, index) => _buildBoardCard(scanResults[index]),
                                  )),
                      ),

                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: isScanning || isConnecting ? null : (connectedDevice != null ? disconnectDevice : startScan),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: connectedDevice != null ? Colors.redAccent.withOpacity(0.1) : Colors.white,
                            foregroundColor: connectedDevice != null ? Colors.redAccent : Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: connectedDevice != null ? const BorderSide(color: Colors.redAccent) : BorderSide.none),
                            elevation: 0,
                          ),
                          child: Text(connectedDevice != null ? 'Disconnect Board' : (isScanning ? 'Scanning...' : 'Scan Again'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.greenAccent.withOpacity(0.1), Colors.greenAccent.withOpacity(0.02)]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle), child: const Icon(Icons.check_circle, color: Colors.greenAccent)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(connectedDevice!.platformName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)), const Text('Successfully paired', style: TextStyle(color: Colors.greenAccent, fontSize: 13))])),
        ],
      ),
    );
  }

  Widget _buildBoardCard(ScanResult result) {
    String name = result.device.platformName.isNotEmpty ? result.device.platformName : result.advertisementData.advName;
    return GestureDetector(
      onTap: () => connectToDevice(result.device),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.03)]),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle), child: const Icon(Icons.grid_4x4, color: Colors.white)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), const Text('ChessMate Board Detected', style: TextStyle(color: Colors.greenAccent, fontSize: 12))])),
            _SignalIndicator(rssi: result.rssi),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundButton({required IconData icon, required VoidCallback onPressed}) {
    return GestureDetector(onTap: onPressed, child: Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.1))), child: Icon(icon, color: Colors.white, size: 18)));
  }

  Widget _buildPulseCircle(double size, double opacity) {
    return Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(opacity)));
  }
}

class _SignalIndicator extends StatelessWidget {
  final int rssi;
  const _SignalIndicator({required this.rssi});
  @override
  Widget build(BuildContext context) {
    int bars = rssi > -60 ? 4 : (rssi > -70 ? 3 : (rssi > -80 ? 2 : 1));
    return Row(mainAxisSize: MainAxisSize.min, children: List.generate(4, (index) => Container(width: 3, height: (index + 1) * 4.0, margin: const EdgeInsets.only(left: 3), decoration: BoxDecoration(color: index < bars ? Colors.white : Colors.white24, borderRadius: BorderRadius.circular(2)))));
  }
}
