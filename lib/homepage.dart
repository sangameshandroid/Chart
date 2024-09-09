import 'package:chart/StoryViewPage.dart';
import 'package:chart/UserService.dart';
import 'package:chart/notification_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ScannerPage.dart';
import 'StoryPage.dart';
import 'UserData.dart';
import 'chatroom.dart';
import 'LoginPage.dart';
import 'ProfilePage.dart';
import 'package:fluttertoast/fluttertoast.dart';

class homepage extends StatefulWidget {
  const homepage({super.key});


  @override
  _homepageState createState() => _homepageState();

}



class _homepageState extends State<homepage> {
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  List<Contact> _recentChats = []; // To store recent chats
  SharedPreferences? _prefs;
  String _searchQuery = '';
  int _chatCount = 0;
  List<String> contactNumbers = []; // Define the variable
  String? _storyUrl;
  late Future<List<UserData>> _usersFuture;
  List<Map<String, String>> _storyContacts = []; // List to hold other users' stories



  //Notification
  NotificationServices notificationServices = NotificationServices();
  final UserService _userService = UserService();

  List<Map<String, String>> contactsWithTime = [];



  //Stories fetching in homepage
  Future<String?> fetchStoryUrl() async {
    User? user = FirebaseAuth.instance.currentUser;
    String userPhoneNumber = user?.phoneNumber ?? '';

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('stories')
          .where('phoneNumber', isEqualTo: userPhoneNumber)
          .limit(1) // Assuming one story per user
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first['mediaUrl'] as String;
      }
    } catch (e) {
      print('Error fetching story: $e');
    }

    return null;
  }


  //Story Loading
  Future<void> _loadUserStory() async {
    final storyUrl = await fetchStoryUrl();
    setState(() {
      _storyUrl = storyUrl;
    });
  }


  Future<void> _loadStoryUrl() async {
    String? storyUrl = await fetchStoryUrl(); // Implement fetchStoryUrl based on your logic
    setState(() {
      _storyUrl = storyUrl;
    });
  }



  Future<List<UserData>> fetchRegisteredUsers() async {
    List<UserData> users = [];

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users') // Replace with your users collection
          .get();

      for (var doc in snapshot.docs) {
        UserData user = UserData.fromFirestore(doc);
        users.add(user);
      }
    } catch (e) {
      print('Error fetching users: $e');
    }

    return users;
  }

  Future<List<UserData>> fetchUsersWithStories() async {
    List<UserData> users = await fetchRegisteredUsers();

    // Filter users to ensure you only show those with stories
    users.removeWhere((user) => user.storyUrl.isEmpty);

    return users;
  }


  @override
  void initState() {
    super.initState();
    _fetchContacts();
    _showChatCountToast();
    // _loadSharedPreferences();
    _fetchChatCount();
    checkChatsForCurrentUser();
    _loadChatContacts();
    _requestPermission(); // Request permission when the widget is initialized
    _updateUserFCMToken();
    _loadUserStory();
    _loadStoryUrl();

    _usersFuture = fetchUsersWithStories();

    _fetchContactsAndStories();





    //
    notificationServices.requestNotificationPermission();


    void _showNotification(String? title, String? body) {
      // Implement your local notification display here
      // You can use flutter_local_notifications package for local notifications
    }









    _getChatCountForCurrentUser().then((chatCount) {
      setState(() {
        _chatCount = chatCount;
      });
    });


  }
  Future<void> _updateUserFCMToken() async {
    await _userService.updateFCMToken();
  }

  //
  Future<void> _requestPermission() async {
    var status = await Permission.contacts.status;
    if (!status.isGranted) {
      status = await Permission.contacts.request();
    }
  }

  //Loading of chat contacts
  Future<void> _loadChatContacts() async {
    final numbers = await _getChatContactNumbersForCurrentUser();
    final contacts = await _getChatContactsForCurrentUser();

    setState(() {
      contactNumbers = numbers;
      contactsWithTime = contacts;

    });
  }

  Future<List<Map<String, String>>> _getChatContactsForCurrentUser() async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('No user is currently authenticated.');
        return [];
      }
      final String currentUserPhoneNumber = currentUser.phoneNumber ?? '';
      print('Current User Phone Number: $currentUserPhoneNumber');

      final QuerySnapshot chatsSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUserPhoneNumber)
          .get();

      // Fetch all contacts once
      final contactsMap = await _fetchAllContacts();

      List<Map<String, String>> contactInfoList = [];
      for (var doc in chatsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;

        if (data != null) {
          final participants = data['participants'] as List<dynamic>?;
          final chatTime = data['lastMessageTime'] as String?; // Assuming this field stores the chat time

          if (participants != null) {
            for (var number in participants.whereType<String>()) {
              if (number != currentUserPhoneNumber) {
                // Determine if the current user is the sender or receiver
                final isCurrentUserSender = data['sender'] == currentUserPhoneNumber;

                // Fetch the appropriate name based on sender or receiver
                final contactName = isCurrentUserSender
                    ? data['receiverName'] as String? ?? 'Unknown Contact'
                    : contactsMap[number] ?? data['senderName'] as String? ?? 'Unknown Contact'; // For receiver, use contact name from device

                // Combine contact info
                final contactInfo = {
                  'number': number,
                  'contactName': contactName,
                  'timestamp': chatTime ?? '',

                };

                contactInfoList.add(contactInfo);
              }
            }
          }
        }
      }
      print('Contact information in chats where the current user is a participant: $contactInfoList');
      return contactInfoList;
    } catch (e) {
      print('Error fetching chat contact information: $e');
      return [];
    }
  }


  //Fetch all contacts
  Future<Map<String, String>> _fetchAllContacts() async {
    final Map<String, String> contactsMap = {};

    try {
      final PermissionStatus permissionStatus = await Permission.contacts.request();
      if (permissionStatus.isGranted) {
        final Iterable<Contact> contacts = await ContactsService.getContacts();
        for (Contact contact in contacts) {
          for (Item phone in contact.phones ?? []) {
            if (phone.value != null) {
              contactsMap[phone.value!] = contact.displayName ?? 'Unknown Contact';
            }
          }
        }
      } else {
        print('Contact permission denied.');
      }
    } catch (e) {
      print('Error fetching contacts: $e');
    }

    return contactsMap;
  }





  //Getting of contacting name
  Future<Map<String, String>> _getContactName(String phoneNumber) async {
    try {
      final DocumentSnapshot contactDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(phoneNumber)
          .get();

      if (contactDoc.exists) {
        final contactData = contactDoc.data() as Map<String, dynamic>?;
        final contactName = contactData?['receiverName'] ?? 'Unknown Contact';
        return {'receiverName': contactName, 'number': phoneNumber};
      } else {
        return {'receiverName': 'Unknown Contact', 'number': phoneNumber};
      }
    } catch (e) {
      print('Error fetching contact name: $e');
      return {'receiverName': 'Error', 'number': phoneNumber};
    }
  }


  //gettinfg chat count of current user Chat
  Future<List<String>> _getChatContactNumbersForCurrentUser() async {
    try {
      // Get the current authenticated user
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('No user is currently authenticated.');
        return [];
      }

      // Get the phone number of the current user
      final String currentUserPhoneNumber = currentUser.phoneNumber ?? '';
      print('Current User Phone Number: $currentUserPhoneNumber');

      // Query Firestore to find chats
      final QuerySnapshot chatsSnapshot = await FirebaseFirestore.instance
          .collection('chats') // Ensure 'chats' is the correct collection name
          .get(); // Retrieve all documents

      // List to hold contact numbers of chats where the current user is a participant
      List<String> contactNumbers = [];

      // Process each document
      for (var doc in chatsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?; // Safely cast data to Map
        if (data != null) {
          // Check for participants field
          final participants = data['participants'] as List<dynamic>?; // Ensure participants is a list
          if (participants != null) {
            // Check if the current user is in the participants list
            if (participants.whereType<String>().contains(currentUserPhoneNumber)) {
              // Collect other participants' numbers
              contactNumbers.addAll(participants
                  .whereType<String>() // Filter only strings
                  .where((number) => number != currentUserPhoneNumber)); // Exclude current user's number
              print('Chat Document with current user in participants: ${doc.data()}');
            } else {
              print('Chat Document without current user in participants: ${doc.data()}');
            }
          } else {
            print('Chat Document without participants field: ${doc.data()}');
          }
        } else {
          print('Chat Document without valid data: ${doc.data()}');
        }
      }

      print('Contact numbers in chats where the current user is a participant: $contactNumbers');
      return contactNumbers;
    } catch (e) {
      // Log any errors that occur during the query
      print('Error fetching chat contact numbers: $e');
      return [];
    }
  }



