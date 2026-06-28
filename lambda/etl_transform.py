"""
ETL Lambda: reads NYC Yellow Taxi Parquet from raw S3,
applies cleaning transformations, writes partitioned Parquet to processed S3.
Uses only the standard library + boto3 (pre-installed in Lambda runtime).
Heavy Parquet work is done with pyarrow via a Lambda layer approach:
for the zip-deploy version we use pandas + pyarrow bundled at deploy time.
"""

import os
import io
import json
import logging
import boto3
import urllib.request
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3")

RAW_BUCKET       = os.environ["RAW_BUCKET"]
PROCESSED_BUCKET = os.environ["PROCESSED_BUCKET"]
RAW_PREFIX       = os.environ.get("RAW_PREFIX", "nyc-taxi/")
PROCESSED_PREFIX = os.environ.get("PROCESSED_PREFIX", "nyc-taxi-clean/")


def list_raw_files():
    """Return list of S3 keys under RAW_PREFIX ending in .parquet"""
    paginator = s3.get_paginator("list_objects_v2")
    keys = []
    for page in paginator.paginate(Bucket=RAW_BUCKET, Prefix=RAW_PREFIX):
        for obj in page.get("Contents", []):
            if obj["Key"].endswith(".parquet"):
                keys.append(obj["Key"])
    return keys


def read_parquet_from_s3(bucket, key):
    try:
        import pyarrow.parquet as pq
        import pyarrow as pa
    except ImportError:
        raise RuntimeError(
            "pyarrow not available — bundle it with the Lambda zip or use a layer"
        )

    response = s3.get_object(Bucket=bucket, Key=key)
    buf = io.BytesIO(response["Body"].read())
    table = pq.read_table(buf)
    return table


def transform(table):
    import pyarrow as pa
    import pyarrow.compute as pc

    # Keep only columns we care about
    desired_cols = [
        "tpep_pickup_datetime",
        "tpep_dropoff_datetime",
        "passenger_count",
        "trip_distance",
        "fare_amount",
        "tip_amount",
        "total_amount",
        "payment_type",
    ]
    available = [c for c in desired_cols if c in table.schema.names]
    table = table.select(available)

    # Drop rows where trip_distance or total_amount <= 0
    if "trip_distance" in table.schema.names:
        mask = pc.greater(table["trip_distance"], 0)
        table = table.filter(mask)
    if "total_amount" in table.schema.names:
        mask = pc.greater(table["total_amount"], 0)
        table = table.filter(mask)

    # Add a processing timestamp column
    now_str = datetime.utcnow().isoformat()
    processed_at = pa.array([now_str] * len(table), type=pa.string())
    table = table.append_column("processed_at", processed_at)

    return table


def write_parquet_to_s3(table, bucket, key):
    import pyarrow.parquet as pq

    buf = io.BytesIO()
    pq.write_table(table, buf, compression="snappy")
    buf.seek(0)
    s3.put_object(Bucket=bucket, Key=key, Body=buf.read())
    logger.info("Written %s rows to s3://%s/%s", len(table), bucket, key)


def lambda_handler(event, context):
    logger.info("ETL started. RAW_BUCKET=%s PROCESSED_BUCKET=%s", RAW_BUCKET, PROCESSED_BUCKET)

    raw_keys = list_raw_files()
    if not raw_keys:
        logger.warning("No Parquet files found under s3://%s/%s", RAW_BUCKET, RAW_PREFIX)
        return {"status": "no_files"}

    results = []
    for key in raw_keys:
        logger.info("Processing %s", key)
        table = read_parquet_from_s3(RAW_BUCKET, key)

        before = len(table)
        table = transform(table)
        after = len(table)
        logger.info("Rows: %d raw → %d after cleaning (dropped %d)", before, after, before - after)

        # Derive output key: preserve filename, change prefix
        filename = key.split("/")[-1]
        out_key = f"{PROCESSED_PREFIX}{filename}"
        write_parquet_to_s3(table, PROCESSED_BUCKET, out_key)
        results.append({"input": key, "output": out_key, "rows": after})

    logger.info("ETL complete. Processed %d file(s).", len(results))
    return {"status": "success", "files": results}
