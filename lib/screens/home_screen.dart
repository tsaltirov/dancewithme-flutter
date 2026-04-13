import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Placeholder — se reemplazará con la home real en el siguiente sprint
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EEFF),
      body: Center(
        child: Text(
          'DanceWithMe',
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF7C5CFC),
          ),
        ),
      ),
    );
  }
}
