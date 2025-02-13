import 'package:flutter/material.dart';
import 'package:scenickazatva_app/providers/counter_bloc.dart';
import 'package:provider/provider.dart';

class DecrementButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final CounterBloc counterBloc = Provider.of<CounterBloc>(context);
    return new TextButton.icon(
        icon: Icon(Icons.remove),
        label: Text("Remove"),
        onPressed: () => counterBloc.decrement());
  }
}
