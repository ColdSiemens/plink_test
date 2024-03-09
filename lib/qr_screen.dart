import 'dart:async';
import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:web_socket_channel/io.dart';

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
  late Timer? timer = null;

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
        if (timer != null) {
          timer!.cancel();
        }
        if (userToken != null) {
          channel.sink.close();
          isLoading = false;
        }
      });
    });

    setState(() {
      isLoading = false;
    });

    if (timer != null && timer!.isActive) {
      timer!.cancel();
    }
    timer = Timer(const Duration(seconds: 60), () {
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
      return Scaffold(
        body: Center(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Successfully logged in!',
              style: TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const Icon(Icons.check_circle_outlined,
                color: Colors.green, size: 60),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  isLoading = true;
                  userToken = null;
                });
                getSlug();
              },
              child: const Text('Reset'),
            ),
          ],
        )),
      );
    } else {
      return QrCodeScreenLayout(
          children: !isLoading && slug != null
              ? [
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
                    color: const Color.fromARGB(255, 247, 87, 164),
                    width: 210 * _animation.value,
                  ),
                ]
              : [
                  const SizedBox(
                    height: 233,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Loading...'),
                        SizedBox(height: 20),
                        CircularProgressIndicator(
                          color: Color.fromARGB(255, 247, 87, 164),
                        ),
                      ],
                    ),
                  ),
                ]);
    }
  }

  @override
  void dispose() {
    channel.sink.close();
    _animationController.dispose();
    super.dispose();
  }
}

class QrCodeScreenLayout extends StatelessWidget {
  final List<Widget> children;

  const QrCodeScreenLayout({super.key, required this.children});

  void launchUrl(String url) async {
    await launchUrlString(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return const LinearGradient(
                          colors: [
                            Color.fromARGB(255, 247, 87, 164),
                            Color.fromARGB(255, 253, 149, 129)
                          ],
                        ).createShader(bounds);
                      },
                      child: const Text(
                        'Hi, Plinker!',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('SCAN QR CODE TO LOGIN:',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        )),
                    const Text(
                        'Plink mobile app > Profile > Settings > My Plink for PC',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 30),
                    ...children,
                    const SizedBox(height: 40),
                    const Text(
                        'In order to use Plink Desktop please get mobile app first:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        )),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {
                        launchUrl(
                            'https://play.google.com/store/apps/details?id=tech.plink.PlinkApp');
                      },
                      child: Image.asset('assets/images/GooglePlay.png',
                          width: 150),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {
                        launchUrl(
                            'https://apps.apple.com/us/app/plink-team-up-chat-play/id1306783602');
                      },
                      child:
                          Image.asset('assets/images/AppStore.png', width: 150),
                    ),
                  ],
                ),
              ),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  text: 'By continuing you agree with our ',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                  children: [
                    TextSpan(
                      text: 'Terms and Conditions',
                      style: const TextStyle(
                        color: Color.fromARGB(255, 247, 87, 164),
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          launchUrl(
                              'https://plink.tech/static/pages/pdfs/ToU.pdf');
                        },
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: const TextStyle(
                        color: Color.fromARGB(255, 247, 87, 164),
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          launchUrl(
                              'https://plink.tech/static/pages/pdfs/PP.pdf');
                        },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
