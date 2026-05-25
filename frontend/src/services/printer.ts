const PRINTER_SERVICE_URL = 'http://localhost:8085';

class PrinterService {
  private async fetch(endpoint: string, options?: RequestInit) {
    const response = await fetch(`${PRINTER_SERVICE_URL}${endpoint}`, {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        ...options?.headers,
      },
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(error || 'Printer request failed');
    }

    return response.json();
  }

  // Get printer service status
  async getStatus() {
    return this.fetch('/status');
  }

  // Get available printers
  async getPrinters() {
    return this.fetch('/printers');
  }

  // Print raw data
  async printRaw(data: { printer: any; data: string }) {
    return this.fetch('/print/raw', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  // Print invoice
  async printInvoice(data: {
    type: 'invoice';
    printer: {
      type: string;
      name: string;
      vendor_id?: string;
      product_id?: string;
      address?: string;
      paper_width: '2inch' | '3inch';
    };
    invoice: {
      store: {
        name: string;
        branch?: string;
        location?: string;
        gst_number?: string;
        fssai_lic_no?: string;
        phone?: string;
        address?: string;
      };
      customer: {
        name: string;
        mobile?: string;
      };
      invoice_no: string;
      bill_no: string;
      date: string;
      items: Array<{
        name: string;
        hsn?: string;
        qty: number;
        unit: string;
        rate: number;
        tax_percent: number;
        amount: number;
      }>;
      summary: {
        sub_total: number;
        discount: number;
        taxable: number;
        cgst: number;
        sgst: number;
        grand_total: number;
      };
      payment: {
        cash: number;
        card: number;
        upi: number;
        balance: number;
      };
      payment_mode: string;
      dr_ref?: string;
      footer?: string[];
    };
  }) {
    return this.fetch('/print', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  // Print KOT (Kitchen Order Ticket)
  async printKOT(data: {
    type: 'kot';
    printer: {
      type: string;
      name: string;
      vendor_id?: string;
      product_id?: string;
      address?: string;
      paper_width: '2inch' | '3inch';
    };
    kot: {
      order_id: number;
      table_number: string;
      waiter_name: string;
      date: string;
      items: Array<{
        name: string;
        qty: number;
        unit: string;
        rate: number;
        tax_percent: number;
        amount: number;
      }>;
      notes: string;
      order_type: string;
      customer_name: string;
      customer_mobile: string;
    };
  }) {
    return this.fetch('/print', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }
}

export const printerService = new PrinterService();
