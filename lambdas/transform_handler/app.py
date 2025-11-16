import json
import base64
import time

HIGH_RISK_COUNTRIES = {"RU", "IR", "KP"}  # just example list
HIGH_AMOUNT_THRESHOLD = 1000.0


def enrich_record(rec: dict) -> dict:
    """Add simple enrichment fields to a transaction record."""
    amount = rec.get("amount") or 0.0
    country = rec.get("country") or ""

    is_high_risk = bool(
        (isinstance(amount, (int, float)) and amount > HIGH_AMOUNT_THRESHOLD)
        or (country in HIGH_RISK_COUNTRIES)
    )

    rec["ingest_ts"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    rec["is_high_risk"] = is_high_risk
    return rec


def handler(event, context):
    """Firehose transformation Lambda entrypoint."""
    out_records = []

    for record in event["records"]:
        try:
            # Decode incoming data
            payload_bytes = base64.b64decode(record["data"])
            payload_str = payload_bytes.decode("utf-8")

            data = json.loads(payload_str)

            # Enrich
            enriched = enrich_record(data)

            # Re-encode
            enriched_str = json.dumps(enriched) + "\n"
            enriched_bytes = enriched_str.encode("utf-8")
            encoded = base64.b64encode(enriched_bytes).decode("utf-8")

            out_records.append(
                {
                    "recordId": record["recordId"],
                    "result": "Ok",
                    "data": encoded,
                }
            )
        except Exception as e:
            # On error, keep original data but mark as Dropped
            out_records.append(
                {
                    "recordId": record["recordId"],
                    "result": "ProcessingFailed",
                    "data": record["data"],
                }
            )

    return {"records": out_records}
