"""
Glue ETL Job: Transform raw JSON events to partitioned Parquet in curated layer.
Partitions by: tenant_id, year, month, day
"""
import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.context import SparkContext
from pyspark.sql.functions import col, to_date, year, month, dayofmonth

args = getResolvedOptions(sys.argv, ["JOB_NAME", "S3_INPUT_PATH", "S3_OUTPUT_PATH"])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

# Read raw JSON from S3
df = spark.read.json(args["S3_INPUT_PATH"])

# Add date partition columns from ingested_at
df = df.withColumn("event_date", to_date(col("ingested_at"))) \
       .withColumn("year", year(col("event_date"))) \
       .withColumn("month", month(col("event_date"))) \
       .withColumn("day", dayofmonth(col("event_date")))

# Write as partitioned Parquet
df.write \
    .mode("append") \
    .partitionBy("tenant_id", "year", "month", "day") \
    .parquet(args["S3_OUTPUT_PATH"])

job.commit()
