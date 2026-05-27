
import 'package:flutter/material.dart';
import 'package:scenickazatva_app/models/Event.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/providers/EventsProvider.dart';
import 'package:intl/intl.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

class EventEditPage extends StatefulWidget {
  //const EventEditPage({super.key, @required this.event});
  final eventId;
  const EventEditPage({Key? key, required this.eventId}) : super(key: key);

  @override
  EventEditPageState createState() => EventEditPageState();
}

class EventEditPageState extends State<EventEditPage> {
  final _formKey = GlobalKey<FormState>();
  var startDate;
  var endDate;
  late Event event = Event();
  Event edited = Event();
  QuillController _controller = QuillController.basic();

  @override
  void initState() {
    super.initState();

    // Start listening to changes.
  }

  Widget buildForm(BuildContext context) {
    EventsProvider eventsProvider =
        Provider.of<EventsProvider>(context, listen: false);
    List<Event> events = eventsProvider.events;
    if (events.where((element) => (element.id == widget.eventId)).length > 0) {
      event =
          events.where((element) => (element.id == widget.eventId)).toList()[0];
    }

    if (event.id == "") {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        context.go('/events');
      });
    }

    print(event.description);
    var delta = HtmlToDelta().convert(event.description, transformTableAsEmbed: false);
    _controller.document = Document.fromDelta(delta);

    edited = event;

    startDate = event.startTime;
    endDate = event.endTime;
    //Event edited = Event();

    Future<void> displayTimeDialog(BuildContext context, iniTime, field) async {
      final TimeOfDay? time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(iniTime),
          builder: (ctx, child) => PointerInterceptor(child: child!));
      if (time != null) {
        setState(() {
          if (field == "start") {
            startDate = DateTime(iniTime.year, iniTime.month, iniTime.day,
                time.hour, time.minute);
          } else if (field == "end") {
            endDate = DateTime(iniTime.year, iniTime.month, iniTime.day,
                time.hour, time.minute);
          }
        });
      }
    }

    Future<DateTime?> displayDateDialog(
        BuildContext context, iniDate, field) async {
      final DateTime? date = await showDatePicker(
          context: context,
          initialDate: iniDate,
          firstDate: DateTime(1970),
          lastDate: DateTime(2201),
          builder: (ctx, child) => PointerInterceptor(child: child!));

      if (date != null) {
        setState(() {
          if (field == "start") {
            startDate = DateTime(
                date.year, date.month, date.day, iniDate.hour, iniDate.minute);
          } else if (field == "end") {
            endDate = DateTime(
                date.year, date.month, date.day, iniDate.hour, iniDate.minute);
          }
        });
      }
      return date;
    }

    // Build a Form widget using the _formKey created above.
    return Container(
      padding: EdgeInsets.all(45),
      child: Form(
        key: _formKey,
        child: Column(
          children: <Widget>[
            Row(children: <Widget>[
              Expanded(
                child: TextFormField(
                  onSaved: (value) {
                    edited.title = value!;
                  },
                  initialValue: event.title,
                  decoration: InputDecoration(
                    border: UnderlineInputBorder(),
                    labelText: "Názov podujatia",
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter some text';
                    }
                    return null;
                  },
                ),
              ),
              Flexible(
                child: TextFormField(
                  onSaved: (value) {
                    edited.id = value!;
                  },
                  initialValue: event.id,
                  readOnly: true,
                  decoration: InputDecoration(
                    border: UnderlineInputBorder(),
                    labelText: "ID",
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter some text';
                    }
                    return null;
                  },
                ),
              ),
            ]),

            TextFormField(
              onSaved: (value) {
                edited.artist = value!;
              },
              initialValue: event.artist,
              decoration: InputDecoration(
                border: UnderlineInputBorder(),
                labelText: "Umelec",
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter some text';
                }
                return null;
              },
            ),
            TextFormField(
              onSaved: (value) {
                edited.location = value!;
              },
              initialValue: event
                  .location, // TODO Prerobiť location na DropdownButtonFormField() - na to ale treba zmeniť aj spôsob priraďovania miest podujatí a prehodiť to na firebase (teraz je to hardcoded)
              decoration: InputDecoration(
                border: UnderlineInputBorder(),
                labelText: "Miesto podujatia",
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter some text';
                }
                return null;
              },
            ),
            Row(
              children: <Widget>[
                Flexible(
                  child: TextFormField(
                    onSaved: (value) {
                      edited.startTime = startDate!;
                    },
                    controller: TextEditingController(
                        text:
                            "${DateFormat("E, d.M. yyyy", "sk_SK").format(startDate ?? DateTime.now())}"),
                    readOnly: true,
                    decoration: InputDecoration(
                      border: UnderlineInputBorder(),
                      labelText: "Dátum začiatku",
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Prosím, vyklikajte si dátum.';
                      }
                      return null;
                    },
                    onTap: () {
                      displayDateDialog(context, startDate ?? DateTime.now(), "start");
                    },
                  ),
                ),
                Flexible(
                  child: TextFormField(
                    controller: TextEditingController(
                        text:
                            "${DateFormat("HH:mm", "sk_SK").format(startDate ?? DateTime.now())}"),
                    readOnly: true,
                    decoration: InputDecoration(
                      border: UnderlineInputBorder(),
                      labelText: "Čas začiatku",
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Prosím, vyklikajte si čas.';
                      }
                      return null;
                    },
                    onTap: () {
                      displayTimeDialog(context, startDate ?? DateTime.now(), "start");
                    },
                  ),
                ),
              ],
            ),
            Row(
              children: <Widget>[
                Flexible(
                  child: TextFormField(
                    onSaved: (value) {
                      edited.endTime = endDate!;
                    },
                    controller: TextEditingController(
                        text:
                            "${DateFormat("E, d.M. yyyy", "sk_SK").format(endDate ?? DateTime.now())}"),
                    readOnly: true,
                    decoration: InputDecoration(
                      border: UnderlineInputBorder(),
                      labelText: "Dátum konca",
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Prosím, vyklikajte si dátum.';
                      }
                      return null;
                    },
                    onTap: () {
                      displayDateDialog(context, endDate ?? DateTime.now(), "end");
                    },
                  ),
                ),
                Flexible(
                  child: TextFormField(
                    controller: TextEditingController(
                        text:
                            "${DateFormat("HH:mm", "sk_SK").format(endDate ?? DateTime.now())}"),
                    readOnly: true,
                    decoration: InputDecoration(
                      border: UnderlineInputBorder(),
                      labelText: "Čas začiatku",
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Prosím, vyklikajte si čas.';
                      }
                      return null;
                    },
                    onTap: () {
                      displayTimeDialog(context, endDate ?? DateTime.now(), "end");
                    },
                  ),
                ),
              ],
            ),

            QuillSimpleToolbar(
              controller: _controller,
              config: const QuillSimpleToolbarConfig(),
            ),
            SizedBox(
              height: 300.0,
              child: QuillEditor.basic(
                controller: _controller,
                config: const QuillEditorConfig(),
              ),
            )
            // Add TextFormFields and ElevatedButton here.
          ],
        ),
      ),
    );
  }

  Widget build(BuildContext context) {
    void _saveForm() async {
      var delta = _controller.document.toDelta().toJson();
      final converter = QuillDeltaToHtmlConverter(
        List.castFrom(delta),
        ConverterOptions.forEmail(),
      );

      String desc = converter.convert();
      edited.description = desc;
      _formKey.currentState!.save();

      EventsProvider eventsProvider =
          Provider.of<EventsProvider>(context, listen: false);
      eventsProvider.updateEvent(edited);
    }

    //Location
    //final location = widget.event.location != null ? "\n${widget.event.location}" : '';
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        foregroundColor: Colors.redAccent,
        leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
            ),
            onPressed: () {
              context.go("/events/" + widget.eventId);
            }),
        title: const Text(
          "Upraviť podujatie",
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(
              Icons.delete,
              color: Colors.redAccent,
            ),
            onPressed: () {
              // TODO Delete event
              context.go("/events/" + widget.eventId);
            },
          ),
          IconButton(
            icon: Icon(
              Icons.exit_to_app,
              color: Colors.white,
            ),
            onPressed: () {
              context.go("/events/" + widget.eventId);
              /* Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EventDetailPage(
                    eventId: event.id,
                  ),
                ),
              );*/
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          children: [
            Card(child: buildForm(context)),
          ],
        ),
      ),
      floatingActionButton: PointerInterceptor(
        child: FloatingActionButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _saveForm();
              // If the form is valid, display a snackbar. In the real world,
              // you'd often call a server or save the information in a database.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Processing Data')),
              );
            }
            context.go("/events/" + widget.eventId);
          },
          child: const Icon(Icons.save),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
