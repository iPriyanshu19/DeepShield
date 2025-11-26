// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:deepshield/screens/login_screen.dart';
import 'package:deepshield/screens/result_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _video;
  bool _isProcessing = false;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _video = File(pickedFile.path);
      });
    }
  }

  Future<void> _uploadVideo() async {
    if (_video == null) return;
    setState(() {
      _isProcessing = true;
    });
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(dotenv.env['API_URL'] ?? ''),
      );
      request.files.add(
        await http.MultipartFile.fromPath('video', _video!.path),
      );
      var response = await request.send();
      if (response.statusCode == 200) {
        var respStr = await response.stream.bytesToString();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ResultScreen(resultJson: respStr),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<Uint8List?> generateThumbnail(String videoPath) async {
    try {
      final Uint8List? bytes = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 500,
        maxHeight: 500,
        quality: 75,
      );
      return bytes;
    } catch (e) {
      throw Exception('Thumbnail error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Center(
                    child: Column(
                      children: [
                        Image.asset('assets/logo.png', height: 100),
                        const SizedBox(height: 12),
                        const Text(
                          'DeepShield',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_video != null)
                          FutureBuilder<Uint8List?>(
                            future: generateThumbnail(_video!.path),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return CircularProgressIndicator();
                              } else if (snapshot.hasError) {
                                return Text(
                                  'Error: ${snapshot.error}',
                                  style: TextStyle(color: Colors.white),
                                );
                              } else if (!snapshot.hasData) {
                                return Text(
                                  'No thumbnail generated',
                                  style: TextStyle(color: Colors.white),
                                );
                              } else {
                                return Image.memory(
                                  snapshot.data!,
                                  height: 200,
                                );
                              }
                            },
                          ),
                        SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _pickVideo,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 8,
                            ),
                          ),
                          child: const Text(
                            'Pick Video',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (_isProcessing)
                          Padding(
                            padding: const EdgeInsets.only(top: 24.0),
                            child: Text(
                              'Processing... Please wait',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 15,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _uploadVideo,
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color>((
                        Set<WidgetState> states,
                      ) {
                        if (states.contains(WidgetState.disabled)) {
                          return Colors.red.withValues(alpha: 0.6);
                        }
                        return Colors.red;
                      }),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    child: const Text(
                      'Detect Deepfake',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.black,
        child: Row(
          children: [
            Spacer(),
            IconButton(
              icon: Icon(Icons.logout, color: Colors.white, size: 28),
              tooltip: 'Sign Out',
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Signed out successfully')),
                );
                await Future.delayed(const Duration(seconds: 1));
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
