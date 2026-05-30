import 'package:flutter/material.dart';
import 'package:scenickazatva_app/models/Event.dart';
import 'package:scenickazatva_app/models/Location.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/providers/EventsProvider.dart';
import 'package:scenickazatva_app/providers/UserProvider.dart';
import 'package:intl/intl.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';
import 'package:firebase_cached_image/firebase_cached_image.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:scenickazatva_app/utils/TimeUtils.dart';

/// Page for editing existing events or creating new ones.
/// Restricted to users with admin or editor roles.
class EventEditPage extends StatefulWidget {
  final String eventId;
  const EventEditPage({Key? key, required this.eventId}) : super(key: key);

  @override
  EventEditPageState createState() => EventEditPageState();
}

class EventEditPageState extends State<EventEditPage> {
  final _formKey = GlobalKey<FormState>();
  DateTime? startDate;
  DateTime? endDate;
  late Event edited;
  late QuillController _controller;
  bool _isInitialized = false;
  bool _isNew = false;

  @override
  void initState() {
    super.initState();
    _controller = QuillController.basic();
    _isNew = widget.eventId == "new";
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      // 1. Check permissions first
      final userProvider = Provider.of<UserProvider>(context);
      if (!userProvider.canEdit) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go('/events');
          }
        });
        return;
      }

      // 2. Initialize data
      final location = TimeUtils.festivalLocation;
      
      if (_isNew) {
        final nowFestival = tz.TZDateTime.now(location);
        edited = Event(
          id: "",
          title: "",
          startTime: nowFestival,
          endTime: nowFestival.add(const Duration(hours: 1)),
        );
        startDate = edited.startTime;
        endDate = edited.endTime;
        _isInitialized = true;
      } else {
        final eventsProvider = Provider.of<EventsProvider>(context);
        final foundEvent = eventsProvider.events.cast<Event?>().firstWhere(
              (e) => e?.id == widget.eventId,
              orElse: () => null,
            );

        if (foundEvent != null) {
          // Clone the event
          edited = foundEvent.copy();
          // Convert the UTC stored in the model to Prague time for the UI
          startDate = TimeUtils.fromUtc(edited.startTime!);
          endDate = TimeUtils.fromUtc(edited.endTime!);

          // Convert HTML description to Quill Delta
          if (edited.description.isNotEmpty) {
            try {
              var delta = HtmlToDelta().convert(edited.description, transformTableAsEmbed: false);
              _controller.document = Document.fromDelta(delta);
            } catch (e) {
              debugPrint("Error converting HTML to Delta: $e");
            }
          }
          _isInitialized = true;
        } else {
          // If event not found and not loading, redirect back
          if (!eventsProvider.loading) {
            SchedulerBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                context.go('/events');
              }
            });
          }
        }
      }
    }
  }

  /// Displays time picker and updates local state
  Future<void> _displayTimeDialog(BuildContext context, DateTime iniTime, String field) async {
    final location = TimeUtils.festivalLocation;
    final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(iniTime),
        builder: (ctx, child) => PointerInterceptor(child: child!));
    if (time != null) {
      setState(() {
        if (field == "start") {
          startDate = tz.TZDateTime(location, iniTime.year, iniTime.month, iniTime.day,
              time.hour, time.minute);
        } else if (field == "end") {
          endDate = tz.TZDateTime(location, iniTime.year, iniTime.month, iniTime.day,
              time.hour, time.minute);
        }
      });
    }
  }

  /// Displays date picker and updates local state
  Future<void> _displayDateDialog(BuildContext context, DateTime iniDate, String field) async {
    final location = TimeUtils.festivalLocation;
    final DateTime? date = await showDatePicker(
        context: context,
        initialDate: iniDate,
        firstDate: DateTime(1970),
        lastDate: DateTime(2201),
        builder: (ctx, child) => PointerInterceptor(child: child!));

    if (date != null) {
      setState(() {
        if (field == "start") {
          startDate = tz.TZDateTime(
              location, date.year, date.month, date.day, iniDate.hour, iniDate.minute);
        } else if (field == "end") {
          endDate = tz.TZDateTime(
              location, date.year, date.month, date.day, iniDate.hour, iniDate.minute);
        }
      });
    }
  }

  /// Validates the form, converts Delta to HTML and saves to Firebase via Provider
  void _saveForm() async {
    if (_formKey.currentState!.validate()) {
      // 1. Get HTML from Quill
      var delta = _controller.document.toDelta().toJson();
      final converter = QuillDeltaToHtmlConverter(
        List.castFrom(delta),
        ConverterOptions.forEmail(),
      );

      String desc = converter.convert();
      
      // 2. Save form fields
      _formKey.currentState!.save();
      edited.description = desc;
      edited.startTime = startDate;
      edited.endTime = endDate;

      final provider = Provider.of<EventsProvider>(context, listen: false);
      if (_isNew) {
        final newId = await provider.createEvent(edited);
        if (newId != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vytvorené')),
          );
          context.go("/events/$newId");
        }
      } else {
        provider.updateEvent(edited);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uložené')),
        );
        context.go("/events/${widget.eventId}");
      }
    }
  }

  /// Shows confirmation dialog before deleting an event
  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => PointerInterceptor(
        child: AlertDialog(
          title: const Text("Zmazať podujatie?"),
          content: const Text("Naozaj chcete zmazať toto podujatie? Táto akcia je nevratná."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Zrušiť"),
            ),
            TextButton(
              onPressed: () {
                Provider.of<EventsProvider>(context, listen: false).deleteEvent(widget.eventId);
                Navigator.of(ctx).pop();
                context.go("/events");
              },
              child: const Text("Zmazať", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final EventsProvider eventsProvider = Provider.of<EventsProvider>(context);
    final List<Location> venues = eventsProvider.venues;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        foregroundColor: Colors.redAccent,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => _isNew ? context.go("/events") : context.go("/events/${widget.eventId}")),
        title: Text(_isNew ? "Nové podujatie" : "Upraviť podujatie"),
        actions: <Widget>[
          if (!_isNew)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: _confirmDelete,
            ),
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: () => _isNew ? context.go("/events") : context.go("/events/${widget.eventId}"),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextFormField(
                              initialValue: edited.title,
                              onSaved: (value) => edited.title = value!,
                              decoration: const InputDecoration(
                                labelText: "Názov podujatia",
                              ),
                              validator: (value) => (value == null || value.isEmpty) ? 'Prosím zadajte názov' : null,
                            ),
                          ),
                          if (!_isNew) ...[
                            const SizedBox(width: 16),
                            SizedBox(
                              width: 100,
                              child: TextFormField(
                                initialValue: edited.id,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: "ID",
                                ),
                              ),
                            ),
                          ]
                        ],
                      ),
                      TextFormField(
                        initialValue: edited.artist,
                        onSaved: (value) => edited.artist = value!,
                        decoration: const InputDecoration(
                          labelText: "Umelec",
                        ),
                        validator: (value) => (value == null || value.isEmpty) ? 'Prosím zadajte umelca' : null,
                      ),
                      const SizedBox(height: 16),
                      // Image URL and Preview
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: edited.image,
                              decoration: const InputDecoration(
                                labelText: "URL obrázka (gs://...)",
                              ),
                              onChanged: (val) => setState(() => edited.image = val.trim()),
                              onSaved: (value) => edited.image = value?.trim() ?? "",
                            ),
                          ),
                          const SizedBox(width: 16),
                          if (edited.image.isNotEmpty)
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image(
                                  image: FirebaseImageProvider(FirebaseUrl(edited.image)),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.error_outline),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Location Dropdown (Loaded from Provider)
                      DropdownButtonFormField<String>(
                        initialValue: venues.any((v) => v.id == edited.location) ? edited.location : null,
                        items: venues.map((v) => DropdownMenuItem<String>(
                          value: v.id,
                          child: Text(v.displayName),
                        )).toList(),
                        onChanged: (val) => setState(() => edited.location = val ?? ""),
                        decoration: const InputDecoration(
                          labelText: "Miesto podujatia",
                        ),
                        validator: (value) => (value == null || value.isEmpty) ? 'Prosím vyberte miesto' : null,
                      ),
                      const SizedBox(height: 16),
                      // Start Date & Time
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextFormField(
                              controller: TextEditingController(
                                  text: DateFormat("E, d.M. yyyy", "sk_SK").format(startDate ?? DateTime.now())),
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: "Dátum začiatku",
                              ),
                              onTap: () => _displayDateDialog(context, startDate ?? DateTime.now(), "start"),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: TextEditingController(
                                  text: DateFormat("HH:mm", "sk_SK").format(startDate ?? DateTime.now())),
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: "Čas začiatku",
                              ),
                              onTap: () => _displayTimeDialog(context, startDate ?? DateTime.now(), "start"),
                            ),
                          ),
                        ],
                      ),
                      // End Date & Time
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextFormField(
                              controller: TextEditingController(
                                  text: DateFormat("E, d.M. yyyy", "sk_SK").format(endDate ?? DateTime.now())),
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: "Dátum konca",
                              ),
                              onTap: () => _displayDateDialog(context, endDate ?? DateTime.now(), "end"),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: TextEditingController(
                                  text: DateFormat("HH:mm", "sk_SK").format(endDate ?? DateTime.now())),
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: "Čas konca",
                              ),
                              onTap: () => _displayTimeDialog(context, endDate ?? DateTime.now(), "end"),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Rich Text Editor (Quill)
                      QuillSimpleToolbar(
                        controller: _controller,
                        config: const QuillSimpleToolbarConfig(),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 400.0,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: QuillEditor.basic(
                          controller: _controller,
                          config: QuillEditorConfig(
                            customStyles: DefaultStyles.getInstance(context).merge(
                              DefaultStyles(
                                h1: DefaultTextBlockStyle(
                                  TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 32, fontWeight: FontWeight.bold),
                                  const HorizontalSpacing(0, 0),
                                  const VerticalSpacing(16, 0),
                                  const VerticalSpacing(0, 0),
                                  null,
                                ),
                                h2: DefaultTextBlockStyle(
                                  TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.bold),
                                  const HorizontalSpacing(0, 0),
                                  const VerticalSpacing(8, 0),
                                  const VerticalSpacing(0, 0),
                                  null,
                                ),
                                h3: DefaultTextBlockStyle(
                                  TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold),
                                  const HorizontalSpacing(0, 0),
                                  const VerticalSpacing(8, 0),
                                  const VerticalSpacing(0, 0),
                                  null,
                                ),
                                paragraph: DefaultTextBlockStyle(
                                  TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                  const HorizontalSpacing(0, 0),
                                  const VerticalSpacing(0, 0),
                                  const VerticalSpacing(0, 0),
                                  null,
                                ),
                                lists: DefaultListBlockStyle(
                                  TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                  const HorizontalSpacing(0, 0),
                                  const VerticalSpacing(0, 0),
                                  const VerticalSpacing(0, 0),
                                  null,
                                  null,
                                ),
                                link: const TextStyle(
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: PointerInterceptor(
        child: FloatingActionButton(
          onPressed: _saveForm,
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
