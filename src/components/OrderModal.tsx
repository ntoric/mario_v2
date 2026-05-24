import React, { useState, useEffect, useCallback } from 'react';
import { X, Plus, Minus, Trash2, Receipt, Search, Printer } from 'lucide-react';
import { useDataStore, useUIStore, useAuthStore } from '../stores';
import { formatCurrency } from '../utils/currency';
import { api } from '../services/api';
import type { OrderItem, Item } from '../types';

const OrderModal: React.FC = () => {
  const { categories, items, stores, createOrder, updateOrder, completeOrder, createBill, fetchCategories, fetchItems } = useDataStore();
  const { user, currentStoreId } = useAuthStore();
  const { orderModal, closeOrderModal } = useUIStore();
  const currentStore = stores.find(s => s.id === currentStoreId);
  const [selectedCategory, setSelectedCategory] = useState<string>('all');
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [orderItems, setOrderItems] = useState<OrderItem[]>([]);
  const [showBillDialog, setShowBillDialog] = useState(false);
  const [paymentMethod, setPaymentMethod] = useState('upi');
  const [isPrinting, setIsPrinting] = useState(false);

  const isOpen = orderModal.isOpen;
  const { table, existingOrder, viewOnly } = orderModal.data || {};

  // Fetch categories and items when modal opens
  useEffect(() => {
    if (isOpen) {
      fetchCategories();
      fetchItems();
    }
  }, [isOpen, fetchCategories, fetchItems]);

  useEffect(() => {
    if (isOpen && existingOrder) {
      setOrderItems(existingOrder.items);
    } else if (isOpen) {
      setOrderItems([]);
    }
    // Reset state when modal opens
    if (isOpen) {
      setShowBillDialog(false);
      setPaymentMethod('upi');
      setIsPrinting(false);
    }
  }, [isOpen, existingOrder]);

  // Handle Enter key in bill dialog
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (showBillDialog && e.key === 'Enter' && !isPrinting && currentStore?.remoteBillingEnabled) {
        e.preventDefault();
        handlePrintAndComplete();
      }
    };

    if (showBillDialog) {
      window.addEventListener('keydown', handleKeyDown);
      return () => window.removeEventListener('keydown', handleKeyDown);
    }
  }, [showBillDialog, isPrinting, paymentMethod, currentStore]);

  if (!isOpen || !table) return null;

  const filteredItems = items.filter(item => {
    const matchesCategory = selectedCategory === 'all' || item.categoryId === selectedCategory;
    const matchesSearch = searchQuery === '' || item.name.toLowerCase().includes(searchQuery.toLowerCase());
    return matchesCategory && matchesSearch;
  });

  const addItemToOrder = (item: Item) => {
    if (viewOnly) return;
    
    const existingItem = orderItems.find(oi => oi.itemId === item.id);
    if (existingItem) {
      setOrderItems(orderItems.map(oi =>
        oi.itemId === item.id
          ? { ...oi, quantity: oi.quantity + 1 }
          : oi
      ));
    } else {
      setOrderItems([...orderItems, { itemId: item.id, item, quantity: 1 }]);
    }
  };

  const updateQuantity = (itemId: string, delta: number) => {
    if (viewOnly) return;
    
    setOrderItems(orderItems.map(oi => {
      if (oi.itemId === itemId) {
        const newQuantity = oi.quantity + delta;
        return newQuantity > 0 ? { ...oi, quantity: newQuantity } : oi;
      }
      return oi;
    }).filter(oi => oi.quantity > 0));
  };

  const removeItem = (itemId: string) => {
    if (viewOnly) return;
    setOrderItems(orderItems.filter(oi => oi.itemId !== itemId));
  };

  const calculateTotal = () => {
    return orderItems.reduce((sum, oi) => sum + (oi.item.price * oi.quantity), 0);
  };

  const calculateTax = () => {
    return orderItems.reduce((sum, oi) => {
      const taxPercent = oi.item.taxPercent || 0;
      return sum + (oi.item.price * oi.quantity * taxPercent / 100);
    }, 0);
  };

  const handleSaveOrder = async () => {
    if (orderItems.length === 0) return;

    const totalAmount = calculateTotal();
    const taxAmount = calculateTax();
    
    if (existingOrder) {
      await updateOrder(existingOrder.id, {
        items: orderItems,
        totalAmount,
        taxAmount,
      });
    } else {
      const newOrder = await createOrder({
        tableId: table.id,
        tableNumber: table.number,
        items: orderItems,
        totalAmount,
        taxAmount,
        discountAmount: 0,
        paymentMethod: 'cash',
      });

      // Print KOT if enabled for the store
      if (currentStore?.kotPrintEnabled && newOrder?.id) {
        try {
          await api.printKOT({ orderId: newOrder.id });
        } catch (error) {
          console.error('Failed to print KOT:', error);
          // Don't block the order creation if KOT printing fails
        }
      }
    }
    closeOrderModal();
    setOrderItems([]);
  };

  const handlePrintAndComplete = async () => {
    if (!existingOrder || orderItems.length === 0 || isPrinting) return;

    setIsPrinting(true);

    try {
      const subtotal = calculateTotal();
      const tax = calculateTax();
      const total = subtotal + tax;
      const invoiceNo = `INV-${Date.now()}`;

      // Create bill
      await createBill({
        orderId: existingOrder.id,
        tableNumber: table.number,
        invoiceNo,
        subtotal,
        taxTotal: tax,
        discount: 0,
        total,
        paymentMethod,
        customerName: 'Walk-in Customer',
      });

      // Print invoice
      await api.printInvoice({
        orderId: existingOrder.id,
        invoiceNo,
        paymentMethod,
        customerName: 'Walk-in Customer',
      });

      // Complete order
      await completeOrder(existingOrder.id, paymentMethod);

      // Close modal and reset
      setShowBillDialog(false);
      closeOrderModal();
      setOrderItems([]);
    } catch (error) {
      console.error('Failed to print and complete:', error);
      alert('Failed to print bill. Please try again.');
    } finally {
      setIsPrinting(false);
    }
  };

  const total = calculateTotal() + calculateTax();

  return (
    <div className="modal-overlay" onClick={closeOrderModal}>
      <div className="modal order-modal" onClick={e => e.stopPropagation()}>
        <div className="modal-header">
          <h2>
            {viewOnly ? 'View Order' : existingOrder ? 'Edit Order' : 'New Order'} - Table {table.number}
          </h2>
          <button className="close-btn" onClick={closeOrderModal}>
            <X size={24} />
          </button>
        </div>

        <div className="modal-body order-modal-body">
          <div className="order-layout-fixed">
            <div className="order-main-fixed">
              {!viewOnly && (
                <>
                  <div className="order-search-box">
                    <Search size={16} className="search-icon" />
                    <input
                      type="text"
                      placeholder="Search items..."
                      value={searchQuery}
                      onChange={(e) => setSearchQuery(e.target.value)}
                      className="order-search-input"
                    />
                    {searchQuery && (
                      <button
                        className="clear-search-btn"
                        onClick={() => setSearchQuery('')}
                      >
                        <X size={14} />
                      </button>
                    )}
                  </div>

                  <div className="categories-list">
                    <button
                      className={`category-btn ${selectedCategory === 'all' ? 'active' : ''}`}
                      onClick={() => setSelectedCategory('all')}
                    >
                      All
                    </button>
                    {categories.map(cat => (
                      <button
                        key={cat.id}
                        className={`category-btn ${selectedCategory === cat.id ? 'active' : ''}`}
                        onClick={() => setSelectedCategory(cat.id)}
                      >
                        {cat.name}
                      </button>
                    ))}
                  </div>

                  <div className="items-grid-scrollable">
                    {filteredItems.map(item => (
                      <div
                        key={item.id}
                        className="item-card"
                        onClick={() => addItemToOrder(item)}
                      >
                        <div className="item-name">{item.name}</div>
                        <div className="item-price">{formatCurrency(item.price)}</div>
                      </div>
                    ))}
                  </div>
                </>
              )}

              {viewOnly && (
                <div style={{ textAlign: 'center', color: 'var(--gray-600)', padding: '3rem' }}>
                  Order items are shown in the sidebar
                </div>
              )}
            </div>

            <div className="order-sidebar-fixed">
              <h3>Order Items ({orderItems.length})</h3>
              
              {orderItems.length === 0 ? (
                <div className="empty-order">
                  {viewOnly ? 'No items in this order' : 'Click items to add'}
                </div>
              ) : (
                <>
                  <div className="order-items-scrollable">
                    {orderItems.map(oi => (
                      <div key={oi.itemId} className="order-item-compact">
                        <div className="order-item-info">
                          <div className="order-item-name">{oi.item.name}</div>
                          <div className="order-item-price">{formatCurrency(oi.item.price)}</div>
                        </div>
                        <div className="order-item-actions">
                          {!viewOnly && (
                            <>
                              <button
                                className="quantity-btn"
                                onClick={() => updateQuantity(oi.itemId, -1)}
                              >
                                <Minus size={10} />
                              </button>
                              <span className="order-item-quantity">{oi.quantity}</span>
                              <button
                                className="quantity-btn"
                                onClick={() => updateQuantity(oi.itemId, 1)}
                              >
                                <Plus size={10} />
                              </button>
                              <button
                                className="remove-item-btn"
                                onClick={() => removeItem(oi.itemId)}
                              >
                                <Trash2 size={12} />
                              </button>
                            </>
                          )}
                          {viewOnly && (
                            <span className="order-item-quantity">x{oi.quantity}</span>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>

                  <div className="order-total-fixed">
                    <div className="total-row">
                      <span>Subtotal</span>
                      <span>{formatCurrency(calculateTotal())}</span>
                    </div>
                    <div className="total-row">
                      <span>Tax</span>
                      <span>{formatCurrency(calculateTax())}</span>
                    </div>
                    <div className="total-row final">
                      <span>Total</span>
                      <span>{formatCurrency(total)}</span>
                    </div>
                  </div>
                </>
              )}
            </div>
          </div>
        </div>

        <div className="modal-footer">
          {existingOrder && !viewOnly && (
            <button
              className="btn btn-primary"
              onClick={() => setShowBillDialog(true)}
              disabled={orderItems.length === 0}
            >
              <Receipt size={16} />
              Bill
            </button>
          )}
          {!viewOnly && (
            <button
              className="btn btn-primary"
              onClick={handleSaveOrder}
              disabled={orderItems.length === 0}
            >
              {existingOrder ? 'Update Order' : 'Place Order'}
            </button>
          )}
          <button className="btn btn-secondary" onClick={closeOrderModal}>
            {viewOnly ? 'Close' : 'Cancel'}
          </button>
        </div>

        {/* Bill Dialog */}
        {showBillDialog && (
          <div className="modal-overlay" onClick={() => !isPrinting && setShowBillDialog(false)}>
            <div className="modal bill-dialog" onClick={e => e.stopPropagation()}>
              <div className="modal-header">
                <h2>Print Bill</h2>
                <button 
                  className="close-btn" 
                  onClick={() => !isPrinting && setShowBillDialog(false)}
                  disabled={isPrinting}
                >
                  <X size={24} />
                </button>
              </div>
              <div className="modal-body">
                <div className="bill-total-display">
                  <span className="bill-total-label">Total Amount</span>
                  <span className="bill-total-value">{formatCurrency(total)}</span>
                </div>
                
                <div className="payment-method-section">
                  <label className="payment-label">Payment Method</label>
                  <div className="payment-options">
                    <button
                      className={`payment-option ${paymentMethod === 'cash' ? 'active' : ''}`}
                      onClick={() => setPaymentMethod('cash')}
                      data-method="cash"
                    >
                      Cash
                    </button>
                    <button
                      className={`payment-option ${paymentMethod === 'card' ? 'active' : ''}`}
                      onClick={() => setPaymentMethod('card')}
                      data-method="card"
                    >
                      Card
                    </button>
                    <button
                      className={`payment-option ${paymentMethod === 'upi' ? 'active' : ''}`}
                      onClick={() => setPaymentMethod('upi')}
                      data-method="upi"
                    >
                      UPI
                    </button>
                  </div>
                </div>

                <p className="bill-hint">Press Enter or click Print to complete</p>
              </div>
              <div className="modal-footer">
                <button 
                  className="btn btn-primary btn-lg" 
                  onClick={handlePrintAndComplete}
                >
                  <Printer size={18} />
                  {isPrinting ? 'Printing...' : 'Print & Complete'}
                </button>
                <button 
                  className="btn btn-secondary" 
                  onClick={() => setShowBillDialog(false)}
                  disabled={isPrinting}
                >
                  Cancel
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default OrderModal;