//Checking of current user chats
  Future<void> checkChatsForCurrentUser() async {
    try {
      // Get the current user's phone number
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('No user is currently authenticated.');
        return;
      }

      final phoneNumber = currentUser.phoneNumber ?? '';
      print('Current User Phone Number: $phoneNumber');

      // Fetch chats where the current user is the sender
      final QuerySnapshot chatsSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .where('sender', isEqualTo: phoneNumber)
          .get();

      // Print the number of documents fetched
      print('Number of chat documents where sender matches current user: ${chatsSnapshot.size}');

      // Iterate through the fetched documents and print details
      for (var doc in chatsSnapshot.docs) {
        final chatData = doc.data() as Map<String, dynamic>;
        final sender = chatData['sender'];

        print('Chat Document: ${doc.id}');
        print('Sender in document: $sender');

        if (sender == phoneNumber) {
          print('Match found: Sender number matches the current user.');
        } else {
          print('No match: Sender number does not match the current user.');
        }
      }

    } catch (e) {
      print('Error fetching chats: $e');
    }
  }




  //Chat count of Fetched
  void _fetchChatCount() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('No user is currently authenticated.');
      return;
    }

    final phoneNumber = currentUser.phoneNumber ?? '';
    print('Current User Phone Number: $phoneNumber');

    // Fetch chats where the user is a participant
    // Query for chats where the current user is the sender
    final QuerySnapshot senderChatsSnapshot = await FirebaseFirestore.instance
        .collection('chats')
        .where('sender', isEqualTo: phoneNumber)
        .get();

