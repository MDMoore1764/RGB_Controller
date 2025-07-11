import 'package:controller/screens/connect/device_card.dart';
import 'package:flutter/material.dart';

class Connect extends StatelessWidget {
  final List<String> devices;

  late double listHeight;

  Connect({super.key, required this.devices}) {
    this.listHeight = 150;
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
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
                color: Theme.of(context).colorScheme.outline,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(5),
            ),
            height: this.listHeight,
            child: ListView.builder(
              physics: BouncingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, index) {
                final device = this.devices[index];

                return DeviceCard(name: device, selected: false);
              },
              itemCount: this.devices.length,
            ),
          ),

          const Text(
            "Connected Devices",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Container(
            margin: EdgeInsets.only(left: 0, right: 0, top: 10, bottom: 40),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(5),
            ),
            height: this.listHeight,
            child: ListView.builder(
              physics: BouncingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, index) {
                final device = this.devices[index];

                return DeviceCard(name: device, selected: true);
              },
              itemCount: this.devices.length,
            ),
          ),
        ],
      ),
    );
  }
}
