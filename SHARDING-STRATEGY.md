# Estratégia de Sharding para S3 Sink Connectors

## 🎯 Objetivo

Distribuir a carga de escrita no S3 entre múltiplos connectors para:
1. Aumentar throughput total
2. Paralelizar I/O
3. Isolar falhas
4. Facilitar manutenção sem downtime

## 📊 Arquitetura de Sharding

### Opção 1: Sharding por Tópico (Topic-based Sharding)

Cada connector é responsável por um conjunto específico de tópicos.

```
┌─────────────────────────────────────────────────────────┐
│                    Kafka Cluster (MSK)                  │
├─────────────────────────────────────────────────────────┤
│  Topic: user-events         (12 partitions)             │
│  Topic: transaction-events  (18 partitions)             │
│  Topic: system-logs         (6 partitions)              │
│  Topic: analytics-events    (12 partitions)             │
└─────────────────┬──────────────┬───────────────────────┘
                  │              │
        ┌─────────┴─────┐   ┌───┴────────┐
        │               │   │            │
        v               v   v            v
┌───────────────┐ ┌──────────────┐ ┌──────────────┐
│ S3 Connector  │ │ S3 Connector │ │ S3 Connector │
│   Shard 0     │ │   Shard 1    │ │   Shard 2    │
├───────────────┤ ├──────────────┤ ├──────────────┤
│ Topics:       │ │ Topics:      │ │ Topics:      │
│ - user-events │ │ - transaction│ │ - system-logs│
│               │ │   -events    │ │ - analytics  │
└───────┬───────┘ └──────┬───────┘ └──────┬───────┘
        │                │                │
        v                v                v
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│  S3 Bucket   │ │  S3 Bucket   │ │  S3 Bucket   │
│   Shard 0    │ │   Shard 1    │ │   Shard 2    │
└──────────────┘ └──────────────┘ └──────────────┘
```

**Configuração:**

```json
{
  "name": "s3-sink-shard-0",
  "config": {
    "topics": "user-events",
    "s3.bucket.name": "kafka-data-shard-0-prod"
  }
}
```

**Vantagens:**
- Isolamento claro por domínio de negócio
- Fácil de gerenciar e debugar
- Ideal quando tópicos têm cargas balanceadas

**Desvantagens:**
- Desbalanceamento se um tópico tem muito mais tráfego
- Requer planejamento cuidadoso de alocação

### Opção 2: Sharding por Partição (Partition-based Sharding)

Cada connector consome partições específicas de múltiplos tópicos.

```
Tópico: user-events (12 partitions)
┌──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┐
│  P0  │  P1  │  P2  │  P3  │  P4  │  P5  │  P6  │  P7  │  P8  │  P9  │ P10  │ P11  │
└──┬───┴──┬───┴──┬───┴──┬───┴──┬───┴──┬───┴──┬───┴──┬───┴──┬───┴──┬───┴──┬───┴──┬───┘
   │      │      │      │      │      │      │      │      │      │      │      │
   └──────┴──────┴──────┘      └──────┴──────┴──────┘      └──────┴──────┴──────┘
        Connector 0                 Connector 1                 Connector 2
```

**Configuração:**

```json
{
  "name": "s3-sink-shard-0",
  "config": {
    "topics": "user-events,transaction-events",
    "consumer.partition.assignment.strategy": "org.apache.kafka.clients.consumer.RoundRobinAssignor",
    "tasks.max": "4",
    "s3.bucket.name": "kafka-data-shard-0-prod"
  }
}
```

**Vantagens:**
- Balanceamento automático de carga
- Escala bem com crescimento de partições
- Distribuição uniforme de throughput

**Desvantagens:**
- Mais complexo para debugar
- Dados de um tópico ficam espalhados em múltiplos buckets

### Opção 3: Sharding Híbrido (Recomendado)

Combina topic e partition-based sharding usando regex patterns e transformações.

```
High-volume topics → Dedicated shards com múltiplas tasks
Low-volume topics  → Shared shard

user-events (high volume)     → Shard 0 (dedicated, 6 tasks)
transaction-events (high vol) → Shard 1 (dedicated, 6 tasks)
system-logs + analytics       → Shard 2 (shared, 3 tasks)
```

## 🔧 Implementação Detalhada

### Configuração 1: Topic-based com Regex

