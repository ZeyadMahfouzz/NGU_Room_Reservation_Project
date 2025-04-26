import 'package:flutter/material.dart';
import 'login_screen.dart';

class Splashscreen extends StatefulWidget {
  const Splashscreen({super.key});

  @override
  State<Splashscreen> createState() => _SplashscreenState();
}

class _SplashscreenState extends State<Splashscreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(seconds: 5), () {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => LoginScreen()));
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Color(0xFF8D0035),
      body: Center(
        child: Container(
          height: 400,
          width: 400,
          decoration: BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(
              'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTw7XRyI9v3Ii34ygvSIlMWFGiOsI5FdD3ryb4PCNkVObY0xaD8f7OhUt4w7bEhwzXp8Ek&usqp=CAU'),
            fit: BoxFit.cover, // Make the image fill the container
            ),
          ),
        ),
      ),
    );
  }
}