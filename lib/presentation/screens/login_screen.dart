import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../data/services/firebase_auth_service.dart';
import 'register_screen.dart';
import 'user_dashboard.dart';
import 'admin_dashboard.dart';

class LoginScreen extends StatefulWidget {
   const LoginScreen({super.key});

   @override
   State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
   final TextEditingController _emailController = TextEditingController();
   final TextEditingController _passwordController = TextEditingController();
   final FirebaseAuthService _authService = FirebaseAuthService();
   bool _isLoading = false;
   bool _obscurePassword = true;

   // Animation et Focus Node pour l'effet interactif
   late AnimationController _logoController;
   late Animation<double> _logoScale;
   final FocusNode _emailFocusNode = FocusNode();
   final FocusNode _passwordFocusNode = FocusNode();
   bool _isButtonHovered = false;

   @override
   void initState() {
     super.initState();
     // Logo pulsant continu (breathing effect)
     _logoController = AnimationController(
       vsync: this,
       duration: const Duration(seconds: 2),
     )..repeat(reverse: true);
     _logoScale = Tween<double>(begin: 0.95, end: 1.05).animate(
       CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
     );

     // Listeners de focus pour mettre à jour le style en temps réel
     _emailFocusNode.addListener(() => setState(() {}));
     _passwordFocusNode.addListener(() => setState(() {}));
   }

   @override
   void dispose() {
     _logoController.dispose();
     _emailFocusNode.dispose();
     _passwordFocusNode.dispose();
     _emailController.dispose();
     _passwordController.dispose();
     super.dispose();
   }

