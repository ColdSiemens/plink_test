import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:web_socket_channel/io.dart';
import 'dart:convert';

class QrCodeScreen extends StatefulWidget {
  const QrCodeScreen({super.key});

  @override
  State<QrCodeScreen> createState() => _QrCodeScreenState();
}

class _QrCodeScreenState extends State<QrCodeScreen>
    with SingleTickerProviderStateMixin {
  late String? slug;
  late String? userToken = null;
  late IOWebSocketChannel channel;
  bool isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    getSlug();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    );
    _animation =
        Tween<double>(begin: 1.0, end: 0.0).animate(_animationController)
          ..addListener(() {
            setState(() {});
          });
    _animationController.forward();
  }

  Future<void> getSlug() async {
    var response = await http
        .post(Uri.parse('https://desktop.plink.tech/qrcode_authentications/'));

    slug = jsonDecode(response.body)['slug'];
    _animationController.reset();
    _animationController.forward();

    channel = IOWebSocketChannel.connect(
        'wss://desktop.plink.tech/wss/qr_code_authentication/$slug/');

    channel.stream.listen((message) {
      setState(() {
        userToken = jsonDecode(message)['user_token'];
        if (userToken != null) {
          channel.sink.close();
          isLoading = false;
        }
      });
    });

    setState(() {
      isLoading = false;
    });

    Future.delayed(const Duration(seconds: 60), () {
      if (mounted) {
        setState(() {
          isLoading = true;
        });
        getSlug();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (userToken != null) {
      return const Scaffold(
        body: Center(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Successfully logged in!',
              style: TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Icon(Icons.check_circle_outlined, color: Colors.green, size: 60),
          ],
        )),
      );
    } else if (!isLoading && slug != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Scan QR code to login',
                  style: TextStyle(
                    fontSize: 20,
                  )),
              const SizedBox(height: 20),
              Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: QrImageView(
                      data: slug!,
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                  )),
              const SizedBox(height: 20),
              Container(
                height: 3,
                color: const Color.fromARGB(255, 10, 163, 218),
                width: 210 * _animation.value,
              ),
            ],
          ),
        ),
      );
    } else {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Loading...'),
              SizedBox(height: 20),
              CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    channel.sink.close();
    super.dispose();
  }
}
