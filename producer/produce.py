import csv
import glob
import json
import time

from kafka import KafkaProducer
from kafka.admin import KafkaAdminClient, NewTopic
from kafka.errors import NoBrokersAvailable, TopicAlreadyExistsError

BOOTSTRAP_SERVERS = "kafka:9092"
TOPIC = "mock_data"

INT_FIELDS = {
    "id", "customer_age", "product_quantity", "sale_customer_id", "sale_seller_id",
    "sale_product_id", "sale_quantity", "product_reviews",
}
FLOAT_FIELDS = {"product_price", "product_weight", "product_rating", "sale_total_price"}
DATE_FIELDS = {"sale_date", "product_release_date", "product_expiry_date"}


def to_iso_date(value):
    month, day, year = value.split("/")
    return year + "-" + month.zfill(2) + "-" + day.zfill(2)


def convert(row):
    result = {}
    for key, value in row.items():
        if key in INT_FIELDS:
            result[key] = int(value)
        elif key in FLOAT_FIELDS:
            result[key] = float(value)
        elif key in DATE_FIELDS:
            result[key] = to_iso_date(value)
        else:
            result[key] = value
    return result


admin = None
for _ in range(60):
    try:
        admin = KafkaAdminClient(bootstrap_servers=BOOTSTRAP_SERVERS)
        break
    except NoBrokersAvailable:
        time.sleep(2)
if admin is None:
    raise RuntimeError("kafka is not available")

try:
    admin.create_topics([NewTopic(name=TOPIC, num_partitions=3, replication_factor=1)])
except TopicAlreadyExistsError:
    pass
admin.close()

producer = KafkaProducer(
    bootstrap_servers=BOOTSTRAP_SERVERS,
    key_serializer=str.encode,
    value_serializer=lambda row: json.dumps(row, ensure_ascii=False).encode("utf-8"),
    acks="all",
    retries=5,
)

futures = []
for path in sorted(glob.glob("/data/MOCK_DATA*.csv")):
    with open(path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            futures.append(producer.send(TOPIC, key=str(len(futures)), value=convert(row)))

producer.flush()
for future in futures:
    future.get(timeout=60)
print("sent messages: " + str(len(futures)))
