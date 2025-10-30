#!/usr/bin/env python3
"""Quick test to verify Kafka connectivity"""

from kafka import KafkaProducer
import json

BOOTSTRAP_SERVERS = ['localhost:9092']

print("🔌 Testing Kafka connection to", BOOTSTRAP_SERVERS)

try:
    producer = KafkaProducer(
        bootstrap_servers=BOOTSTRAP_SERVERS,
        value_serializer=lambda v: json.dumps(v).encode('utf-8'),
        request_timeout_ms=5000,
        api_version_auto_timeout_ms=5000
    )
    
    # Send a test message
    event = {'test': 'connection', 'status': 'success'}
    future = producer.send('events', value=event)
    record_metadata = future.get(timeout=10)
    
    print(f"✅ SUCCESS! Connected to Kafka")
    print(f"   Topic: {record_metadata.topic}")
    print(f"   Partition: {record_metadata.partition}")
    print(f"   Offset: {record_metadata.offset}")
    
    producer.close()
    
except Exception as e:
    print(f"❌ FAILED: {e}")
    import traceback
    traceback.print_exc()
