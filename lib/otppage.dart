import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:pinput/pinput.dart';
import 'setuppage.dart';
import 'package:fluttertoast/fluttertoast.dart';

class otppage extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;

  const otppage({super.key, required this.verificationId, required this.phoneNumber});

  @override
  _otppageState createState() => _otppageState();
}

class _otppageState extends State<otppage> {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final TextEditingController _otpController = TextEditingController();
  late Timer _timer;
  int _remainingTime = 15;
  bool _isResendVisible = false;

  @override
  void initState() {
    super.initState();
    _startTimer();

    // Show a toast with the phone number when the page is initialized
    Fluttertoast.showToast(
      msg: "Mobile number passed: ${widget.phoneNumber}",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.blue,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  void _resetTimer() {
    setState(() {
      _remainingTime = 15;
      _isResendVisible = false;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_remainingTime == 0) {
        timer.cancel();
        setState(() {
          _isResendVisible = true;
        });
      } else {
        setState(() {
          _remainingTime--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter the OTP'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      // Create a PhoneAuthCredential with the code
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: otp,
      );

      // Sign the user in with the credential
      await auth.signInWithCredential(credential);

      // Navigate to setupPage
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => setuppage(phoneNumber: widget.phoneNumber),
        ),
      );
    } catch (e) {
      print("Error verifying OTP: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid OTP, please try again'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.maxFinite,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("images/chatgradient3.png"), // Path to your background image
            fit: BoxFit.cover, // Cover the whole screen
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(top: 70.0),
              child: Text(
                "Enter the OTP",
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 24,
                  color: Colors.black38,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Pinput(
                length: 6,
                controller: _otpController,
                focusNode: FocusNode(),
                onChanged: (value) {
                  if (value.length == 6) {
                    // Verify OTP
                    _verifyOtp();
                  }
                },
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _verifyOtp,
              child: Text('Confirm'),
            ),
            SizedBox(height: 20),
            Text(
              'Resend OTP in $_remainingTime seconds',
              style: TextStyle(fontSize: 16),
            ),
            Visibility(
              visible: _isResendVisible,
              child: ElevatedButton(
                onPressed: () {
                  // Resend OTP logic here
                  _resetTimer();
                },
                child: Text('Resend OTP'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
