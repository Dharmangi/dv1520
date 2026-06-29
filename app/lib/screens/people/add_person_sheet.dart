import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/person.dart';
import '../../providers/people_provider.dart';

Future<void> showAddPersonSheet(BuildContext context, {Person? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => AddPersonSheet(existing: existing),
  );
}

class AddPersonSheet extends ConsumerStatefulWidget {
  const AddPersonSheet({super.key, this.existing});

  final Person? existing;

  @override
  ConsumerState<AddPersonSheet> createState() => _AddPersonSheetState();
}

class _AddPersonSheetState extends ConsumerState<AddPersonSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _tokenNoController;
  late final TextEditingController _placeController;
  late bool _isOwner;
  String? _selectedOwnerId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _mobileController = TextEditingController(text: widget.existing?.mobile ?? '');
    _tokenNoController = TextEditingController(text: widget.existing?.tokenNo ?? '');
    _placeController = TextEditingController(text: widget.existing?.place ?? '');
    _isOwner = widget.existing?.isOwner ?? false;
    _selectedOwnerId = widget.existing?.ownerId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _tokenNoController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final person = Person(
        id: '',
        name: _nameController.text.trim(),
        mobile: _mobileController.text.trim().isEmpty ? null : _mobileController.text.trim(),
        isOwner: _isOwner,
        ownerId: _selectedOwnerId,
        tokenNo: _tokenNoController.text.trim().isEmpty ? null : _tokenNoController.text.trim(),
        place: _placeController.text.trim().isEmpty ? null : _placeController.text.trim(),
      );
      if (widget.existing != null) {
        await ref.read(peopleProvider.notifier).updatePerson(widget.existing!.id, person);
      } else {
        await ref.read(peopleProvider.notifier).addPerson(person);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final peopleAsync = ref.watch(peopleProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.existing != null ? 'Edit Person' : 'Add Person', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Mobile (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _placeController,
                decoration: const InputDecoration(labelText: 'Place (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tokenNoController,
                decoration: const InputDecoration(labelText: 'Token No (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              peopleAsync.when(
                data: (people) {
                  final owners = people.where((p) => p.isOwner && p.id != widget.existing?.id).toList();
                  return DropdownButtonFormField<String?>(
                    initialValue: _selectedOwnerId,
                    decoration: const InputDecoration(labelText: 'Owner (optional)', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('None')),
                      ...owners.map((o) => DropdownMenuItem<String?>(value: o.id, child: Text(o.name))),
                    ],
                    onChanged: (v) => setState(() => _selectedOwnerId = v),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Failed to load owners: $e'),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Acts as an Owner'),
                subtitle: const Text('Other customers can be grouped under this person'),
                value: _isOwner,
                onChanged: (v) => setState(() => _isOwner = v ?? false),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
