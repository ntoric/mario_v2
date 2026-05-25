import React, { useState, useEffect } from 'react';
import { X, Plus, Minus, Trash2, Search, Printer, Package } from 'lucide-react';
import { useDataStore, useUIStore, useAuthStore } from '../stores';
import { formatCurrency } from '../utils/currency';
import { api } from '../services/api';
import { printerService } from '../services/printer';
import type { OrderItem, Item } from '../types';

const ParcelOrderModal: React.FC = () => {
  const { categories, items, stores, fetchCategories, fetchItems, fetchOrders } = useDataStore();
  const { user, currentStoreId } = useAuthStore();
  const { parcelOrderModal, closeParcelOrderModal } = useUIStore();
  const currentStore = stores.find(s => s.id === currentStoreId);
  const [selectedCategory, setSelectedCategory] = useState<string>('all');
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [orderItems, setOrderItems] = useState<OrderItem[]>([]);
  const [showCustomerDialog, setShowCustomerDialog] = useState(false);
  const [customerName, setCustomerName] = useState('');
  const [customerMobile, setCustomerMobile] = useState('');
  const [paymentMethod, setPaymentMethod] = useState('cash');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const isOpen = parcelOrderModal.isOpen;

  useEffect(() => {
    if (isOpen) {
      fetchCategories();
      fetchItems();
    }
  }, [isOpen, fetchCategories, fetchItems]);

  useEffect(() => {
    if (isOpen) {
      setOrderItems([]);
      setShowCustomerDialog(false);
      setCustomerName('');
      setCustomerMobile('');
      setPaymentMethod('upi');
      setIsSubmitting(false);
      setSelectedCategory('all');
      setSearchQuery('');
    }
  }, [isOpen]);

  if (!isOpen) return null;

  const filteredItems = items.filter(item => {
    const matchesCategory = selectedCategory === 'all' || item.categoryId === selectedCategory;
    const matchesSearch = searchQuery === '' || item.name.toLowerCase().includes(searchQuery.toLowerCase());
    return matchesCategory && matchesSearch;
  });

  const addItemToOrder = (item: Item) => {
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
    setOrderItems(orderItems.map(oi => {
      if (oi.itemId === itemId) {
        const newQuantity = oi.quantity + delta;
        return newQuantity > 0 ? { ...oi, quantity: newQuantity } : oi;
      }
      return oi;
    }).filter(oi => oi.quantity > 0));
  };

  const removeItem = (itemId: string) => {
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

  const total = calculateTotal() + calculateTax();

  const handleCreateOrderClick = () => {
    if (orderItems.length === 0) return;
    setShowCustomerDialog(true);
  };

  const handleSubmit = async () => {
    if (orderItems.length === 0 || isSubmitting) return;

    setIsSubmitting(true);

    try {
      const totalAmount = calculateTotal();
      const taxAmount = calculateTax();
      const invoiceNo = `INV-${Date.now()}`;

      const payload = {
        storeId: currentStoreId,
        items: orderItems.map(oi => ({
          itemId: oi.itemId,
          quantity: oi.quantity,
          unitPrice: oi.item.price,
          taxPercent: oi.item.taxPercent || 0,
          notes: oi.notes || '',
          item: {
            id: oi.item.id,
            name: oi.item.name,
            price: oi.item.price,
            description: oi.item.description || '',
            taxPercent: oi.item.taxPercent || 0,
          },
        })),
        totalAmount,
        taxAmount,
        discountAmount: 0,
        paymentMethod,
        customerName: customerName.trim() || 'Walk-in Customer',
        customerMobile: customerMobile.trim(),
      };

      const createdOrder = await api.createParcelOrder(payload);

      // Print KOT if enabled for the store
      if (currentStore?.kotPrintEnabled && createdOrder?.id) {
        try {
          await printerService.printKOT({
            type: 'kot',
            printer: {
              type: 'usb',
              name: currentStore.printerName || 'Thermal Printer',
              vendor_id: currentStore.printerVendorId || '0x0fe6',
              product_id: currentStore.printerProductId || '0x811e',
              paper_width: (currentStore.invoiceSize as '2inch' | '3inch') || '3inch',
            },
            kot: {
              order_id: parseInt(createdOrder.id.slice(-6), 36) || 0,
              table_number: 'Parcel',
              waiter_name: '',
              date: new Date().toLocaleString('en-IN'),
              items: orderItems.map(oi => ({
                name: oi.item.name,
                qty: oi.quantity,
                unit: 'PCS',
                rate: oi.item.price,
                tax_percent: oi.item.taxPercent || 0,
                amount: oi.item.price * oi.quantity,
              })),
              notes: '',
              order_type: 'TAKE_AWAY',
              customer_name: customerName.trim() || 'Guest',
              customer_mobile: customerMobile.trim(),
            },
          });
        } catch (error) {
          console.error('Failed to print KOT:', error);
        }
      }

      // Print invoice
      try {
        const printItems = orderItems.map(oi => {
          const itemTotal = oi.item.price * oi.quantity;
          const taxPercent = oi.item.taxPercent || 0;
          return {
            name: oi.item.name,
            hsn: oi.item.description || '',
            qty: oi.quantity,
            unit: 'PCS',
            rate: oi.item.price,
            tax_percent: taxPercent,
            amount: itemTotal,
          };
        });

        const taxable = printItems.reduce((sum, item) => sum + item.amount, 0);
        const cgst = taxable * 0.025;
        const sgst = taxable * 0.025;

        await printerService.printInvoice({
          type: 'invoice',
          printer: {
            type: 'usb',
            name: currentStore?.printerName || 'Thermal Printer',
            vendor_id: currentStore?.printerVendorId || '0x0fe6',
            product_id: currentStore?.printerProductId || '0x811e',
            paper_width: (currentStore?.invoiceSize as '2inch' | '3inch') || '3inch',
          },
          invoice: {
            store: {
              name: currentStore?.name || 'Cafe',
              branch: currentStore?.branch || '',
              location: currentStore?.location || '',
              gst_number: currentStore?.gstin || '',
              fssai_lic_no: currentStore?.fssaiNo || '',
              phone: currentStore?.phone || '',
              address: currentStore?.location || '',
            },
            customer: {
              name: customerName.trim() || 'Walk-in Customer',
              mobile: customerMobile.trim(),
            },
            invoice_no: invoiceNo,
            bill_no: invoiceNo,
            date: new Date().toLocaleString('en-IN'),
            items: printItems,
            summary: {
              sub_total: taxable,
              discount: 0,
              taxable: taxable,
              cgst: cgst,
              sgst: sgst,
              grand_total: total,
            },
            payment: {
              cash: paymentMethod === 'cash' ? total : 0,
              card: paymentMethod === 'card' ? total : 0,
              upi: paymentMethod === 'upi' ? total : 0,
              balance: 0,
            },
            payment_mode: paymentMethod,
            dr_ref: '',
            footer: ['Thank You Visit Again'],
          },
        });
      } catch (error) {
        console.error('Failed to print invoice:', error);
      }

      await fetchOrders();
      closeParcelOrderModal();
    } catch (error) {
      console.error('Failed to create parcel order:', error);
      alert('Failed to create parcel order. Please try again.');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="modal-overlay" onClick={closeParcelOrderModal}>
      <div className="modal order-modal" onClick={e => e.stopPropagation()}>
        <div className="modal-header">
          <h2>
            <Package size={20} style={{ marginRight: '0.5rem', verticalAlign: 'middle' }} />
            Parcel Order
          </h2>
          <button className="close-btn" onClick={closeParcelOrderModal}>
            <X size={24} />
          </button>
        </div>

        <div className="modal-body order-modal-body">
          <div className="order-layout-fixed">
            <div className="order-main-fixed">
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
            </div>

            <div className="order-sidebar-fixed">
              <h3>Order Items ({orderItems.length})</h3>

              {orderItems.length === 0 ? (
                <div className="empty-order">
                  Click items to add
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
          <button
            className="btn btn-primary"
            onClick={handleCreateOrderClick}
            disabled={orderItems.length === 0}
          >
            <Package size={16} />
            Create Order
          </button>
          <button className="btn btn-secondary" onClick={closeParcelOrderModal}>
            Cancel
          </button>
        </div>

        {/* Customer Details Dialog */}
        {showCustomerDialog && (
          <div className="modal-overlay" onClick={() => !isSubmitting && setShowCustomerDialog(false)}>
            <div className="modal" style={{ maxWidth: '450px' }} onClick={e => e.stopPropagation()}>
              <div className="modal-header">
                <h2>Customer Details</h2>
                <button
                  className="close-btn"
                  onClick={() => !isSubmitting && setShowCustomerDialog(false)}
                  disabled={isSubmitting}
                >
                  <X size={24} />
                </button>
              </div>
              <div className="modal-body">
                <div className="bill-total-display">
                  <span className="bill-total-label">Total Amount</span>
                  <span className="bill-total-value">{formatCurrency(total)}</span>
                </div>

                <div className="form-group" style={{ marginTop: '1rem' }}>
                  <label>Customer Name <span style={{ color: 'var(--gray-400)' }}>(optional)</span></label>
                  <input
                    type="text"
                    value={customerName}
                    onChange={e => setCustomerName(e.target.value)}
                    placeholder="e.g. John Doe"
                    disabled={isSubmitting}
                  />
                </div>

                <div className="form-group">
                  <label>Mobile Number <span style={{ color: 'var(--gray-400)' }}>(optional)</span></label>
                  <input
                    type="text"
                    value={customerMobile}
                    onChange={e => setCustomerMobile(e.target.value)}
                    placeholder="e.g. 9876543210"
                    disabled={isSubmitting}
                  />
                </div>

                <div className="payment-method-section" style={{ marginTop: '1rem' }}>
                  <label className="payment-label">Payment Method</label>
                  <div className="payment-options">
                    <button
                      className={`payment-option ${paymentMethod === 'cash' ? 'active' : ''}`}
                      onClick={() => setPaymentMethod('cash')}
                      data-method="cash"
                      disabled={isSubmitting}
                    >
                      Cash
                    </button>
                    <button
                      className={`payment-option ${paymentMethod === 'card' ? 'active' : ''}`}
                      onClick={() => setPaymentMethod('card')}
                      data-method="card"
                      disabled={isSubmitting}
                    >
                      Card
                    </button>
                    <button
                      className={`payment-option ${paymentMethod === 'upi' ? 'active' : ''}`}
                      onClick={() => setPaymentMethod('upi')}
                      data-method="upi"
                      disabled={isSubmitting}
                    >
                      UPI
                    </button>
                  </div>
                </div>
              </div>
              <div className="modal-footer">
                <button
                  className="btn btn-primary btn-lg"
                  onClick={handleSubmit}
                  disabled={isSubmitting}
                >
                  <Printer size={18} />
                  {isSubmitting ? 'Processing...' : 'Submit & Print'}
                </button>
                <button
                  className="btn btn-secondary"
                  onClick={() => setShowCustomerDialog(false)}
                  disabled={isSubmitting}
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

export default ParcelOrderModal;