```json
{
  "name": "s3-sink-user-shard",
  "config": {
    "connector.class": "io.confluent.connect.s3.S3SinkConnector",
    "tasks.max": "6",
    "topics.regex": "user-.*",
    "s3.bucket.name": "kafka-data-user-events-prod",
    
    // Particionamento temporal
    "partitioner.class": "io.confluent.connect.storage.partitioner.TimeBasedPartitioner",
    "path.format": "'domain'=users/'year'=YYYY/'month'=MM/'day'=dd/'hour'=HH",
    "partition.duration.ms": "3600000",
    "timestamp.extractor": "RecordField",
    "timestamp.field": "event_timestamp",
    
    // Performance
    "flush.size": "10000",
    "rotate.interval.ms": "300000",
    "s3.part.size": "10485760",
    "s3.compression.type": "gzip",
    
    // Error handling
    "errors.tolerance": "all",
    "errors.log.enable": "true",
    "errors.deadletterqueue.topic.name": "dlq-user-events",
    "errors.deadletterqueue.topic.replication.factor": "3"
  }
}
```

### Configuração 2: Sharding com Transformações

Adicionar metadados para rastreamento:

```json
{
  "name": "s3-sink-shard-0",
  "config": {
    "connector.class": "io.confluent.connect.s3.S3SinkConnector",
    "topics": "user-events",
    
    // Adicionar shard_id e timestamp
    "transforms": "addShardId,addProcessTime",
    
    "transforms.addShardId.type": "org.apache.kafka.connect.transforms.InsertField$Value",
    "transforms.addShardId.static.field": "shard_id",
    "transforms.addShardId.static.value": "0",
    
    "transforms.addProcessTime.type": "org.apache.kafka.connect.transforms.InsertField$Value",
    "transforms.addProcessTime.timestamp.field": "processed_at",
    
    "s3.bucket.name": "kafka-data-shard-0-prod"
  }
}
```

### Configuração 3: Multi-task para Alta Paralelização

```json
{
  "name": "s3-sink-high-throughput",
  "config": {
    "connector.class": "io.confluent.connect.s3.S3SinkConnector",
    "tasks.max": "12",
    "topics": "high-volume-events",
    
    // Otimizações de performance
    "s3.part.size": "52428800",
    "flush.size": "50000",
    "rotate.interval.ms": "600000",
    
    // Buffer maior
    "consumer.max.poll.records": "5000",
    "consumer.max.poll.interval.ms": "600000",
    
    // Compressão agressiva
    "s3.compression.type": "gzip",
    
    "s3.bucket.name": "kafka-data-high-volume-prod"
  }
}
```

## 📈 Estratégias de Particionamento S3

### 1. Particionamento Temporal (Time-based)

```
s3://bucket/topics/user-events/
  year=2025/
    month=01/
      day=15/
        hour=14/
          user-events+0+0000000000.json.gz
          user-events+0+0000001000.json.gz
          user-events+1+0000000000.json.gz
```

**Configuração:**
```json
{
  "partitioner.class": "io.confluent.connect.storage.partitioner.TimeBasedPartitioner",
  "path.format": "'year'=YYYY/'month'=MM/'day'=dd/'hour'=HH",
  "partition.duration.ms": "3600000",
  "locale": "en_US",
  "timezone": "UTC"
}
```

### 2. Particionamento por Campo (Field-based)

```
s3://bucket/topics/user-events/
  region=us-east/
    user-events+0+0000000000.json.gz
  region=us-west/
    user-events+1+0000000000.json.gz
  region=eu-west/
    user-events+2+0000000000.json.gz
```

**Configuração:**
```json
{
  "partitioner.class": "io.confluent.connect.storage.partitioner.FieldPartitioner",
  "partition.field.name": "region"
}
```

### 3. Particionamento Diário + Campo

```
s3://bucket/topics/user-events/
  year=2025/month=01/day=15/
    region=us-east/
      user-events+0+0000000000.json.gz
```

**Configuração:**
```json
{
  "partitioner.class": "io.confluent.connect.storage.partitioner.DailyPartitioner",
  "path.format": "'year'=YYYY/'month'=MM/'day'=dd/'region'=REGION"
}
```

## 🎛️ Tuning de Performance

### Para Alta Taxa de Mensagens (>100k msgs/s)

