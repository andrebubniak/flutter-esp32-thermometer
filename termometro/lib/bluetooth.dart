import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter_blue/flutter_blue.dart' as flutter_blue;
import 'package:permission_handler/permission_handler.dart';

import 'device.dart';

class BluetoothConnectionHandler extends ChangeNotifier
{
  // device related attributes
  DiscoveredDevice? _discoveredDevice;
  final Device device;

  // device connection state attributes
  StreamSubscription<ConnectionStateUpdate>? _currentConnectionStream;
  BluetoothConnectionState _currentBluetoothConnectionState = BluetoothConnectionState.none;
  BluetoothConnectionState get currentBluetoothConnectionState => _currentBluetoothConnectionState;
  
  // flutterReactiveBle object
  final _flutterReactiveBle = FlutterReactiveBle();

  // callback for when receive data
  final void Function(String) onReceiveData;
  

  BluetoothConnectionHandler({required this.device, required this.onReceiveData});


  // public functions

  Future<void> connect() async
  {
    await _currentConnectionStream?.cancel();
    bool isBluetoothOn = await flutter_blue.FlutterBlue.instance.isOn;
    if(!isBluetoothOn)
    {
      _currentBluetoothConnectionState = BluetoothConnectionState.bluetoothDisabled;
      notifyListeners();
      return;
    }
    bool permissionGranted = await _getPermissions();
    if(permissionGranted)
    {
      _currentBluetoothConnectionState = BluetoothConnectionState.connecting;
      notifyListeners();
      bool scanned = await _scanDevices();
      if(scanned)
      {
        await _connectToDevice();
      }
    }
  }// connect

  Future<void> disconnect() async
  {
    await _currentConnectionStream?.cancel();
    _currentBluetoothConnectionState = BluetoothConnectionState.deviceDisconnected;
    notifyListeners();
  }// disconnect


  // private functions

  Future<bool> _getPermissions() async
  {
    bool permGranted = false;
    if (Platform.isAndroid) 
    {
      final btPermission = await Permission.bluetooth.request();
      if(btPermission.isGranted)
      {
        final locationPermission = await Permission.location.request();
        if(locationPermission.isGranted)
        {
          permGranted = true;
        }
      }
    }

    else if (Platform.isIOS) 
    {
      permGranted = true;
    }
 
    if(!permGranted)
    {
      _currentBluetoothConnectionState = BluetoothConnectionState.permissionDenied;
      notifyListeners();
    }

    return permGranted;

  }// _getPermissions


  Future<bool> _scanDevices() async 
  {
    _discoveredDevice = null;
    final discoveredDevice = _flutterReactiveBle.scanForDevices(withServices: [Uuid.parse(device.serviceUUID)]).timeout(const Duration(seconds: 10), onTimeout: (event)
    {
      debugPrint("Bluetooth Scan Timeout");
      event.close();
    })
    .take(10)
    .firstWhere((element)
    {
      debugPrint("Find Device => ${element.name}");
      return element.name == device.name;
    });
    

    await discoveredDevice.then((value)
    {
      _discoveredDevice = value;
    },
    onError: (error)
    {
      debugPrint("Error on discovering device => $error");
      return;
    });

    if(_discoveredDevice != null)
    {
      return true;
    }
    _currentBluetoothConnectionState = BluetoothConnectionState.deviceNotFound;
    notifyListeners();
    return false;

  }// _scanDevices
  
  
  Future<void> _connectToDevice() async
  {
    _currentConnectionStream = _flutterReactiveBle.connectToAdvertisingDevice(
      id: _discoveredDevice!.id,
      prescanDuration: const Duration(seconds: 5),
      withServices: [Uuid.parse(device.serviceUUID)],
      connectionTimeout: const Duration(seconds: 10)
    )
    .listen((event) async
    {
      try
      {
        if(event.connectionState == DeviceConnectionState.connected)
        {
          _currentBluetoothConnectionState = BluetoothConnectionState.deviceConnected;
          await _initializeSubscription();
          notifyListeners();
        }
        else if(event.connectionState == DeviceConnectionState.disconnected)
        {
          _currentBluetoothConnectionState = BluetoothConnectionState.deviceDisconnected;
          notifyListeners();
        }
      }
      catch (err)
      {
        debugPrint("Error on receiving Bluetooth Connection Update => $err");
      }
    },
    onError: (error)
    {
      debugPrint("Error on listening for Bluetooth Connection Update => $error");
      _currentBluetoothConnectionState = BluetoothConnectionState.deviceDisconnected;
      notifyListeners();
    });

  }// _connectToDevice
  
  Future<void> _initializeSubscription() async
  {
    if(_discoveredDevice == null) return;

    final characteristic = QualifiedCharacteristic(
      serviceId: Uuid.parse(device.serviceUUID),
      characteristicId: Uuid.parse(device.receiveDataCharacteristicUUID),
      deviceId: _discoveredDevice!.id
    );

    _flutterReactiveBle.subscribeToCharacteristic(characteristic).map((event) => utf8.decode(event)).listen(onReceiveData, onError: (err) {}, cancelOnError: false);

  }// _initializeSubscription

}


enum BluetoothConnectionState
{
  none,
  deviceNotFound,     
  deviceConnected,    
  permissionDenied,
  deviceDisconnected,
  bluetoothDisabled,
  connecting,
  timeoutOnConnection
}