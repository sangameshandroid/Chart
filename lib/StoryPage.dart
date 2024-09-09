import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StoryPage extends StatefulWidget {
  @override
  _StoryPageState createState() => _StoryPageState();
}

class _StoryPageState extends State<StoryPage> {
  final ImagePicker _picker = ImagePicker();
  List<XFile>? _imageFiles;

  @override
  void initState() {
    super.initState();
    _retrieveImages();
  }

  Future<void> _retrieveImages() async {
    final List<XFile>? pickedFiles = await _picker.pickMultiImage();
    setState(() {
      _imageFiles = pickedFiles;
    });
  }

  Future<void> _uploadStory() async {
    if (_imageFiles != null && _imageFiles!.isNotEmpty) {
      try {
        // Get the currently authenticated user
        User? user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw Exception('User is not authenticated');
        }

        // Fetch the user's phone number and nickname
        String userPhoneNumber = user.phoneNumber ?? ''; // Retrieve phone number
        String nickname = user.displayName ?? 'Anonymous'; // Fetch user's display name

        if (nickname.isEmpty) {
          nickname = 'Anonymous'; // Provide a default nickname if empty
        }

        // Prepare the file for upload
        File file = File(_imageFiles![0].path);
        String extension = file.path.split('.').last.toLowerCase();

        // Determine the appropriate file name and extension
        String fileName = 'stories/${DateTime.now().millisecondsSinceEpoch}';
        if (['jpg', 'jpeg', 'png'].contains(extension)) {
          fileName += '.jpg'; // Store images as .jpg
        } else if (['mp4', 'mov', 'avi'].contains(extension)) {
          fileName += '.mp4'; // Store videos as .mp4
        } else {
          throw Exception('Unsupported file type: $extension');
        }

        // Upload the file to Firebase Storage
        Reference storageRef = FirebaseStorage.instance.ref(fileName);
        UploadTask uploadTask = storageRef.putFile(file);

        TaskSnapshot snapshot = await uploadTask.whenComplete(() {});
        String mediaUrl = await snapshot.ref.getDownloadURL();

        // Save the story details to Firestore
        await FirebaseFirestore.instance.collection('stories').add({
          'nickname': nickname,
          'phoneNumber': userPhoneNumber, // Include phone number
          'mediaUrl': mediaUrl,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Notify the user of successful upload
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Story uploaded successfully')),
        );

        // Clear the selected images and navigate back
        setState(() {
          _imageFiles = null; // Clear selected images
        });

        Navigator.pop(context);
      } catch (e) {
        print('Error uploading story: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload story: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select an image or video')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Story'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.check),
            onPressed: _uploadStory, // Call _uploadStory when the icon is pressed
          ),
        ],
      ),
      body: Column(
        children: [
          // Square shape at the top
          Container(
            margin: EdgeInsets.all(16.0),
            width: 150.0,
            height: 150.0,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue, width: 2.0),
              shape: BoxShape.rectangle,
            ),
            child: _imageFiles != null && _imageFiles!.isNotEmpty
                ? Image.file(
              File(_imageFiles![0].path),
              fit: BoxFit.cover,
            )
                : Center(
              child: Text('No image selected'),
            ),
          ),

          SizedBox(height: 16.0), // Space between square and gallery

          // Gallery grid view
          _imageFiles != null && _imageFiles!.isNotEmpty
              ? Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4.0,
                mainAxisSpacing: 4.0,
              ),
              itemCount: _imageFiles!.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      // Set the tapped image in the square
                      File imageFile = File(_imageFiles![index].path);
                      _imageFiles!.insert(0, _imageFiles!.removeAt(index));
                    });
                  },
                  child: Image.file(
                    File(_imageFiles![index].path),
                    fit: BoxFit.cover,
                  ),
                );
              },
            ),
          )
              : Expanded(
            child: Center(
              child: Text('No images found'),
            ),
          ),
        ],
      ),
    );
  }
}
