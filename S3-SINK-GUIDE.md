# Guia Completo: Kafka S3 Sink com LocalStack

Este guia mostra como usar o Kafka Connect S3 Sink Connector com LocalStack para streaming de dados do Kafka para S3 localmente.

## 🏗️ Arquitetura

```
┌─────────────┐      ┌──────────────────┐      ┌─────────────┐
│  Producer   │─────▶│  Kafka Topic     │─────▶│ S3 Sink     │
│             │      │  (events)        │      │ Connector   │
└─────────────┘      └──────────────────┘      └──────┬──────┘
                                                       │
                                                       ▼
                                              ┌─────────────────┐
                                              │   LocalStack    │
                                              │   S3 Bucket     │
                                              │ kafka-events... │
                                              └─────────────────┘
```

### Componentes

- **Kafka Cluster**: 3 brokers + 3 controllers em modo KRaft
- **Kafka Connect**: Worker standalone com S3 Sink plugin
- **LocalStack**: Emulador AWS S3 para desenvolvimento local
- **AKHQ**: Interface web para administração (porta 8080)
- **Prometheus**: Coleta de métricas (porta 9090)

## 📁 Estrutura de Arquivos

```
year=YYYY/month=MM/day=DD/hour=HH/events+0+0000000000.json
year=YYYY/month=MM/day=DD/hour=HH/events+0+0000000001.json
```

- Particionamento por tempo (ano/mês/dia/hora)
- Arquivos em formato JSON
- Flush após 3 mensagens ou 60 segundos
- Rotação automática de arquivos

## 🚀 Início Rápido

### 1. Subir a Infraestrutura

```bash
# Subir todos os serviços
podman-compose up -d

# Verificar status
podman-compose ps

# Verificar logs
podman-compose logs -f kafka-connect
podman-compose logs -f localstack
```

### 2. Criar o Tópico

```bash
# Criar tópico 'events'
podman exec -it broker-1 kafka-topics --create \
    --bootstrap-server localhost:9092 \
    --topic events \
    --partitions 3 \
    --replication-factor 3

# Listar tópicos
podman exec -it broker-1 kafka-topics --list \
    --bootstrap-server localhost:9092
```

### 3. Criar o Conector S3 Sink

#### Opção A: Via Script (Recomendado)

```bash
./s3-connector.sh create
```

#### Opção B: Via AKHQ

1. Acesse http://localhost:8080
2. Menu lateral: **Connect** → **Create**
3. Cole o conteúdo de `s3-sink-connector.json`
4. Clique em **Create**

#### Opção C: Via API REST

```bash
curl -X POST http://localhost:8083/connectors \
    -H "Content-Type: application/json" \
    -d @s3-sink-connector.json
```

### 4. Verificar Status do Conector

```bash
# Via script
./s3-connector.sh status

# Via API
curl http://localhost:8083/connectors/s3-sink-connector/status | jq '.'

# Via AKHQ
# Acesse: http://localhost:8080/cluster/local/connect/local/s3-sink-connector
```

## 📤 Produzir Mensagens de Teste

### Console Producer

```bash
podman exec -it broker-1 kafka-console-producer \
    --bootstrap-server localhost:9092 \
    --topic events
```

Digite mensagens JSON e pressione Enter:

```json
{"id": 1, "type": "user_login", "user": "alice", "timestamp": "2024-01-15T10:30:00Z"}
{"id": 2, "type": "page_view", "page": "/home", "user": "bob", "timestamp": "2024-01-15T10:31:00Z"}
{"id": 3, "type": "purchase", "product": "laptop", "amount": 1200, "timestamp": "2024-01-15T10:32:00Z"}
```

Pressione `Ctrl+C` para sair.

### Python Producer

Crie um arquivo `producer.py`:

```python
from kafka import KafkaProducer
import json
from datetime import datetime

producer = KafkaProducer(
    bootstrap_servers='localhost:9092',
    value_serializer=lambda v: json.dumps(v).encode('utf-8')
)

# Enviar eventos
events = [
    {"id": 1, "type": "user_login", "user": "alice"},
    {"id": 2, "type": "page_view", "page": "/home", "user": "bob"},
    {"id": 3, "type": "purchase", "product": "laptop", "amount": 1200},
]

for event in events:
    event["timestamp"] = datetime.utcnow().isoformat()
    producer.send('events', event)
    print(f"Sent: {event}")

producer.flush()
producer.close()
```

Execute:

```bash
pip install kafka-python
python producer.py
```

## 🔍 Verificar Dados no S3

### Listar Arquivos

