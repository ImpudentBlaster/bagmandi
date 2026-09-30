import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/chat_nav.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';

class EnquiryDetailScreen extends StatelessWidget {
  final String enquiryId;

  const EnquiryDetailScreen({super.key, required this.enquiryId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EnquiryProvider>();
    final enquiry = provider.getEnquiry(enquiryId);
    final quotes = provider.getQuotesForEnquiry(enquiryId);

    if (enquiry == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Enquiry not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enquiry Details'),
        actions: [
          if (quotes.length > 1)
            TextButton(
              onPressed: () => context.push('/buyer/enquiry/$enquiryId/compare'),
              child: const Text('Compare'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('#${enquiry.id}  •  ${enquiry.bagType}', style: Theme.of(context).textTheme.titleLarge),
                      ),
                      StatusChip.enquiry(enquiry.status.name),
                    ],
                  ),
                  const Divider(height: 24),
                  _DetailRow('Size', enquiry.size),
                  _DetailRow('Color', enquiry.color),
                  _DetailRow('GSM', '${enquiry.gsm}'),
                  _DetailRow('Printing', enquiry.printing),
                  _DetailRow('Quantity', '${enquiry.quantityKg.toInt()} KG'),
                  _DetailRow('Delivery', enquiry.deliveryLocation),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Received Quotes (${quotes.length})', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16)),
            const SizedBox(height: 12),
            if (quotes.isEmpty)
              const AppCard(
                child: Center(child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No quotes received yet'),
                )),
              )
            else
              ...quotes.map((q) => AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primaryLight,
                              child: Text(q.manufacturerName[0], style: const TextStyle(color: AppColors.primary)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(q.manufacturerName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text('Delivery: ${q.deliveryDays} days', style: Theme.of(context).textTheme.bodyMedium),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _QuoteStat(
                              label: 'Price / KG',
                              value: '₹${(q.bagPricePerKg + q.printingPricePerKg).toStringAsFixed(0)}',
                            ),
                            const SizedBox(width: 12),
                            _QuoteStat(
                              label: 'Delivery',
                              value: '${q.deliveryDays} days',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton(
                            onPressed: () => context.push('/buyer/enquiry/$enquiryId/quote/${q.id}'),
                            child: const Text('View Quote'),
                          ),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

class _QuoteStat extends StatelessWidget {
  final String label;
  final String value;

  const _QuoteStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class ViewQuoteScreen extends StatelessWidget {
  final String enquiryId;
  final String quoteId;

  const ViewQuoteScreen({super.key, required this.enquiryId, required this.quoteId});

  @override
  Widget build(BuildContext context) {
    final quotes = context.watch<EnquiryProvider>().getQuotesForEnquiry(enquiryId);
    Quote? quote;
    for (final q in quotes) {
      if (q.id == quoteId) quote = q;
    }
    if (quote == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Quote not found')));
    }
    final q = quote;
    return Scaffold(
      appBar: AppBar(title: const Text('View Quote')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(q.manufacturerName, style: Theme.of(context).textTheme.titleLarge),
                  const Divider(height: 24),
                  _DetailRow('Price / KG', '₹${q.bagPricePerKg.toStringAsFixed(0)}'),
                  _DetailRow('Printing / KG', '₹${q.printingPricePerKg.toStringAsFixed(0)}'),
                  _DetailRow('GST', '${q.gstPercent}%'),
                  _DetailRow('Transport', '₹${q.transportCharges.toStringAsFixed(0)}'),
                  _DetailRow('Delivery', '${q.deliveryDays} days'),
                  _DetailRow('Validity', q.validity),
                  _DetailRow('Payment', q.paymentTerms),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Approx.', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        '₹${q.totalApprox.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => ChatNav.openRoom(context, q.manufacturerId),
                    child: const Text('Chat'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    label: 'Accept Quote',
                    color: AppColors.manufacturer,
                    onPressed: () async {
                      try {
                        final order = await context.read<EnquiryProvider>().acceptQuote(q);
                        if (!context.mounted) return;
                        await context.read<HomeProvider>().refreshOrders(buyerId: order.buyerId);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Quote accepted. Order ${order.id} created')),
                        );
                        context.go('/buyer/orders');
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e')),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CompareQuotesScreen extends StatefulWidget {
  final String enquiryId;

  const CompareQuotesScreen({super.key, required this.enquiryId});

  @override
  State<CompareQuotesScreen> createState() => _CompareQuotesScreenState();
}

class _CompareQuotesScreenState extends State<CompareQuotesScreen> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final quotes = context.watch<EnquiryProvider>().getQuotesForEnquiry(widget.enquiryId);
    if (quotes.isEmpty) {
      return Scaffold(appBar: AppBar(title: const Text('Compare Quotes')), body: const Center(child: Text('No quotes')));
    }
    final selected = quotes[_selected.clamp(0, quotes.length - 1)];
    final lowestPrice = quotes.map((q) => q.bagPricePerKg + q.printingPricePerKg).reduce((a, b) => a < b ? a : b);

    return Scaffold(
      appBar: AppBar(title: const Text('Compare Quotes')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(AppColors.primaryLight),
                    columns: [
                      const DataColumn(label: Text('Parameter', style: TextStyle(fontWeight: FontWeight.w700))),
                      ...quotes.asMap().entries.map((e) {
                        final q = e.value;
                        final active = e.key == _selected;
                        return DataColumn(
                          label: GestureDetector(
                            onTap: () => setState(() => _selected = e.key),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: active ? AppColors.manufacturerLight : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                q.manufacturerName.split(' ').first,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: active ? AppColors.manufacturer : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                    rows: [
                      _row(
                        'Price/KG',
                        quotes
                            .map((q) {
                              final p = q.bagPricePerKg + q.printingPricePerKg;
                              return MapEntry('₹${p.toStringAsFixed(0)}', p == lowestPrice);
                            })
                            .toList(),
                      ),
                      _row('Printing', quotes.map((q) => MapEntry('₹${q.printingPricePerKg}/KG', false)).toList()),
                      _row('GST', quotes.map((q) => MapEntry('${q.gstPercent}%', false)).toList()),
                      _row('Transport', quotes.map((q) => MapEntry('₹${q.transportCharges.toStringAsFixed(0)}', false)).toList()),
                      _row('Delivery', quotes.map((q) => MapEntry('${q.deliveryDays} days', false)).toList()),
                      _row('Validity', quotes.map((q) => MapEntry(q.validity, false)).toList()),
                      _row('Payment', quotes.map((q) => MapEntry(q.paymentTerms, false)).toList()),
                      _row(
                        'Total Approx',
                        quotes.map((q) => MapEntry('₹${q.totalApprox.toStringAsFixed(0)}', false)).toList(),
                        bold: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => ChatNav.openRoom(context, selected.manufacturerId),
                    child: const Text('Chat'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    label: 'Accept Quote',
                    color: AppColors.manufacturer,
                    onPressed: () async {
                      try {
                        final order = await context.read<EnquiryProvider>().acceptQuote(selected);
                        if (!context.mounted) return;
                        await context.read<HomeProvider>().refreshOrders(buyerId: order.buyerId);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Accepted ${selected.manufacturerName}. Order ${order.id}')),
                        );
                        context.go('/buyer/orders');
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  DataRow _row(String label, List<MapEntry<String, bool>> values, {bool bold = false}) {
    return DataRow(
      cells: [
        DataCell(Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        ...values.map(
          (v) => DataCell(
            Text(
              v.key,
              style: TextStyle(
                fontWeight: bold || v.value ? FontWeight.w700 : FontWeight.w500,
                color: v.value ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
