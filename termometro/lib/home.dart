import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:termometro/bluetooth.dart';
import 'package:termometro/bluetooth_status_bar.dart';
import 'package:termometro/device.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:open_file/open_file.dart';

class Home extends StatefulWidget 
{
  final String spreadSheetFileName = "LM35.xlsx";
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> 
{

  double temperature = 0;

  late final BluetoothConnectionHandler bluetoothConnectionHandler;

  bool isGatheringData = false;
  bool isSavingFile = false;
  bool hasSavedFile = false;


  final Excel excel = Excel.createExcel();
  late final Sheet defaultSheet;
  int currentRow = 1;

  @override
  void initState() 
  {
    bluetoothConnectionHandler = BluetoothConnectionHandler(
      device: Device(
        name: "ESP32_LM35",
        serviceUUID: "c097aeb9-0d5e-4fb2-817f-29d6fd5184fd",
        receiveDataCharacteristicUUID: "9a542120-3f62-4aec-8223-809f94d0bab5"
      ),
      onReceiveData: onReceiveData
    );

    defaultSheet = excel[excel.getDefaultSheet()!];
    defaultSheet.insertRowIterables(["Horário", "Temperatura ºC"], 0);

    super.initState();
    checkFileExistence();
  }

  @override
  void dispose()
  {
    bluetoothConnectionHandler.disconnect();
    bluetoothConnectionHandler.dispose();
    super.dispose();
  }


  void checkFileExistence()
  {
    path_provider.getExternalStorageDirectory().then(
      (value)
      {
        if(value == null) return;
        File("${value.path}/${widget.spreadSheetFileName}").exists().then(
          (value)
          {
            hasSavedFile = value;
            setState(() {});
          }
        );
      },
      onError: (err) {}
    );
  }


  void onReceiveData(String data)
  {
    temperature = double.tryParse(data)?? 0;
    if(temperature != 0)
    {
      if(isGatheringData)
      {
        String currentTime = DateFormat("d/M, HH:mm:ss").format(DateTime.now());
        defaultSheet.insertRowIterables([currentTime, temperature.toStringAsFixed(2)], currentRow);
        currentRow++;
      }
      setState(() {});
    }
  }


  Future<void> saveDataOnExcel() async
  {
    var dir = await path_provider.getExternalStorageDirectory();

    if(dir != null)
    {
      isSavingFile = true;
      setState(() {});

      var fileBytes = excel.save();
      if(fileBytes == null) return;

      File("${dir.path}/${widget.spreadSheetFileName}").writeAsBytes(fileBytes).then(
        (value)
        {
          isSavingFile = false;
          checkFileExistence();              
        },
        onError: (_) {}
      );
    }
  }



  void openSpreadSheet()
  {
    path_provider.getExternalStorageDirectory().then(
      (value)
      {
        if(value == null) return;
        OpenFile.open("${value.path}/${widget.spreadSheetFileName}", type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", uti: "com.microsoft.excel.xls");
      }
    );
  }



  void startStopGatheringData()
  {
    if(!isGatheringData)
    {
      isGatheringData = true;
      setState(() {});
    }
    else
    {
      isGatheringData = false;
      currentRow = 1;
      setState(() {});
      saveDataOnExcel();
    }
  }


  Widget temperatureGauge() => 
  SfRadialGauge(
    axes: <RadialAxis>[
      RadialAxis(
        minimum: 0,
        maximum: 100,
        ranges: <GaugeRange>[
          GaugeRange(
            startValue: 0,
            endValue: 100,
            gradient: const SweepGradient(
              colors: <Color>[
                Colors.blue,
                Colors.yellow,
                Colors.orange,
                Colors.deepOrange,
                Colors.red
              ],
              stops: [0.15, 0.4, 0.6, 0.8, 1]
            ),
          )
        ],
        pointers: <GaugePointer>[
          NeedlePointer(
            value: temperature,
            enableAnimation: true,
            animationDuration: 400
          )
        ],
        annotations: <GaugeAnnotation>[
          GaugeAnnotation(
            widget: Text(
              "${temperature.toStringAsFixed(2)}ºC",
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold
                )
            ),
            angle: 90,
            positionFactor: 0.5
          )
        ]
      )
    ]
  );



  Widget gatherDataOptions()
  {
    String gatherDataText = (!isGatheringData)? "Iniciar coleta de temperatura" : "Parar coleta de temperatura";

    if(isSavingFile) gatherDataText = "Salvando...";

    return PopupMenuButton(
      itemBuilder: (context)
      {
        return [
          PopupMenuItem<int>(
            value: 0,
            enabled: !isSavingFile,
            child: Text(gatherDataText)
          ),
          PopupMenuItem<int>(
            enabled: hasSavedFile,
            value: 1,
            child: const Text("Abrir planilha de temperatura")
          )
        ];
      },
      onSelected: (value)
      {
        switch(value)
        {
          case 0:
            startStopGatheringData();
            break;

          case 1:
            openSpreadSheet();
            break;

          default: break;
        }
      },
    );
  }



  Widget gatherData()
  {

    final Widget infoWidget = (isGatheringData)? 
      const Text("Obter dados de temperatura") : 
      Row(
        children: const [
          CircularProgressIndicator(),
          Text("Obtendo dados")
        ],
      );

    final String buttonText = (isGatheringData)? "Começar" : "Parar";

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        infoWidget,
        ElevatedButton(
          onPressed: startStopGatheringData,
          child: Text(buttonText),
        )
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Termômetro"),
        actions: [
          gatherDataOptions()
        ],
      ),
      bottomNavigationBar: BluetoothStatusBar(bluetoothConnectionHandler: bluetoothConnectionHandler),
      body: Center(
        child: temperatureGauge()
      )
    );
  }

}

