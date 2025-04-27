import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frier_cost/currency_formatter.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'utils.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  DateTime selectedDate = DateTime.now();
  final _piecesSoldController = TextEditingController();
  final _revenueController = TextEditingController();

  final formKey = GlobalKey<FormState>();
  final int pageSize = 20;
  int currentPage = 1;

  @override
  void dispose() {
    _piecesSoldController.dispose();
    _revenueController.dispose();
    super.dispose();
  }

  Future _saveSalesData() async {
    if (!formKey.currentState!.validate()) return;
    var piecesSold = int.parse(_piecesSoldController.text);
    var totalRevenue = double.parse(_revenueController.text);
    var avgPrice = totalRevenue / piecesSold;
    if (avgPrice < 0.5 || avgPrice > 100050) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Average price per piece is outside reasonable range'),
        ),
      );
      return;
    }
    var docId = selectedDate.toString().substring(0, 10);
    await FirebaseFirestore.instance.collection('sales').doc(docId).set({
      'date': selectedDate,
      'piecesSold': piecesSold,
      'totalRevenue': totalRevenue,
    });
    if (mounted) {
      ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Sales data saved')));
    }
    _piecesSoldController.clear();
    _revenueController.clear();
  }

  @override
  Widget build(BuildContext context) {
    var avgPrice =
        (_piecesSoldController.text.isNotEmpty &&
                _revenueController.text.isNotEmpty &&
                int.tryParse(_piecesSoldController.text) != null &&
                double.tryParse(_revenueController.text) != null)
            ? CurrencyFormatter().formatWithPrecision(
              (double.parse(_revenueController.text) /
                  int.parse(_piecesSoldController.text)),
              2,
            )
            : '0.00';
    return Scaffold(
      appBar: AppBar(title: Text('Sales')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Date: ${selectedDate.toString().substring(0, 10)}'),
                IconButton(
                  icon: Icon(Icons.calendar_today),
                  onPressed: () async {
                    var newDate = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (newDate != null) {
                      setState(() {
                        selectedDate = newDate;
                      });
                    }
                  },
                ),
              ],
            ),
            Form(
              key: formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _piecesSoldController,
                    decoration: InputDecoration(
                      labelText: 'Chicken Pieces Sold',
                    ),
                    keyboardType: TextInputType.number,
                    validator:
                        (value) =>
                            value!.isEmpty ||
                                    int.tryParse(value) == null ||
                                    int.parse(value) < 0
                                ? 'Invalid number'
                                : null,
                    onChanged: debounced((value) => setState(() {})),
                  ),
                  TextFormField(
                    controller: _revenueController,
                    decoration: InputDecoration(labelText: 'Total Revenue'),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator:
                        (value) =>
                            value!.isEmpty ||
                                    double.tryParse(value) == null ||
                                    double.parse(value) < 0
                                ? 'Invalid number'
                                : null,
                    onChanged: debounced((value) => setState(() {})),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Average Price: $avgPrice',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _saveSalesData,
                    child: Text('Save'),
                  ),
                ],
              ),
            ),
            SizedBox(height: 32),
            Text(
              'Historical Sales Data',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Expanded(
              child: StreamBuilder(
                stream:
                    FirebaseFirestore.instance
                        .collection('sales')
                        .orderBy('date', descending: true)
                        .limit(pageSize * currentPage)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return ShimmerWidget(
                      child: Container(height: 300, color: Colors.grey[300]),
                    );
                  }
                  var salesDocs = snapshot.data!.docs;
                  return Column(
                    children: [
                      Expanded(
                        child:
                            ResponsiveBreakpoints.of(
                                  context,
                                ).smallerThan(DESKTOP)
                                ? ListView.builder(
                                  itemCount: salesDocs.length,
                                  itemBuilder: (context, index) {
                                    var data = salesDocs[index].data();
                                    return ListTile(
                                      title: Text(
                                        'Date: ${data['date'].toDate().toString().substring(0, 10)}',
                                      ),
                                      subtitle: Text(
                                        'Pieces Sold: ${data['piecesSold']}, Revenue: ${CurrencyFormatter().format(data['totalRevenue'])}',
                                      ),
                                    );
                                  },
                                )
                                : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    columns: [
                                      DataColumn(label: Text('Date')),
                                      DataColumn(label: Text('Pieces Sold')),
                                      DataColumn(label: Text('Total Revenue')),
                                    ],
                                    rows:
                                        salesDocs.map((doc) {
                                          var data = doc.data();
                                          return DataRow(
                                            cells: [
                                              DataCell(
                                                Text(
                                                  data['date']
                                                      .toDate()
                                                      .toString()
                                                      .substring(0, 10),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  data['piecesSold'].toString(),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  '${data['totalRevenue'].toStringAsFixed(2)}',
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                  ),
                                ),
                      ),
                      if (salesDocs.length >= pageSize * currentPage)
                        ElevatedButton(
                          onPressed: () => setState(() => currentPage++),
                          child: Text('Load More'),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
