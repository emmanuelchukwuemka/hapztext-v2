import 'package:flutter/material.dart';

class Phones extends StatefulWidget {
  const Phones({Key? key}) : super(key: key);

  @override
  State<Phones> createState() => _PhonesState();
}

class _PhonesState extends State<Phones> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
      child: Text('No Calls Yet'),
    ));
  }
}
