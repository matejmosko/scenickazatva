import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/models/Location.dart';
import 'package:scenickazatva_app/providers/EventsProvider.dart';
import 'package:scenickazatva_app/providers/UserProvider.dart';
import 'package:scenickazatva_app/widgets/DeepLinkButton.dart';

class LocationEditPage extends StatefulWidget {
  final String? locationId;
  const LocationEditPage({super.key, this.locationId});

  @override
  State<LocationEditPage> createState() => _LocationEditPageState();
}

class _LocationEditPageState extends State<LocationEditPage> {
  final _formKey = GlobalKey<FormState>();
  late Location _edited;
  bool _isNew = false;
  bool _authorized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_authorized) {
      final canEdit = Provider.of<UserProvider>(context).canEdit;
      if (!canEdit) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/events');
        });
      }

      _isNew = widget.locationId == null || widget.locationId == 'new';

      if (!_isNew) {
        final eventsProvider = Provider.of<EventsProvider>(context, listen: false);
        final existing = eventsProvider.getLocationById(widget.locationId!);
        _edited = existing != null
            ? Location(
                id: existing.id,
                displayName: existing.displayName,
                description: existing.description,
                address: existing.address,
                city: existing.city,
                longitude: existing.longitude,
                latitude: existing.latitude,
                icon: existing.icon,
                color: existing.color,
                photo: existing.photo,
              )
            : Location();
      } else {
        _edited = Location();
      }
      _authorized = true;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final eventsProvider = Provider.of<EventsProvider>(context, listen: false);

    if (_isNew) {
      final id = await eventsProvider.createLocation(_edited);
      if (!mounted) return;
      if (id != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vytvorené')),
        );
        context.go('/locations/$id');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chyba pri vytváraní')),
        );
      }
    } else {
      await eventsProvider.updateLocation(_edited);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uložené')),
      );
      context.go('/locations/${_edited.id}');
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Zmazať lokalitu?"),
        content: Text("Naozaj chcete zmazať „${_edited.displayName}“?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Zrušiť"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await Provider.of<EventsProvider>(context, listen: false)
                  .deleteLocation(_edited.id);
              if (mounted) context.go('/events');
            },
            child: const Text("Zmazať", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () {
            if (_isNew) {
              context.go('/events');
            } else {
              context.go('/locations/${_edited.id}');
            }
          },
        ),
        title: Text(_isNew ? "Nová lokalita" : "Upraviť lokalitu"),
        actions: [
          const DeepLinkButton(),
          if (!_isNew)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: _confirmDelete,
            ),
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      initialValue: _edited.displayName,
                      onSaved: (value) => _edited.displayName = value ?? "",
                      decoration: const InputDecoration(
                        labelText: "Názov",
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          (value == null || value.isEmpty) ? 'Prosím zadajte názov' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: _edited.description,
                      onSaved: (value) => _edited.description = value ?? "",
                      maxLines: null,
                      decoration: const InputDecoration(
                        labelText: "Popis",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: _edited.address,
                      onSaved: (value) => _edited.address = value ?? "",
                      decoration: const InputDecoration(
                        labelText: "Adresa",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: _edited.city,
                      onSaved: (value) => _edited.city = value ?? "",
                      decoration: const InputDecoration(
                        labelText: "Mesto",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _edited.latitude,
                            onSaved: (value) => _edited.latitude = value ?? "",
                            decoration: const InputDecoration(
                              labelText: "Zemepisná šírka",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            initialValue: _edited.longitude,
                            onSaved: (value) => _edited.longitude = value ?? "",
                            decoration: const InputDecoration(
                              labelText: "Zemepisná dĺžka",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: _edited.icon,
                      onSaved: (value) => _edited.icon = value ?? "0xe88a",
                      decoration: const InputDecoration(
                        labelText: "Icon codepoint (hex)",
                        border: OutlineInputBorder(),
                        hintText: "0xe88a",
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: _edited.color,
                      onSaved: (value) => _edited.color = value ?? "333333FF",
                      decoration: const InputDecoration(
                        labelText: "Farba (hex ARGB)",
                        border: OutlineInputBorder(),
                        hintText: "333333FF",
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: _edited.photo,
                      onSaved: (value) => _edited.photo = value ?? "",
                      decoration: const InputDecoration(
                        labelText: "URL fotografie",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
