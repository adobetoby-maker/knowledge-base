# PDF Generation

## Options Overview

| Approach | Library | Use case |
|----------|---------|---------|
| React → PDF | `@react-pdf/renderer` | Complex layouts, invoices |
| HTML → PDF (headless Chrome) | `puppeteer` | Pixel-perfect from HTML/CSS |
| Template PDF fill | `pdf-lib` | Fill form fields in existing PDF |
| Simple tables | `jspdf` | Basic text/tables, lightweight |

For invoices in jrs-auto-repair: `@react-pdf/renderer` is the right choice — it uses React JSX for layout and generates PDFs without a browser dependency.

## @react-pdf/renderer

```bash
npm install @react-pdf/renderer
```

```typescript
// lib/invoice-pdf.tsx
import {
  Document, Page, Text, View, StyleSheet, Font, pdf,
} from '@react-pdf/renderer'

const styles = StyleSheet.create({
  page: {
    fontFamily: 'Helvetica',
    fontSize: 10,
    padding: 40,
    backgroundColor: '#ffffff',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 30,
  },
  businessName: { fontSize: 20, fontWeight: 'bold', color: '#111' },
  invoiceNumber: { fontSize: 16, color: '#666' },
  section: { marginBottom: 20 },
  label: { fontSize: 8, color: '#888', marginBottom: 2, textTransform: 'uppercase' },
  value: { fontSize: 11, color: '#111' },
  table: { width: '100%' },
  tableHeader: {
    flexDirection: 'row',
    borderBottomWidth: 1,
    borderBottomColor: '#ddd',
    paddingBottom: 6,
    marginBottom: 6,
  },
  tableRow: {
    flexDirection: 'row',
    paddingVertical: 4,
    borderBottomWidth: 0.5,
    borderBottomColor: '#f0f0f0',
  },
  col1: { flex: 3 },
  col2: { flex: 1, textAlign: 'right' },
  col3: { flex: 1, textAlign: 'right' },
  col4: { flex: 1, textAlign: 'right' },
  total: { flexDirection: 'row', justifyContent: 'flex-end', marginTop: 16 },
  totalLabel: { fontSize: 12, fontWeight: 'bold', marginRight: 20 },
  totalValue: { fontSize: 14, fontWeight: 'bold', color: '#111' },
})

interface InvoicePDFProps {
  invoice: Invoice
  lineItems: LineItem[]
  customer: Customer
}

export function InvoicePDF({ invoice, lineItems, customer }: InvoicePDFProps) {
  return (
    <Document>
      <Page size="A4" style={styles.page}>
        {/* Header */}
        <View style={styles.header}>
          <View>
            <Text style={styles.businessName}>Jr.'s Auto Repair</Text>
            <Text style={{ color: '#666', fontSize: 9 }}>417 Main Ave E, Twin Falls, ID 83301</Text>
            <Text style={{ color: '#666', fontSize: 9 }}>(208) 595-2101</Text>
          </View>
          <View style={{ alignItems: 'flex-end' }}>
            <Text style={styles.invoiceNumber}>Invoice #{invoice.number}</Text>
            <Text style={{ color: '#666', fontSize: 9 }}>
              Date: {new Date(invoice.created_at).toLocaleDateString('en-US')}
            </Text>
          </View>
        </View>

        {/* Customer Info */}
        <View style={styles.section}>
          <Text style={styles.label}>Bill To</Text>
          <Text style={styles.value}>{customer.name}</Text>
          {customer.email && <Text style={{ ...styles.value, color: '#666' }}>{customer.email}</Text>}
        </View>

        {/* Line Items */}
        <View style={styles.table}>
          <View style={styles.tableHeader}>
            <Text style={{ ...styles.col1, color: '#888', fontSize: 8 }}>DESCRIPTION</Text>
            <Text style={{ ...styles.col2, color: '#888', fontSize: 8 }}>QTY</Text>
            <Text style={{ ...styles.col3, color: '#888', fontSize: 8 }}>PRICE</Text>
            <Text style={{ ...styles.col4, color: '#888', fontSize: 8 }}>TOTAL</Text>
          </View>
          {lineItems.map((item, i) => (
            <View key={i} style={styles.tableRow}>
              <Text style={styles.col1}>{item.description}</Text>
              <Text style={styles.col2}>{item.quantity}</Text>
              <Text style={styles.col3}>${item.unit_price.toFixed(2)}</Text>
              <Text style={styles.col4}>${(item.quantity * item.unit_price).toFixed(2)}</Text>
            </View>
          ))}
        </View>

        {/* Total */}
        <View style={styles.total}>
          <Text style={styles.totalLabel}>Total Due</Text>
          <Text style={styles.totalValue}>${invoice.total.toFixed(2)}</Text>
        </View>
      </Page>
    </Document>
  )
}

// Generate PDF buffer for API route
export async function generateInvoicePDF(props: InvoicePDFProps): Promise<Buffer> {
  const doc = <InvoicePDF {...props} />
  const stream = await pdf(doc).toBuffer()
  return stream
}
```

## API Route for PDF Download

```typescript
// app/api/invoices/[id]/pdf/route.ts
import { generateInvoicePDF } from '@/lib/invoice-pdf'

export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params
  const supabase = await createClient()
  
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const { data: invoice } = await supabase
    .from('invoices')
    .select('*, line_items(*), customers(*)')
    .eq('id', id)
    .eq('user_id', user.id)
    .single()

  if (!invoice) return NextResponse.json({ error: 'Not found' }, { status: 404 })

  const pdfBuffer = await generateInvoicePDF({
    invoice,
    lineItems: invoice.line_items,
    customer: invoice.customers,
  })

  return new Response(pdfBuffer, {
    headers: {
      'Content-Type': 'application/pdf',
      'Content-Disposition': `attachment; filename="invoice-${invoice.number}.pdf"`,
      'Content-Length': pdfBuffer.length.toString(),
    },
  })
}
```

## Triggering Download in Browser

```typescript
async function downloadPDF(invoiceId: string) {
  const response = await fetch(`/api/invoices/${invoiceId}/pdf`)
  const blob = await response.blob()
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `invoice-${invoiceId}.pdf`
  a.click()
  URL.revokeObjectURL(url)
}
```

## Note on Cloudflare Workers

`@react-pdf/renderer` uses Node.js APIs (stream, Buffer) and may not work on Cloudflare Workers Edge Runtime. For Cloudflare deployments, use the Node.js runtime:

```typescript
// app/api/invoices/[id]/pdf/route.ts
export const runtime = 'nodejs'  // force Node.js runtime
```
