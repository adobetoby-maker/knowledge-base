# Skill: Server-Side Spreadsheet Generation (XLSX)

## Overview
Server-generated spreadsheets are more useful than CSV exports when the data has multiple sheets, requires formatting (currency, dates, colors), or needs frozen headers and column widths for readability. The file is generated in memory, streamed to the client as a download, and never touches the filesystem. ExcelJS is the preferred library: it handles streams natively, supports full formatting, and is actively maintained.

## Implementation

### Basic ExcelJS Report
```ts
import ExcelJS from 'exceljs';

export async function generateInvoiceReport(invoices: Invoice[]): Promise<Buffer> {
  const workbook = new ExcelJS.Workbook();
  workbook.creator = 'YourApp';
  workbook.created = new Date();

  const sheet = workbook.addWorksheet('Invoices', {
    views: [{ state: 'frozen', ySplit: 1 }], // freeze header row
  });

  // Define columns (sets header text, key, and width)
  sheet.columns = [
    { header: 'Invoice #',    key: 'number',    width: 14 },
    { header: 'Customer',     key: 'customer',  width: 28 },
    { header: 'Issue Date',   key: 'issued',    width: 14 },
    { header: 'Due Date',     key: 'due',       width: 14 },
    { header: 'Amount',       key: 'amount',    width: 14 },
    { header: 'Status',       key: 'status',    width: 12 },
  ];

  // Style header row
  const headerRow = sheet.getRow(1);
  headerRow.font = { bold: true, size: 11 };
  headerRow.fill = {
    type: 'pattern',
    pattern: 'solid',
    fgColor: { argb: 'FF1F4E79' },
  };
  headerRow.font = { bold: true, color: { argb: 'FFFFFFFF' } };
  headerRow.alignment = { vertical: 'middle', horizontal: 'center' };
  headerRow.height = 20;

  // Add data rows
  invoices.forEach(inv => {
    const row = sheet.addRow({
      number:   inv.number,
      customer: inv.customerName,
      issued:   new Date(inv.issuedAt),
      due:      new Date(inv.dueAt),
      amount:   inv.amountCents / 100,
      status:   inv.status,
    });

    // Number formatting
    row.getCell('issued').numFmt = 'MM/DD/YYYY';
    row.getCell('due').numFmt = 'MM/DD/YYYY';
    row.getCell('amount').numFmt = '$#,##0.00';

    // Conditional formatting: overdue = red background
    if (inv.status === 'overdue') {
      row.getCell('status').fill = {
        type: 'pattern',
        pattern: 'solid',
        fgColor: { argb: 'FFFEE2E2' },
      };
      row.getCell('status').font = { color: { argb: 'FF991B1B' } };
    }
  });

  // Summary row
  const summaryRow = sheet.addRow({
    customer: 'TOTAL',
    amount: invoices.reduce((sum, inv) => sum + inv.amountCents / 100, 0),
  });
  summaryRow.getCell('amount').numFmt = '$#,##0.00';
  summaryRow.font = { bold: true };
  sheet.getCell(`E${sheet.rowCount}`).border = {
    top: { style: 'thin' },
  };

  // Auto-filter on header
  sheet.autoFilter = 'A1:F1';

  // Write to buffer
  const buffer = await workbook.xlsx.writeBuffer();
  return buffer as Buffer;
}
```

### Multi-Sheet Workbook
```ts
const summarySheet = workbook.addWorksheet('Summary');
const detailSheet = workbook.addWorksheet('Line Items');
const rawSheet = workbook.addWorksheet('Raw Data');

// Hide raw data sheet from casual view
rawSheet.state = 'hidden';
```

### Next.js Route Handler
```ts
// GET /api/reports/invoices
export async function GET(req: Request) {
  const { searchParams } = new URL(req.url);
  const month = searchParams.get('month') ?? format(new Date(), 'yyyy-MM');

  const invoices = await fetchInvoicesForMonth(month);
  const buffer = await generateInvoiceReport(invoices);
  const filename = `invoices-${month}.xlsx`;

  return new Response(buffer, {
    headers: {
      'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'Content-Disposition': `attachment; filename="${filename}"`,
      'Cache-Control': 'no-store',
    },
  });
}
```

### Column Width Auto-Sizing
ExcelJS doesn't auto-size columns natively. Calculate widths from content:

```ts
function autoSizeColumns(sheet: ExcelJS.Worksheet) {
  sheet.columns.forEach(col => {
    if (!col.values) return;
    let maxLength = 10; // minimum width
    col.values.forEach(value => {
      if (value) {
        const len = String(value).length;
        if (len > maxLength) maxLength = len;
      }
    });
    col.width = Math.min(maxLength + 2, 50); // cap at 50 chars
  });
}
```

### CSV Fallback (Lighter Alternative)
When full formatting isn't needed:
```ts
import { stringify } from 'csv-stringify/sync';

export function generateCSV(data: object[]): string {
  if (data.length === 0) return '';
  const headers = Object.keys(data[0]);
  return stringify(data, { header: true, columns: headers });
}

// Route handler:
return new Response(csv, {
  headers: {
    'Content-Type': 'text/csv; charset=utf-8',
    'Content-Disposition': 'attachment; filename="export.csv"',
  },
});
```

## Key Rules
- Use `writeBuffer()` not `writeFile()` — never write to the server filesystem in a serverless environment.
- Set `Content-Disposition: attachment` — without it, the browser may render the binary file inline.
- Freeze the header row via `views: [{ state: 'frozen', ySplit: 1 }]` — essential for any table longer than a screen.
- Divide cent-denominated amounts by 100 before writing — format as `$#,##0.00`, not as integers.
- Date cells should use actual `Date` objects, not strings — ExcelJS formats them correctly; strings require manual numFmt.
- Include row count and generated timestamp in a separate summary sheet for audit purposes.
- `Cache-Control: no-store` on the export endpoint — report data changes; clients must not cache stale exports.