// Query for chats where the current user is the receiver
    final QuerySnapshot receiverChatsSnapshot = await FirebaseFirestore.instance
        .collection('chats')
        .where('receiver', isEqualTo: phoneNumber)
        .get();

// Combine counts from both queries
    final int chatCount = senderChatsSnapshot.size + receiverChatsSnapshot.size;


    // Print each document to check if data is correct

  }



//Chat count for current User
  Future<int> _getChatCountForCurrentUser() async {
    try {
      // Get the current authenticated user
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('No user is currently authenticated.');
        return 0;
      }

      // Get the phone number of the current user
      final String currentUserPhoneNumber = currentUser.phoneNumber ?? '';
      print('Current User Phone Number: $currentUserPhoneNumber');

      // Query Firestore to find chats
      final QuerySnapshot senderChatsSnapshot = await FirebaseFirestore.instance
          .collection('chats') // Ensure 'chats' is the correct collection name
          .get(); // Retrieve all documents

      // Count and check each document to see if the current user's phone number is in the participants list
      int matchedChatCount = 0;
      for (var doc in senderChatsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?; // Safely cast data to Map
        if (data != null) {
          // Check for participants field
          final participants = data['participants'] as List<dynamic>?; // Ensure participants is a list
          if (participants != null) {
            // Ensure each participant is a string and check if the current user is in the list
            final isCurrentUserInParticipants = participants
                .whereType<String>() // Filter only strings
                .contains(currentUserPhoneNumber);
            if (isCurrentUserInParticipants) {
              matchedChatCount++;
              print('Chat Document with current user in participants: ${doc.data()}');
            } else {
              print('Chat Document without current user in participants: ${doc.data()}');
            }
          } else {
            print('Chat Document without participants field: ${doc.data()}');
          }
        } else {
          print('Chat Document without valid data: ${doc.data()}');
        }
      }

      print('Number of chats where the current user is a participant: $matchedChatCount');
      return matchedChatCount;
    } catch (e) {
      // Log any errors that occur during the query
      print('Error fetching chat count: $e');
      return 0;
    }
  }