```json
{
  "tasks.max": "12",
  "s3.part.size": "52428800",
  "flush.size": "50000",
  "rotate.interval.ms": "300000",
  "s3.compression.type": "snappy",
  "consumer.max.poll.records": "5000",
  "consumer.fetch.min.bytes": "1048576",
  "s3.part.retries": "5"
}
```

### Para Mensagens Grandes (>1MB cada)

```json
{
  "tasks.max": "3",
  "s3.part.size": "104857600",
  "flush.size": "100",
  "rotate.interval.ms": "600000",
  "s3.compression.type": "gzip",
  "consumer.max.poll.records": "100",
  "consumer.max.partition.fetch.bytes": "10485760"
}
```

### Para Baixa Latência

```json
{
  "tasks.max": "6",
  "s3.part.size": "5242880",
  "flush.size": "1000",
  "rotate.interval.ms": "60000",
  "s3.compression.type": "none",
  "consumer.max.poll.records": "500"
}
```

## 📊 Monitoramento de Shards

### Métricas por Connector

```promql
# Taxa de envio de registros
kafka_connect_sink_record_send_rate{connector="s3-sink-shard-0"}

# Latência de envio
kafka_connect_sink_record_send_latency_avg{connector="s3-sink-shard-0"}

# Erros
kafka_connect_task_error_total{connector="s3-sink-shard-0"}

# Offset lag
kafka_connect_source_task_offset_lag{connector="s3-sink-shard-0"}
```

### Dashboard Grafana

```json
{
  "dashboard": {
    "title": "Kafka S3 Sink Shards",
    "panels": [
      {
        "title": "Throughput por Shard",
        "targets": [{
          "expr": "sum(rate(kafka_connect_sink_record_send_rate[5m])) by (connector)"
        }]
      },
      {
        "title": "S3 Upload Success Rate",
        "targets": [{
          "expr": "(sum(rate(kafka_connect_sink_record_send_total[5m])) by (connector) / sum(rate(kafka_connect_sink_record_read_total[5m])) by (connector)) * 100"
        }]
      }
    ]
  }
}
```

## 🔄 Rebalanceamento de Shards

### Cenário: Shard 0 está sobrecarregado

```bash
# 1. Pausar connector sobrecarregado
curl -X PUT $CONNECT_ENDPOINT/connectors/s3-sink-shard-0/pause

# 2. Criar novo connector para dividir carga
cat > new-shard.json <<EOF
{
  "name": "s3-sink-shard-3",
  "config": {
    "topics": "user-events",
    "tasks.max": "6",
    "s3.bucket.name": "kafka-data-shard-3-prod"
  }
}
EOF

curl -X POST -H "Content-Type: application/json" \
  --data @new-shard.json \
  $CONNECT_ENDPOINT/connectors

# 3. Atualizar connector original para menos tópicos
curl -X PUT -H "Content-Type: application/json" \
  --data '{"topics": "transaction-events"}' \
  $CONNECT_ENDPOINT/connectors/s3-sink-shard-0/config

# 4. Resume connector
curl -X PUT $CONNECT_ENDPOINT/connectors/s3-sink-shard-0/resume
```

## 🎯 Recomendações Finais

### Para 3 Shards (Configuração Inicial)

```
Shard 0: High-volume user events     → 6 tasks, bucket-0
Shard 1: Transaction events           → 6 tasks, bucket-1  
Shard 2: System logs + analytics      → 3 tasks, bucket-2
```

### Para 6 Shards (Escalado)

```
Shard 0: user-events (P0-P5)          → 6 tasks, bucket-0
Shard 1: user-events (P6-P11)         → 6 tasks, bucket-1
Shard 2: transaction-events (P0-P8)   → 6 tasks, bucket-2
Shard 3: transaction-events (P9-P17)  → 6 tasks, bucket-3
Shard 4: system-logs                  → 3 tasks, bucket-4
Shard 5: analytics-events             → 3 tasks, bucket-5
```

### Para 9 Shards (Máximo)

Adicione sharding por região ou ambiente além do sharding por tópico/partição.

---

**A estratégia de sharding deve ser ajustada baseada em:**
1. Volume de dados por tópico
2. Latência requerida
3. Orçamento (custos de S3 e transfer)
4. Complexidade operacional aceitável
