import json
import boto3
import os

sns = boto3.client("sns")

SNS_TOPIC_ARN = os.getenv("SNS_TOPIC_ARN")

def handler(event, context):
    # Kinesis Firehose transformation sends events wrapped inside "records"
    for record in event.get("records", []):
        payload = json.loads(record["data"].decode("utf-8"))

        # Only alert if transaction is high risk
        if payload.get("is_high_risk") is True:
            message = f"""
⚠️ HIGH RISK TRANSACTION DETECTED

Transaction ID: {payload.get('transaction_id')}
Amount: {payload.get('amount')}
Currency: {payload.get('currency')}
Country: {payload.get('country')}
Timestamp: {payload.get('timestamp')}
Card Last4: {payload.get('card_last4')}
Risk Score: {payload.get('features', {}).get('device_trust')}
            """

            sns.publish(
                TopicArn=SNS_TOPIC_ARN,
                Message=message,
                Subject="🚨 Fraud Alert – High Risk Transaction"
            )

    # Firehose requires transformed output format
    return {
        "records": [
            {
                "recordId": r["recordId"],
                "result": "Ok",
                "data": r["data"]
            }
            for r in event["records"]
        ]
    }
