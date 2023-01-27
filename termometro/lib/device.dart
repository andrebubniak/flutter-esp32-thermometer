class Device
{
  final String name;
  final String serviceUUID;
  final String receiveDataCharacteristicUUID;

  Device({
    required this.name,
    required this.serviceUUID,
    required this.receiveDataCharacteristicUUID,
  });
}