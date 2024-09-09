import 'dart:convert';
import 'dart:io';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';


import 'CallPage.dart';
import 'VideoCallPage.dart';
import 'package:speech_to_text/speech_to_text.dart' ;
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart'; // For downloading remote files
import 'package:path_provider/path_provider.dart'; // For accessing temporary directories








class chatroom extends StatefulWidget {
  final String contactName;
  final String contactPhoneNumber;
  final String channelId; // Channel ID for Agora
  final String token; // Agora token for authentication
  final int userId; // User ID for the current user





  const chatroom({
    super.key,
    required this.contactName,
    required this.contactPhoneNumber, required bool isAvailable, required boolisAvailable,
    required this.channelId,
    required this.token,
    required this.userId,
  });

  @override
  _chatroomState createState() => _chatroomState();
  
}

class _chatroomState extends State<chatroom> with SingleTickerProviderStateMixin{
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  late String _userPhoneNumber;
  late CollectionReference _messagesCollection;
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedMedia;
  String? _mediaType; // 'image', 'video', or 'document'
  VideoPlayerController? _videoPlayerController;
  String? _lastMessageTime;

  //Call
  static const String appId = 'f6ae7f0b709c41858594e0c5c1b1a9de'; // Replace with your Agora App ID
  String _channelName = "testChannel"; // Replace with a unique channel name for each chat or call session
  String _agoraAppId = 'f6ae7f0b709c41858594e0c5c1b1a9de'; // Replace with your Agora App ID
  bool _isInCall = false;
  late RtcEngine _agoraEngine;

  //
  late SpeechToText _speech;
  bool _isListening = false;
  String _text = "";

  late AnimationController _animationController;
  late Animation<double> _animation;








  @override
  void initState() {
    super.initState();
    _userPhoneNumber = FirebaseAuth.instance.currentUser!.phoneNumber ?? '';
    _messagesCollection = FirebaseFirestore.instance
        .collection('chats')
        .doc(_getChatId())
        .collection('messages');
    _fetchLastMessageTime();
    _listenForNewMessages;
    _initializeNotifications();
    _setupMessageListener();
    _testNotification(); // For testing
    _initializeSpeech();


    //Agora
    _initializeAgora();

    //Speech to text
    _speech = SpeechToText();


    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.0, end: 30.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );







  }



  Future<void> _initializeSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (val) => print('onStatus: $val'),
      onError: (val) => print('onError: $val'),
    );
    if (available) {
      print('Speech recognition initialized successfully');
    } else {
      print('Speech recognition not available');
    }
  }

  void _startListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        print('Starting listening');
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _text = val.recognizedWords;
            _messageController.text = _text;
          }),
          onSoundLevelChange: (level) {
            print('Sound level: $level');
          },
        );
      } else {
        print('Speech recognition not available');
      }
    }
  }

  void _stopListening() {
    if (_isListening) {
      print('Stopping listening');
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }


  //

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _text = val.recognizedWords;
            _messageController.text = _text;
          }),
          onSoundLevelChange: (level) {
            // Optionally handle sound level changes
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }



  void _showIncomingCallNotification(String callID, String callerUserID) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'call_channel', 'Call Notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      fullScreenIntent: true,
    );
    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0,
      'Incoming Call',
      'You have an incoming call from $callerUserID',
      platformChannelSpecifics,
      payload: callID,
    );
  }


  //Agora SDK Voice Call
// Agora SDK Voice Call
  Future<void> _initializeAgora() async {
    await [Permission.microphone].request();
    _agoraEngine = createAgoraRtcEngine();
    await _agoraEngine.initialize(RtcEngineContext(appId: appId));

    // Register event handlers
    _agoraEngine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          setState(() {
            _isInCall = true;
          });
        },
        onUserOffline: (RtcConnection connection, int uid, UserOfflineReasonType reason) {
          setState(() {
            _isInCall = false;
          });
        },
      ),
    );
  }


  String _generateCallId() {
    return '${_userPhoneNumber}_${widget.contactPhoneNumber}_${DateTime.now().millisecondsSinceEpoch}';
  }

