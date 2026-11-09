import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class CoachFeeVerificationScreen extends StatefulWidget {
  const CoachFeeVerificationScreen({super.key});

  @override
  State<CoachFeeVerificationScreen> createState() => _CoachFeeVerificationScreenState();
}

class _CoachFeeVerificationScreenState extends State<CoachFeeVerificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Show Dialog to Edit Coach Bank Details
  void _showEditBankDetailsDialog(BuildContext context, Map<String, dynamic> currentData) {
    final bankNameController = TextEditingController(text: currentData['bankName'] ?? '');
    final accountTitleController = TextEditingController(text: currentData['accountTitle'] ?? '');
    final accountNumberController = TextEditingController(text: currentData['accountNumber'] ?? '');
    final ibanController = TextEditingController(text: currentData['ibn'] ?? currentData['iban'] ?? '');
    final mobileAccountController = TextEditingController(text: currentData['easypaisaJazzcash'] ?? currentData['mobileAccount'] ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Edit Coach Bank Details',
              style: GoogleFonts.sourceSerif4(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: bankNameController,
                    enabled: !isSaving,
                    decoration: const InputDecoration(labelText: 'Bank Name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: accountTitleController,
                    enabled: !isSaving,
                    decoration: const InputDecoration(labelText: 'Account Title'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: accountNumberController,
                    enabled: !isSaving,
                    decoration: const InputDecoration(labelText: 'Account Number'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: ibanController,
                    enabled: !isSaving,
                    decoration: const InputDecoration(labelText: 'IBAN (Optional)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: mobileAccountController,
                    enabled: !isSaving,
                    decoration: const InputDecoration(labelText: 'JazzCash / Easypaisa Number & Name'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                child: Text('Cancel', style: GoogleFonts.sourceSans3(color: Colors.grey.shade700)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC85A32),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        setDialogState(() => isSaving = true);
                        try {
                          await FirebaseFirestore.instance
                              .collection('settings')
                              .doc('bank_details')
                              .set({
                            'bankName': bankNameController.text.trim(),
                            'accountTitle': accountTitleController.text.trim(),
                            'accountNumber': accountNumberController.text.trim(),
                            'ibn': ibanController.text.trim(),
                            'easypaisaJazzcash': mobileAccountController.text.trim(),
                            'updatedAt': FieldValue.serverTimestamp(),
                          }, SetOptions(merge: true));

                          if (context.mounted) {
                            Navigator.pop(dialogCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Bank details updated successfully!'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to update bank details: $e'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCoachBankDetailsCard() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('settings').doc('bank_details').snapshots(),
      builder: (context, snapshot) {
        final data = (snapshot.hasData && snapshot.data!.exists)
            ? (snapshot.data!.data() as Map<String, dynamic>)
            : <String, dynamic>{
                'bankName': 'Meezan Bank / Alfalah',
                'accountTitle': 'Warrior Coach',
                'accountNumber': '0123-987654321-01',
                'ibn': 'PK36MEZN0000009876543201',
                'easypaisaJazzcash': '0300-1234567 (Coach Name)',
              };

        final bankName = data['bankName'] ?? 'Bank Name';
        final accountTitle = data['accountTitle'] ?? 'Account Title';
        final accountNumber = data['accountNumber'] ?? 'Account Number';
        final iban = data['ibn'] ?? data['iban'] ?? '';
        final mobileAccount = data['easypaisaJazzcash'] ?? data['mobileAccount'] ?? '';

        return Card(
          elevation: 0,
          color: const Color(0xFFFBF9F5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: const Color(0xFFC85A32).withValues(alpha: 0.3), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance_rounded, color: Color(0xFFC85A32), size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Your Bank & Payment Details',
                          style: GoogleFonts.sourceSans3(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: const Color(0xFF1A2F25),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20, color: Color(0xFFC85A32)),
                      tooltip: 'Edit Bank Details',
                      onPressed: () => _showEditBankDetailsDialog(context, data),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Divider(height: 1),
                const SizedBox(height: 10),
                _buildDetailRow('Bank:', bankName),
                _buildDetailRow('Account Title:', accountTitle),
                _buildDetailRow('Account No / IBAN:', accountNumber),
                if (iban.isNotEmpty && iban != accountNumber)
                  _buildDetailRow('IBAN:', iban),
                if (mobileAccount.isNotEmpty)
                  _buildDetailRow('JazzCash / Easypaisa:', mobileAccount),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: GoogleFonts.sourceSans3(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.sourceSans3(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A2F25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Delete Challan Confirmation & Action
  Future<void> _deleteChallan(BuildContext context, String challanId, String month, String childName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Challan',
          style: GoogleFonts.sourceSerif4(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete the fee challan for "$month • $childName"? This action cannot be undone.',
          style: GoogleFonts.sourceSans3(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text('Cancel', style: GoogleFonts.sourceSans3(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Delete', style: GoogleFonts.sourceSans3(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('fee_challans').doc(challanId).delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Challan deleted successfully.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete challan: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  // Launch WhatsApp with pre-filled message
  Future<void> _sendWhatsAppReminder({
    required BuildContext context,
    required String? parentId,
    required String parentName,
    required String childName,
    required String month,
    required String dueDateStr,
  }) async {
    String phone = '';

    if (parentId != null && parentId.isNotEmpty) {
      try {
        final parentDoc = await FirebaseFirestore.instance.collection('users').doc(parentId).get();
        if (parentDoc.exists) {
          final parentData = parentDoc.data();
          phone = (parentData?['phone'] ?? parentData?['phoneNumber'] ?? '').toString();
        }
      } catch (e) {
        debugPrint('Error fetching parent phone: $e');
      }
    }

    final cleanedPhone = phone.replaceAll(RegExp(r'[^\d]'), '');

    if (cleanedPhone.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parent phone number is not available or invalid.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final message = "Hi $parentName, this is Coach. A quick reminder that the fee payment for "
        "$childName for $month was due on $dueDateStr and is currently pending. "
        "Please upload the receipt in the app once paid. Thank you!";

    final encodedMessage = Uri.encodeComponent(message);
    final whatsappUri = Uri.parse("whatsapp://send?phone=$cleanedPhone&text=$encodedMessage");
    final webUri = Uri.parse("https://wa.me/$cleanedPhone?text=$encodedMessage");

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('WhatsApp is not installed on this device.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open WhatsApp: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Fullscreen enlarged image view on tap
  void _showEnlargedImage(BuildContext context, String base64Str) {
    final cleanBase64 = base64Str.contains(',') ? base64Str.split(',').last : base64Str;

    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.black.withOpacity(0.9),
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.memory(
                  base64Decode(cleanBase64),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(dialogCtx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verifyPayment(BuildContext context, String challanId, Map<String, dynamic> data, bool accept) async {
    final firestore = FirebaseFirestore.instance;

    await firestore.collection('fee_challans').doc(challanId).update({
      'status': accept ? 'paid' : 'unpaid',
      'verifiedAt': FieldValue.serverTimestamp(),
    });

    final String? parentId = data['parentId'];
    final String? childName = data['childName'];

    if (parentId != null && childName != null) {
      final childrenQuery = await firestore
          .collection('children')
          .where('parentId', isEqualTo: parentId)
          .where('name', isEqualTo: childName)
          .get();

      for (var doc in childrenQuery.docs) {
        await doc.reference.update({
          'feeStatus': accept ? 'paid' : 'due',
        });
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? 'Payment accepted & marked as PAID.' : 'Receipt rejected.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Bulk Issue Fee Challan to All Registered Warriors
  Future<void> _sendChallanToAllWarriors({
    required BuildContext context,
    required BuildContext dialogCtx,
    required String month,
    required double amount,
    required StateSetter setDialogState,
  }) async {
    setDialogState(() => isIssuing = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final childrenQuery = await firestore.collection('children').get();

      if (childrenQuery.docs.isEmpty) {
        if (context.mounted) {
          setDialogState(() => isIssuing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No registered warriors found in the database.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final batch = firestore.batch();
      final now = DateTime.now();
      final dueDate = now.add(const Duration(days: 10));

      for (var cDoc in childrenQuery.docs) {
        final cData = cDoc.data();
        final childName = (cData['name'] ?? 'Warrior').toString();
        final parentId = cData['parentId'] as String?;
        final parentName = (cData['parentName'] ?? 'Parent').toString();

        final challanRef = firestore.collection('fee_challans').doc();
        batch.set(challanRef, {
          'parentId': parentId,
          'parentName': parentName,
          'childName': childName,
          'month': month,
          'year': now.year,
          'amount': amount,
          'status': 'unpaid',
          'issuedAt': Timestamp.fromDate(now),
          'dueDate': Timestamp.fromDate(dueDate),
          'createdAt': FieldValue.serverTimestamp(),
          'receiptBase64': '',
        });

        batch.update(cDoc.reference, {'feeStatus': 'due'});
      }

      await batch.commit();

      if (context.mounted) {
        Navigator.pop(dialogCtx);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fee challan issued to all ${childrenQuery.docs.length} warriors!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setDialogState(() => isIssuing = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to issue to all: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  bool isIssuing = false;

  void _showIssueChallanDialog(BuildContext context) {
    String? selectedParentId;
    String? selectedParentName;
    String? selectedChildName;
    isIssuing = false;
    final monthController = TextEditingController(text: DateFormat('MMMM yyyy').format(DateTime.now()));
    final amountController = TextEditingController(text: '5000');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Issue Fee Challan',
              style: GoogleFonts.sourceSerif4(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Parent',
                    style: GoogleFonts.sourceSans3(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const LinearProgressIndicator(color: Color(0xFFC85A32));
                      }

                      final parents = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final role = (data['role'] ?? '').toString().toLowerCase();
                        return role == 'parent' || role.isEmpty;
                      }).toList();

                      return DropdownButtonFormField<String>(
                        value: selectedParentId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          hintText: 'Choose Parent',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        items: parents.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final name = (data['fullName'] ?? data['name'] ?? 'Parent (${doc.id.substring(0, 5)})').toString();
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(name, style: GoogleFonts.sourceSans3()),
                          );
                        }).toList(),
                        onChanged: isIssuing
                            ? null
                            : (val) {
                                if (val == null) return;
                                final parentDoc = parents.firstWhere((d) => d.id == val);
                                final pData = parentDoc.data() as Map<String, dynamic>;
                                final pName = (pData['fullName'] ?? pData['name'] ?? 'Parent').toString();

                                setDialogState(() {
                                  selectedParentId = val;
                                  selectedParentName = pName;
                                  selectedChildName = null;
                                });
                              },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Select Warrior Child',
                    style: GoogleFonts.sourceSans3(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  if (selectedParentId == null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        'Please select a parent first',
                        style: GoogleFonts.sourceSans3(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    )
                  else
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('children')
                          .where('parentId', isEqualTo: selectedParentId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const LinearProgressIndicator(color: Color(0xFFC85A32));
                        }

                        final childDocs = snapshot.data?.docs ?? [];

                        if (childDocs.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Text(
                              'No registered warrior children found for this parent.',
                              style: GoogleFonts.sourceSans3(color: Colors.orange.shade900, fontSize: 13),
                            ),
                          );
                        }

                        return DropdownButtonFormField<String>(
                          value: selectedChildName,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            hintText: 'Choose Warrior Child',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          items: childDocs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final childName = (data['name'] ?? 'Warrior').toString();
                            return DropdownMenuItem<String>(
                              value: childName,
                              child: Text(childName, style: GoogleFonts.sourceSans3()),
                            );
                          }).toList(),
                          onChanged: isIssuing
                              ? null
                              : (val) {
                                  setDialogState(() {
                                    selectedChildName = val;
                                  });
                                },
                        );
                      },
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: monthController,
                    enabled: !isIssuing,
                    decoration: const InputDecoration(
                      labelText: 'Billing Month',
                      hintText: 'e.g. November 2026',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    enabled: !isIssuing,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount (PKR)',
                    ),
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            actions: [
              Row(
                children: [
                  TextButton(
                    onPressed: isIssuing ? null : () => Navigator.pop(dialogCtx),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.sourceSans3(color: Colors.grey.shade700),
                    ),
                  ),
                  const Spacer(),
                  // Send to All Button
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC85A32),
                      side: const BorderSide(color: Color(0xFFC85A32)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    onPressed: isIssuing
                        ? null
                        : () {
                            final month = monthController.text.trim();
                            final amount = double.tryParse(amountController.text.trim()) ?? 5000.0;

                            if (month.isNotEmpty) {
                              _sendChallanToAllWarriors(
                                context: context,
                                dialogCtx: dialogCtx,
                                month: month,
                                amount: amount,
                                setDialogState: setDialogState,
                              );
                            }
                          },
                    child: Text(
                      'Send to All',
                      style: GoogleFonts.sourceSans3(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Issue Challan Button
                  ElevatedButton(
                    onPressed: (selectedParentId == null || selectedChildName == null || isIssuing)
                        ? null
                        : () async {
                            final month = monthController.text.trim();
                            final amount = double.tryParse(amountController.text.trim()) ?? 5000.0;
                            final now = DateTime.now();
                            final dueDate = now.add(const Duration(days: 10));

                            if (month.isNotEmpty) {
                              setDialogState(() {
                                isIssuing = true;
                              });

                              try {
                                await FirebaseFirestore.instance.collection('fee_challans').add({
                                  'parentId': selectedParentId,
                                  'parentName': selectedParentName ?? 'Parent',
                                  'childName': selectedChildName,
                                  'month': month,
                                  'year': now.year,
                                  'amount': amount,
                                  'status': 'unpaid',
                                  'issuedAt': Timestamp.fromDate(now),
                                  'dueDate': Timestamp.fromDate(dueDate),
                                  'createdAt': FieldValue.serverTimestamp(),
                                  'receiptBase64': '',
                                });

                                final childQuery = await FirebaseFirestore.instance
                                    .collection('children')
                                    .where('parentId', isEqualTo: selectedParentId)
                                    .where('name', isEqualTo: selectedChildName)
                                    .get();

                                for (var cDoc in childQuery.docs) {
                                  await cDoc.reference.update({'feeStatus': 'due'});
                                }

                                if (context.mounted) {
                                  Navigator.pop(dialogCtx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Fee challan issued successfully!'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setDialogState(() {
                                  isIssuing = false;
                                });
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to issue challan: $e'),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B3B2B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: isIssuing
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Issue Challan',
                            style: GoogleFonts.sourceSans3(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Fee Management',
          style: GoogleFonts.sourceSerif4(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFC85A32),
          labelColor: const Color(0xFFC85A32),
          unselectedLabelColor: Colors.grey.shade700,
          labelStyle: GoogleFonts.sourceSans3(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Unpaid'),
            Tab(text: 'Pending Approval'),
            Tab(text: 'Paid'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChallanList(statusFilter: 'unpaid'),
          _buildChallanList(statusFilter: 'pending'),
          _buildChallanList(statusFilter: 'paid'),
        ],
      ),
    );
  }

  Widget _buildChallanList({required String statusFilter}) {
    final colors = Theme.of(context).colorScheme;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('fee_challans').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFC85A32)));
        }

        final docs = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final rawStatus = (data['status'] ?? 'unpaid').toString().toLowerCase();

          if (statusFilter == 'pending') {
            return rawStatus == 'pending' ||
                rawStatus == 'pending_approval' ||
                rawStatus == 'pending_review';
          } else if (statusFilter == 'unpaid') {
            return rawStatus == 'unpaid' || rawStatus == 'due';
          } else {
            return rawStatus == 'paid';
          }
        }).toList();

        final dateFormat = DateFormat('MMM d, yyyy');

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildCoachBankDetailsCard(),
            const SizedBox(height: 12),
            // Issue New Challan Button Card
            Card(
              elevation: 0,
              color: const Color(0xFF1B3B2B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showIssueChallanDialog(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_card, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Issue New Challan',
                        style: GoogleFonts.sourceSans3(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (docs.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 32.0),
                  child: Text(
                    'No $statusFilter fee challans.',
                    style: GoogleFonts.sourceSans3(
                      fontSize: 15,
                      color: colors.primary.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              )
            else
              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final docId = doc.id;
                final month = data['month'] ?? 'Monthly Fee';
                final childName = data['childName'] ?? 'Warrior';
                final parentName = data['parentName'] ?? 'Parent';
                final parentId = data['parentId'] as String?;
                final amount = data['amount'] ?? 0;
                final rawStatus = (data['status'] ?? 'unpaid').toString().toLowerCase();
                final isPending = rawStatus == 'pending' ||
                    rawStatus == 'pending_approval' ||
                    rawStatus == 'pending_review';
                final isPaid = rawStatus == 'paid';
                final isUnpaid = !isPaid && !isPending;

                final receiptBase64 = (data['receiptBase64'] ?? data['photoBase64']) as String?;

                final Timestamp? issuedTs = data['issuedAt'] as Timestamp?;
                final Timestamp? dueTs = data['dueDate'] as Timestamp?;
                final issueDateStr = issuedTs != null ? dateFormat.format(issuedTs.toDate()) : 'N/A';
                final dueDateStr = dueTs != null ? dateFormat.format(dueTs.toDate()) : 'N/A';

                final bool isOverdue = isUnpaid && dueTs != null && DateTime.now().isAfter(dueTs.toDate());

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: colors.primary.withValues(alpha: 0.15)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$month • $childName',
                                      style: GoogleFonts.sourceSans3(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                      ),
                                    ),
                                    Text(
                                      'Parent: $parentName',
                                      style: GoogleFonts.sourceSans3(
                                        fontSize: 13,
                                        color: colors.primary.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isPaid
                                          ? Colors.green.withValues(alpha: 0.15)
                                          : (isPending
                                              ? Colors.orange.withValues(alpha: 0.15)
                                              : Colors.red.withValues(alpha: 0.15)),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isPaid
                                          ? 'PAID'
                                          : (isPending ? 'PENDING APPROVAL' : (isOverdue ? 'OVERDUE' : 'UNPAID')),
                                      style: GoogleFonts.sourceSans3(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: isPaid
                                            ? Colors.green.shade800
                                            : (isPending
                                                ? Colors.orange.shade800
                                                : Colors.red.shade800),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                    tooltip: 'Delete Challan',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _deleteChallan(context, docId, month, childName),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Amount: PKR $amount', style: GoogleFonts.sourceSans3(fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text('Issue Date: $issueDateStr', style: GoogleFonts.sourceSans3(fontSize: 12, color: Colors.grey.shade700)),
                              const SizedBox(width: 16),
                              Text('Due Date: $dueDateStr', style: GoogleFonts.sourceSans3(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFC85A32))),
                            ],
                          ),
                          if (receiptBase64 != null && receiptBase64.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () => _showEnlargedImage(context, receiptBase64),
                              child: Stack(
                                alignment: Alignment.topRight,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      base64Decode(receiptBase64.contains(',')
                                          ? receiptBase64.split(',').last
                                          : receiptBase64),
                                      height: 180,
                                      width: double.infinity,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.all(8),
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.fullscreen, color: Colors.white, size: 20),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (isPending) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _verifyPayment(context, docId, data, false),
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                    child: const Text('Reject Receipt'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _verifyPayment(context, docId, data, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Accept Payment'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (isUnpaid) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _sendWhatsAppReminder(
                                  context: context,
                                  parentId: parentId,
                                  parentName: parentName,
                                  childName: childName,
                                  month: month,
                                  dueDateStr: dueDateStr,
                                ),
                                icon: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                                label: Text(
                                  'Send WhatsApp Reminder',
                                  style: GoogleFonts.sourceSans3(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF25D366),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}