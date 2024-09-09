import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:contacts_service/contacts_service.dart';

class ScannerPage extends StatefulWidget {
  @override
  _ScannerPageState createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  QRViewController? controller;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('QR Code Scanner')),
      body: Stack(
        children: [
          QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: Colors.red,
              borderRadius: 10,
              borderLength: 30,
              borderWidth: 10,
              cutOutSize: MediaQuery.of(context).size.width * 0.7,
            ),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Scan a QR code',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onQRViewCreated(QRViewController qrController) {
    setState(() {
      controller = qrController;
    });

    qrController.scannedDataStream.listen((scanData) async {
      final String? scannedData = scanData.code;

      if (scannedData != null) {
        // Parsing the QR code data
        final dataLines = scannedData.split('\n');
        String name = '';
        String mobile = '';

        for (var line in dataLines) {
          if (line.startsWith('Name:')) {
            name = line.substring('Name:'.length).trim();
          } else if (line.startsWith('Mobile:')) {
            mobile = line.substring('Mobile:'.length).trim();
          }
        }

        // Check contact permission status
        var status = await Permission.contacts.status;

        if (!status.isGranted) {
          // Request permission if not already granted
          status = await Permission.contacts.request();
        }

        // Handle permission denied scenario
        if (status.isDenied) {
          _showPermissionDeniedDialog(context);
          return;
        }

        // Handle permission permanently denied scenario
        if (status.isPermanentlyDenied) {
          _showPermissionPermanentlyDeniedDialog(context);
          return;
        }

        // If permission is granted, save the contact
        if (status.isGranted) {
          if (name.isNotEmpty && mobile.isNotEmpty) {
            final newContact = Contact(
              givenName: name,
              phones: [Item(label: 'mobile', value: mobile)],
            );

            await ContactsService.addContact(newContact);

            // Pause the scanner before showing the dialog
            await controller?.pauseCamera();

            // Show dialog instead of SnackBar
            _showContactSavedDialog(context, name);
          } else {
            _showInvalidQRCodeDialog(context);
          }
        }
      }
    });
  }

  void _showContactSavedDialog(BuildContext context, String name) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Center(child: Text('Contact Saved')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Contact $name saved successfully.',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20), // Space between the message and the button
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Resume the camera after the dialog is dismissed
                    controller?.resumeCamera();
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white, backgroundColor: Color(0xFF000080), // White text color
                  ),
                  child: Text('OK'),
                ),
              ),
            ],
          ),
        );
      },



    );
  }

  void _showPermissionDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Permission Denied'),
          content: Text('Contact permission is required to save the contact.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Resume the camera after the dialog is dismissed
                controller?.resumeCamera();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showPermissionPermanentlyDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Permission Permanently Denied'),
          content: Text('Contact permission is permanently denied, please enable it from settings.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Resume the camera after the dialog is dismissed
                controller?.resumeCamera();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showInvalidQRCodeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Invalid QR Code'),
          content: Text('Invalid QR code format.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Resume the camera after the dialog is dismissed
                controller?.resumeCamera();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