// Example function to fetch the user ID dynamically
  Future<int> _getUserIdForCall() async {
    // This is just an example. Replace it with your actual logic to fetch the user ID.
    // For example, you might query a database, use a service, or pass it as an argument.
    return 12345; // Replace with your logic to get the user ID
  }

  Future<void> _endCall() async {
    try {
      await _agoraEngine.leaveChannel();
      setState(() {
        _isInCall = false;
      });
    } catch (e) {
      print('Error ending call: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to end call')),
      );
    }
  }

  void _testNotification() async {
    await _showNotification('Test Notification', 'This is a test notification.');
  }

  void _setupMessageListener() {
    FirebaseFirestore.instance.collection('chats').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final message = change.doc.data();
          _showNotification(message!['senderId'], message['content']);
        }
      }
    });
  }

  void _initializeNotifications() {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);


  }


  void _listenForNewMessages() {
    _firestore.collection('chats').snapshots().listen((snapshot) {
      for (var doc in snapshot.docs) {
        final message = doc.data();
        if (message['receiverId'] == 'currentUserId') { // Replace 'currentUserId' with the actual user ID
          _showNotification('New Message', message['message']);
        }
      }
    });
  }


  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'chat_channel', // Unique channel ID
      'Chat Notifications', // Channel name
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      0, // Notification ID
      title, // Notification title
      body, // Notification body
      platformChannelSpecifics,
      payload: 'message_id_123', // Optional payload
    );
  }



  // @override
  // void dispose() {
  //   _videoPlayerController?.dispose();
  //   super.dispose();
  // }

  String _getChatId() {
    final sender = _userPhoneNumber;
    final receiver = widget.contactPhoneNumber;

    if (sender.isEmpty || receiver.isEmpty) {
      throw Exception('Sender or receiver phone number is empty');
    }

    List<String> phoneNumbers = [sender, receiver];
    phoneNumbers.sort();
    return phoneNumbers.join('_');
  }

  //
