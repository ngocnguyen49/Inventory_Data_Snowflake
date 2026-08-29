import pandas as pd
import boto3
import io
import sys


def validate_s3_csv(bucket, key, aws_access_key=None, aws_secret_key=None):
    print("=" * 50)
    print("PRE-LOAD VALIDATION — Sales Pipeline (S3 Source)")
    print("=" * 50)
    print(f"\n📦 Source: s3://{bucket}/{key}")

    # ── Connect to S3 and read CSV ────────────────────────────
    try:
        session = boto3.Session(
            aws_access_key_id     = aws_access_key,
            aws_secret_access_key = aws_secret_key
        )
        s3  = session.client('s3')
        obj = s3.get_object(Bucket=bucket, Key=key)
        df  = pd.read_csv(io.BytesIO(obj['Body'].read()))
        print(f"✅ Successfully connected to S3 and read file")
    except Exception as e:
        print(f"❌ Failed to read from S3: {e}")
        print("   Check your bucket name, key path, and AWS credentials")
        return False

    checks = {}

    # ── Check 1: File is not empty ────────────────────────────
    checks['file_not_empty'] = len(df) > 0
    print(f"\n{'✅' if checks['file_not_empty'] else '❌'} "
          f"Row count: {len(df):,} rows")

    # ── Check 2: File has columns ─────────────────────────────
    # No hardcoded column names — INFER_SCHEMA handles schema detection
    # We just confirm the file has columns and print them for visibility
    checks['has_columns'] = len(df.columns) > 0
    print(f"{'✅' if checks['has_columns'] else '❌'} "
          f"Columns detected: {len(df.columns)}")
    print(f"   Column list: {list(df.columns)}")

    # ── Check 3: No fully duplicate rows ─────────────────────
    full_dupes = df.duplicated().sum()
    checks['no_full_duplicates'] = full_dupes == 0
    print(f"\n{'✅' if checks['no_full_duplicates'] else '❌'} "
          f"Fully duplicate rows: {full_dupes}")

    # ── Check 4: No completely empty rows ────────────────────
    empty_rows = df.isnull().all(axis=1).sum()
    checks['no_empty_rows'] = empty_rows == 0
    print(f"{'✅' if checks['no_empty_rows'] else '❌'} "
          f"Completely empty rows: {empty_rows}")

    # ── Check 5: Null rate per column ─────────────────────────
    # Generic — works for any number of columns
    print(f"\n📊 Null rate per column:")
    null_summary = df.isnull().sum()
    high_null_cols = []
    for col, null_count in null_summary.items():
        null_pct = round(null_count / len(df) * 100, 2)
        status   = "✅" if null_pct == 0 else ("⚠️ " if null_pct < 20 else "❌")
        print(f"   {status} {col}: {null_count} nulls ({null_pct}%)")
        if null_pct >= 20:
            high_null_cols.append(col)
    checks['no_high_null_columns'] = len(high_null_cols) == 0
    if high_null_cols:
        print(f"   ❌ High null columns (>20%): {high_null_cols}")

    # ── Check 6: Numeric columns have no negative values ─────
    # Generic — detects numeric columns automatically
    print(f"\n📊 Numeric column checks:")
    numeric_cols     = df.select_dtypes(include='number').columns.tolist()
    negative_issues  = []
    if numeric_cols:
        for col in numeric_cols:
            neg_count = (df[col] < 0).sum()
            status    = "✅" if neg_count == 0 else "⚠️ "
            print(f"   {status} {col}: {neg_count} negative values "
                  f"| min={df[col].min()} | max={df[col].max()} "
                  f"| mean={round(df[col].mean(), 2)}")
            if neg_count > 0:
                negative_issues.append(col)
        checks['no_unexpected_negatives'] = len(negative_issues) == 0
    else:
        # INFER_SCHEMA may load all as string — flag for awareness
        print(f"   ⚠️  No numeric columns detected — "
              f"all columns loaded as string")
        print(f"      This is expected if CSV has mixed formats — "
              f"Snowflake INFER_SCHEMA will handle type casting")
        checks['no_unexpected_negatives'] = True

    # ── Check 7: Date-like columns have parseable values ──────
    # Generic — detects columns with 'date' in name automatically
    print(f"\n📊 Date column checks:")
    date_cols = [c for c in df.columns if 'date' in c.lower()]
    if date_cols:
        for col in date_cols:
            parsed    = pd.to_datetime(df[col], errors='coerce')
            bad_dates = parsed.isnull().sum()
            status    = "✅" if bad_dates == 0 else "❌"
            print(f"   {status} {col}: {bad_dates} unparseable dates "
                  f"| range: {parsed.min()} → {parsed.max()}")
        checks['valid_dates'] = all(
            pd.to_datetime(df[col], errors='coerce').isnull().sum() == 0
            for col in date_cols
        )
    else:
        print(f"   ⚠️  No date columns detected by name")
        checks['valid_dates'] = True

    # ── Check 8: File size warning ────────────────────────────
    checks['reasonable_size'] = len(df) > 0
    if len(df) > 1_000_000:
        print(f"\n⚠️  Large file warning: {len(df):,} rows — "
              f"consider partitioning before S3 upload")
    else:
        print(f"\n✅ File size is within normal range: {len(df):,} rows")

    # ── Final scorecard ───────────────────────────────────────
    print("\n" + "=" * 50)
    print("SCORECARD")
    print("=" * 50)
    all_passed = all(checks.values())
    for check, passed in checks.items():
        print(f"  {'PASS ✅' if passed else 'FAIL ❌'}  {check}")

    print("\n" + (
        "✅ All checks passed — safe to load into Snowflake Bronze layer via COPY INTO."
        if all_passed else
        "❌ Validation failed — fix issues in S3 file before running Snowflake Bronze load."
    ))
    return all_passed


if __name__ == "__main__":
    # ── Usage ─────────────────────────────────────────────────
    # python 00_pre_load_validation.py <bucket> <key> <aws_key_id> <aws_secret>
    # Example:
    # python 00_pre_load_validation.py my-bucket data/sample_data.csv AKIAXXXX secretXXXX

    if len(sys.argv) >= 3:
        bucket         = sys.argv[1]
        key            = sys.argv[2]
        aws_access_key = sys.argv[3] if len(sys.argv) > 3 else None
        aws_secret_key = sys.argv[4] if len(sys.argv) > 4 else None
    else:
        bucket         = "your-bucket-name"
        key            = "path/to/sample_data.csv"
        aws_access_key = None
        aws_secret_key = None

    validate_s3_csv(bucket, key, aws_access_key, aws_secret_key)
