import pandas as pd
import sys

def validate_csv(filepath):
    print("=" * 50)
    print("PRE-LOAD VALIDATION — Sales Pipeline")
    print("=" * 50)

    df = pd.read_csv(filepath)

    checks = {}

    # Check 1: Row count
    print(f"\n✅ Total rows loaded: {len(df)}")

    # Check 2: Required columns exist
    required = ['Row ID', 'Order ID', 'Order Date', 'Ship Date',
                'Sales', 'Profit', 'Quantity', 'Discount']
    missing_cols = [c for c in required if c not in df.columns]
    checks['required_columns'] = len(missing_cols) == 0
    print(f"{'✅' if checks['required_columns'] else '❌'} Required columns: "
          f"{'All present' if checks['required_columns'] else f'Missing: {missing_cols}'}")
    # Check 3: Duplicate Row IDs
    dupes = df['Row ID'].duplicated().sum()
    checks['no_duplicates'] = dupes == 0
    print(f"{'✅' if checks['no_duplicates'] else '❌'} Duplicate Row IDs: {dupes}")

    # Check 4: Null Sales
    null_sales = df['Sales'].isnull().sum()
    checks['no_null_sales'] = null_sales == 0
    print(f"{'✅' if checks['no_null_sales'] else '❌'} Null Sales rows: {null_sales}")

    # Check 5: Negative Sales
    neg_sales = (pd.to_numeric(df['Sales'], errors='coerce') < 0).sum()
    checks['no_negative_sales'] = neg_sales == 0
    print(f"{'✅' if checks['no_negative_sales'] else '❌'} Negative Sales rows: {neg_sales}")

    # Check 6: Date range
    df['Order Date Parsed'] = pd.to_datetime(df['Order Date'], errors='coerce')
    bad_dates = df['Order Date Parsed'].isnull().sum()
    checks['valid_dates'] = bad_dates == 0
    print(f"{'✅' if checks['valid_dates'] else '❌'} Unparseable dates: {bad_dates}")
    print(f"   Date range: {df['Order Date Parsed'].min()} → {df['Order Date Parsed'].max()}")

    # Final scorecard
    print("\n" + "=" * 50)
    print("SCORECARD")
    print("=" * 50)
    all_passed = all(checks.values())
    for check, passed in checks.items():
        print(f"  {'PASS ✅' if passed else 'FAIL ❌'}  {check}")

    print("\n" + ("✅ All checks passed — safe to load into Snowflake Bronze layer."
                  if all_passed else
                  "❌ Validation failed — fix issues before loading into Snowflake."))
    return all_passed

if __name__ == "__main__":
    filepath = sys.argv[1] if len(sys.argv) > 1 else "data/sample_data.csv"
    validate_csv(filepath)
