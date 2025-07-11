import 'package:flutter/material.dart';

class DeviceCard extends StatelessWidget {
  final String name;
  final bool selected;

  DeviceCard({super.key, required this.name, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 0, horizontal: 5),
      child: SizedBox(
        width: 145,
        child: Card(
          surfaceTintColor: this.selected
              ? Theme.of(context).focusColor
              : Theme.of(context).cardColor,
          elevation: 5,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    this.name,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    "5 db",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