```bash
# Via script
./s3-connector.sh show-s3

# Via LocalStack CLI
podman exec -it localstack awslocal s3 ls s3://kafka-events-bucket/ --recursive

# Via AWS CLI (se configurado)
aws --endpoint-url=http://localhost:4566 s3 ls s3://kafka-events-bucket/ --recursive
```

### Baixar e Visualizar Arquivo

```bash
# Listar arquivos
./s3-connector.sh show-s3

# Baixar arquivo específico
# Exemplo: year=2024/month=01/day=15/hour=10/events+0+0000000000.json
podman exec -it localstack awslocal s3 cp \
    s3://kafka-events-bucket/year=2024/month=01/day=15/hour=10/events+0+0000000000.json \
    - | jq '.'

# Ou baixar para arquivo local
podman exec -it localstack awslocal s3 cp \
    s3://kafka-events-bucket/year=2024/month=01/day=15/hour=10/events+0+0000000000.json \
    /tmp/events.json

podman cp localstack:/tmp/events.json ./events.json
cat events.json | jq '.'
```

### Contar Total de Arquivos

```bash
podman exec -it localstack awslocal s3 ls s3://kafka-events-bucket/ --recursive | wc -l
```

## 🎛️ Gerenciamento do Conector

### Via Script `s3-connector.sh`

```bash
# Criar conector
./s3-connector.sh create

# Ver status
./s3-connector.sh status

# Listar todos os conectores
./s3-connector.sh list

# Reiniciar conector
./s3-connector.sh restart

# Deletar conector
./s3-connector.sh delete

# Listar arquivos S3
./s3-connector.sh show-s3

# Ajuda
./s3-connector.sh help
```

### Via API REST

```bash
# Status do worker
curl http://localhost:8083/ | jq '.'

# Plugins instalados
curl http://localhost:8083/connector-plugins | jq '.'

# Lista de conectores
curl http://localhost:8083/connectors | jq '.'

# Status detalhado
curl http://localhost:8083/connectors/s3-sink-connector/status | jq '.'

# Configuração atual
curl http://localhost:8083/connectors/s3-sink-connector/config | jq '.'

# Pausar conector
curl -X PUT http://localhost:8083/connectors/s3-sink-connector/pause

# Resumir conector
curl -X PUT http://localhost:8083/connectors/s3-sink-connector/resume

# Deletar conector
curl -X DELETE http://localhost:8083/connectors/s3-sink-connector
```

## 📊 Monitoramento via AKHQ

Acesse http://localhost:8080

### Verificar Tópicos
- Menu: **Topics** → `events`
- Visualizar mensagens, partições, consumer groups

### Gerenciar Conectores
- Menu: **Connect** → **local** → `s3-sink-connector`
- Ver status, tasks, configuração
- Pausar, resumir, reiniciar, deletar

### Visualizar Métricas JMX
- Menu: **Nodes** → Selecione um broker
- Ver métricas de CPU, memória, disco, rede
- Métricas de Kafka (throughput, latência, etc.)

## 🔧 Configuração do S3 Sink

Arquivo: `s3-sink-connector.json`

### Parâmetros Principais

```json
{
  "name": "s3-sink-connector",
  "config": {
    // Classe do conector
    "connector.class": "io.confluent.connect.s3.S3SinkConnector",
    
    // Tópico a ser consumido
    "topics": "events",
    
    // Configuração AWS/LocalStack
    "s3.bucket.name": "kafka-events-bucket",
    "store.url": "http://localstack:4566",
    "aws.access.key.id": "test",
    "aws.secret.access.key": "test",
    
    // Formato dos arquivos
    "format.class": "io.confluent.connect.s3.format.json.JsonFormat",
    
    // Particionamento por tempo
    "partitioner.class": "io.confluent.connect.storage.partitioner.TimeBasedPartitioner",
    "path.format": "'year'=YYYY/'month'=MM/'day'=dd/'hour'=HH",
    "partition.duration.ms": "3600000",  // 1 hora
    "timestamp.extractor": "Record",
    
    // Rotação de arquivos
    "flush.size": "3",                   // Flush após 3 mensagens
    "rotate.interval.ms": "60000",       // Ou após 60 segundos
    
    // Timezone
    "timezone": "America/Sao_Paulo"
  }
}
```

### Modificar Configuração

Para alterar configuração após criar:

```bash
# Editar s3-sink-connector.json
vim s3-sink-connector.json

# Deletar e recriar
./s3-connector.sh delete
./s3-connector.sh create

# Ou atualizar via API
curl -X PUT http://localhost:8083/connectors/s3-sink-connector/config \
    -H "Content-Type: application/json" \
    -d @s3-sink-connector.json
```

