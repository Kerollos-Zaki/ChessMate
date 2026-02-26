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
    
    // Check if any device is already connected
    List<BluetoothDevice> connected = FlutterBluePlus.connectedDevices;
    if (connected.isNotEmpty) {
      setState(() {
        connectedDevice = connected.first;
      });
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
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

      scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (mounted) {
          setState(() {
            scanResults = results.where((r) {
              final name = r.device.platformName.toLowerCase();
              return name.contains('chessmate');
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
    setState(() {
      isConnecting = true;
    });

    try {
      await FlutterBluePlus.stopScan();
      await device.connect();
      
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
      setState(() {
        isConnecting = false;
      });
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
      setState(() {
        connectedDevice = null;
      });
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
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.03),
              ),
            ),
          ),
          Column(
            children: [
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      _buildRoundButton(
                        icon: Icons.arrow_back_ios_new,
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 20),
                      const Text(
                        'Connect Board',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
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
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: connectedDevice != null 
                                  ? Colors.greenAccent.withOpacity(0.1) 
                                  : Colors.white.withOpacity(0.05),
                              border: Border.all(
                                color: connectedDevice != null 
                                    ? Colors.greenAccent.withOpacity(0.3) 
                                    : Colors.white.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              connectedDevice != null 
                                  ? Icons.bluetooth_connected 
                                  : (isScanning ? Icons.bluetooth_searching : Icons.bluetooth),
                              color: connectedDevice != null ? Colors.greenAccent : Colors.white,
                              size: 48,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Text(
                        connectedDevice != null 
                            ? 'Board Connected' 
                            : (isConnecting ? 'Connecting...' : (isScanning ? 'Searching for Board...' : 'Scan Complete')),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        connectedDevice != null 
                            ? 'Your ChessMate board is ready' 
                            : 'Showing only ChessMate devices',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 14,
                        ),
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
                                        Text(
                                          isScanning ? "Looking for your board..." : "ChessMate board not found",
                                          style: TextStyle(color: Colors.white.withOpacity(0.5)),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: scanResults.length,
                                    itemBuilder: (context, index) {
                                      final result = scanResults[index];
                                      return _buildBoardCard(result);
                                    },
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: connectedDevice != null ? const BorderSide(color: Colors.redAccent, width: 1) : BorderSide.none,
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            connectedDevice != null 
                                ? 'Disconnect Board' 
                                : (isScanning ? 'Scanning...' : 'Scan Again'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
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
        gradient: LinearGradient(
          colors: [
            Colors.greenAccent.withOpacity(0.1),
            Colors.greenAccent.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.greenAccent.withOpacity(0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connectedDevice!.platformName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Successfully paired',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBoardCard(ScanResult result) {
    return GestureDetector(
      onTap: () => connectToDevice(result.device),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.08),
              Colors.white.withOpacity(0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.grid_4x4, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.device.platformName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'ChessMate Board Detected',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            _SignalIndicator(rssi: result.rssi),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundButton({required IconData icon, required VoidCallback onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _buildPulseCircle(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    );
  }
}

class _SignalIndicator extends StatelessWidget {
  final int rssi;
  const _SignalIndicator({required this.rssi});

  @override
  Widget build(BuildContext context) {
    int bars = 1;
    if (rssi > -60) bars = 4;
    else if (rssi > -70) bars = 3;
    else if (rssi > -80) bars = 2;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (index) {
        return Container(
          width: 3,
          height: (index + 1) * 4.0,
          margin: const EdgeInsets.only(left: 3),
          decoration: BoxDecoration(
            color: index < bars ? Colors.white : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}
