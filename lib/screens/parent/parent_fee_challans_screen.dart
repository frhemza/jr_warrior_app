import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

const Color kDeepOlive = Color(0xFF1A2F25);
const Color kWarmCream = Color(0xFFFBF9F5);
const Color kTerracotta = Color(0xFFC85A32);

class ParentFeeChallansScreen extends StatefulWidget {
  const ParentFeeChallansScreen({super.key});

  @override
  State<ParentFeeChallansScreen> createState() => _ParentFeeChallansScreenState();
}

class _ParentFeeChallansScreenState extends State<ParentFeeChallansScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _uploadReceipt(String challanId) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 80,
    );

    if (image == null) return;

    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);

    await FirebaseFirestore.instance
        .collection('fee_challans')
        .doc(challanId)
        .update({
      'receiptBase64': base64Image,
      'status': 'pending',
      'submittedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment receipt submitted! Status set to PENDING.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _removeSubmission(String challanId) async {
    try {
      await FirebaseFirestore.instance
          .collection('fee_challans')
          .doc(challanId)
          .update({
        'receiptBase64': FieldValue.delete(),
        'photoBase64': FieldValue.delete(),
        'status': 'unpaid',
        'submittedAt': FieldValue.delete(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Submission removed. Challan status is now UNPAID.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove submission: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied $label to clipboard!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showBankDetailsPopup(BuildContext context, String allDetailsText) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kWarmCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_outlined, color: kTerracotta, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Coach Bank & Payment Details',
                  style: GoogleFonts.sourceSans3(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kDeepOlive,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close, color: kDeepOlive, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tap and hold to select specific lines or copy details below:',
              style: GoogleFonts.sourceSans3(
                fontSize: 12,
                color: kDeepOlive.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kDeepOlive.withOpacity(0.12)),
              ),
              child: SelectableText(
                allDetailsText,
                style: GoogleFonts.sourceSans3(
                  fontSize: 14,
                  height: 1.5,
                  color: kDeepOlive,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: kTerracotta,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.copy, size: 16),
            label: Text(
              'Copy All',
              style: GoogleFonts.sourceSans3(fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: allDetailsText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All bank details copied to clipboard!'),
                  backgroundColor: kDeepOlive,
                  duration: Duration(seconds: 2),
                ),
              );
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCoachBankDetailsCard() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('settings')
          .doc('bank_details')
          .snapshots(),
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

        final String allDetailsText = '''
Bank: $bankName
Account Title: $accountTitle
Account No / IBAN: $accountNumber
${iban.isNotEmpty && iban != accountNumber ? 'IBAN: $iban\n' : ''}${mobileAccount.isNotEmpty ? 'JazzCash / Easypaisa: $mobileAccount' : ''}
'''.trim();

        return GestureDetector(
          onTap: () => _showBankDetailsPopup(context, allDetailsText),
          child: Container(
            decoration: BoxDecoration(
              color: kWarmCream,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kTerracotta.withValues(alpha: 0.4), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: kTerracotta.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 0),
                ),
              ],
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
                            'Coach Bank & Payment Details',
                            style: GoogleFonts.sourceSans3(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: const Color(0xFF1A2F25),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.copy_rounded, size: 14, color: Color(0xFFC85A32)),
                          const SizedBox(width: 4),
                          Text(
                            'Tap to View / Select',
                            style: GoogleFonts.sourceSans3(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: const Color(0xFFC85A32),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
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
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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

  Widget _buildFeeStatusSummaryCard(List<QueryDocumentSnapshot> docs) {
    bool isAllPaid = docs.isNotEmpty && docs.every((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return (data['status'] ?? '').toString().toLowerCase() == 'paid';
    });

    return Card(
      elevation: 0,
      color: isAllPaid ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isAllPaid ? Colors.green.shade300 : Colors.orange.shade300,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              isAllPaid ? Icons.check_circle_outline : Icons.pending_actions_outlined,
              color: isAllPaid ? Colors.green.shade800 : Colors.orange.shade800,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fee Status: ${isAllPaid ? "Paid" : "Pending / Due"}',
                    style: GoogleFonts.sourceSans3(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isAllPaid ? Colors.green.shade900 : Colors.orange.shade900,
                    ),
                  ),
                  Text(
                    isAllPaid
                        ? 'Account in good standing.'
                        : 'Please submit payment receipt below.',
                    style: GoogleFonts.sourceSans3(
                      fontSize: 13,
                      color: isAllPaid ? Colors.green.shade800 : Colors.orange.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Fee Challans & Status',
          style: GoogleFonts.sourceSerif4(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFC85A32),
          labelColor: const Color(0xFFC85A32),
          unselectedLabelColor: Colors.grey.shade700,
          labelStyle: GoogleFonts.sourceSans3(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'Unpaid'),
            Tab(text: 'Paid'),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('fee_challans')
            .where('parentId', isEqualTo: userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFC85A32)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error loading fee challans: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sourceSans3(color: Colors.red),
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          return TabBarView(
            controller: _tabController,
            children: [
              _buildChallanList(docs, isPaidTab: false),
              _buildChallanList(docs, isPaidTab: true),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChallanList(List<QueryDocumentSnapshot> allParentDocs, {required bool isPaidTab}) {
    final colors = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('MMM d, yyyy');

    final docs = allParentDocs.where((doc) {
      final status = ((doc.data() as Map<String, dynamic>)['status'] ?? 'unpaid').toString().toLowerCase();
      return isPaidTab ? status == 'paid' : status != 'paid';
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCoachBankDetailsCard(),
        const SizedBox(height: 16),
        _buildFeeStatusSummaryCard(allParentDocs),
        const SizedBox(height: 16),
        if (docs.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 32.0),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 48,
                    color: colors.primary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isPaidTab ? 'No paid fee challans.' : 'No unpaid fee challans.',
                    style: GoogleFonts.sourceSans3(
                      fontSize: 16,
                      color: colors.primary.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final month = data['month'] ?? 'Monthly Fee';
            final childName = data['childName'] ?? 'Warrior';
            final amount = data['amount'] ?? 0;
            final status = (data['status'] ?? 'unpaid').toString().toLowerCase();
            final receiptBase64 = (data['receiptBase64'] ?? data['photoBase64']) as String?;

            final Timestamp? issuedTs = data['issuedAt'] as Timestamp?;
            final Timestamp? dueTs = data['dueDate'] as Timestamp?;
            final issueDateStr = issuedTs != null ? dateFormat.format(issuedTs.toDate()) : 'N/A';
            final dueDateStr = dueTs != null ? dateFormat.format(dueTs.toDate()) : 'N/A';

            Color badgeColor = Colors.red;
            String statusText = 'UNPAID';

            if (status == 'pending') {
              badgeColor = Colors.orange;
              statusText = 'PENDING';
            } else if (status == 'paid') {
              badgeColor = Colors.green;
              statusText = 'PAID';
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: colors.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                month,
                                style: GoogleFonts.sourceSans3(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                'Warrior: $childName',
                                style: GoogleFonts.sourceSans3(
                                  color: colors.primary.withValues(alpha: 0.7),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusText,
                              style: GoogleFonts.sourceSans3(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Amount: PKR $amount',
                        style: GoogleFonts.sourceSans3(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text('Issue Date: $issueDateStr', style: GoogleFonts.sourceSans3(fontSize: 12, color: Colors.grey.shade700)),
                          const SizedBox(width: 16),
                          Text('Due Date: $dueDateStr', style: GoogleFonts.sourceSans3(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFC85A32))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (receiptBase64 != null && receiptBase64.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(
                              receiptBase64.contains(',')
                                  ? receiptBase64.split(',').last
                                  : receiptBase64,
                            ),
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (status != 'paid') ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _uploadReceipt(doc.id),
                            icon: const Icon(Icons.upload_file),
                            label: Text(
                              receiptBase64 == null
                                  ? 'Upload Payment Receipt'
                                  : 'Re-upload Payment Receipt',
                            ),
                          ),
                        ),
                        if (status == 'pending') ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _removeSubmission(doc.id),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                side: BorderSide(color: Colors.red.shade300),
                              ),
                              icon: const Icon(Icons.delete_outline_rounded, size: 18),
                              label: const Text('Remove Submission (Make Unpaid)'),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}