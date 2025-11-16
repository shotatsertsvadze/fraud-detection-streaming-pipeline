
import json, os
import boto3

kinesis = boto3.client("kinesis")
STREAM_NAME = os.getenv("STREAM_NAME")
REQUIRED = {"transaction_id": str, "timestamp": str, "amount": (int, float), "currency": str}

def _validate(payload: dict):
    for k, t in REQUIRED.items():
        if k not in payload:
            return False, f"missing field: {k}"
        if not isinstance(payload[k], t):
            return False, f"wrong type for {k}"
    return True, "ok"

def handler(event, context):
    try:
        body = event.get("body") or "{}"
        data = json.loads(body)
        ok, msg = _validate(data)
        if not ok:
            return {"statusCode": 400, "body": json.dumps({"error": msg})}
        partition_key = data.get("card_last4") or data["transaction_id"]
        kinesis.put_record(StreamName=STREAM_NAME, Data=json.dumps(data).encode("utf-8"), PartitionKey=partition_key)
        return {"statusCode": 202, "body": json.dumps({"status": "accepted"})}
    except Exception as e:
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}