// Inside the _fetchLastMessageTime method

  void _fetchLastMessageTime() async {
    final docSnapshot = await _messagesCollection
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (docSnapshot.docs.isNotEmpty) {
      final lastMessageData = docSnapshot.docs.first.data() as Map<String, dynamic>;
      final timestamp = lastMessageData['timestamp'] as Timestamp?;
      _updateLastMessageTime(timestamp);
    }
  }

  void _updateLastMessageTime(Timestamp? timestamp) {
    if (timestamp != null) {
      setState(() {
        _lastMessageTime = DateFormat('dd-MM-yyyy hh:mm a').format(timestamp.toDate());
      });
    } else {
      setState(() {
        _lastMessageTime = 'Unknown Time';
      });
    }
  }





  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();

    // Check if there is a message or media to send
    if (message.isNotEmpty || _selectedMedia != null) {
      try {
        final chatId = _getChatId();
        print('Generated Chat ID: $chatId'); // Debugging line

        // Get a reference to the chat document
        final chatDoc = FirebaseFirestore.instance.collection('chats').doc(chatId);

        // Create or update the chat document with the last message
        await chatDoc.set({
          'participants': [_userPhoneNumber, widget.contactPhoneNumber],
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
          'lastMessage': message.isNotEmpty ? message : 'Media',
          'receiverName': widget.contactName, // Add receiver's name
        }, SetOptions(merge: true));

        // Upload media if available
        String? mediaUrl;
        if (_selectedMedia != null) {
          mediaUrl = await _uploadFile(_selectedMedia!);
        }

        // Add the message to the subcollection
        await chatDoc.collection('messages').add({
          'sender': _userPhoneNumber,
          'receiver': widget.contactPhoneNumber,
          'receiverName': message.isEmpty ? null : widget.contactName,
          'text': message.isNotEmpty ? message : null,
          'mediaUrl': mediaUrl,
          'mediaType': _mediaType,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'Sent', // Can be updated later if needed
        });

        print('Message sent successfully.');

        // Fetch the recipient's FCM token
        final receiverDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.contactPhoneNumber)
            .get();

        String? fcmToken = receiverDoc.data()?['fcmToken'];

        // Send FCM notification if the recipient's FCM token is available
        if (fcmToken != null) {
          await _sendPushNotification(fcmToken, message.isNotEmpty ? message : 'Media');
        }

        // Clear the message input and media preview
        _messageController.clear();
        setState(() {
          _selectedMedia = null;
          _mediaType = null;
          _videoPlayerController?.dispose();
          _videoPlayerController = null;
        });

      } catch (e) {
        print('Error sending message: $e');
      }
    }
  }

  // Helper method to send push notification using Firebase Cloud Messaging (FCM)

  Future<void> _sendPushNotification(String fcmToken, String message) async {
    final accessToken = '900d8e864a88a03c2c3070b51d8b2418433e1391'; // Replace with your OAuth 2.0 access token
    final postUrl = 'https://fcm.googleapis.com/v1/projects/chart-a7076/messages:send';

    final data = {
      "message": {
        "token": fcmToken,
        "notification": {
          "title": "New Message",
          "body": message,
          "sound": "default",
        },
        "data": {
          "click_action": "FLUTTER_NOTIFICATION_CLICK",
          "message": message,
        },
      },
    };

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    final response = await http.post(
      Uri.parse(postUrl),
      body: json.encode(data),
      headers: headers,
    );

    if (response.statusCode == 200) {
      print('FCM Notification sent successfully');
    } else {
      print('Error sending FCM Notification: ${response.body}');
    }
  }


  Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    print('Handling a background message: ${message.messageId}');
  }

  void setupFirebaseMessaging() {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
      }
    });
  }




  Future<String> _uploadFile(XFile file) async {
    // Determine the file extension based on the media type
    String fileExtension;
    if (_mediaType == 'document') {
      // Extract the file extension from the document path
      fileExtension = file.path.split('.').last;
    } else if (_mediaType == 'video') {
      fileExtension = 'mp4';
    } else {
      // Default file extension for images
      fileExtension = 'jpg';
    }

    // Create a unique file name with the correct extension
    String fileName = DateTime.now().millisecondsSinceEpoch.toString() + '.' + fileExtension;

    // Upload file to Firebase Storage
    final storageRef = FirebaseStorage.instance.ref().child('chat_media/$fileName');
    final uploadTask = storageRef.putFile(File(file.path));
    final snapshot = await uploadTask.whenComplete(() => {});
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> _pickMedia(ImageSource source) async {
    final XFile? file = await _picker.pickImage(
      source: source,
      imageQuality: 100,
    );

    if (file != null) {
      setState(() {
        _selectedMedia = file;
        _mediaType = 'image';
      });
    }
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'], // Specify allowed document types
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.single;

      setState(() {
        _selectedMedia = XFile(file.path!);
        _mediaType = 'document'; // Set media type to document
      });

      print('Picked document: ${file.name}');
    }
  }

  Future<void> _showAttachmentOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.image),
              title: Text('Media'),
              onTap: () {
                Navigator.of(context).pop();
                _pickMedia(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Icon(Icons.insert_drive_file),
              title: Text('Document'),
              onTap: () {
                Navigator.of(context).pop();
                _pickDocument();
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('Camera'),
              onTap: () {
                Navigator.of(context).pop();
                _pickMedia(ImageSource.camera);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildMediaPreview() {
    if (_selectedMedia == null) return SizedBox.shrink();

    return Stack(
      children: [
        if (_mediaType == 'image')
          GestureDetector(
            onTap: () => _launchURL(_selectedMedia!.path),
            child: Image.file(
              File(_selectedMedia!.path),
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          ),
        if (_mediaType == 'video')
          GestureDetector(
            onTap: () => _launchURL(_selectedMedia!.path),
            child: _videoPlayerController!.value.isInitialized
                ? AspectRatio(
              aspectRatio: _videoPlayerController!.value.aspectRatio,
              child: VideoPlayer(_videoPlayerController!),
            )
                : CircularProgressIndicator(),
          ),
        if (_mediaType == 'document')
          if (_mediaType == 'document')
            Container(
              width: 200, // Adjust this width as needed
              color: Colors.grey[300], // Set the background color to a light grey
              child: ListTile(
                leading: Icon(Icons.description),
                title: Text(
                  _selectedMedia!.name,
                  overflow: TextOverflow.ellipsis, // Ensure the text doesn't overflow
                ),
                onTap: () => _launchURL(_selectedMedia!.path),
              ),
            ),


      ],
    );
  }

  void _showMediaOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.share),
              title: Text('Share'),
              onTap: () {
                Navigator.of(context).pop();
                // Implement share functionality here
              },
            ),
            ListTile(
              leading: Icon(Icons.delete),
              title: Text('Delete'),
              onTap: () {
                Navigator.of(context).pop();
                // Implement delete functionality here
              },
            ),
          ],
        );
      },
    );
  }

  void _showMenu() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Chat Options'),
          actions: [
            TextButton(
              child: Text('Clear Chat'),
              onPressed: () {
                Navigator.of(context).pop();
                _clearChat();
              },
            ),
            TextButton(
              child: Text('Delete Chat'),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteChat();
              },
            ),
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(); // Dismiss the dialog
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _clearChat() async {
    final messages = await _messagesCollection.get();
    for (var message in messages.docs) {
      await message.reference.delete(); // Delete from Firestore
    }
    setState(() {
      // Optionally update UI state
    });
  }

  Future<void> _deleteChat() async {
    final messages = await _messagesCollection.get();
    for (var message in messages.docs) {
      await message.reference.delete();
    }

    Navigator.pop(context);
  }

  Future<void> _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  // title: Text('${widget.contactName}'),



  //Voice Call Logic
  Future<void> _makeVoiceCall() async {
    // Request phone permission
    PermissionStatus status = await Permission.phone.request();

    // Check the status of the permission request
    if (status.isGranted) {
      // Permission is granted, initiate the call
      final phoneNumber = widget.contactPhoneNumber;
      final callUrl = 'tel:$phoneNumber';
      if (await canLaunch(callUrl)) {
        await launch(callUrl);
      } else {
        print('Could not launch $callUrl');
        // Handle error: show a message to the user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not initiate call to $phoneNumber')),
        );
      }
    } else if (status.isDenied) {
      // Permission is denied (this should trigger a re-request)
      print('Call permission denied');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Call permission is required to make a call')),
      );
      // Optionally, re-request permission
      // await Permission.phone.request();
    } else if (status.isPermanentlyDenied) {
      // Permissions are permanently denied, show dialog
      print('Call permission permanently denied. Prompting user to go to settings.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Call permission is permanently denied. Please enable it in settings.')),
      );
      // Open app settings to allow user to enable permission
      openAppSettings();
    } else if (status.isRestricted) {
      print('Call permission is restricted');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Call permission is restricted and cannot be granted.')),
      );
    } else {
      // Handle any other unexpected cases
      print('Unexpected permission status: $status');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected error. Could not make the call.')),
      );
    }
  }


  Widget _buildSentMediaPreview(String mediaUrl, String? mediaType) {
    if (mediaType == 'image') {
      return GestureDetector(
        onTap: () => _launchURL(mediaUrl),
        child: Image.network(
          mediaUrl,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
        ),
      );
    } else if (mediaType == 'video') {
      return GestureDetector(
        onTap: () => _launchURL(mediaUrl),
        child: AspectRatio(
          aspectRatio: 16 / 9, // Adjust as needed
          child: VideoPlayer(VideoPlayerController.network(mediaUrl)),
        ),
      );
    } else if (mediaType == 'document') {
      return Container(
        width: 200, // Adjust this width as needed
        color: Colors.grey[300], // Set the background color to a light grey
        child: ListTile(
          leading: Icon(Icons.description),
          title: Text(
            mediaUrl.split('/').last, // Show the document name
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _launchURL(mediaUrl),
        ),
      );
    } else {
      return SizedBox.shrink();
    }
  }











  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.contactName}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (_lastMessageTime != null)
              Text(
                _lastMessageTime!,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.video_call),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoCallPage(
                    callerName: widget.contactName, // Replace with actual caller name
                    callerPhoneNumber: widget.contactPhoneNumber, // Replace with actual caller phone number
                  ),
                ),
              );
            },
          ),

          IconButton(
            icon: Icon(Icons.call),
            onPressed: () {
              // Replace 'currentUserId' and 'currentUserName' with actual values
              String currentUserId = 'current_user_id'; // Get this from your user state or auth
              String currentUserName = 'current_user_name'; // Get this from your user state or auth

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CallPage(
                    receptionistName: widget.contactName,
                    receptionistPhoneNumber: widget.contactPhoneNumber,
                    callerUserId: currentUserId,
                    callerUserName: currentUserName,
                  ),
                ),
              );
            },
          ),



          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: _showMenu,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesCollection
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No messages yet.'));
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].data() as Map<String, dynamic>;
                    final isMe = message['sender'] == widget.contactPhoneNumber;
                    final messageId = messages[index].id;
                    final mediaUrl = message['mediaUrl'];
                    final mediaType = message['mediaType'];

                    final timestamp = message['timestamp'] as Timestamp?;
                    final formattedTime = timestamp != null
                        ? DateFormat('hh:mm a').format(timestamp.toDate())
                        : 'Unknown Time';

                    final status = message['status'] ?? 'Sent';


                    return Dismissible(
                      key: Key(messageId),
                      direction: DismissDirection.horizontal, // Allow both left (share) and right (delete)
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          // Right swipe (delete logic)
                          final shouldDelete = await _confirmDelete(context);
                          return shouldDelete;
                        } else if (direction == DismissDirection.endToStart) {
                          // Left swipe (share logic)
                          await _shareMessage(message);
                          return false; // Prevent deletion after sharing
                        }
                        return false;
                      },
                      onDismissed: (direction) async {
                        // Handle actual deletion
                        if (direction == DismissDirection.startToEnd) {
                          await _messagesCollection.doc(messageId).delete();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Message deleted')),
                          );
                        }
                      },
                      child: ListTile(
                        title: Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            padding: EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.blue : Colors.grey[300],
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                // Display text message with GestureDetector
                                if (message['text'] != null)
                                  GestureDetector(
                                    onTap: () {
                                      // Copy the message text to clipboard
                                      Clipboard.setData(ClipboardData(text: message['text']));

                                      // Show a toast or snackbar message to inform the user
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Message copied to clipboard'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      message['text'] ?? '',
                                      style: TextStyle(
                                        fontSize: 16.0,
                                        color: isMe ? Colors.white : Colors.black,
                                      ),
                                    ),
                                  ),

                                // Display media (image, video, or document) if present
                                if (mediaUrl != null) _buildSentMediaPreview(mediaUrl, mediaType),

                                SizedBox(height: 4.0),

                                // Display timestamp and status
                                Text(
                                  '$formattedTime | $status',
                                  style: TextStyle(
                                    fontSize: 12.0,
                                    color: isMe ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    );

                  },
                );

              },
            ),
          ),
          _buildMediaPreview(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.attach_file),
                  onPressed: _showAttachmentOptions,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onLongPress: _startListening,
                  onLongPressUp: _stopListening,
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    size: 30.0,
                  ),
                ),
                if (_isListening)
                  Positioned(child:
                  Align(
                    alignment: Alignment.center,
    child: AnimatedBuilder(
      animation: _animation,
    builder: (context, child) {
      return CustomPaint(
        painter: WavePainter(_animation.value),
        size: Size(MediaQuery.of(context).size.width, 60),
      );

          },

    ),


    ),
                  ),

    IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),

    ),
        ],
      ),
    );
  }
}

