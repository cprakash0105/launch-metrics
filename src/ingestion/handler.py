import json
import os
import uuid
from datetime import datetime

import boto3

kinesis = boto3.client("kinesis")
STREAM_NAME = os.environ["KINESIS_STREAM_NAME"]


def lambda_handler(event, context):
    try:
        body = json.loads(event.get("body", "{}"))

        # Validate required fields
        required = ["tenant_id", "event", "user_id"]
        missing = [f for f in required if f not in body]
        if missing:
            return {
                "statusCode": 400,
                "body": json.dumps({"error": f"Missing fields: {missing}"}),
            }

        # Enrich the event
        record = {
            **body,
            "event_id": str(uuid.uuid4()),
            "ingested_at": datetime.utcnow().isoformat() + "Z",
        }

        # Push to Kinesis
        kinesis.put_record(
            StreamName=STREAM_NAME,
            Data=json.dumps(record),
            PartitionKey=body["tenant_id"],
        )

        return {
            "statusCode": 200,
            "body": json.dumps({"message": "Event ingested", "event_id": record["event_id"]}),
        }

    except json.JSONDecodeError:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "Invalid JSON"}),
        }
    except Exception as e:
        print(f"Error: {e}")
        return {
            "statusCode": 500,
            "body": json.dumps({"error": "Internal server error"}),
        }