//Fetching of contacts
  Future<void> _fetchContacts() async {
    PermissionStatus permission = await Permission.contacts.request();

    if (permission.isGranted) {
      List<Contact> contacts = (await ContactsService.getContacts()).toList();
      setState(() {
        _contacts = contacts;
        _filteredContacts = contacts; // Initialize filtered contacts
      });
    } else {
      print("Contacts permission denied");
    }
  }


  //Showing of Chat Contacts
  Future<void> _showChatCountToast() async {
    try {
      final chatCount = await _getChatCountForCurrentUser();
      Fluttertoast.showToast(
        msg: chatCount > 0
            ? 'You have $chatCount recent chats'
            : 'No recent chats available',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.black,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } catch (e) {
      print('Error showing chat count toast: $e');
    }
  }


  //Not used
  Future<int> _getChatCount() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('No user is currently authenticated.');
        return 0;
      }

      final phoneNumber = currentUser.phoneNumber ?? '';
      print('Current User Phone Number: $phoneNumber');

      // Fetch recent chats from Firestore where the current user is the receiver
      final recentChatsSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .where('receiver', isEqualTo: phoneNumber)
          .get();

      final chatCount = recentChatsSnapshot.size;
      print('Number of recent chats: $chatCount');
      return chatCount;
    } catch (e) {
      print('Error fetching chat count: $e');
      return 0;
    }
  }


  //Filtering of Contacts
  void _filterContacts(String query) {
    setState(() {
      _searchQuery = query;
      _filteredContacts = _contacts.where((contact) {
        final contactName = contact.displayName?.toLowerCase() ?? '';
        final phoneNumber = contact.phones!.isNotEmpty
            ? contact.phones!.first.value?.toLowerCase() ?? ''
            : '';
        final searchQuery = query.toLowerCase();
        return contactName.contains(searchQuery) || phoneNumber.contains(searchQuery);
      }).toList();
    });
  }

  String _normalizePhoneNumber(String phoneNumber) {
    // Add normalization logic if necessary
    return phoneNumber.replaceAll(' ', '').replaceAll('-', '');
  }