Future<void> _shareMessage(Map<String, dynamic> message) async {
  if (message['text'] != null) {
    // Share text message
    await Share.share(message['text']);
  } else if (message['mediaUrl'] != null) {
    // Share media (image or document)
    final mediaUrl = message['mediaUrl'];
    final mediaType = message['mediaType'];

    // Check if mediaUrl is a remote URL (starts with http or https)
    if (mediaUrl.startsWith('http')) {
      // Download the file first
      final file = await _downloadFile(mediaUrl);

      // Check media type and share the file
      if (mediaType == 'image') {
        await Share.shareFiles([file.path], text: 'Shared image');
      } else if (mediaType == 'document') {
        await Share.shareFiles([file.path], text: 'Shared document');
      }
    } else {
      // For local file paths
      if (mediaType == 'image') {
        await Share.shareFiles([mediaUrl], text: 'Shared image');
      } else if (mediaType == 'document') {
        await Share.shareFiles([mediaUrl], text: 'Shared document');
      }
    }
  }
}


//
Future<File> _downloadFile(String url) async {
  try {
    final response = await Dio().get(url, options: Options(responseType: ResponseType.bytes));

    // Get the temporary directory of the device
    final tempDir = await getTemporaryDirectory();
    final tempPath = '${tempDir.path}/${url.split('/').last}';

    // Write the downloaded file to the temp directory
    final file = File(tempPath);
    await file.writeAsBytes(response.data);

    return file;
  } catch (e) {
    throw Exception('Error downloading file: $e');
  }
}

//
Future<bool> _confirmDelete(BuildContext context) async {
  return await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Delete Message'),
        content: Text('Are you sure you want to delete this message?'),
        actions: <Widget>[
          TextButton(
            child: Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop(false);
            },
          ),
          TextButton(
            child: Text('Delete'),
            onPressed: () {
              Navigator.of(context).pop(true);
            },
          ),
        ],
      );
    },
  ) ?? false;
}







class WavePainter extends CustomPainter {
  final double waveHeight;

  WavePainter(this.waveHeight);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, size.height - waveHeight)
      ..lineTo(0, size.height - waveHeight)
      ..close();

    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}


Future<void> _showShareOptions(Map<String, dynamic> message) async {
  // Use a package like 'share_plus' to share the message content
  final text = message['text'] ?? '';
  final mediaUrl = message['mediaUrl'] ?? '';

  if (text.isNotEmpty || mediaUrl.isNotEmpty) {
    await Share.share(text.isNotEmpty ? text : mediaUrl);
  } else {
    // Handle cases where there's nothing to share
    print('Nothing to share');
  }
}