   void _login() async {
     if (_emailController.text.trim().isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(
           content: Text('Veuillez entrer votre email'),
           backgroundColor: AppColors.error,
         ),
       );
       return;
     }
     if (_passwordController.text.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(
           content: Text('Veuillez entrer votre mot de passe'),
           backgroundColor: AppColors.error,
         ),
       );
       return;
     }

     setState(() => _isLoading = true);
     try {
       final user = await _authService.login(
         email: _emailController.text,
         password: _passwordController.text,
       );

       setState(() => _isLoading = false);

        if (mounted && user != null) {
          final String userRole = user['role'] ?? 'normal';
          final Widget targetScreen = userRole == 'admin'
              ? AdminDashboard(email: user['email'] ?? '')
              : UserDashboard(
                  role: userRole,
                  email: user['email'] ?? '',
                );

          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 800),
            ),
          );
        }
     } catch (e) {
       setState(() => _isLoading = false);
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text(e.toString().replaceAll('Exception: ', '')),
             backgroundColor: AppColors.error,
           ),
         );
       }
     }
   }

   @override
   Widget build(BuildContext context) {
     final size = MediaQuery.of(context).size;
     return Scaffold(
       body: Container(
         decoration: const BoxDecoration(
           gradient: LinearGradient(
             colors: [Color(0xFF8F4E24), Color(0xFF4A230A)], // Chocolat foncé/Caramel riche
             begin: Alignment.topLeft,
             end: Alignment.bottomRight,
           ),
         ),
         child: Stack(
           children: [
             // Cercles lumineux décoratifs
             Positioned(
               top: -60,
               right: -60,
               child: Container(
                 width: size.width * 0.75,
                 height: size.width * 0.75,
                 decoration: BoxDecoration(
                   shape: BoxShape.circle,
                   color: AppColors.primary.withOpacity(0.12),
                 ),
               ),
             ),
             Positioned(
               bottom: -120,
               left: -60,
               child: Container(
                 width: size.width * 0.85,
                 height: size.width * 0.85,
                 decoration: BoxDecoration(
                   shape: BoxShape.circle,
                   color: AppColors.secondary.withOpacity(0.08),
                 ),
               ),
             ),

             SafeArea(
               child: Center(
                 child: SingleChildScrollView(
                   padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                   child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     crossAxisAlignment: CrossAxisAlignment.stretch,
                     children: [
                       // 1. Logo - Staggered Entry 1 (Scale) & Pulsation
                       TweenAnimationBuilder<double>(
                         tween: Tween<double>(begin: 0.0, end: 1.0),
                         duration: const Duration(milliseconds: 600),
                         curve: Curves.easeOutBack,
                         builder: (context, scaleVal, child) {
                           return Transform.scale(
                             scale: scaleVal,
                             child: child,
                           );
                         },
                         child: Center(
                           child: ScaleTransition(
                             scale: _logoScale,
                             child: Container(
                               width: 90,
                               height: 90,
                               decoration: BoxDecoration(
                                 shape: BoxShape.circle,
                                 gradient: AppColors.primaryGradient,
                                 boxShadow: [
                                   BoxShadow(
                                     color: AppColors.primary.withOpacity(0.35),
                                     blurRadius: 22,
                                     offset: const Offset(0, 8),
                                   ),
                                 ],
                               ),
                               child: const Icon(Icons.handshake_rounded, size: 45, color: Colors.white),
                             ),
                           ),
                         ),
                       ),
                       const SizedBox(height: 24),

                       // 2. Titre - Staggered Entry 2 (Slide Up + Fade)
                       TweenAnimationBuilder<double>(
                         tween: Tween<double>(begin: 0.0, end: 1.0),
                         duration: const Duration(milliseconds: 800),
                         curve: Curves.easeOutCubic,
                         builder: (context, value, child) {
                           return Transform.translate(
                             offset: Offset(0, 20 * (1 - value)),
                             child: Opacity(
                               opacity: value,
                               child: child,
                             ),
                           );
                         },
                         child: Column(
                           children: [
                             Text(
                               'Connexion',
                               style: GoogleFonts.poppins(
                                 fontSize: 34,
                                 fontWeight: FontWeight.bold,
                                 color: Colors.white,
                                 shadows: [
                                   Shadow(
                                     color: Colors.black.withOpacity(0.2),
                                     offset: const Offset(0, 2),
                                     blurRadius: 4,
                                   ),
                                 ],
                               ),
                               textAlign: TextAlign.center,
                             ),
                             const SizedBox(height: 6),
                             Text(
                               "Accédez à votre espace d'apprentissage Zhẽnù",
                               style: GoogleFonts.inter(
                                 fontSize: 14,
                                 fontWeight: FontWeight.w500,
                                 color: Colors.white.withOpacity(0.85),
                               ),
                               textAlign: TextAlign.center,
                             ),
                           ],
                         ),
                       ),
                       const SizedBox(height: 24),
                       
                       // Bandeau Démo (si hors-ligne)
                       if (!_authService.isFirebaseConfigured)
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                           decoration: BoxDecoration(
                             color: AppColors.warning.withOpacity(0.15),
                             borderRadius: BorderRadius.circular(16),
                             border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                           ),
                           child: Row(
                             children: [
                               const Icon(Icons.cloud_off_rounded, color: AppColors.secondary, size: 18),
                               const SizedBox(width: 10),
                               Expanded(
                                 child: Text(
                                   "Mode Démo local actif (Firebase non configuré)",
                                   style: GoogleFonts.inter(
                                     fontSize: 11,
                                     fontWeight: FontWeight.w600,
                                     color: Colors.white.withOpacity(0.9),
                                   ),
                                 ),
                               ),
                             ],
                           ),
                         ),
                       const SizedBox(height: 16),

                       // 3. Carte de Formulaire Haute Visibilité - Staggered Entry 3
                       TweenAnimationBuilder<double>(
                         tween: Tween<double>(begin: 0.0, end: 1.0),
                         duration: const Duration(milliseconds: 1000),
                         curve: Curves.easeOutCubic,
                         builder: (context, value, child) {
                           return Transform.translate(
                             offset: Offset(0, 35 * (1 - value)),
                             child: Opacity(
                               opacity: value,
                               child: child,
                             ),
                           );
                         },
                         child: Container(
                           padding: const EdgeInsets.all(24),
                           decoration: BoxDecoration(
                             color: Colors.white.withOpacity(0.85), // Semi-transparent pour le look premium tout en restant lisible
                             borderRadius: BorderRadius.circular(28),
                             border: Border.all(
                               color: Colors.white.withOpacity(0.4),
                               width: 2,
                             ),
                             boxShadow: [
                               BoxShadow(
                                 color: Colors.black.withOpacity(0.25),
                                 blurRadius: 30,
                                 offset: const Offset(0, 15),
                               ),
                             ],
                           ),
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.stretch,
                             children: [
                               // Email Input avec Halo lumineux animé au focus
                               AnimatedContainer(
                                 duration: const Duration(milliseconds: 250),
                                 decoration: BoxDecoration(
                                   borderRadius: BorderRadius.circular(16),
                                   boxShadow: [
                                     if (_emailFocusNode.hasFocus)
                                       BoxShadow(
                                         color: AppColors.primary.withOpacity(0.25),
                                         blurRadius: 10,
                                         spreadRadius: 2,
                                       ),
                                   ],
                                 ),
                                 child: TextField(
                                   controller: _emailController,
                                   focusNode: _emailFocusNode,
                                   keyboardType: TextInputType.emailAddress,
                                   style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
                                   decoration: InputDecoration(
                                     hintText: 'Adresse email',
                                     hintStyle: const TextStyle(color: Colors.black38),
                                     prefixIcon: Icon(
                                       Icons.email_outlined,
                                       color: _emailFocusNode.hasFocus ? AppColors.primary : Colors.black45,
                                     ),
                                     fillColor: const Color(0xFFFAF6F2),
                                     filled: true,
                                     enabledBorder: OutlineInputBorder(
                                       borderRadius: BorderRadius.circular(16),
                                       borderSide: const BorderSide(color: Color(0xFFEADBCE), width: 1.2),
                                     ),
                                     focusedBorder: OutlineInputBorder(
                                       borderRadius: BorderRadius.circular(16),
                                       borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                     ),
                                   ),
                                 ),
                               ),
                               const SizedBox(height: 16),
                               
                               // Password Input avec Halo lumineux animé au focus
                               AnimatedContainer(
                                 duration: const Duration(milliseconds: 250),
                                 decoration: BoxDecoration(
                                   borderRadius: BorderRadius.circular(16),
                                   boxShadow: [
                                     if (_passwordFocusNode.hasFocus)
                                       BoxShadow(
                                         color: AppColors.primary.withOpacity(0.25),
                                         blurRadius: 10,
                                         spreadRadius: 2,
                                       ),
                                   ],
                                 ),
                                 child: TextField(
                                   controller: _passwordController,
                                   focusNode: _passwordFocusNode,
                                   obscureText: _obscurePassword,
                                   style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
                                   decoration: InputDecoration(
                                     hintText: 'Mot de passe',
                                     hintStyle: const TextStyle(color: Colors.black38),
                                     prefixIcon: Icon(
                                       Icons.lock_outline_rounded,
                                       color: _passwordFocusNode.hasFocus ? AppColors.primary : Colors.black45,
                                     ),
                                     suffixIcon: IconButton(
                                       icon: Icon(
                                         _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                         color: _passwordFocusNode.hasFocus ? AppColors.primary : Colors.black45,
                                       ),
                                       onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                     ),
                                     fillColor: const Color(0xFFFAF6F2),
                                     filled: true,
                                     enabledBorder: OutlineInputBorder(
                                       borderRadius: BorderRadius.circular(16),
                                       borderSide: const BorderSide(color: Color(0xFFEADBCE), width: 1.2),
                                     ),
                                     focusedBorder: OutlineInputBorder(
                                       borderRadius: BorderRadius.circular(16),
                                       borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                     ),
                                   ),
                                 ),
                               ),
                               const SizedBox(height: 8),
                               Align(
                                 alignment: Alignment.centerRight,
                                 child: TextButton(
                                   onPressed: () {},
                                   style: TextButton.styleFrom(
                                     minimumSize: Size.zero,
                                     padding: EdgeInsets.zero,
                                   ),
                                   child: Text(
                                     'Mot de passe oublié ?',
                                     style: GoogleFonts.inter(
                                       color: AppColors.primary,
                                       fontSize: 12,
                                       fontWeight: FontWeight.bold,
                                     ),
                                   ),
                                 ),
                               ),
                               const SizedBox(height: 24),
                               
                               // Connexion Button avec survol interactif (Hover zoom + glow)
                               MouseRegion(
                                 onEnter: (_) => setState(() => _isButtonHovered = true),
                                 onExit: (_) => setState(() => _isButtonHovered = false),
                                 child: AnimatedContainer(
                                   duration: const Duration(milliseconds: 200),
                                   transform: Matrix4.identity()..scale(_isButtonHovered ? 1.03 : 1.0),
                                   child: ElevatedButton(
                                     onPressed: _isLoading ? null : _login,
                                     style: ElevatedButton.styleFrom(
                                       backgroundColor: AppColors.primary,
                                       foregroundColor: Colors.white,
                                       minimumSize: const Size(double.infinity, 56),
                                       shape: RoundedRectangleBorder(
                                         borderRadius: BorderRadius.circular(18),
                                       ),
                                       elevation: _isButtonHovered ? 6 : 3,
                                       shadowColor: AppColors.primary.withOpacity(0.5),
                                     ),
                                     child: _isLoading
                                         ? const SizedBox(
                                             width: 20,
                                             height: 20,
                                             child: CircularProgressIndicator(
                                               strokeWidth: 2.5,
                                               color: Colors.white,
                                             ),
                                           )
                                         : Text(
                                             'SE CONNECTER',
                                             style: GoogleFonts.poppins(
                                               fontWeight: FontWeight.bold,
                                               fontSize: 15,
                                               letterSpacing: 1.2,
                                             ),
                                           ),
                                   ),
                                 ),
                               ),
                               const SizedBox(height: 20),
                               
                               // Inscription Link
                               Row(
                                 mainAxisAlignment: MainAxisAlignment.center,
                                 children: [
                                   Text(
                                     "Pas encore de compte ? ",
                                     style: GoogleFonts.inter(
                                       color: Colors.black54,
                                       fontSize: 13,
                                       fontWeight: FontWeight.w500,
                                     ),
                                   ),
                                   TextButton(
                                     onPressed: () {
                                       Navigator.push(
                                         context,
                                         MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                       );
                                     },
                                     style: TextButton.styleFrom(
                                       minimumSize: Size.zero,
                                       padding: EdgeInsets.zero,
                                     ),
                                     child: Text(
                                       "S'inscrire",
                                       style: GoogleFonts.poppins(
                                         color: AppColors.primary,
                                         fontSize: 13,
                                         fontWeight: FontWeight.bold,
                                         decoration: TextDecoration.underline,
                                       ),
                                     ),
                                   ),
                                 ],
                               ),
                             ],
                           ),
                         ),
                       ),
                     ],
                   ),
                 ),
               ),
             ),
           ],
         ),
       ),
     );
   }
}
