
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'utils.dart';

class IngredientPage extends StatefulWidget {
  const IngredientPage({super.key});

  @override
  State<IngredientPage> createState() => _IngredientPageState();
}

class _IngredientPageState extends State<IngredientPage> with SingleTickerProviderStateMixin {
  final _ingredientFormKey = GlobalKey<FormState>();
  final _recipeFormKey = GlobalKey<FormState>();
  final _ingredientItemController = TextEditingController();
  final _unitController = TextEditingController();
  final _unitCostController = TextEditingController();
  final _supplierController = TextEditingController();
  final _notesController = TextEditingController();
  final _recipeItemController = TextEditingController();
  final _quantityPerPieceController = TextEditingController();
  String? _editingIngredientId;
  String? _editingRecipeId;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _ingredientItemController.dispose();
    _unitController.dispose();
    _unitCostController.dispose();
    _supplierController.dispose();
    _notesController.dispose();
    _recipeItemController.dispose();
    _quantityPerPieceController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  void _editIngredient(Map<String, dynamic> data, String id) {
    setState(() {
      _editingIngredientId = id;
      _ingredientItemController.text = data['item'];
      _unitController.text = data['unit'];
      _unitCostController.text = data['unitCost'].toString();
      _supplierController.text = data['supplier'] ?? '';
      _notesController.text = data['notes'] ?? '';
    });
  }

  void _editRecipeStandard(Map<String, dynamic> data, String id) {
    setState(() {
      _editingRecipeId = id;
      _recipeItemController.text = data['item'];
      _quantityPerPieceController.text = data['quantityPerPiece'].toString();
    });
  }

  Future _saveIngredient() async {
    if (!_ingredientFormKey.currentState!.validate()) {
      return;
    }
    var data = {
      'item': _ingredientItemController.text,
      'unit': _unitController.text,
      'unitCost': double.parse(_unitCostController.text),
      'supplier': _supplierController.text,
      'notes': _notesController.text,
      'updatedAt': Timestamp.now(),
    };
    if (_editingIngredientId != null) {
      await FirebaseFirestore.instance
          .collection('ingredients')
          .doc(_editingIngredientId)
          .update(data);
    } else {
      await FirebaseFirestore.instance.collection('ingredients').add(data);
    }
    _clearIngredientForm();
    if (mounted) {
      ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Ingredient saved')));
    }
  }

  Future _saveRecipeStandard() async {
    if (!_recipeFormKey.currentState!.validate()) {
      return;
    }
    var data = {
      'item': _recipeItemController.text,
      'quantityPerPiece': double.parse(_quantityPerPieceController.text),
      'updatedAt': Timestamp.now(),
    };
    if (_editingRecipeId != null) {
      await FirebaseFirestore.instance
          .collection('recipe_standards')
          .doc(_editingRecipeId)
          .update(data);
    } else {
      await FirebaseFirestore.instance
          .collection('recipe_standards')
          .doc(_recipeItemController.text)
          .set(data);
    }
    clearRecipeCache(); // Invalidate cache
    _clearRecipeForm();
    if (mounted) {
      ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Recipe standard saved')));
    }
  }

  Future _deleteIngredient(String id) async {
    await FirebaseFirestore.instance.collection('ingredients').doc(id).delete();
    if (mounted) {
      ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Ingredient deleted')));
    }
  }

  Future _deleteRecipeStandard(String id) async {
    await FirebaseFirestore.instance
        .collection('recipe_standards')
        .doc(id)
        .delete();
    clearRecipeCache(); // Invalidate cache
    if (mounted) {
      ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Recipe standard deleted')));
    }
  }

  void _clearIngredientForm() {
    setState(() {
      _editingIngredientId = null;
      _ingredientItemController.clear();
      _unitController.clear();
      _unitCostController.clear();
      _supplierController.clear();
      _notesController.clear();
    });
  }

