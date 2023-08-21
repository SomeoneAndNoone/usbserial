import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:usb_serial/transaction.dart';
import 'package:usb_serial/usb_serial.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  UsbPort? _port;
  String _status = "Idle";
  List<Widget> _serialData = [];

  StreamSubscription<String>? _subscription;
  Transaction<String>? _transaction;
  UsbDeviceDecorator? _device;

  TextEditingController _textController = TextEditingController();
  List<UsbDeviceDecorator> devices = [];

  Future<bool> _connectTo(UsbDeviceDecorator? device) async {
    print('Setting DTR: ${device?.dtr}');
    _serialData.clear();

    if (_subscription != null) {
      _subscription!.cancel();
      _subscription = null;
    }

    if (_transaction != null) {
      _transaction!.dispose();
      _transaction = null;
    }

    if (_port != null) {
      _port!.close();
      _port = null;
    }

    if (device == null) {
      _device = null;
      setState(() {
        _status = "Disconnected";
      });
      return true;
    }

    _port = await device.device.create();
    if (await (_port!.open()) != true) {
      setState(() {
        _status = "Failed to open port";
      });
      return false;
    }
    _device = device;

    await _port!.setDTR(device.dtr);
    await _port!.setRTS(device.rts);
    await _port!
        .setPortParameters(115200, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);

    _transaction = Transaction.stringTerminated(
        _port!.inputStream as Stream<Uint8List>, Uint8List.fromList([13, 10]));

    _subscription = _transaction!.stream.listen((String line) {
      setState(() {
        _serialData.add(Text(line));
        if (_serialData.length > 20) {
          _serialData.removeAt(0);
        }
      });
    });

    setState(() {
      _status = "Connected";
    });
    return true;
  }

  void _getPorts() async {
    List<UsbDevice> usbDevices = await UsbSerial.listDevices();
    usbDevices.forEach((usbDevice) {
      devices.add(UsbDeviceDecorator(usbDevice));
    });

    // todo delete
    devices.add(UsbDeviceDecorator(
        UsbDevice('Soter', 234, 234324, 'Soter Name', 'Man name', 2342, 'My Serial', 2)));

    if (!devices.contains(_device)) {
      _connectTo(null);
    }

    print(devices);

    setState(() {});
  }

  @override
  void initState() {
    super.initState();

    UsbSerial.usbEventStream!.listen((UsbEvent event) {
      _getPorts();
    });

    _getPorts();
  }

  @override
  void dispose() {
    super.dispose();
    _connectTo(null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('USB Serial Plugin example app'),
        ),
        body: Center(
            child: Column(children: <Widget>[
          Text(devices.length > 0 ? "Available Serial Ports" : "No serial devices available",
              style: Theme.of(context).textTheme.bodyLarge),
          ...devices
              .map((mDevice) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                          leading: Icon(Icons.usb),
                          title: Text(mDevice.device.productName!),
                          subtitle: Text(mDevice.device.manufacturerName!),
                          trailing: ElevatedButton(
                            child: Text(_device == mDevice ? "Disconnect" : "Connect"),
                            onPressed: () {
                              _connectTo(_device == mDevice ? null : mDevice).then((res) {
                                _getPorts();
                              });
                            },
                          )),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: mDevice.dtr,
                                onChanged: (bool? value) {
                                  if (value != null) mDevice.dtr = value;
                                  setState(() {});
                                },
                              ),
                              Text('DTR'),
                            ],
                          ),
                          SizedBox(width: 32),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: mDevice.rts,
                                onChanged: (bool? value) {
                                  if (value != null) mDevice.rts = value;
                                  setState(() {});
                                },
                              ),
                              Text('RTS'),
                            ],
                          )
                        ],
                      ),
                    ],
                  ))
              .toList(),
          Text('Status: $_status\n'),
          Text('info: ${_port.toString()}\n'),
          ListTile(
            title: TextField(
              controller: _textController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Text To Send',
              ),
            ),
            trailing: ElevatedButton(
              child: Text("Send"),
              onPressed: _port == null
                  ? null
                  : () async {
                      if (_port == null) {
                        return;
                      }
                      String data = _textController.text + "\r\n";
                      await _port!.write(Uint8List.fromList(data.codeUnits));
                      _textController.text = "";
                    },
            ),
          ),
          Text("Result Data", style: Theme.of(context).textTheme.bodyLarge),
          ..._serialData,
        ])),
      ),
    );
  }
}

class UsbDeviceDecorator {
  final UsbDevice device;
  bool dtr = true;
  bool rts = true;

  UsbDeviceDecorator(this.device);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UsbDeviceDecorator && runtimeType == other.runtimeType && device == other.device;

  @override
  int get hashCode => device.hashCode;
}
