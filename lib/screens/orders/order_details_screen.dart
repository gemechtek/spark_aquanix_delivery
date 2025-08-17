import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:provider/provider.dart';
import 'package:spark_aquanix_delivery/backend/enums/order_status.dart';
import 'package:spark_aquanix_delivery/backend/models/order_model.dart';
import 'package:spark_aquanix_delivery/backend/providers/auth_provider.dart';
import 'package:spark_aquanix_delivery/backend/providers/order_provider.dart';
import 'package:intl/intl.dart';
import 'package:spark_aquanix_delivery/screens/orders/widgets/make_phone_call.dart';
import 'package:url_launcher/url_launcher.dart';
import 'widgets/dropdown_widget.dart';
import 'widgets/verify_bottom_sheet.dart';

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
      return Scaffold(
        body: Center(
          child: Text(
            'Order not found',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      );
    }
    final order = widget.order!;
    final dateFormat = DateFormat('MMMM d, yyyy');

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          'Order ${order.id?.substring(0, 8) ?? 'N/A'}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pushNamed(context, '/orders'),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: _isUpdating
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order Status
                  _buildCard(
                    context,
                    title: 'Order Status',
                    icon: Icons.info,
                    children: [
                      Text(
                        'Current Status: ${_selectedStatus.toString().split('.').last}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
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
                                  child: Text(
                                    status.toString().split('.').last,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
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
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: AnimatedOpacity(
                          opacity: _selectedStatus == order.status ? 0.5 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: ElevatedButton.icon(
                            onPressed: order.statusHistory.any((change) =>
                                    change.status == _selectedStatus)
                                ? null
                                : () async {
                                    if (_selectedStatus ==
                                        OrderStatus.delivered) {
                                      final isCodeValid =
                                          await _showCodeVerificationBottomSheet(
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
                                          "Hello ${order.userName}, your order for ${order.items[0].productName} (Order ID: ${order.id}) is out for delivery. Your delivery code is $deliveryCode. Thank you for choosing us!";
                                    } else {
                                      notificationBody =
                                          "Hello ${order.userName}, your order for ${order.items[0].productName} (Order ID: ${order.id}) has been updated to ${_selectedStatus.toString().split('.').last}. Thank you for choosing us!";
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
                                          behavior: SnackBarBehavior.floating,
                                          backgroundColor: Colors.green,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                            icon: const Icon(
                              Icons.update,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Update Status',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              disabledForegroundColor: Colors.black,
                              disabledBackgroundColor: Colors.grey,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Order Items
                  _buildCard(
                    context,
                    title: 'Order Items',
                    icon: Icons.shopping_cart,
                    children: [
                      order.items.isEmpty
                          ? const Text('No items in this order')
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: order.items.length,
                              itemBuilder: (context, index) {
                                final item = order.items[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Hero(
                                        tag: 'item-${item.productId}',
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Image.network(
                                            item.image,
                                            width: 90,
                                            height: 90,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Container(
                                              width: 90,
                                              height: 90,
                                              color: Colors.grey.shade200,
                                              child: const Icon(
                                                Icons.broken_image,
                                                size: 40,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
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
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Qty: ${item.quantity} | Size: ${item.size} | Color: ${item.selectedColor.toString().split('.').last}',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '₹${item.totalPrice.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.blueAccent,
                                              ),
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

                  const SizedBox(height: 16),

                  _buildCard(context,
                      title: "Contact Customer",
                      icon: Icons.phone,
                      children: [
                        _buildInfoRow(
                          'Name',
                          order.deliveryAddress.fullName,
                        ),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(
                                text: order.deliveryAddress.phoneNumber));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Phone number copied to clipboard'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildInfoRow(
                                  'Phone',
                                  order.deliveryAddress.phoneNumber,
                                ),
                              ),
                              const Icon(Icons.copy, size: 20),
                            ],
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey.shade200,
                          ),
                          child: Dismissible(
                            key: Key(
                                'call-${order.deliveryAddress.phoneNumber}'),
                            direction: DismissDirection.startToEnd,
                            background: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.green,
                              ),
                              alignment: Alignment.centerLeft,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: const Icon(
                                Icons.phone,
                                color: Colors.white,
                              ),
                            ),
                            confirmDismiss: (direction) async {
                              try {
                                // bool success =
                                //     await PhoneCallHelper.makePhoneCall(
                                //   order.deliveryAddress.phoneNumber,
                                // );

                                bool? success =
                                    await FlutterPhoneDirectCaller.callNumber(
                                        order.deliveryAddress.phoneNumber);

                                if (success == true && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Opening phone dialer...'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                } else if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Could not open phone dialer'),
                                      backgroundColor: Colors.red,
                                      duration: Duration(seconds: 3),
                                    ),
                                  );
                                }
                              } catch (e) {
                                print('Error making phone call: $e');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: ${e.toString()}'),
                                      backgroundColor: Colors.red,
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }
                              }

                              // Always return false to keep the widget in place
                              return false;
                            },
                            dismissThresholds: const {
                              DismissDirection.startToEnd: 0.4
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.arrow_forward, size: 20),
                                  SizedBox(width: 8),
                                  Text('Swipe to call'),
                                  SizedBox(width: 8),
                                  Icon(Icons.phone, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ]),

                  const SizedBox(height: 16),

                  // Delivery Address
                  _buildCard(
                    context,
                    title: 'Delivery Address',
                    icon: Icons.location_on,
                    children: [
                      _buildInfoRow(
                        'Name',
                        order.deliveryAddress.fullName,
                      ),
                      _buildInfoRow(
                        'Phone',
                        order.deliveryAddress.phoneNumber,
                      ),
                      _buildInfoRow(
                        'Address',
                        order.deliveryAddress.addressLine1,
                      ),
                      if (order.deliveryAddress.addressLine2.isNotEmpty)
                        _buildInfoRow(
                          'Address Line 2',
                          order.deliveryAddress.addressLine2,
                        ),
                      _buildInfoRow(
                        'City',
                        order.deliveryAddress.city,
                      ),
                      _buildInfoRow(
                        'State',
                        order.deliveryAddress.state,
                      ),
                      _buildInfoRow(
                        'Postal Code',
                        order.deliveryAddress.postalCode,
                      ),
                      _buildInfoRow(
                        'Country',
                        order.deliveryAddress.country,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Order Summary
                  _buildCard(
                    context,
                    title: 'Order Summary',
                    icon: Icons.receipt,
                    children: [
                      _buildSummaryRow(
                        'Subtotal',
                        '₹${order.subtotal.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 8),
                      _buildSummaryRow(
                        'Tax',
                        '₹${order.tax.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 8),
                      _buildSummaryRow(
                        'Shipping',
                        '₹${order.shippingCost.toStringAsFixed(2)}',
                      ),
                      const Divider(height: 24),
                      _buildSummaryRow(
                        'Total',
                        '₹${order.total.toStringAsFixed(2)}',
                        isBold: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Order Dates
                  _buildCard(
                    context,
                    title: 'Order Dates',
                    icon: Icons.calendar_today,
                    children: [
                      _buildInfoRow(
                        'Created',
                        dateFormat.format(order.createdAt),
                      ),
                      _buildInfoRow(
                        'Updated',
                        dateFormat.format(order.updatedAt),
                      ),
                    ],
                  ),

                  if (order.deliveredBy != null) ...[
                    const SizedBox(height: 16),
                    _buildCard(
                      context,
                      title: 'Delivered By',
                      icon: Icons.person,
                      children: [
                        Text(
                          order.deliveredBy!,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      color: Colors.blueAccent,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 20,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: isBold ? Colors.blueAccent : Colors.black87,
          ),
        ),
      ],
    );
  }

  Future<bool> _showCodeVerificationBottomSheet(
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

    final enteredCode = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return CodeVerificationBottomSheetContent(order: order);
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
            onPressed: () => _showCodeVerificationBottomSheet(context, order),
          ),
        ),
      );
      return false;
    }

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
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
      return deliveryCode;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }
}
