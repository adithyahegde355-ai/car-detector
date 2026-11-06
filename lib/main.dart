import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'car_service.dart';

void main() => runApp(const CarDetectorApp());

class CarDetectorApp extends StatelessWidget {
  const CarDetectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Car Detector',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF4F8CFF),
        scaffoldBackgroundColor: const Color(0xFF0E1116),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _picker = ImagePicker();
  final _service = CarService();

  File? _image;
  CarResult? _result;
  String? _error;
  bool _loading = false;

  Future<void> _pick(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1280, // keeps the upload small and fast
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() {
      _image = File(picked.path);
      _result = null;
      _error = null;
      _loading = true;
    });

    try {
      final result = await _service.identify(_image!);
      if (!mounted) return;
      setState(() => _result = result);
    } on CarDetectionException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Car Detector'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ImagePreview(image: _image),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        _loading ? null : () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _loading ? null : () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_loading) const _Loading(),
            if (_error != null) _ErrorCard(message: _error!),
            if (_result != null) _ResultCard(result: _result!),
          ],
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final File? image;
  const _ImagePreview({required this.image});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          color: const Color(0xFF181D26),
          child: image == null
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.directions_car, size: 64, color: Colors.white38),
                      SizedBox(height: 8),
                      Text('Take or choose a photo of a car',
                          style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                )
              : Image.file(image!, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Analysing the car...'),
          ],
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFF3A1B1B),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
}

class _ResultCard extends StatelessWidget {
  final CarResult result;
  const _ResultCard({required this.result});

  Color get _confidenceColor {
    switch (result.confidence.toLowerCase()) {
      case 'high':
        return Colors.greenAccent;
      case 'medium':
        return Colors.amberAccent;
      default:
        return Colors.orangeAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!result.isCar) {
      return const _ErrorCard(
          message: 'No car found in this image. Try a clearer photo.');
    }

    return Card(
      color: const Color(0xFF181D26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${result.make} ${result.model}',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Chip(
              avatar: Icon(Icons.verified, size: 18, color: _confidenceColor),
              label: Text('${result.confidence} confidence'),
            ),
            const Divider(height: 28),
            _Row(icon: Icons.factory, label: 'Make', value: result.make),
            _Row(
                icon: Icons.directions_car_filled,
                label: 'Model',
                value: result.model),
            _Row(icon: Icons.palette, label: 'Colour', value: result.colour),
            _Row(
                icon: Icons.airline_seat_recline_normal,
                label: 'Body type',
                value: result.bodyType),
            _Row(
                icon: Icons.calendar_today,
                label: 'Years',
                value: result.yearRange),
            if (result.notes.isNotEmpty) ...[
              const Divider(height: 28),
              Text(result.notes,
                  style: const TextStyle(color: Colors.white60, height: 1.4)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Row({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.white54),
            const SizedBox(width: 12),
            SizedBox(
              width: 84,
              child:
                  Text(label, style: const TextStyle(color: Colors.white54)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}
