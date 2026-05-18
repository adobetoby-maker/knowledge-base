# Batch: Automated Security Scan

## Overview
Security vulnerabilities in production are much more costly than catching them in CI. An automated
security scan pipeline that runs on every merge (and nightly on the main branch) creates a consistent
baseline and catches regressions before they reach users. The output should be machine-readable JSON
for CI gating and human-readable reports for the security team.

## Implementation

### npm audit for Dependency Vulnerabilities
```bash
# In CI — fail on high severity or above
npm audit --audit-level=high --json > audit-report.json

# Parse and gate
node -e "
const report = require('./audit-report.json');
const critical = report.metadata.vulnerabilities.critical;
const high = report.metadata.vulnerabilities.high;
if (critical > 0 || high > 0) {
  console.error('Security gate failed: ' + critical + ' critical, ' + high + ' high vulnerabilities');
  process.exit(1);
}
console.log('Security gate passed');
"

# Auto-fix where possible
npm audit fix

# For transitive deps you can't upgrade, override in package.json:
# "overrides": { "problematic-dep": ">=secure-version" }
```

### Container Scanning with Trivy
```bash
# Scan Docker image for OS and library CVEs
trivy image --format json --output trivy-report.json my-app:latest

# Gate on critical severity
trivy image --exit-code 1 --severity CRITICAL my-app:latest

# Scan the source filesystem (not container) for dependency CVEs
trivy fs --security-checks vuln --format json --output trivy-fs-report.json .
```
```yaml
# GitHub Actions integration
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: 'my-app:${{ github.sha }}'
    format: 'sarif'
    output: 'trivy-results.sarif'

- name: Upload Trivy scan results to GitHub Security tab
  uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: 'trivy-results.sarif'
```

### Secrets Detection with gitleaks
```bash
# Scan current commit (in pre-commit hook)
gitleaks detect --source . --staged --verbose

# Scan all commits (scheduled scan of entire history)
gitleaks detect --source . --log-opts="--all"

# .gitleaks.toml — custom rules
[[rules]]
  id = "custom-api-key"
  description = "Custom API key pattern"
  regex = '''MYAPP_[A-Z0-9]{32}'''
  tags = ["api", "key"]

# Allowlist false positives
[[allowlist]]
  paths = ["tests/fixtures/sample-keys.txt"]
  commits = ["known-false-positive-commit-sha"]
```

### OWASP ZAP Passive Scan Against Staging
```bash
# Run ZAP in daemon mode, passive scan only (no active attacks)
docker run -d -p 8080:8080 owasp/zap2docker-stable zap.sh -daemon \
    -host 0.0.0.0 -port 8080 \
    -config api.key=${ZAP_API_KEY} \
    -config api.addrs.addr.name=.* \
    -config api.addrs.addr.regex=true

# Spider the staging site
curl "http://localhost:8080/JSON/spider/action/scan/?apikey=${ZAP_API_KEY}&url=https://staging.myapp.com"

# Wait for scan to complete, then get alerts
curl "http://localhost:8080/JSON/alert/view/alerts/?apikey=${ZAP_API_KEY}&riskId=3" \
    | jq '.alerts[] | {risk, alert, url, description}' > zap-report.json

# Gate on high-risk alerts
HIGH_RISK=$(jq '[.alerts[] | select(.riskcode == "3")] | length' zap-report.json)
if [ "$HIGH_RISK" -gt 0 ]; then
    echo "ZAP found $HIGH_RISK high-risk issues"
    exit 1
fi
```

### Structured JSON Output for CI Gating
```ts
// Aggregate all scan results into a unified report
interface SecurityReport {
  timestamp: string;
  commit: string;
  passed: boolean;
  findings: {
    tool: string;
    severity: 'critical' | 'high' | 'medium' | 'low';
    count: number;
    details: Finding[];
  }[];
}

async function generateSecurityReport(): Promise<SecurityReport> {
  const [npmAudit, trivy, gitleaks, zap] = await Promise.all([
    parseNpmAudit('./audit-report.json'),
    parseTrivyReport('./trivy-report.json'),
    parseGitleaksReport('./gitleaks-report.json'),
    parseZapReport('./zap-report.json'),
  ]);

  const allFindings = [npmAudit, trivy, gitleaks, zap];
  const passed = allFindings.every(f => f.findings.filter(x => x.severity === 'critical').length === 0);

  return {
    timestamp: new Date().toISOString(),
    commit: process.env.GITHUB_SHA ?? 'unknown',
    passed,
    findings: allFindings,
  };
}
```

## Key Rules
- Security scans must run on every merge to main, not just nightly — nightlies catch regressions that merge checks missed
- Gate CI on `critical` and `high` severity — `medium` and below goes to the backlog for scheduled remediation
- Scan container images in addition to source deps — OS-level CVEs in base images are invisible to npm audit
- gitleaks in the pre-commit hook catches secrets before they reach the repository; the nightly scan is the backstop
- ZAP passive scan only in CI — active scanning generates real traffic that can corrupt staging data
- Store scan results as JSON artifacts in CI — enables trend analysis and compliance reporting
- Never suppress a security finding without a documented rationale and owner — suppression without tracking is technical debt
