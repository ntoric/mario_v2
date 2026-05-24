import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../models/category.dart';
import '../models/item.dart';
import '../utils/constants.dart';

class CategoriesItemsScreen extends StatefulWidget {
  const CategoriesItemsScreen({super.key});

  @override
  State<CategoriesItemsScreen> createState() => _CategoriesItemsScreenState();
}

class _CategoriesItemsScreenState extends State<CategoriesItemsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _itemSearchController = TextEditingController();
  String _selectedCategoryId = 'all';
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _itemSearchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _itemSearchController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    final auth = context.read<AuthProvider>();
    final data = context.read<DataProvider>();
    if (auth.currentStore != null) {
      await data.loadCategories(auth.currentStore!.id);
      await data.loadItems(auth.currentStore!.id);
    }
    setState(() => _isRefreshing = false);
  }

  // --- Category Dialog Form ---
  void _showCategoryDialog({Category? category}) {
    final nameController = TextEditingController(text: category?.name ?? '');
    final descriptionController = TextEditingController(text: category?.description ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(category == null ? 'Add Category' : 'Edit Category'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Category Name *',
                    hintText: 'e.g., Starters, Main Course, Desserts',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter category name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Short description of this category',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final name = nameController.text.trim();
                  final description = descriptionController.text.trim().isEmpty 
                      ? null 
                      : descriptionController.text.trim();
                  
                  final auth = context.read<AuthProvider>();
                  final data = context.read<DataProvider>();
                  
                  Navigator.pop(context); // Close dialog

                  if (category == null) {
                    final newCat = await data.createCategory(
                      name: name,
                      description: description,
                      storeId: auth.currentStore!.id,
                    );
                    if (newCat != null && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Category "$name" created successfully'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error creating category: ${data.error ?? 'Unknown error'}'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                    }
                  } else {
                    final success = await data.updateCategory(
                      categoryId: category.id,
                      name: name,
                      description: description,
                    );
                    if (success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Category updated to "$name"'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error updating category: ${data.error ?? 'Unknown error'}'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // --- Category Delete Confirmation ---
  void _confirmDeleteCategory(Category category) {
    final data = context.read<DataProvider>();
    final itemsCount = data.items.where((i) => i.categoryId == category.id).length;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Category?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to delete category "${category.name}"?'),
              if (itemsCount > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Warning: This category contains $itemsCount items. Deleting it will detach these items.',
                          style: const TextStyle(fontSize: 12, color: AppColors.warning),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final success = await data.deleteCategory(category.id);
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Category "${category.name}" deleted'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting category: ${data.error ?? 'Unknown error'}'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // --- Item Dialog Form ---
  void _showItemDialog({Item? item}) {
    final nameController = TextEditingController(text: item?.name ?? '');
    final priceController = TextEditingController(text: item != null ? item.price.toStringAsFixed(2) : '');
    final hsnController = TextEditingController(text: item?.hsnCode ?? '');
    final taxController = TextEditingController(text: item != null ? item.taxPercent.toStringAsFixed(1) : '5.0');
    final descriptionController = TextEditingController(text: item?.description ?? '');
    final formKey = GlobalKey<FormState>();

    final data = context.read<DataProvider>();
    final categories = data.categories;

    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one category before adding items'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    String selectedCatId = item?.categoryId ?? categories.first.id;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(item == null ? 'Add Food Item' : 'Edit Food Item'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Item Name *',
                          hintText: 'e.g., Margherita Pizza, Masala Chai',
                          prefixIcon: Icon(Icons.fastfood_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter item name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedCatId,
                        decoration: const InputDecoration(
                          labelText: 'Category *',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: categories.map((cat) {
                          return DropdownMenuItem<String>(
                            value: cat.id,
                            child: Text(cat.name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setStateDialog(() => selectedCatId = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: priceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Price * (₹)',
                                hintText: '0.00',
                                prefixIcon: Icon(Icons.currency_rupee),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Enter price';
                                }
                                final p = double.tryParse(value);
                                if (p == null || p < 0) {
                                  return 'Invalid price';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: taxController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Tax (%)',
                                hintText: '5.0',
                                prefixIcon: Icon(Icons.percent),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Enter tax';
                                }
                                final t = double.tryParse(value);
                                if (t == null || t < 0) {
                                  return 'Invalid tax';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: hsnController,
                        decoration: const InputDecoration(
                          labelText: 'HSN / SAC Code',
                          hintText: 'e.g., 9963',
                          prefixIcon: Icon(Icons.pin_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Ingredients or details',
                          prefixIcon: Icon(Icons.description_outlined),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final name = nameController.text.trim();
                      final price = double.parse(priceController.text);
                      final tax = double.parse(taxController.text);
                      final hsn = hsnController.text.trim().isEmpty ? null : hsnController.text.trim();
                      final description = descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim();

                      final auth = context.read<AuthProvider>();
                      final data = context.read<DataProvider>();

                      Navigator.pop(context); // Close dialog

                      if (item == null) {
                        final newItem = await data.createItem(
                          categoryId: selectedCatId,
                          name: name,
                          description: description,
                          price: price,
                          hsnCode: hsn,
                          taxPercent: tax,
                          storeId: auth.currentStore!.id,
                        );
                        if (newItem != null && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Item "$name" added'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error adding item: ${data.error ?? 'Unknown error'}'),
                              backgroundColor: AppColors.danger,
                            ),
                          );
                        }
                      } else {
                        final success = await data.updateItem(
                          itemId: item.id,
                          categoryId: selectedCatId,
                          name: name,
                          description: description,
                          price: price,
                          hsnCode: hsn,
                          taxPercent: tax,
                        );
                        if (success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Item "$name" updated'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error updating item: ${data.error ?? 'Unknown error'}'),
                              backgroundColor: AppColors.danger,
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Item Delete Confirmation ---
  void _confirmDeleteItem(Item item) {
    final data = context.read<DataProvider>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Food Item?'),
          content: Text('Are you sure you want to delete food/beverage item "${item.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final success = await data.deleteItem(item.id);
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Item "${item.name}" deleted'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting item: ${data.error ?? 'Unknown error'}'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final data = context.watch<DataProvider>();
    const isStaff = true; // Categories and items are read-only in the mobile app

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14.0),
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Menu List'),
            if (auth.currentStore != null)
              Text(
                auth.currentStore!.displayName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: AppColors.gray600,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.category_outlined),
              text: 'Categories',
            ),
            Tab(
              icon: Icon(Icons.fastfood_outlined),
              text: 'Food Items',
            ),
          ],
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.gray600,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCategoriesTab(data, isStaff),
          _buildItemsTab(data, isStaff),
        ],
      ),
      floatingActionButton: null,
    );
  }

  // --- Categories List Panel ---
  Widget _buildCategoriesTab(DataProvider data, bool isStaff) {
    final categories = data.categories;

    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.category_outlined,
              size: 64,
              color: AppColors.gray400,
            ),
            const SizedBox(height: 16),
            const Text(
              'No categories found',
              style: TextStyle(fontSize: 18, color: AppColors.gray600),
            ),
            if (!isStaff) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _showCategoryDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Category'),
              ),
            ],
          ],
        ),
      );
    }

    final isTablet = ResponsiveHelper.isTablet(context) || ResponsiveHelper.isDesktop(context);

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isTablet ? 3 : 1,
          childAspectRatio: isTablet ? 2.5 : 3.8,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final itemsCount = data.items.where((i) => i.categoryId == cat.id).length;

          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.category,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          cat.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.dark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (cat.description != null && cat.description!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            cat.description!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.gray600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          '$itemsCount items linked',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isStaff) ...[
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: AppColors.info, size: 20),
                      onPressed: () => _showCategoryDialog(category: cat),
                      tooltip: 'Edit Category',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                      onPressed: () => _confirmDeleteCategory(cat),
                      tooltip: 'Delete Category',
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Items List Panel with Search & Filter ---
  Widget _buildItemsTab(DataProvider data, bool isStaff) {
    final categories = data.categories;
    final query = _itemSearchController.text.toLowerCase().trim();

    // Filter Items dynamically
    final filteredItems = data.items.where((item) {
      final matchesQuery = item.name.toLowerCase().contains(query) ||
          (item.description?.toLowerCase().contains(query) ?? false);
      
      final matchesCategory = _selectedCategoryId == 'all' || item.categoryId == _selectedCategoryId;

      return matchesQuery && matchesCategory;
    }).toList();

    return Column(
      children: [
        // Search and Filter Bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _itemSearchController,
                      decoration: InputDecoration(
                        hintText: 'Search food or beverages...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _itemSearchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => _itemSearchController.clear(),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        fillColor: AppColors.light,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text(
                      'Filter: ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.gray700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('All Categories'),
                      selected: _selectedCategoryId == 'all',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedCategoryId = 'all');
                        }
                      },
                    ),
                    ...categories.map((cat) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: ChoiceChip(
                          label: Text(cat.name),
                          selected: _selectedCategoryId == cat.id,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedCategoryId = cat.id);
                            }
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Items Grid/List
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshData,
            child: filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.fastfood_outlined,
                          size: 64,
                          color: AppColors.gray400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          query.isNotEmpty || _selectedCategoryId != 'all'
                              ? 'No matching food items found'
                              : 'No food items added yet',
                          style: const TextStyle(fontSize: 16, color: AppColors.gray600),
                        ),
                        if (!isStaff && query.isEmpty && _selectedCategoryId == 'all') ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _showItemDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Food Item'),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: AppColors.gray200,
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            child: const Icon(
                              Icons.restaurant_menu,
                              color: AppColors.primary,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Text(
                                '₹${item.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.gray200,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item.categoryName ?? 'Uncategorized',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.gray700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Tax: ${item.taxPercent}%',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.gray600,
                                    ),
                                  ),
                                  if (item.hsnCode != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      'HSN: ${item.hsnCode}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.gray600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (item.description != null && item.description!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  item.description!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.gray600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                          trailing: isStaff
                              ? null
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: AppColors.info, size: 20),
                                      onPressed: () => _showItemDialog(item: item),
                                      tooltip: 'Edit Item',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                                      onPressed: () => _confirmDeleteItem(item),
                                      tooltip: 'Delete Item',
                                    ),
                                  ],
                                ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
