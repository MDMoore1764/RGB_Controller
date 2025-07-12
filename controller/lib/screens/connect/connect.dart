import 'package:controller/screens/connect/device_card.dart';
import 'package:flutter/material.dart';

class Connect extends StatefulWidget {
  final List<String> devices;

  late double listHeight;

  Connect({super.key, required this.devices}) {
    this.listHeight = 150;
  }

  @override
  State<Connect> createState() => _ConnectState(devices: devices);
}

class _ConnectState extends State<Connect> {
  late double _timeDelay;
  late int _offsetEvery;
  final List<String> _devices;

  _ConnectState({required List<String> devices}) : _devices = devices {
    _timeDelay = 2.5;
    _offsetEvery = 1;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const Text(
              "Available Devices",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Container(
              margin: EdgeInsets.only(left: 0, right: 0, top: 10, bottom: 40),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withAlpha(80),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(5),
              ),
              height: this.widget.listHeight,
              child: ListView.builder(
                physics: BouncingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(8),
                itemBuilder: (context, index) {
                  final device = this.widget.devices[index];

                  return DeviceCard(name: device, selected: false);
                },
                itemCount: this.widget.devices.length,
              ),
            ),

            const Text(
              "Connected Devices",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Container(
              margin: EdgeInsets.only(left: 0, right: 0, top: 10, bottom: 10),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withAlpha(80),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(5),
              ),
              height: this.widget.listHeight,
              child: ListView.builder(
                physics: BouncingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(8),
                itemBuilder: (context, index) {
                  final device = this.widget.devices[index];

                  return DeviceCard(name: device, selected: true);
                },
                itemCount: this.widget.devices.length,
              ),
            ),

            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text("Offset: ${_timeDelay.toStringAsFixed(1)} s"),
                          SizedBox(
                            height: 50,
                            child: RotatedBox(
                              quarterTurns: 0,
                              child: Slider(
                                value: _timeDelay,
                                min: 0.0,
                                max: 5.0,
                                divisions: (5.0 / 0.1).toInt(),
                                label: "${_timeDelay.toStringAsFixed(1)} s",

                                onChanged: (double newValue) {
                                  setState(() {
                                    _timeDelay = newValue;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            "Every: ${_offsetEvery.toStringAsFixed(0)} devices",
                          ),
                          RotatedBox(
                            quarterTurns: 0,
                            child: Slider(
                              value: _offsetEvery.toDouble(),

                              min: 1,
                              max: this._devices.length.toDouble(),
                              divisions: this._devices.length,
                              label:
                                  "${_offsetEvery.toStringAsFixed(0)} devices",

                              onChanged: (double newValue) {
                                setState(() {
                                  _offsetEvery = newValue.toInt();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Column(
            //   children: [
            //     Text("Every: $_offsetEvery devices"),
            //     Row(
            //       mainAxisAlignment: MainAxisAlignment.center,
            //       crossAxisAlignment: CrossAxisAlignment.center,
            //       children: [
            //         Expanded(
            //           child: SizedBox(
            //             height: 50,
            //             child: RotatedBox(
            //               quarterTurns: 0,
            //               child: Slider(
            //                 value: _offsetEvery.toDouble(),

            //                 min: 1,
            //                 max: this._devices.length.toDouble(),
            //                 divisions: 10,
            //                 label: "${_timeDelay.toStringAsFixed(0)} devices",

            //                 onChanged: (double newValue) {
            //                   setState(() {
            //                     _timeDelay = newValue;
            //                   });
            //                 },
            //               ),
            //             ),
            //           ),
            //         ),
            //       ],
            //     ),
            //   ],
            // ),
          ],
        ),

        Row(
          children: [
            Expanded(
              child: Container(
                // margin: EdgeInsets.only(bottom: 30),
                child: FloatingActionButton.extended(
                  onPressed: () {},
                  icon: Icon(Icons.add),
                  label: Text('Scan for Devices'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
