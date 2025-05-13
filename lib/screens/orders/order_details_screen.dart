import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:spark_aquanix_delivery/backend/enums/order_status.dart';
import 'package:spark_aquanix_delivery/backend/models/order_model.dart';
import 'package:spark_aquanix_delivery/backend/providers/auth_provider.dart';
import 'package:spark_aquanix_delivery/backend/providers/order_provider.dart';

import 'package:intl/intl.dart';

class CustomDropdownButtonFormField<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String labelText;

  const CustomDropdownButtonFormField({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.labelText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(color: Colors.grey.shade600),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        dropdownColor: Colors.white,
        style: const TextStyle(color: Colors.black, fontSize: 16),
        icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
      ),
    );
  }
}

class OrderDetailsScreen extends StatefulWidget {
  final OrderDetails? order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late OrderStatus _selectedStatus;
  bool _isUpdating = false;
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.order?.status ?? OrderStatus.pending;
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.order == null) {
      return const Scaffold(
        body: Center(child: Text('Order not found')),
      );
    }
    final order = widget.order!;
    final dateFormat = DateFormat('MMMM d, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text('Order ${order.id?.substring(0, 8) ?? 'N/A'}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/orders'),
        ),
      ),
      body: _isUpdating
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order Status
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                'Order Status',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Current Status: ${order.status.toString().split('.').last}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          if (order.deliveryCode != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Delivery Code: ${order.deliveryCode}',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                          const SizedBox(height: 8),
                          CustomDropdownButtonFormField<OrderStatus>(
                            value: _selectedStatus,
                            labelText: 'Select Status',
                            items: [
                              OrderStatus.pending,
                              OrderStatus.orderConfirmed,
                              OrderStatus.shipped,
                              OrderStatus.outForDelivery,
                              OrderStatus.delivered,
                            ]
                                .map((status) => DropdownMenuItem(
                                      value: status,
                                      child: Text(status.toString()),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedStatus = value;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: _selectedStatus == order.status
                                  ? null
                                  : () async {
                                      if (_selectedStatus ==
                                          OrderStatus.delivered) {
                                        // Show code verification dialog
                                        final isCodeValid =
                                            await _showCodeVerificationDialog(
                                                context, order);
                                        if (!isCodeValid) return;
                                      }
                                      final deliveryCode =
                                          await _updateStatus(context, order);
                                      String notificationBody;
                                      if (_selectedStatus ==
                                              OrderStatus.outForDelivery &&
                                          deliveryCode != null) {
                                        notificationBody =
                                            "Hello ${order.userName}, your order for ${order.items[0].productName} (Order ID: ${order.id}) is out for delivery. Your delivery code is $deliveryCode.  'Thank you for choosing us!'}";
                                      } else {
                                        notificationBody =
                                            "Hello ${order.userName}, your order for ${order.items[0].productName} (Order ID: ${order.id}) has been updated to ${_selectedStatus.toString().split('.').last}.  'Thank you for choosing us!'}";
                                      }

                                      await Provider.of<OrderProvider>(
                                        context,
                                        listen: false,
                                      ).sendNotification(
                                        order.userFcmToken,
                                        "Order ${_selectedStatus.toString().split('.').last}",
                                        notificationBody,
                                      );

                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Status updated to ${_selectedStatus.toString().split('.').last}',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                              child: const Text('Update Status'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Order Items
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.shopping_cart,
                                  color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                'Order Items',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          order.items.isEmpty
                              ? const Text('No items in this order')
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: order.items.length,
                                  itemBuilder: (context, index) {
                                    final item = order.items[index];
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12.0),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Image.network(
                                              item.image,
                                              width: 80,
                                              height: 80,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error,
                                                      stackTrace) =>
                                                  const Icon(Icons.broken_image,
                                                      size: 80),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.productName,
                                                  style: const TextStyle(
                                                      fontSize: 16),
                                                ),
                                                Text(
                                                  'Qty: ${item.quantity} | Size: ${item.size} | Color: ${item.selectedColor.toString().split('.').last}',
                                                  style: const TextStyle(
                                                      color: Colors.grey),
                                                ),
                                                Text(
                                                  '\$${item.totalPrice.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Delivery Address
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                'Delivery Address',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text('Name: ${order.deliveryAddress.fullName}'),
                          Text('Phone: ${order.deliveryAddress.phoneNumber}'),
                          Text(
                              'Address: ${order.deliveryAddress.addressLine1}'),
                          if (order.deliveryAddress.addressLine2.isNotEmpty)
                            Text(
                                'Address Line 2: ${order.deliveryAddress.addressLine2}'),
                          Text('City: ${order.deliveryAddress.city}'),
                          Text('State: ${order.deliveryAddress.state}'),
                          Text(
                              'Postal Code: ${order.deliveryAddress.postalCode}'),
                          Text('Country: ${order.deliveryAddress.country}'),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Order Summary
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.receipt, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                'Order Summary',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Subtotal'),
                              Text('\$${order.subtotal.toStringAsFixed(2)}'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Tax'),
                              Text('\$${order.tax.toStringAsFixed(2)}'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Shipping'),
                              Text(
                                  '\$${order.shippingCost.toStringAsFixed(2)}'),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '\$${order.total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Order Dates
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                'Order Dates',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                              'Created: ${dateFormat.format(order.createdAt)}'),
                          Text(
                              'Updated: ${dateFormat.format(order.updatedAt)}'),
                        ],
                      ),
                    ),
                  ),

                  if (order.deliveredBy != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person, color: Colors.blue),
                                const SizedBox(width: 8),
                                Text(
                                  'Delivered By',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(order.deliveredBy!),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Future<bool> _showCodeVerificationDialog(
      BuildContext context, OrderDetails order) async {
    if (order.deliveryCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              const Text('Delivery code not generated yet'),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return false;
    }

    // Create controllers and focus nodes for each digit
    List<TextEditingController> controllers = List.generate(
      6,
      (index) => TextEditingController(),
    );

    List<FocusNode> focusNodes = List.generate(
      6,
      (index) => FocusNode(),
    );

    // Function to check if all fields are filled and valid
    String getFullCode() {
      return controllers.map((controller) => controller.text).join();
    }

    // Function to verify the code and close the dialog
    void verifyCode(BuildContext dialogContext) {
      String fullCode = getFullCode();
      if (fullCode.length == 6) {
        Navigator.pop(dialogContext, fullCode);
      }
    }

    // Handle auto-verification
    void autoVerifyIfComplete(BuildContext dialogContext) {
      String fullCode = getFullCode();
      if (fullCode.length == 6) {
        // Short delay to allow keyboard to close
        Future.delayed(const Duration(milliseconds: 200), () {
          verifyCode(dialogContext);
        });
      }
    }

    final enteredCode = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.verified_user,
                      color: Colors.green,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Verify Delivery Code',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Please enter the 6-digit code provided by the customer:',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 32),

                // OTP-style input fields
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    6,
                    (index) => SizedBox(
                      width: 36,
                      height: 46,
                      child: TextField(
                        controller: controllers[index],
                        focusNode: focusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade400),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Theme.of(dialogContext).primaryColor,
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
                          // Move to next field when filled
                          if (value.isNotEmpty && index < 5) {
                            focusNodes[index + 1].requestFocus();
                          }
                          // Auto-verify when all filled
                          autoVerifyIfComplete(dialogContext);
                        },
                        onTap: () {
                          // Select all text when tapped
                          controllers[index].selection = TextSelection(
                            baseOffset: 0,
                            extentOffset: controllers[index].text.length,
                          );
                        },
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => verifyCode(dialogContext),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Verify',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.check_circle_outline, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (enteredCode == null || enteredCode.isEmpty) {
      return false;
    }

    if (enteredCode != order.deliveryCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              const Text('Invalid verification code'),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          action: SnackBarAction(
            label: 'Try Again',
            textColor: Colors.white,
            onPressed: () => _showCodeVerificationDialog(context, order),
          ),
        ),
      );
      return false;
    }

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            const Text('Code verified successfully'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    return true;
  }

  Future<String?> _updateStatus(
      BuildContext context, OrderDetails order) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _isUpdating = true);
    try {
      String? deliveryCode =
          await Provider.of<OrderProvider>(context, listen: false)
              .updateOrderStatus(
        order.id!,
        _selectedStatus,
        deliveryPersonnelName: authProvider.deliveryPersonnel?.name,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Status updated to ${_selectedStatus.toString().split('.').last}'),
          ),
        );
      }
      return deliveryCode;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
    return null;
  }
}
