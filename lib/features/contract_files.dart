import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/offline.dart';
import '../data/store.dart';
import '../util/dates.dart';
import '../util/open_bytes.dart';
import '../widgets/common.dart';

/// households/{id}/contractFiles: Dokumente und Fotos zu einem Vertrag,
/// je Datei ein Dokument. Wie die Pflanzenfotos liegen die Dateien direkt in
/// Firestore, deshalb darf eine Datei höchstens knapp 1 MB groß sein.
class ContractFile {
  const ContractFile({
    required this.id,
    required this.contractId,
    required this.name,
    required this.mime,
    required this.addedAt,
    required this.bytes,
  });

  final String id;
  final String contractId;
  final String name;
  final String mime;
  final DateTime addedAt;
  final Uint8List bytes;

  bool get isImage => mime.startsWith('image/');

  factory ContractFile.fromDoc(Doc d) => ContractFile(
    id: d.id,
    contractId: d.data['contractId'] as String? ?? '',
    name: d.data['name'] as String? ?? 'Datei',
    mime: d.data['mime'] as String? ?? 'application/octet-stream',
    addedAt: readDate(d.data['addedAt']) ?? today(),
    bytes: switch (d.data['data']) {
      Blob b => b.bytes,
      _ => Uint8List(0),
    },
  );
}

/// Ein Firestore-Dokument darf höchstens 1 MB groß sein.
const maxContractFileBytes = 900 * 1024;

typedef ContractKey = ({String householdId, String contractId});

/// Alle Dateien eines Vertrags, die älteste zuerst.
final contractFilesProvider =
    StreamProvider.family<List<ContractFile>, ContractKey>(
      (ref, key) => ref
          .watch(firestoreProvider)
          .collection('households/${key.householdId}/contractFiles')
          .where('contractId', isEqualTo: key.contractId)
          .snapshots()
          .map(
            (s) => [
              for (final d in s.docs) ContractFile.fromDoc(Doc(d.id, d.data())),
            ]..sort((a, b) => a.addedAt.compareTo(b.addedAt)),
          ),
    );

/// Eine ausgewählte Datei, bevor sie gespeichert wird.
typedef PickedFile = ({Uint8List bytes, String name, String mime});

/// Foto aufnehmen oder aus der Galerie wählen (verkleinert). Im Test ersetzbar.
final contractPhotoPickerProvider =
    Provider<Future<PickedFile?> Function(ImageSource)>(
      (ref) => (source) async {
        final image = await ImagePicker().pickImage(
          source: source,
          maxWidth: 2000,
          maxHeight: 2000,
          imageQuality: 70,
        );
        if (image == null) return null;
        final name = image.name.isEmpty ? 'Foto.jpg' : image.name;
        return (
          bytes: await image.readAsBytes(),
          name: name,
          mime: mimeForName(name, fallback: 'image/jpeg'),
        );
      },
    );

/// Beliebige Datei wählen, z. B. ein PDF. Im Test ersetzbar.
final contractDocumentPickerProvider = Provider<Future<PickedFile?> Function()>(
  (ref) => () async {
    final file = await FilePicker.pickFile(dialogTitle: 'Dokument wählen');
    if (file == null) return null;
    return (
      bytes: await file.readAsBytes(),
      name: file.name,
      mime: mimeForName(file.name),
    );
  },
);

String mimeForName(
  String name, {
  String fallback = 'application/octet-stream',
}) {
  final dot = name.lastIndexOf('.');
  final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  return switch (ext) {
    'pdf' => 'application/pdf',
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'heic' => 'image/heic',
    'txt' => 'text/plain',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    _ => fallback,
  };
}

Future<void> addContractFile(
  HouseholdStore store,
  String contractId,
  PickedFile file,
) => writeInBackground(
  store.col('contractFiles').doc().set({
    'contractId': contractId,
    'name': file.name,
    'mime': file.mime,
    'addedAt': writeDate(today()),
    'data': Blob(file.bytes),
    'createdBy': store.uid,
    'createdAt': FieldValue.serverTimestamp(),
  }),
);

/// Beim Löschen eines Vertrags verschwinden auch seine Dateien.
Future<void> deleteContractFiles(
  HouseholdStore store,
  String contractId,
) async {
  final docs = await store
      .col('contractFiles')
      .where('contractId', isEqualTo: contractId)
      .get();
  for (final d in docs.docs) {
    await store.delete('contractFiles', d.id);
  }
}

