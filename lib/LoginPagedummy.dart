import 'package:chart/OTPPagedummy.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'otppage.dart'; // Import the OTPPage

class LoginPagedummy extends StatefulWidget {
  const LoginPagedummy({super.key});

  @override
  _LoginPagedummyState createState() => _LoginPagedummyState();
}

class _LoginPagedummyState extends State<LoginPagedummy> {
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _countryCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _countryCodeController.text = "+91"; // Default country code
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
        child: Center(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 80.0),
                child: Icon(
                  Icons.mark_chat_unread_outlined,
                  size: 48,
                  color: Colors.blue,
                ),
              ),
              SizedBox(height: 4), // Space between title and subtitle
              Text(
                "Login",
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 24,
                  color: Colors.black38,
                ),
              ),
              SizedBox(height: 4), // Space between title and subtitle
              Padding(
                padding: EdgeInsets.only(top: 80.0, right: 20.0, left: 20.0),
                child: TextField(
                  controller: _phoneNumberController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    labelText: "Enter Your Mobile Number",
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blueAccent, width: 2.0),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final phoneNumber = _phoneNumberController.text;
                  final countryCode = _countryCodeController.text;
                  final fullPhoneNumber = '$countryCode$phoneNumber';

                  if (phoneNumber.isEmpty) {
                    Fluttertoast.showToast(
                      msg: "Enter your mobile number",
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                      timeInSecForIosWeb: 1,
                      backgroundColor: Colors.red,
                      textColor: Colors.white,
                      fontSize: 16.0,
                    );
                    return;
                  }

                  // Save the phone number in SharedPreferences
                  final prefs = await SharedPreferences.getInstance();
                  List<String>? phoneNumbers = prefs.getStringList('phoneNumbers') ?? [];

                  // Debug: Print current phone numbers
                  print('Current phone numbers in SharedPreferences: $phoneNumbers');

                  if (!phoneNumbers.contains(fullPhoneNumber)) {
                    phoneNumbers.add(fullPhoneNumber);
                    bool isSaved = await prefs.setStringList('phoneNumbers', phoneNumbers);

                    if (isSaved) {
                      Fluttertoast.showToast(
                        msg: "Phone number saved successfully",
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.BOTTOM,
                        timeInSecForIosWeb: 1,
                        backgroundColor: Colors.green,
                        textColor: Colors.white,
                        fontSize: 16.0,
                      );
                      print('Phone number saved: $fullPhoneNumber');
                    } else {
                      Fluttertoast.showToast(
                        msg: "Failed to save phone number",
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.BOTTOM,
                        timeInSecForIosWeb: 1,
                        backgroundColor: Colors.red,
                        textColor: Colors.white,
                        fontSize: 16.0,
                      );
                      print('Failed to save phone number: $fullPhoneNumber');
                    }
                  } else {
                    Fluttertoast.showToast(
                      msg: "Phone number already saved",
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                      timeInSecForIosWeb: 1,
                      backgroundColor: Colors.orange,
                      textColor: Colors.white,
                      fontSize: 16.0,
                    );
                    print('Phone number already exists: $fullPhoneNumber');
                  }

                  // Debug: Retrieve and print saved phone numbers
                  List<String>? savedPhoneNumbers = prefs.getStringList('phoneNumbers');
                  if (savedPhoneNumbers != null) {
                    print('Saved phone numbers in SharedPreferences: $savedPhoneNumbers');
                    for (String number in savedPhoneNumbers) {
                      print('Saved phone number: $number');
                    }
                  } else {
                    print('No phone numbers found in SharedPreferences.');
                  }

                  // Navigate to OTP page with the mobile number
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OTPPagedummy(
                        verificationId: fullPhoneNumber,
                        phoneNumber: fullPhoneNumber, // Pass the mobile number
                      ),
                    ),
                  );
                },
                child: Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
