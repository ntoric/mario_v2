import React, { useState } from 'react';
import { X, Printer, Check } from 'lucide-react';
import { useDataStore, useUIStore, useAuthStore } from '../stores';
import { formatCurrency } from '../utils/currency';
import { api } from '../services/api';
import { printerService } from '../services/printer';

const BillModal: React.FC = () => {
  const { stores, orders, createBill, completeOrder } = useDataStore();
  const { user, currentStoreId } = useAuthStore();
  const currentStore = stores.find(s => s.id === currentStoreId);
  const { billModal, closeBillModal } = useUIStore();
  const [isPrinting, setIsPrinting] = useState(false);
  const [printError, setPrintError] = useState('');

  const isOpen = billModal.isOpen;
  const { order, table } = billModal.data || {};

  if (!isOpen || !order || !table) return null;

  const calculateTotals = () => {
    const subtotal = order.items.reduce((sum: number, oi: any) => sum + (oi.item.price * oi.quantity), 0);
    const tax = order.items.reduce((sum: number, oi: any) => {
      const taxPercent = oi.item.taxPercent || 0;
      return sum + (oi.item.price * oi.quantity * taxPercent / 100);
    }, 0);
    const total = subtotal + tax;
    return { subtotal, tax, total };
  };

  const { subtotal, tax, total } = calculateTotals();

  const handlePrint = async () => {
    setIsPrinting(true);
    setPrintError('');

    try {
      const invoiceNo = `INV-${Date.now()}`;

      // Create bill
      await createBill({
        orderId: order.id,
        tableNumber: table.number,
        invoiceNo,
        subtotal,
        taxTotal: tax,
        discount: 0,
        total,
        paymentMethod: order.paymentMethod || 'cash',
        customerName: 'Walk-in Customer',
      });

      // Print invoice via printer service
      const printItems = order.items.map((oi: any) => {
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

      const taxable = printItems.reduce((sum: number, item: any) => sum + item.amount, 0);
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
            name: 'Walk-in Customer',
            mobile: '',
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
            cash: (order.paymentMethod || 'cash') === 'cash' ? total : 0,
            card: (order.paymentMethod || 'cash') === 'card' ? total : 0,
            upi: (order.paymentMethod || 'cash') === 'upi' ? total : 0,
            balance: 0,
          },
          payment_mode: order.paymentMethod || 'cash',
          dr_ref: '',
          footer: ['Thank You Visit Again'],
        },
      });

      // Complete order
      await completeOrder(order.id, order.paymentMethod || 'cash');

      closeBillModal();
    } catch (error: any) {
      setPrintError(error.message || 'Failed to print');
    } finally {
      setIsPrinting(false);
    }
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleString();
  };

  return (
    <div className="modal-overlay" onClick={closeBillModal}>
      <div className="modal" onClick={e => e.stopPropagation()}>
        <div className="modal-header">
          <h2>Bill Receipt</h2>
          <button className="close-btn" onClick={closeBillModal}>
            <X size={24} />
          </button>
        </div>

        <div className="modal-body">
          <div className="bill-container">
            <div className="bill-header">
              <h2>Cafe Manager</h2>
              <p>123 Coffee Street, City</p>
              <p>Tel: (555) 123-4567</p>
            </div>

            <div className="bill-table-info">
              <h3>Table {order.tableNumber}</h3>
              <p>{formatDate(new Date().toISOString())}</p>
              <p>Server: {user?.name}</p>
            </div>

            <div className="bill-items">
              {order.items.map((oi: any, index: number) => (
                <div key={index} className="bill-item">
                  <div className="bill-item-details">
                    <div className="bill-item-name">{oi.item.name}</div>
                    <div className="bill-item-qty">{oi.quantity} x {formatCurrency(oi.item.price)}</div>
                  </div>
                  <div className="bill-item-price">{formatCurrency(oi.quantity * oi.item.price)}</div>
                </div>
              ))}
            </div>

            <div className="bill-totals">
              <div className="bill-total-row">
                <span>Subtotal</span>
                <span>{formatCurrency(subtotal)}</span>
              </div>
              <div className="bill-total-row">
                <span>Tax</span>
                <span>{formatCurrency(tax)}</span>
              </div>
              <div className="bill-total-row grand-total">
                <span>TOTAL</span>
                <span>{formatCurrency(total)}</span>
              </div>
            </div>

            <div className="bill-footer">
              <p>Thank you for visiting!</p>
              <p>Please come again</p>
            </div>
          </div>

          {printError && (
            <div style={{ color: 'var(--danger)', textAlign: 'center', marginTop: '1rem' }}>
              {printError}
            </div>
          )}
        </div>

        <div className="modal-footer">
          <button className="btn btn-primary" onClick={handlePrint} disabled={isPrinting}>
            <Printer size={16} />
            {isPrinting ? 'Printing...' : 'Print Bill'}
          </button>
          <button className="btn btn-secondary" onClick={closeBillModal}>
            Close
          </button>
        </div>
      </div>
    </div>
  );
};

export default BillModal;