/// Fragt nach Kamera, Galerie oder (ohne [photosOnly]) Dokument und gibt die
/// gewählte Datei zurück. Zu große Dateien werden mit einem Hinweis abgelehnt.
Future<PickedFile?> pickAttachment(
  BuildContext context,
  WidgetRef ref, {
  bool photosOnly = false,
}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Foto aufnehmen'),
            onTap: () => Navigator.pop(context, 'camera'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Foto aus der Galerie'),
            onTap: () => Navigator.pop(context, 'gallery'),
          ),
          if (!photosOnly)
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Dokument (z. B. PDF)'),
              onTap: () => Navigator.pop(context, 'file'),
            ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return null;
  final PickedFile? file;
  try {
    file = switch (choice) {
      'camera' => await ref.read(contractPhotoPickerProvider)(
        ImageSource.camera,
      ),
      'gallery' => await ref.read(contractPhotoPickerProvider)(
        ImageSource.gallery,
      ),
      _ => await ref.read(contractDocumentPickerProvider)(),
    };
  } catch (e) {
    if (context.mounted) showError(context, 'Datei ging nicht: $e');
    return null;
  }
  if (file == null || !context.mounted) return null;
  if (file.bytes.length > maxContractFileBytes) {
    showError(
      context,
      'Die Datei ist zu groß (höchstens 900 KB). '
      'Ein Foto der Seite klappt meistens.',
    );
    return null;
  }
  return file;
}

/// Öffnet eine Datei: Fotos in der App, alles andere mit einer anderen App.
Future<void> openAttachment(
  BuildContext context, {
  required Uint8List bytes,
  required String name,
  required String mime,
}) async {
  if (mime.startsWith('image/')) {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FileImageViewer(bytes: bytes, name: name, mime: mime),
      ),
    );
    return;
  }
  try {
    await openBytes(bytes, name, mime);
  } catch (e) {
    if (context.mounted) showError(context, 'Öffnen ging nicht: $e');
  }
}

/// Abschnitt „Dokumente & Fotos“ im Vertrag.
class ContractFilesSection extends ConsumerWidget {
  const ContractFilesSection({
    super.key,
    required this.householdId,
    required this.contractId,
  });

  final String householdId;
  final String contractId;

  ContractKey get _key => (householdId: householdId, contractId: contractId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = ref.watch(contractFilesProvider(_key)).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dokumente & Fotos',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        if (files.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('z. B. Vertrag als PDF oder ein Foto der Rechnung'),
          ),
        for (final f in files)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: f.isImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.memory(
                      f.bytes,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.image_outlined),
                    ),
                  )
                : Icon(
                    f.mime == 'application/pdf'
                        ? Icons.picture_as_pdf_outlined
                        : Icons.insert_drive_file_outlined,
                  ),
            title: Text(f.name, overflow: TextOverflow.ellipsis),
            subtitle: Text(formatShortDate(f.addedAt)),
            trailing: IconButton(
              tooltip: 'Datei löschen',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (!await confirmDelete(context, f.name)) return;
                await ref
                    .read(storeProvider(householdId))
                    .delete('contractFiles', f.id);
              },
            ),
            onTap: () => _open(context, f),
          ),
        OutlinedButton.icon(
          icon: const Icon(Icons.attach_file),
          label: const Text('Datei hinzufügen'),
          onPressed: () => _add(context, ref),
        ),
      ],
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final file = await pickAttachment(context, ref);
    if (file == null || !context.mounted) return;
    await addContractFile(
      ref.read(storeProvider(householdId)),
      contractId,
      file,
    );
  }

  Future<void> _open(BuildContext context, ContractFile f) =>
      openAttachment(context, bytes: f.bytes, name: f.name, mime: f.mime);
}

/// Ein Foto bildschirmfüllend, mit Zoom und „Mit anderer App öffnen“.
class FileImageViewer extends StatelessWidget {
  const FileImageViewer({
    super.key,
    required this.bytes,
    required this.name,
    required this.mime,
  });

  final Uint8List bytes;
  final String name;
  final String mime;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      title: Text(name),
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          tooltip: 'Mit anderer App öffnen',
          icon: const Icon(Icons.open_in_new),
          onPressed: () async {
            try {
              await openBytes(bytes, name, mime);
            } catch (e) {
              if (context.mounted) showError(context, 'Öffnen ging nicht: $e');
            }
          },
        ),
      ],
    ),
    body: InteractiveViewer(
      maxScale: 5,
      child: Center(child: Image.memory(bytes)),
    ),
  );
}