## 🐛 Troubleshooting

### Conector Não Inicia

```bash
# Verificar logs do Kafka Connect
podman-compose logs kafka-connect

# Verificar se o plugin S3 está instalado
curl http://localhost:8083/connector-plugins | jq '.[] | select(.class | contains("S3"))'

# Verificar status detalhado
curl http://localhost:8083/connectors/s3-sink-connector/status | jq '.tasks[].trace'
```

### LocalStack Não Responde

```bash
# Verificar status
podman-compose logs localstack

# Testar conectividade
curl http://localhost:4566/_localstack/health

# Recriar bucket manualmente
podman exec -it localstack awslocal s3 mb s3://kafka-events-bucket
```

### Arquivos Não Aparecem no S3

**Verificar se o conector está RUNNING:**
```bash
./s3-connector.sh status
```

**Verificar se há mensagens no tópico:**
```bash
podman exec -it broker-1 kafka-console-consumer \
    --bootstrap-server localhost:9092 \
    --topic events \
    --from-beginning \
    --max-messages 10
```

**Lembre-se:** Arquivos só são criados após:
- 3 mensagens (flush.size)
- OU 60 segundos (rotate.interval.ms)

**Forçar flush enviando 3 mensagens de teste.**

### Permissões S3

LocalStack usa credenciais fake, então não há problemas de permissão. Se usar AWS real:

```json
{
  "s3.part.size": "5242880",
  "s3.region": "us-east-1",
  "aws.access.key.id": "SEU_ACCESS_KEY",
  "aws.secret.access.key": "SUA_SECRET_KEY"
}
```

## 📈 Métricas do Conector

### Via JMX (Prometheus)

Acesse http://localhost:9090

Queries úteis:

```promql
# Taxa de mensagens processadas
rate(kafka_connect_sink_task_offset_commit_success_total[5m])

# Lag do consumer
kafka_connect_sink_task_consumer_lag

# Erros
rate(kafka_connect_task_error_total[5m])
```

### Via API REST

```bash
curl http://localhost:8083/connectors/s3-sink-connector/status | jq '.tasks[].id'
```

## 🧪 Teste Completo End-to-End

```bash
# 1. Subir ambiente
podman-compose up -d

# 2. Aguardar serviços (30-60 segundos)
sleep 60

# 3. Criar tópico
podman exec -it broker-1 kafka-topics --create \
    --bootstrap-server localhost:9092 \
    --topic events \
    --partitions 3 \
    --replication-factor 3

# 4. Criar conector
./s3-connector.sh create

# 5. Aguardar conector iniciar
sleep 10

# 6. Verificar status
./s3-connector.sh status

# 7. Produzir 3 mensagens
podman exec -it broker-1 bash -c 'echo "{\"id\":1,\"message\":\"test1\"}" | kafka-console-producer --bootstrap-server localhost:9092 --topic events'
podman exec -it broker-1 bash -c 'echo "{\"id\":2,\"message\":\"test2\"}" | kafka-console-producer --bootstrap-server localhost:9092 --topic events'
podman exec -it broker-1 bash -c 'echo "{\"id\":3,\"message\":\"test3\"}" | kafka-console-producer --bootstrap-server localhost:9092 --topic events'

# 8. Aguardar flush (10 segundos)
sleep 10

# 9. Verificar arquivos no S3
./s3-connector.sh show-s3

# 10. Baixar e visualizar arquivo
podman exec -it localstack awslocal s3 ls s3://kafka-events-bucket/ --recursive
```

## 🔄 Limpeza

```bash
# Parar todos os serviços
podman-compose down

# Remover volumes (apaga todos os dados)
podman-compose down -v

# Remover apenas dados do LocalStack
podman volume rm kafka-project_localstack-data
```

## 🌐 URLs Úteis

- AKHQ: http://localhost:8080
- Kafka Connect API: http://localhost:8083
- Prometheus: http://localhost:9090
- LocalStack Health: http://localhost:4566/_localstack/health

## 📚 Referências

- [Confluent S3 Sink Connector](https://docs.confluent.io/kafka-connectors/s3-sink/current/overview.html)
- [LocalStack S3 Documentation](https://docs.localstack.cloud/user-guide/aws/s3/)
- [AKHQ Documentation](https://akhq.io/)
- [Kafka Connect REST API](https://docs.confluent.io/platform/current/connect/references/restapi.html)
