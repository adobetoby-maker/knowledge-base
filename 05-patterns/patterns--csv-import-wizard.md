# Pattern: CSV Import Wizard

## Overview
Importing data is high-stakes: a bad import corrupts production records, and users won't trust the system again. Showing all validation errors before committing lets users fix their source data without needing to re-upload. The template download prevents format confusion at the source.

## Implementation

### Multi-Step Flow
```tsx
type ImportStep = 'upload' | 'map' | 'validate' | 'import';

function CsvImportWizard({ onComplete }) {
  const [step, setStep] = useState<ImportStep>('upload');
  const [file, setFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<string[][]>([]); // first 5 rows
  const [headers, setHeaders] = useState<string[]>([]);
  const [mapping, setMapping] = useState<Record<string, string>>({});
  const [validationResult, setValidationResult] = useState<ValidationResult | null>(null);

  return (
    <div>
      <StepIndicator steps={['Upload', 'Map Fields', 'Validate', 'Import']} current={step} />
      {step === 'upload' && <UploadStep onNext={(f, p, h) => { setFile(f); setPreview(p); setHeaders(h); setStep('map'); }} />}
      {step === 'map' && <MapStep headers={headers} preview={preview} mapping={mapping} onBack={() => setStep('upload')} onNext={m => { setMapping(m); setStep('validate'); }} />}
      {step === 'validate' && <ValidateStep file={file} mapping={mapping} onBack={() => setStep('map')} onNext={r => { setValidationResult(r); setStep('import'); }} />}
      {step === 'import' && <ImportStep file={file} mapping={mapping} validationResult={validationResult} onComplete={onComplete} />}
    </div>
  );
}
```

### Step 1: Upload + Preview
```tsx
function UploadStep({ onNext }) {
  const handleFile = async (file: File) => {
    const text = await file.text();
    const rows = parseCSV(text); // returns string[][]
    if (rows.length < 2) throw new UserError('CSV must have at least a header row and one data row');
    const headers = rows[0];
    const preview = rows.slice(1, 6); // first 5 data rows
    onNext(file, preview, headers);
  };

  return (
    <div>
      <a href="/templates/import-contacts.csv" download>Download CSV template</a>
      <FileDropZone accept=".csv" onFile={handleFile} />
    </div>
  );
}
```

### Step 2: Column Mapping
```tsx
const REQUIRED_FIELDS = ['email'];
const OPTIONAL_FIELDS = ['firstName', 'lastName', 'phone', 'company'];

function MapStep({ headers, preview, mapping, onBack, onNext }) {
  const [localMapping, setLocalMapping] = useState<Record<string, string>>(
    autoDetectMapping(headers) // tries to match by name similarity
  );

  const allRequiredMapped = REQUIRED_FIELDS.every(f =>
    Object.values(localMapping).includes(f)
  );

  return (
    <div>
      <table>
        <thead>
          <tr>
            <th>CSV Column</th>
            <th>Sample Data</th>
            <th>Map to Field</th>
          </tr>
        </thead>
        <tbody>
          {headers.map((header, i) => (
            <tr key={header}>
              <td>{header}</td>
              <td className="text-muted text-sm">{preview.map(r => r[i]).filter(Boolean)[0]}</td>
              <td>
                <select
                  value={localMapping[header] ?? ''}
                  onChange={e => setLocalMapping(m => ({ ...m, [header]: e.target.value }))}
                >
                  <option value="">Skip this column</option>
                  {[...REQUIRED_FIELDS, ...OPTIONAL_FIELDS].map(f => (
                    <option key={f} value={f}>{f}</option>
                  ))}
                </select>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      <button disabled={!allRequiredMapped} onClick={() => onNext(localMapping)}>
        Validate →
      </button>
    </div>
  );
}
```

### Step 3: Validate (server-side, dry run)
```typescript
// Server: validate without writing
async function validateImport(fileContent: string, mapping: Record<string, string>) {
  const rows = parseCSV(fileContent).slice(1); // skip header
  const errors: { row: number; field: string; message: string }[] = [];
  const valid: Record<string, string>[] = [];

  for (let i = 0; i < rows.length; i++) {
    const record = applyMapping(rows[i], mapping);
    const rowErrors = validateRecord(record); // email format, required fields, etc.
    if (rowErrors.length > 0) {
      errors.push(...rowErrors.map(e => ({ row: i + 2, ...e }))); // +2: 1-indexed + header
    } else {
      valid.push(record);
    }
  }

  return {
    totalRows: rows.length,
    validCount: valid.length,
    errorCount: errors.length,
    errors, // show all before asking to proceed
  };
}
```

### Step 4: Import with Skip Option
```tsx
function ImportStep({ file, mapping, validationResult, onComplete }) {
  const [skipInvalid, setSkipInvalid] = useState(false);

  const canImport = validationResult.errorCount === 0 || skipInvalid;

  return (
    <div>
      <p>{validationResult.validCount} valid rows ready to import.</p>
      {validationResult.errorCount > 0 && (
        <div className="error-summary">
          <p>{validationResult.errorCount} rows have errors:</p>
          <ValidationErrorTable errors={validationResult.errors} />
          <label>
            <input type="checkbox" checked={skipInvalid} onChange={e => setSkipInvalid(e.target.checked)} />
            Skip invalid rows and import {validationResult.validCount} valid rows
          </label>
        </div>
      )}
      <button disabled={!canImport} onClick={() => executeImport(file, mapping, skipInvalid).then(onComplete)}>
        Import {skipInvalid ? validationResult.validCount : validationResult.totalRows} rows
      </button>
    </div>
  );
}
```

## Key Rules
- Validate all rows before committing any — don't import row 1 then fail on row 50
- Show row numbers in validation errors (1-indexed, header is row 1)
- Offer "skip invalid rows" as opt-in, not default — most users want to fix errors first
- Preview shows first 5 rows so users confirm they uploaded the right file
- Download template link is on the upload step, not after failure
- Auto-detect column mapping by header name similarity — saves most users from mapping entirely
- Show sample data next to column names in the mapping step — context prevents wrong mappings
- Run the heavy validation server-side, not in the browser — large files need streaming
- Progress indicator for large files (>500 rows) — don't let users think it froze
- Dry-run validation is separate from actual import — two distinct API endpoints
