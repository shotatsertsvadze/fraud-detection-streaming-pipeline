import json
import os
import base64
import boto3

SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN")
sns = boto3.client("sns")

# -----------------------------------
# Simple fraud logic
# -----------------------------------
def is_suspicious(tx):
    try:
        amount = float(tx.get("amount", 0))
    except:
        amount = 0

    country = tx.get("country", "").upper()

    high_risk_countries = {"RU", "BY", "UA", "KP", "IR"}
    amount_threshold = 2000.0

    return (amount > amount_threshold) or (country in high_risk_countries)

# -----------------------------------
# Main Lambda handler (Kinesis → Lambda)
# -----------------------------------
def handler(event, context):
    # DEBUG: Show the raw event (first 500 chars)
    print(f"EVENT RECEIVED: {json.dumps(event)[:500]}")

    records = event.get("Records", [])

    for rec in records:
        try:
            # Decode Kinesis base64 payload
            data_b64 = rec["kinesis"]["data"]
            payload_bytes = base64.b64decode(data_b64)
            payload_str = payload_bytes.decode("utf-8")
            tx = json.loads(payload_str)

            # DEBUG: show decoded transaction
            print(f"TX DECODED: {tx}")

            suspicious = is_suspicious(tx)

            # DEBUG: show fraud evaluation result
            print(f"is_suspicious = {suspicious}")

            if suspicious:
                print(
                    f"ALERT: publishing SNS for tx_id={tx.get('transaction_id')}, "
                    f"amount={tx.get('amount')}, country={tx.get('country')}"
                )

                # Prepare the SNS message
                message = json.dumps(
                    {
                        "transaction_id": tx.get("transaction_id"),
                        "amount": tx.get("amount"),
                        "currency": tx.get("currency"),
                        "country": tx.get("country"),
                        "merchant": tx.get("merchant"),
                        "card_last4": tx.get("card_last4"),
                    },
                    indent=2,
                )

                # Publish notification
                sns.publish(
                    TopicArn=SNS_TOPIC_ARN,
                    Subject="🚨 Fraud Alert – Suspicious transaction detected",
                    Message=message,
                )

        except Exception as e:
            print(f"Error processing record: {e}")

    return {"status": "ok"}
