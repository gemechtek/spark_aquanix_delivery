import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spark_aquanix_delivery/backend/models/order_model.dart';

class CodeVerificationBottomSheetContent extends StatefulWidget {
  final OrderDetails order;

  const CodeVerificationBottomSheetContent({super.key, required this.order});

  @override
  CodeVerificationBottomSheetContentState createState() =>
      CodeVerificationBottomSheetContentState();
}

class CodeVerificationBottomSheetContentState
    extends State<CodeVerificationBottomSheetContent> {
  late List<TextEditingController> controllers;
  late List<FocusNode> focusNodes;

  @override
  void initState() {
    super.initState();
    // Initialize controllers and focus nodes
    controllers = List.generate(
      6,
      (index) => TextEditingController(),
    );
    focusNodes = List.generate(
      6,
      (index) => FocusNode(),
    );
  }

  @override
  void dispose() {
    // Dispose controllers and focus nodes when the widget is permanently removed
    for (var controller in controllers) {
      controller.dispose();
    }
    for (var focusNode in focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  String getFullCode() {
    return controllers.map((controller) => controller.text).join();
  }

  void verifyCode(BuildContext sheetContext) {
    String fullCode = getFullCode();
    if (fullCode.length == 6) {
      Navigator.pop(sheetContext, fullCode);
    }
  }

  void autoVerifyIfComplete(BuildContext sheetContext) {
    String fullCode = getFullCode();
    if (fullCode.length == 6) {
      Future.delayed(const Duration(milliseconds: 200), () {
        verifyCode(sheetContext);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                const Icon(
                  Icons.verified_user,
                  color: Colors.green,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Verify Delivery Code',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 20,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Enter the 6-digit code provided by the customer:',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                6,
                (index) => SizedBox(
                  width: 48,
                  height: 56,
                  child: TextField(
                    controller: controllers[index],
                    focusNode: focusNodes[index],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.blueAccent,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (value) {
                      if (value.isNotEmpty && index < 5) {
                        focusNodes[index + 1].requestFocus();
                      }
                      autoVerifyIfComplete(context);
                    },
                    onTap: () {
                      controllers[index].selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: controllers[index].text.length,
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => verifyCode(context),
                  icon: const Icon(
                    Icons.check_circle_outline,
                    size: 20,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Verify',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    backgroundColor: Colors.blueAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