//Checking of user regsitartion
  Future<void> _checkUserRegistered(String phoneNumber, String contactName) async {
    try {
      // Normalize the phone number
      String normalizedPhoneNumber = _normalizePhoneNumber(phoneNumber);

      // Log the phone number being checked
      print('Checking phone number: $normalizedPhoneNumber');

      // Fetch user details from Firebase
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(normalizedPhoneNumber)
          .get();

      if (userDoc.exists) {
        // User is registered
        print('User with phone number $normalizedPhoneNumber is registered.');
        final userId = await _getUserIdForCall(); // Fetch the user ID dynamically

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => chatroom(
              contactName: contactName,
              contactPhoneNumber: normalizedPhoneNumber, // Pass the normalized number here
              isAvailable: true, boolisAvailable: null, channelId: '', token: '', userId: userId ,
            ),
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User is available for chat.'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        // User is not registered
        print('User with phone number $normalizedPhoneNumber is not registered.');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('This contact does not have permission to enter the chatroom.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error checking user registration for phone number: $e');
    }
  }

  Future<int> _getUserIdForCall() async {
    // This is just an example. Replace it with your actual logic to fetch the user ID.
    // For example, you might query a database, use a service, or pass it as an argument.
    return 12345; // Replace with your logic to get the user ID
  }





//This for three dot menu on top of right side logout
  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Logout"),
          content: Text("Are you sure you want to logout?"),
          actions: [
            TextButton(
              child: Text("No"),
              onPressed: () {
                Navigator.of(context).pop(); // Dismiss the dialog
              },
            ),
            TextButton(
              child: Text("Yes"),
              onPressed: () {
                FirebaseAuth.instance.signOut().then((_) {
                  Navigator.of(context).pop(); // Dismiss the dialog
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => LoginPage()),
                  );
                });
              },
            ),
          ],
        );
      },
    );
  }
  Future<List<String>> _getMutualContacts() async {
    // Fetch the list of contacts saved by the user
    final user = FirebaseAuth.instance.currentUser;
    final userContactsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user?.uid)
        .collection('contacts')
        .get();

    final userContacts = userContactsSnapshot.docs.map((doc) => doc['phoneNumber'] as String).toList();

    // Fetch the list of contacts for other users
    final otherUsersSnapshot = await FirebaseFirestore.instance.collection('users').get();
    final mutualContacts = <String>[];

    for (var doc in otherUsersSnapshot.docs) {
      final otherUserContacts = List<String>.from(doc['contacts'] as List);
      mutualContacts.addAll(otherUserContacts.where((contact) => userContacts.contains(contact)));
    }

    return mutualContacts.toSet().toList(); // Remove duplicates
  }


  //
  Future<void> _fetchContactsAndStories() async {
    final mutualContacts = await _getMutualContacts();

    if (mutualContacts.isEmpty) {
      setState(() {
        _storyContacts = []; // No mutual contacts, so no stories
      });
      return;
    }

    // Fetch stories for mutual contacts
    final storiesSnapshot = await FirebaseFirestore.instance
        .collection('stories')
        .where('phoneNumber', whereIn: mutualContacts)
        .get();

    final storyContacts = storiesSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'name': data['name'] as String,
        'storyUrl': data['storyUrl'] as String,
      };
    }).toList();

    setState(() {
      _storyContacts = storyContacts;
    });
  }



  //
  Widget _buildStoryItem(String name, String url) {
    return Container(
      width: 80.0,
      padding: EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 30.0,
            backgroundImage: url.isNotEmpty
                ? NetworkImage(url)
                : AssetImage('images/profilechat.png') as ImageProvider,
          ),
          SizedBox(height: 4.0),
          Text(
            name,
            style: TextStyle(
              fontSize: 14.0,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }





  Future<List<Map<String, String>>> _fetchMutualStories(BuildContext context) async {
    try {
      // Request permission to access contacts
      if (await Permission.contacts.request().isGranted) {
        // Fetch the contacts from the device
        Iterable<Contact> contacts = await ContactsService.getContacts();

        // Extract phone numbers from contacts
        Set contactNumbers = contacts
            .expand((contact) => contact.phones ?? [])
            .map((phone) => phone.value?.replaceAll(RegExp(r'\D'), '') ?? '')
            .toSet();

        // Debug: Print the list of contact numbers
        print('Contact Numbers: $contactNumbers');

        // Query Firestore to get the stories
        QuerySnapshot<Map<String, dynamic>> storiesSnapshot = await FirebaseFirestore.instance
            .collection('stories')
            .orderBy('timestamp', descending: true)
            .get();

        // Filter and process the snapshot to extract the data
        List<Map<String, String>> stories = storiesSnapshot.docs
            .where((doc) {
          String? phoneNumber = doc.data()['phoneNumber'] as String?;
          phoneNumber = phoneNumber?.replaceAll(RegExp(r'\D'), '');

          // Debug: Print each phone number from Firestore
          print('Checking story with phone number: $phoneNumber');

          return phoneNumber != null && contactNumbers.contains(phoneNumber);
        })
            .map((doc) {
          return {
            'name': doc.data()['nickname'] as String? ?? 'Unknown',
            'storyUrl': doc.data()['mediaUrl'] as String? ?? '',
          };
        })
            .toList();

        return stories;
      } else {
        print('Contacts permission denied');
        return [];
      }
    } catch (e) {
      print('Error fetching stories: $e');
      return [];
    }
  }





// Example implementation of getDeviceContacts (adjust according to your needs)
  Future<List<String>> getDeviceContacts() async {
    // Use contacts_service or any other method to fetch device contacts
    final contacts = await ContactsService.getContacts();
    return contacts.map((contact) => contact.phones?.first?.value ?? '').toList();
  }



// Example implementation of getDeviceContacts (adjust according to your needs)




  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // Adjusted for the 3 tabs: Chat, Contacts, Group
      child: Scaffold(
        appBar: AppBar(
          title: Text('Chat'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Chat'),
              Tab(text: 'Contacts'),
              Tab(text: 'Group'), // New Group tab
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.search),
              onPressed: () {
                showSearch(
                  context: context,
                  delegate: ContactSearchDelegate(
                    allContacts: _filteredContacts,
                    onSearch: _filterContacts,
                    normalizePhoneNumber: _normalizePhoneNumber,
                    checkUserRegistered: _checkUserRegistered,
                  ),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.qr_code_scanner),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ScannerPage(),
                  ),
                );
              },
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.person, size: 36),
              onSelected: (String value) {
                if (value == 'profile') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfilePage(
                        userPhoneNumber: FirebaseAuth.instance.currentUser?.phoneNumber ?? '',
                      ),
                    ),
                  );
                } else if (value == 'story') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StoryPage(),
                    ),
                  );
                } else if (value == 'logout') {
                  _showLogoutConfirmationDialog();
                }
              },
              itemBuilder: (BuildContext context) {
                return [
                  PopupMenuItem(value: 'profile', child: Text('Profile')),
                  PopupMenuItem(value: 'story', child: Text('Story')),
                  PopupMenuItem(value: 'logout', child: Text('Logout')),
                ];
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // CircularImageView and HorizontalScrollView with ListView
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StoryViewPage(
                            storyUrl: _storyUrl ?? '', name: '', // Pass the story URL or other necessary data
                          ),
                        ),
                      );
                    },
                    child: CircleAvatar(
                      radius: 30.0,
                      backgroundImage: _storyUrl != null
                          ? NetworkImage(_storyUrl!)
                          : AssetImage('images/profilechat.png') as ImageProvider,
                    ),
                  ),
                  SizedBox(width: 16.0),
                  Expanded(
                    child: Container(
                      height: 120.0,
                      padding: const EdgeInsets.only(top: 20.0),
                      child: FutureBuilder<List<Map<String, String>>>(
                        future: _fetchMutualStories(context),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          } else if (snapshot.hasError) {
                            return Center(child: Text('Error fetching stories.'));
                          } else {
                            final stories = snapshot.data ?? [];
                            return stories.isEmpty
                                ? Center(child: Text('No stories available'))
                                : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: stories.length,
                              itemBuilder: (context, index) {
                                final story = stories[index];
                                final name = story['name'] ?? 'Unknown';
                                final url = story['storyUrl'] ?? '';

                                return InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => StoryViewPage(
                                          storyUrl: url,
                                          name: name,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 80.0,
                                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                                    child: Column(
                                      children: [
                                        CircleAvatar(
                                          radius: 30.0,
                                          backgroundImage: url.isNotEmpty
                                              ? NetworkImage(url)
                                              : AssetImage('images/profilechat.png') as ImageProvider,
                                        ),
                                        SizedBox(height: 4.0),
                                        Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: 14.0,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Expanded TabBarView containing Chat, Contacts, and Group tabs
            Expanded(
              child: TabBarView(
                children: [
                  // Chat Tab
                  FutureBuilder<List<Map<String, String>>>(
                    future: _getChatContactsForCurrentUser(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Center(child: Text('Error fetching chat contacts.'));
                      } else {
                        final chatContacts = snapshot.data ?? [];
                        return chatContacts.isEmpty
                            ? Center(child: Text('No recent chats available'))
                            : ListView.builder(
                          itemCount: chatContacts.length,
                          itemBuilder: (context, index) {
                            final contact = chatContacts[index];
                            final contactNumber = contact['number'] ?? '';
                            final contactName = contact['contactName'] ?? 'Unknown Contact';
                            final contactImageUrl = ''; // Replace with actual image URL or asset

                            final Timestamp? timestamp = contact['lastMessageTimestamp'] as Timestamp?;

                            final String formattedTime = timestamp != null
                                ? DateFormat('dd MMM yyyy, hh:mm a').format(timestamp.toDate())
                                : 'Recent Time';

                            return ListTile(
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 8.0, horizontal: 16.0),
                              leading: CircleAvatar(
                                backgroundImage: contactImageUrl.isNotEmpty
                                    ? NetworkImage(contactImageUrl)
                                    : AssetImage('images/profilechat.png') as ImageProvider<Object>,
                                radius: 24.0,
                              ),
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          contactName,
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (formattedTime.isNotEmpty)
                                        Text(
                                          formattedTime,
                                          style: TextStyle(color: Colors.grey, fontSize: 12.0),
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: 4.0),
                                  Text(contactNumber, style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => chatroom(
                                      contactName: contactName,
                                      contactPhoneNumber: contactNumber,
                                      isAvailable: true,
                                      boolisAvailable: null, channelId: '', token: '', userId: 1234,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      }
                    },
                  ),
                  // Contacts Tab
                  _filteredContacts.isEmpty
                      ? Center(child: CircularProgressIndicator())
                      : ListView.builder(
                    itemCount: _filteredContacts.length,
                    itemBuilder: (context, index) {
                      Contact contact = _filteredContacts[index];
                      return GestureDetector(
                        onTap: () {
                          String phoneNumber = contact.phones!.isNotEmpty
                              ? contact.phones!.first.value ?? ''
                              : '';

                          if (phoneNumber.isNotEmpty) {
                            phoneNumber = _normalizePhoneNumber(phoneNumber);
                            _checkUserRegistered(phoneNumber, contact.displayName ?? 'No Name');
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('This contact has no phone number.'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              (contact.avatar != null && contact.avatar!.isNotEmpty)
                                  ? CircleAvatar(
                                backgroundImage: MemoryImage(contact.avatar!),
                                radius: 25,
                              )
                                  : CircleAvatar(
                                child: Text(contact.initials()),
                                radius: 25,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      contact.displayName ?? 'No Name',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      contact.phones!.isNotEmpty
                                          ? contact.phones!.first.value ?? 'No Phone'
                                          : 'No Phone',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  // Group Tab
                  Center(child: Text('Group Feature Coming Soon')), // Placeholder for the Group tab
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ContactSearchDelegate extends SearchDelegate {
  final List<Contact> allContacts;
  final Function(String) onSearch;
  final String Function(String) normalizePhoneNumber;
  final Future<void> Function(String, String) checkUserRegistered;

  ContactSearchDelegate({
    required this.allContacts,
    required this.onSearch,
    required this.normalizePhoneNumber,
    required this.checkUserRegistered,
  });

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
          onSearch(query);
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final List<Contact> results = allContacts.where((contact) {
      final contactName = contact.displayName?.toLowerCase() ?? '';
      final phoneNumber = contact.phones!.isNotEmpty
          ? contact.phones!.first.value?.toLowerCase() ?? ''
          : '';
      final searchQuery = query.toLowerCase();
      return contactName.contains(searchQuery) ||
          phoneNumber.contains(searchQuery);
    }).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final contact = results[index];
        return ListTile(
          leading: (contact.avatar != null && contact.avatar!.isNotEmpty)
              ? CircleAvatar(
            backgroundImage: MemoryImage(contact.avatar!),
            radius: 25,
          )
              : CircleAvatar(
            child: Text(contact.initials()),
            radius: 25,
          ),
          title: Text(contact.displayName ?? 'No Name'),
          subtitle: Text(contact.phones!.isNotEmpty
              ? contact.phones!.first.value ?? 'No Phone'
              : 'No Phone'),
          onTap: () {
            String phoneNumber = contact.phones!.isNotEmpty
                ? contact.phones!.first.value ?? ''
                : '';

            if (phoneNumber.isNotEmpty) {
              phoneNumber = normalizePhoneNumber(phoneNumber);
              checkUserRegistered(
                  phoneNumber, contact.displayName ?? 'No Name');
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('This contact has no phone number.'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final List<Contact> suggestions = allContacts.where((contact) {
      final contactName = contact.displayName?.toLowerCase() ?? '';
      final phoneNumber = contact.phones!.isNotEmpty
          ? contact.phones!.first.value?.toLowerCase() ?? ''
          : '';
      final searchQuery = query.toLowerCase();
      return contactName.contains(searchQuery) ||
          phoneNumber.contains(searchQuery);
    }).toList();

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final contact = suggestions[index];
        return ListTile(
          leading: (contact.avatar != null && contact.avatar!.isNotEmpty)
              ? CircleAvatar(
            backgroundImage: MemoryImage(contact.avatar!),
            radius: 25,
          )
              : CircleAvatar(
            child: Text(contact.initials()),
            radius: 25,
          ),
          title: Text(contact.displayName ?? 'No Name'),
          subtitle: Text(contact.phones!.isNotEmpty
              ? contact.phones!.first.value ?? 'No Phone'
              : 'No Phone'),
          onTap: () {
            String phoneNumber = contact.phones!.isNotEmpty
                ? contact.phones!.first.value ?? ''
                : '';

            if (phoneNumber.isNotEmpty) {
              phoneNumber = normalizePhoneNumber(phoneNumber);
              checkUserRegistered(
                  phoneNumber, contact.displayName ?? 'No Name');
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('This contact has no phone number.'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
        );
      },
    );
  }

}