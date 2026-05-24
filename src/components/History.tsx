import React, { useState, useEffect } from 'react';
import { Eye, Calendar, Search, Receipt, Printer } from 'lucide-react';
import { useDataStore } from '../stores';
import { usePageHeader } from '../contexts/PageHeaderContext';
import { formatCurrency } from '../utils/currency';
import { api } from '../services/api';
import type { Order } from '../types';

const History: React.FC = () => {
  const { orders, bills, fetchOrders, fetchBills } = useDataStore();
  const { setHeaderContent } = usePageHeader();
  const [viewingOrder, setViewingOrder] = useState<Order | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState<string>('all');
  const [isPrinting, setIsPrinting] = useState<string | null>(null);

  const handlePrintBill = async (order: Order) => {
    setIsPrinting(order.id);
    try {
      const associatedBill = bills.find(b => b.orderId === order.id);
      await api.printInvoice({
        orderId: order.id,
        invoiceNo: associatedBill?.invoiceNo,
        customerName: associatedBill?.customerName || 'Walk-in Customer',
        paymentMethod: associatedBill?.paymentMethod || order.paymentMethod || 'cash',
      });
    } catch (error) {
      console.error('Failed to print bill:', error);
      alert('Failed to print bill. Please try again.');
    } finally {
      setIsPrinting(null);
    }
  };

  // Fetch data on mount
  useEffect(() => {
    fetchOrders();
    fetchBills();
  }, [fetchOrders, fetchBills]);

  const filteredOrders = orders.filter(order => {
    const matchesSearch = 
      order.tableNumber.toString().includes(searchTerm) ||
      order.items.some(i => i.item.name.toLowerCase().includes(searchTerm.toLowerCase()));
    
    const matchesStatus = statusFilter === 'all' || order.status === statusFilter;
    
    return matchesSearch && matchesStatus;
  }).sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());

  // Set page header
  useEffect(() => {
    setHeaderContent({
      title: 'Order History',
      subtitle: 'View and manage all orders',
      actions: null,
    });
  }, [setHeaderContent]);

  const completedCount = orders.filter(o => o.status === 'completed').length;
  const activeCount = orders.filter(o => o.status === 'active').length;
  const totalRevenue = bills.reduce((sum, b) => sum + b.total, 0);

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleString();
  };

  const getStatusBadgeClass = (status: string) => {
    switch (status) {
      case 'completed': return 'status-badge completed';
      case 'active': return 'status-badge active';
      case 'cancelled': return 'status-badge cancelled';
      default: return 'status-badge';
    }
  };

  return (
    <div>
      <div className="stats-grid">
        <div className="stat-card">
          <div className="stat-icon success">
            <Receipt size={24} />
          </div>
          <div className="stat-content">
            <div className="stat-value">{completedCount}</div>
            <div className="stat-label">Completed Orders</div>
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon warning">
            <Calendar size={24} />
          </div>
          <div className="stat-content">
            <div className="stat-value">{activeCount}</div>
            <div className="stat-label">Active Orders</div>
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon primary">
            <Receipt size={24} />
          </div>
          <div className="stat-content">
            <div className="stat-value">{formatCurrency(totalRevenue)}</div>
            <div className="stat-label">Total Revenue</div>
          </div>
        </div>
      </div>

      <div className="card">
        <div className="card-header">
          <div className="history-filters" style={{ margin: 0, flex: 1 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', flex: 1, maxWidth: '400px' }}>
              <Search size={18} color="var(--gray-500)" />
              <input
                type="text"
                placeholder="Search by table or item..."
                value={searchTerm}
                onChange={e => setSearchTerm(e.target.value)}
                style={{ flex: 1 }}
              />
            </div>
            <select value={statusFilter} onChange={e => setStatusFilter(e.target.value)}>
              <option value="all">All Status</option>
              <option value="completed">Completed</option>
              <option value="active">Active</option>
              <option value="cancelled">Cancelled</option>
            </select>
          </div>
        </div>
        <div className="card-body">
          {filteredOrders.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '4rem', color: 'var(--gray-500)' }}>
              <Calendar size={64} style={{ marginBottom: '1.5rem', opacity: 0.5 }} />
              <p style={{ fontSize: '1.125rem' }}>No orders found</p>
              <p style={{ fontSize: '0.875rem', marginTop: '0.5rem' }}>Try adjusting your search or filters</p>
            </div>
          ) : (
            filteredOrders.map(order => (
              <div key={order.id} className="order-card">
                <div className="order-card-header">
                  <div>
                    <span className="order-card-title">Table {order.tableNumber}</span>
                    <span className={getStatusBadgeClass(order.status)} style={{ marginLeft: '1rem' }}>
                      {order.status}
                    </span>
                  </div>
                  <div className="order-card-meta">
                    <span>Order #{order.id.slice(-6).toUpperCase()}</span>
                    <span>{formatDate(order.createdAt)}</span>
                  </div>
                </div>

                <div className="order-card-items">
                  {order.items.map((oi, idx) => (
                    <div key={idx} className="order-item-row">
                      <span>{oi.quantity}x {oi.item.name}</span>
                      <span style={{ fontWeight: 600 }}>{formatCurrency(oi.quantity * oi.item.price)}</span>
                    </div>
                  ))}
                </div>

                <div className="order-card-total">
                  <span>Total</span>
                  <span style={{ color: 'var(--primary)' }}>{formatCurrency(order.totalAmount)}</span>
                </div>

                <div style={{ marginTop: '1.25rem', display: 'flex', gap: '0.75rem' }}>
                  <button className="btn btn-primary btn-sm" onClick={() => setViewingOrder(order)}>
                    <Eye size={16} />
                    View Details
                  </button>
                  <button 
                    className="btn btn-secondary btn-sm" 
                    onClick={() => handlePrintBill(order)}
                    disabled={isPrinting === order.id}
                  >
                    <Printer size={16} />
                    {isPrinting === order.id ? 'Printing...' : 'Print Bill'}
                  </button>
                </div>
              </div>
            ))
          )}
        </div>
      </div>

      {/* View Order Modal */}
      {viewingOrder && (
        <div className="modal-overlay" onClick={() => setViewingOrder(null)}>
          <div className="modal" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h2>Order Details - Table {viewingOrder.tableNumber}</h2>
              <button className="close-btn" onClick={() => setViewingOrder(null)}>
                <Receipt size={20} />
              </button>
            </div>
            <div className="modal-body">
              <div className="order-sidebar">
                {viewingOrder.items.map((oi, idx) => (
                  <div key={idx} className="order-item">
                    <div className="order-item-info">
                      <div className="order-item-name">{oi.item.name}</div>
                      <div className="order-item-price">{formatCurrency(oi.item.price)} each</div>
                    </div>
                    <span className="order-item-quantity">x{oi.quantity}</span>
                  </div>
                ))}
                <div className="order-total">
                  <div className="total-row">
                    <span>Subtotal</span>
                    <span>{formatCurrency(viewingOrder.totalAmount)}</span>
                  </div>
                  <div className="total-row">
                    <span>Tax</span>
                    <span>{formatCurrency(viewingOrder.taxAmount || 0)}</span>
                  </div>
                  <div className="total-row final">
                    <span>Total</span>
                    <span>{formatCurrency((viewingOrder.totalAmount || 0) + (viewingOrder.taxAmount || 0))}</span>
                  </div>
                </div>
              </div>
            </div>
            <div className="modal-footer" style={{ display: 'flex', justifyContent: 'space-between', width: '100%' }}>
              <button 
                className="btn btn-primary" 
                onClick={() => handlePrintBill(viewingOrder)}
                disabled={isPrinting === viewingOrder.id}
              >
                <Printer size={16} style={{ marginRight: '0.5rem' }} />
                {isPrinting === viewingOrder.id ? 'Printing...' : 'Print Bill'}
              </button>
              <button className="btn btn-secondary" onClick={() => setViewingOrder(null)}>Close</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default History;
