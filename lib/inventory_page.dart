import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'utils.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  DateTime selectedDate = DateTime.now();
  List inventoryLogs = [];
  final formKey = GlobalKey<FormState>();
  final int pageSize = 20;
  bool hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future _loadData({bool loadMore = false}) async {
    var ingredientsSnapshot =
        await FirebaseFirestore.instance
            .collection('ingredients')
            .orderBy('item')
            .limit(pageSize)
            .get();
    var items =
        ingredientsSnapshot.docs.map((doc) => doc['item'] as String).toList();
    List logs = [];
    for (var item in items) {
      var log = await _getLogForItem(item, selectedDate);
      logs.add(log);
    }
    setState(() {
      inventoryLogs = loadMore ? [...inventoryLogs, ...logs] : logs;
      hasMore = ingredientsSnapshot.docs.length == pageSize;
    });
  }

  Future _getLogForItem(String item, DateTime date) async {
    var logSnapshot =
        await FirebaseFirestore.instance
            .collection('inventory_logs')
            .where('date', isEqualTo: date)
            .where('item', isEqualTo: item)
            .get();
    if (logSnapshot.docs.isNotEmpty) {
      var data = logSnapshot.docs.first.data();
      return InventoryLog(
        item: item,
        opening: data['opening'].toString(),
        received: data['received'].toString(),
        discarded: data['discarded'].toString(),
        closing: data['closing'].toString(),
        physical: data['physical'].toString(),
      );
    } else {
      var prevLogSnapshot =
          await FirebaseFirestore.instance
              .collection('inventory_logs')
              .where('item', isEqualTo: item)
              .where('date', isLessThan: date)
              .orderBy('date', descending: true)
              .limit(1)
              .get();
      if (prevLogSnapshot.docs.isNotEmpty) {
        var prevData = prevLogSnapshot.docs.first.data();
        var opening = prevData['closing'].toString();
        return InventoryLog(
          item: item,
          opening: opening,
          received: '0',
          discarded: '0',
          closing: opening,
          physical: opening,
        );
      } else {
        return InventoryLog(
          item: item,
          opening: '0',
          received: '0',
          discarded: '0',
          closing: '0',
          physical: '0',
        );
      }
    }
  }

  Future saveData() async {
    if (!formKey.currentState!.validate()) return;
    var batch = FirebaseFirestore.instance.batch();
    for (var log in inventoryLogs) {
      var docId = "${selectedDate.toString().substring(0, 10)}${log.item}";
      var docRef = FirebaseFirestore.instance
          .collection('inventory_logs')
          .doc(docId);
      var opening = double.parse(log.openingController.text);
      var received = double.parse(log.receivedController.text);
      var discarded = double.parse(log.discardedController.text);
      var closing = double.parse(log.closingController.text);
      var physical = double.parse(log.physicalController.text);
      if (physical != closing) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Physical count for ${log.item} does not match closing',
            ),
          ),
        );
        return;
      }
      batch.set(docRef, {
        'date': selectedDate,
        'item': log.item,
        'opening': opening,
        'received': received,
        'discarded': discarded,
        'closing': closing,
        'physical': physical,
      });
    }
    await batch.commit();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Inventory saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Inventory')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
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
                      _loadData();
                    }
                  },
                ),
              ],
            ),
            Expanded(
              child: Form(
                key: formKey,
                child:
                    ResponsiveBreakpoints.of(context).smallerThan(DESKTOP)
                        ? ListView.builder(
                          itemCount: inventoryLogs.length + (hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == inventoryLogs.length && hasMore) {
                              return ElevatedButton(
                                onPressed: () => _loadData(loadMore: true),
                                child: Text('Load More'),
                              );
                            }
                            var log = inventoryLogs[index];

                            var consumed = 0.0;
                            try {
                              if (double.tryParse(log.openingController.text) !=
                                      null &&
                                  double.tryParse(
                                        log.receivedController.text,
                                      ) !=
                                      null &&
                                  double.tryParse(log.closingController.text) !=
                                      null &&
                                  double.tryParse(
                                        log.discardedController.text,
                                      ) !=
                                      null) {
                                consumed =
                                    double.parse(log.openingController.text) +
                                    double.parse(log.receivedController.text) -
                                    double.parse(log.closingController.text) -
                                    double.parse(log.discardedController.text);
                              }
                            } catch (e) {
                              // If any parsing errors occur, consumed remains 0.0
                            }
                            return Card(
                              elevation: 2,
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      log.item,
                                      style:
                                          Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                    ),
                                    Text(
                                      'Consumed: ${consumed.toStringAsFixed(2)}',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                    TextFormField(
                                      controller: log.openingController,
                                      decoration: InputDecoration(
                                        labelText: 'Opening Inventory',
                                      ),
                                      keyboardType: TextInputType.number,
                                      validator:
                                          (value) =>
                                              value!.isEmpty ||
                                                      double.tryParse(value) ==
                                                          null ||
                                                      double.parse(value) < 0
                                                  ? 'Invalid number'
                                                  : null,
                                      onChanged: debounced(
                                        (value) => setState(() {}),
                                      ),
                                    ),
                                    TextFormField(
                                      controller: log.receivedController,
                                      decoration: InputDecoration(
                                        labelText: 'Received',
                                      ),
                                      keyboardType: TextInputType.number,
                                      validator:
                                          (value) =>
                                              value!.isEmpty ||
                                                      double.tryParse(value) ==
                                                          null ||
                                                      double.parse(value) < 0
                                                  ? 'Invalid number'
                                                  : null,
                                      onChanged: debounced(
                                        (value) => setState(() {}),
                                      ),
                                    ),
                                    TextFormField(
                                      controller: log.discardedController,
                                      decoration: InputDecoration(
                                        labelText: 'Discarded',
                                      ),
                                      keyboardType: TextInputType.number,
                                      validator:
                                          (value) =>
                                              value!.isEmpty ||
                                                      double.tryParse(value) ==
                                                          null ||
                                                      double.parse(value) < 0
                                                  ? 'Invalid number'
                                                  : null,
                                      onChanged: debounced(
                                        (value) => setState(() {}),
                                      ),
                                    ),
                                    TextFormField(
                                      controller: log.closingController,
                                      decoration: InputDecoration(
                                        labelText: 'Closing Inventory',
                                      ),
                                      keyboardType: TextInputType.number,
                                      validator:
                                          (value) =>
                                              value!.isEmpty ||
                                                      double.tryParse(value) ==
                                                          null ||
                                                      double.parse(value) < 0
                                                  ? 'Invalid number'
                                                  : null,
                                      onChanged: debounced(
                                        (value) => setState(() {}),
                                      ),
                                    ),
                                    TextFormField(
                                      controller: log.physicalController,
                                      decoration: InputDecoration(
                                        labelText: 'Physical Inventory',
                                      ),
                                      keyboardType: TextInputType.number,
                                      validator:
                                          (value) =>
                                              value!.isEmpty ||
                                                      double.tryParse(value) ==
                                                          null ||
                                                      double.parse(value) < 0
                                                  ? 'Invalid number'
                                                  : null,
                                      onChanged: debounced(
                                        (value) => setState(() {}),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ).animate().fadeIn(duration: 300.ms);
                          },
                        )
                        : SingleChildScrollView(
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text('Item')),
                                  Expanded(child: Text('Consumed')),
                                  Expanded(child: Text('Opening')),
                                  Expanded(child: Text('Received')),
                                  Expanded(child: Text('Discarded')),
                                  Expanded(child: Text('Closing')),
                                  Expanded(child: Text('Physical')),
                                ],
                              ),
                              ...inventoryLogs.map((log) {
                                var consumed =
                                    double.parse(log.openingController.text) +
                                    double.parse(log.receivedController.text) -
                                    double.parse(log.closingController.text) -
                                    double.parse(log.discardedController.text);
                                return Row(
                                  children: [
                                    Expanded(child: Text(log.item)),
                                    Expanded(
                                      child: Text(consumed.toStringAsFixed(2)),
                                    ),
                                    Expanded(
                                      child: TextFormField(
                                        controller: log.openingController,
                                        keyboardType: TextInputType.number,
                                        validator:
                                            (value) =>
                                                value!.isEmpty ||
                                                        double.tryParse(
                                                              value,
                                                            ) ==
                                                            null ||
                                                        double.parse(value) < 0
                                                    ? 'Invalid'
                                                    : null,
                                        onChanged: debounced(
                                          (value) => setState(() {}),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: TextFormField(
                                        controller: log.receivedController,
                                        keyboardType: TextInputType.number,
                                        validator:
                                            (value) =>
                                                value!.isEmpty ||
                                                        double.tryParse(
                                                              value,
                                                            ) ==
                                                            null ||
                                                        double.parse(value) < 0
                                                    ? 'Invalid'
                                                    : null,
                                        onChanged: debounced(
                                          (value) => setState(() {}),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: TextFormField(
                                        controller: log.discardedController,
                                        keyboardType: TextInputType.number,
                                        validator:
                                            (value) =>
                                                value!.isEmpty ||
                                                        double.tryParse(
                                                              value,
                                                            ) ==
                                                            null ||
                                                        double.parse(value) < 0
                                                    ? 'Invalid'
                                                    : null,
                                        onChanged: debounced(
                                          (value) => setState(() {}),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: TextFormField(
                                        controller: log.closingController,
                                        keyboardType: TextInputType.number,
                                        validator:
                                            (value) =>
                                                value!.isEmpty ||
                                                        double.tryParse(
                                                              value,
                                                            ) ==
                                                            null ||
                                                        double.parse(value) < 0
                                                    ? 'Invalid'
                                                    : null,
                                        onChanged: debounced(
                                          (value) => setState(() {}),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: TextFormField(
                                        controller: log.physicalController,
                                        keyboardType: TextInputType.number,
                                        validator:
                                            (value) =>
                                                value!.isEmpty ||
                                                        double.tryParse(
                                                              value,
                                                            ) ==
                                                            null ||
                                                        double.parse(value) < 0
                                                    ? 'Invalid'
                                                    : null,
                                        onChanged: debounced(
                                          (value) => setState(() {}),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                              if (hasMore)
                                ElevatedButton(
                                  onPressed: () => _loadData(loadMore: true),
                                  child: Text('Load More'),
                                ),
                            ],
                          ),
                        ),
              ),
            ),
            ElevatedButton(onPressed: saveData, child: Text('Save')),
          ],
        ),
      ),
    );
  }
}

class InventoryLog {
  String item;
  TextEditingController openingController;
  TextEditingController receivedController;
  TextEditingController discardedController;
  TextEditingController closingController;
  TextEditingController physicalController;

  InventoryLog({
    required this.item,
    required String opening,
    required String received,
    required String discarded,
    required String closing,
    required String physical,
  }) : openingController = TextEditingController(text: opening),
       receivedController = TextEditingController(text: received),
       discardedController = TextEditingController(text: discarded),
       closingController = TextEditingController(text: closing),
       physicalController = TextEditingController(text: physical);
}
