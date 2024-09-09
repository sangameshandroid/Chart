import 'package:chart/Homepage.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:io';

class setuppage extends StatefulWidget {
  final String phoneNumber;

  const setuppage({Key? key, required this.phoneNumber}) : super(key: key);

  @override
  _setuppageState createState() => _setuppageState();
}

class _setuppageState extends State<setuppage> {
  final TextEditingController _nicknameController = TextEditingController();
  File? _profileImage;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _qrImageUrl;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _saveDetails() async {
    final nickname = _nicknameController.text.trim();
    final phoneNumber = widget.phoneNumber;

    if (nickname.isEmpty || _profileImage == null) {
      Fluttertoast.showToast(
        msg: "Please fill all the fields",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      List<Map<String, dynamic>> userDetails = [];
      final userDetailsString = prefs.getString('userDetails');
      if (userDetailsString != null) {
        userDetails = List<Map<String, dynamic>>.from(jsonDecode(userDetailsString));
      }

      // Generate the QR Code Data
      final qrData = Uri.encodeComponent('Name: $nickname\nMobile: $phoneNumber');
      final qrImageUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=$qrData';

      // Prepare new user details including the QR code URL
      final newUserDetail = {
        'phoneNumber': phoneNumber,
        'nickname': nickname,
        'profileImage': _profileImage!.path,
        'qrCodeUrl': qrImageUrl, // Save the QR code URL in Firestore
      };

      userDetails.add(newUserDetail);
      await prefs.setString('userDetails', jsonEncode(userDetails));

      // Save the details in Firestore
      await _firestore.collection('users').doc(phoneNumber).set(newUserDetail);

      // Update the UI to show the QR code
      setState(() {
        _qrImageUrl = qrImageUrl;
      });

      Fluttertoast.showToast(
        msg: "Details saved successfully in SharedPreferences and Firebase!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0,
      );

    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error saving details: ${e.toString()}",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
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
            image: AssetImage("images/chatgradient3.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Setup Profile",
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 24,
                    color: Colors.black38,
                  ),
                ),
                SizedBox(height: 20),
                GestureDetector(
                  onTap: () => _showImageSourceDialog(),
                  child: _profileImage == null
                      ? CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[300],
                    child: Icon(Icons.camera_alt, size: 50, color: Colors.grey[700]),
                  )
                      : CircleAvatar(
                    radius: 60,
                    backgroundImage: FileImage(_profileImage!),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  "Mobile Number: ${widget.phoneNumber}",
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: TextField(
                    controller: _nicknameController,
                    decoration: InputDecoration(
                      labelText: 'Enter Nickname',
                    ),
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _saveDetails,
                  child: Text('Submit'),
                ),
                SizedBox(height: 10),
                _qrImageUrl != null
                    ? Column(
                  children: [
                    Image.network(
                      _qrImageUrl!,
                      width: 300,
                      height: 300,
                      fit: BoxFit.cover,
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        Fluttertoast.showToast(
                          msg: "QR code stored in Firestore!",
                          toastLength: Toast.LENGTH_SHORT,
                          gravity: ToastGravity.BOTTOM,
                          backgroundColor: Colors.green,
                          textColor: Colors.white,
                          fontSize: 16.0,
                        );
                        // Navigate to the home page or other screen
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => homepage()), // Replace HomePage with your actual home page widget
                        );
                      },
                      child: Text('Next'),
                    ),
                  ],
                )
                    : Container(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Image Source'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _pickImage(ImageSource.camera);
            },
            child: Text('Camera'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _pickImage(ImageSource.gallery);
            },
            child: Text('Gallery'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }
}
