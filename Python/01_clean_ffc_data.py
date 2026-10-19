from pathlib import Path
import csv

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "Data" / "Raw"
CLEAN = ROOT / "Data" / "Cleaned"
CLEAN.mkdir(parents=True, exist_ok=True)

def load(filename, required):
    with (RAW / filename).open(newline='', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        if not set(required).issubset(reader.fieldnames or []):
            raise ValueError(f'Missing columns in {filename}: {set(required) - set(reader.fieldnames or [])}')
        rows = list(reader)
    if not rows:
        raise ValueError(f'Empty dataset: {filename}')
    return rows

def export(filename, rows):
    with (CLEAN / filename).open('w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    print(f'Created {filename}: {len(rows)} records')

annual = load('ffc_annual_financials_2022_2025.csv', ['fiscal_year','sales_pkr_thousands','profit_after_tax_pkr_thousands','basis'])
for row in annual:
    sales = float(row['sales_pkr_thousands'])
    profit = float(row['profit_after_tax_pkr_thousands'])
    if sales <= 0: raise ValueError('Annual sales must be positive')
    row['sales_pkr_billions'] = round(sales / 1_000_000, 4)
    row['profit_pkr_billions'] = round(profit / 1_000_000, 4)
    row['calculated_net_margin_pct'] = round(profit / sales * 100, 2)
annual.sort(key=lambda r: int(r['fiscal_year']))
if len({r['fiscal_year'] for r in annual}) != len(annual): raise ValueError('Duplicate annual year')
export('ffc_annual_clean.csv', annual)

quarterly = load('ffc_reported_quarterly_2025_2026.csv', ['period','sales_pkr_thousands','profit_after_tax_pkr_thousands'])
for row in quarterly:
    row['sales_pkr_billions'] = round(float(row['sales_pkr_thousands']) / 1_000_000, 4)
    row['profit_pkr_billions'] = round(float(row['profit_after_tax_pkr_thousands']) / 1_000_000, 4)
if len({r['period'] for r in quarterly}) != len(quarterly): raise ValueError('Duplicate quarterly period')
export('ffc_quarterly_clean.csv', quarterly)

operations = load('ffc_operations_market_2024_2025.csv', ['year','product','entity','metric','value','unit'])
for row in operations:
    row['value'] = float(row['value'])
    if row['value'] < 0: raise ValueError('Negative operational value')
    if row['unit'] != 'KT': raise ValueError('Unexpected operational unit')
    row['tonnes'] = round(row['value'] * 1000)
keys = [(r['year'],r['product'],r['entity'],r['metric']) for r in operations]
if len(set(keys)) != len(keys): raise ValueError('Duplicate operational metric')
export('ffc_operations_clean.csv', operations)
print('Validation complete. All original source URLs retained.')