  void _clearRecipeForm() {
    setState(() {
      _editingRecipeId = null;
      _recipeItemController.clear();
      _quantityPerPieceController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ingredients & Recipes'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [Tab(text: 'Ingredients'), Tab(text: 'Recipe Standards')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Ingredients Tab
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              children: [
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Form(
                      key: _ingredientFormKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _ingredientItemController,
                            decoration: InputDecoration(
                              labelText: 'Ingredient Name',
                            ),
                            validator:
                                (value) => value!.isEmpty ? 'Required' : null,
                          ),
                          TextFormField(
                            controller: _unitController,
                            decoration: InputDecoration(labelText: 'Unit'),
                            validator:
                                (value) => value!.isEmpty ? 'Required' : null,
                          ),
                          TextFormField(
                            controller: _unitCostController,
                            decoration: InputDecoration(labelText: 'Unit Cost'),
                            keyboardType: TextInputType.number,
                            validator:
                                (value) =>
                                    value!.isEmpty ||
                                            double.tryParse(value) == null
                                        ? 'Invalid'
                                        : null,
                          ),
                          TextFormField(
                            controller: _supplierController,
                            decoration: InputDecoration(labelText: 'Supplier'),
                          ),
                          TextFormField(
                            controller: _notesController,
                            decoration: InputDecoration(labelText: 'Notes'),
                          ),
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: _clearIngredientForm,
                                child: Text('Cancel'),
                              ),
                              SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _saveIngredient,
                                child: Text(
                                  _editingIngredientId == null
                                      ? 'Add'
                                      : 'Update',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 300.ms),
                SizedBox(height: 20),
                Expanded(
                  child: StreamBuilder(
                    stream:
                        FirebaseFirestore.instance
                            .collection('ingredients')
                            .orderBy('item')
                            .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return ShimmerWidget(
                          child: Container(
                            height: 300,
                            color: Colors.grey[300],
                          ),
                        );
                      }
                      var ingredients = snapshot.data!.docs;
                      return ResponsiveBreakpoints.of(
                            context,
                          ).smallerThan(DESKTOP)
                          ? ListView.builder(
                            itemCount: ingredients.length,
                            itemBuilder: (context, index) {
                              var data = ingredients[index].data();
                              var id = ingredients[index].id;
                              return Card(
                                elevation: 2,
                                child: ListTile(
                                  title: Text(data['item']),
                                  subtitle: Text(
                                    'Unit: ${data['unit']}, Cost: ${data['unitCost']}, Supplier: ${data['supplier'] ?? 'N/A'}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.edit),
                                        onPressed:
                                            () => _editIngredient(data, id),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete),
                                        onPressed: () => _deleteIngredient(id),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                          : DataTable(
                            columns: [
                              DataColumn(label: Text('Ingredient')),
                              DataColumn(label: Text('Unit')),
                              DataColumn(label: Text('Unit Cost')),
                              DataColumn(label: Text('Supplier')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows:
                                ingredients.map((doc) {
                                  var data = doc.data();
                                  var id = doc.id;
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(data['item'])),
                                      DataCell(Text(data['unit'])),
                                      DataCell(
                                        Text(
                                          '${data['unitCost'].toStringAsFixed(1)}',
                                        ),
                                      ),
                                      DataCell(Text(data['supplier'] ?? 'N/A')),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: Icon(Icons.edit),
                                              onPressed:
                                                  () =>
                                                      _editIngredient(data, id),
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.delete),
                                              onPressed:
                                                  () => _deleteIngredient(id),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                          );
                    },
                  ),
                ),
              ],
            ),
          ), // Recipe Standards Tab
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              children: [
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Form(
                      key: _recipeFormKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _recipeItemController,
                            decoration: InputDecoration(
                              labelText: 'Ingredient Name',
                            ),
                            validator:
                                (value) => value!.isEmpty ? 'Required' : null,
                          ),
                          TextFormField(
                            controller: _quantityPerPieceController,
                            decoration: InputDecoration(
                              labelText: 'Quantity per Piece',
                            ),
                            keyboardType: TextInputType.number,
                            validator:
                                (value) =>
                                    value!.isEmpty ||
                                            double.tryParse(value) == null ||
                                            double.parse(value) <= 0
                                        ? 'Invalid positive number'
                                        : null,
                          ),
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: _clearRecipeForm,
                                child: Text('Cancel'),
                              ),
                              SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _saveRecipeStandard,
                                child: Text(
                                  _editingRecipeId == null ? 'Add' : 'Update',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 300.ms),
                SizedBox(height: 20),
                Expanded(
                  child: StreamBuilder(
                    stream:
                        FirebaseFirestore.instance
                            .collection('recipe_standards')
                            .orderBy('item')
                            .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return ShimmerWidget(
                          child: Container(
                            height: 300,
                            color: Colors.grey[300],
                          ),
                        );
                      }
                      var recipes = snapshot.data!.docs;
                      return ResponsiveBreakpoints.of(
                            context,
                          ).smallerThan(DESKTOP)
                          ? ListView.builder(
                            itemCount: recipes.length,
                            itemBuilder: (context, index) {
                              var data = recipes[index].data();
                              var id = recipes[index].id;
                              return Card(
                                elevation: 2,
                                child: ListTile(
                                  title: Text(data['item']),
                                  subtitle: Text(
                                    'Quantity per Piece: ${data['quantityPerPiece'].toStringAsFixed(4)}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.edit),
                                        onPressed:
                                            () => _editRecipeStandard(data, id),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete),
                                        onPressed:
                                            () => _deleteRecipeStandard(id),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                          : DataTable(
                            columns: [
                              DataColumn(label: Text('Ingredient')),
                              DataColumn(label: Text('Quantity per Piece')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows:
                                recipes.map((doc) {
                                  var data = doc.data();
                                  var id = doc.id;
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(data['item'])),
                                      DataCell(
                                        Text(
                                          data['quantityPerPiece']
                                              .toStringAsFixed(4),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: Icon(Icons.edit),
                                              onPressed:
                                                  () => _editRecipeStandard(
                                                    data,
                                                    id,
                                                  ),
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.delete),
                                              onPressed:
                                                  () =>
                                                      _deleteRecipeStandard(id),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                          );
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
}
