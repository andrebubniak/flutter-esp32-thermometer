import 'package:flutter/material.dart';
import 'bluetooth.dart';

class BluetoothStatusBar extends StatefulWidget
{
  final BluetoothConnectionHandler bluetoothConnectionHandler;
  const BluetoothStatusBar({super.key, required this.bluetoothConnectionHandler});

  @override
  State<BluetoothStatusBar> createState() => _BluetoothStatusBarState();
}

class _BluetoothStatusBarState extends State<BluetoothStatusBar>
{
  late String infoText;
  late String buttonText;
  late bool isButtonEnabled;

  @override
  void initState()
  {
    infoText = "Não Conectado";
    buttonText = "Conectar";
    isButtonEnabled = true;
    widget.bluetoothConnectionHandler.addListener(() {setState(() {});});
    super.initState();
  }


  void setCurrentScreenState(BluetoothConnectionState currentBluetoothState)
  {
    switch(currentBluetoothState)
    {
      case BluetoothConnectionState.bluetoothDisabled:
        infoText = "Bluetooth Desabilitado";
        buttonText = "Conectar";
        isButtonEnabled = true;
        break;
      
      case BluetoothConnectionState.permissionDenied:
        infoText = "Permissão Negada";
        buttonText = "Conectar";
        isButtonEnabled = true;
        break;

      case BluetoothConnectionState.connecting:
        infoText = "Conectando...";
        buttonText = "Conectar";
        isButtonEnabled = false;
        break;

      case BluetoothConnectionState.deviceNotFound:
        infoText = "Dispositivo Não Encontrado";
        buttonText = "Conectar";
        isButtonEnabled = true;
        break;

      case BluetoothConnectionState.timeoutOnConnection:
        infoText = "Não foi possível conectar";
        buttonText = "Conectar";
        isButtonEnabled = true;
        break;

      case BluetoothConnectionState.deviceConnected:
        infoText = "Conectado";
        buttonText = "Desconectar";
        isButtonEnabled = true;
        break;

      case BluetoothConnectionState.deviceDisconnected:
        infoText = "Desconectado";
        buttonText = "Reconectar";
        isButtonEnabled = true;
        break;

      case BluetoothConnectionState.none:
        infoText = "Não Conectado";
        buttonText = "Conectar";
        isButtonEnabled = true;
        break;
    }
  }


  @override
  Widget build(BuildContext context)
  {
    setCurrentScreenState(widget.bluetoothConnectionHandler.currentBluetoothConnectionState);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(infoText),
          ElevatedButton(
            onPressed: (!isButtonEnabled)? null :
            ()
            {
              (buttonText == "Desconectar")? widget.bluetoothConnectionHandler.disconnect() : widget.bluetoothConnectionHandler.connect();
            },
            child: Text(buttonText)
          )
        ],
      )
    );
  }
}