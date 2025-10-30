# Monitoramento Kafka - Métricas e Dashboards

## 📊 Visão Geral

Este projeto inclui monitoramento completo do cluster Kafka usando:
- **Prometheus** - Coleta e armazenamento de métricas
- **Grafana** - Visualização de dashboards
- **JMX Exporter** - Exportação de métricas JMX do Kafka

## 🚀 Início Rápido

### 1. Baixar JMX Exporter (primeira vez apenas)
```bash
./download-jmx-exporter.sh
```

### 2. Iniciar ambiente com métricas
```bash
./restart-with-metrics.sh
```

Ou manualmente:
```bash
docker-compose up -d
```

## 🌐 Acesso aos Serviços

| Serviço | URL | Credenciais |
|---------|-----|-------------|
| **Grafana** | http://localhost:3000 | admin / admin |
| **Prometheus** | http://localhost:9090 | - |
| **AKHQ** | http://localhost:8080 | - |

## 📈 Dashboards Disponíveis

### Kafka Cluster Overview
Dashboard completo com as principais métricas do cluster Kafka.

**Acesso:** Grafana → Dashboards → Kafka → Kafka Cluster Overview

#### Métricas Incluídas:

##### 🎯 Visão Geral (Gauges)
- **Active Brokers** - Número de brokers ativos no cluster
- **Total Partitions** - Total de partições
- **Active Controllers** - Controllers ativos (deve ser sempre 1)
- **Under Replicated Partitions** - Partições sub-replicadas (alerta se > 0)

##### 🖥️ Métricas de Brokers
- **Messages In Per Second** - Taxa de mensagens recebidas por broker
- **Network Throughput** - Bytes in/out por segundo
- **Leader Count** - Distribuição de líderes por broker
- **Partition Count** - Distribuição de partições por broker

##### ⚡ Métricas de Performance
- **Request Latency (p99)** - Latência de Produce e Fetch (percentil 99)
- **Request Rate** - Taxa de requisições por segundo
- **Request Handler Idle %** - Porcentagem de idle dos handlers

##### 🎮 Métricas de Controllers
- **Active Controller** - Monitoramento do controller ativo
- **Partition Health** - Partições offline e sub-replicadas
- **ISR Changes** - Mudanças em In-Sync Replicas
- **Leader Elections** - Eleições de líder (clean e unclean)

##### 📦 Métricas de Tópicos
- **Log Size** - Tamanho dos logs por tópico/partição

## 🔧 Configuração Técnica

### Arquitetura de Métricas

```
Kafka Brokers/Controllers
    ↓ (JMX Metrics via port 9101)
JMX Exporter (port 7071)
    ↓ (Prometheus format)
Prometheus (scrape every 15s)
    ↓ (PromQL queries)
Grafana Dashboards
```

### Portas de Métricas

| Componente | Porta JMX | Porta JMX Exporter | Porta Externa |
|------------|-----------|-------------------|---------------|
| Broker 1 | 9101 | 7071 | 7071 |
| Broker 2 | 9101 | 7071 | 7072 |
| Broker 3 | 9101 | 7071 | 7073 |
| Controller 1 | 9101 | 7071 | 17071 |
| Controller 2 | 9101 | 7071 | 17072 |
| Controller 3 | 9101 | 7071 | 17073 |

### Testar Endpoints de Métricas

#### Via cURL:
```bash
# Broker 1
curl http://localhost:7071/metrics

# Controller 1
curl http://localhost:17071/metrics

# Prometheus targets
curl http://localhost:9090/api/v1/targets
```

#### Via Browser:
- http://localhost:7071/metrics (Broker 1)
- http://localhost:9090/targets (Prometheus targets)

## 📊 Prometheus Queries Úteis

### Métricas de Throughput
```promql
# Taxa de mensagens por segundo
rate(kafka_server_brokertopicmetrics_messagesin_total[5m])

# Bytes in por segundo
rate(kafka_server_brokertopicmetrics_bytesin_total[5m])

# Bytes out por segundo
rate(kafka_server_brokertopicmetrics_bytesout_total[5m])
```

### Métricas de Latência
```promql
# Latência p99 de Produce
kafka_network_requestmetrics_totaltimems{request="Produce",quantile="0.99"}

# Latência p99 de Fetch
kafka_network_requestmetrics_totaltimems{request="FetchConsumer",quantile="0.99"}
```

### Métricas de Saúde
```promql
# Partições under-replicated
kafka_server_replicamanager_underreplicatedpartitions

# Partições offline
kafka_controller_kafkacontroller_offlinepartitionscount

# Controller ativo
kafka_controller_kafkacontroller_activecontrollercount
```

### Métricas de Distribuição
```promql
# Leaders por broker
kafka_server_replicamanager_leadercount

# Partições por broker
kafka_server_replicamanager_partitioncount
```

## 🔍 Troubleshooting

### Métricas não aparecem no Grafana

1. **Verificar se o JMX Exporter está funcionando:**
   ```bash
   curl http://localhost:7071/metrics | grep kafka
   ```

2. **Verificar targets no Prometheus:**
   - Acessar: http://localhost:9090/targets
   - Todos os targets devem estar "UP"

3. **Verificar logs dos containers:**
   ```bash
   docker-compose logs broker1 | grep -i jmx
   docker-compose logs prometheus
   docker-compose logs grafana
   ```

### JMX Exporter não inicia

1. **Verificar se o JAR foi baixado:**
   ```bash
   ls -lh jmx-exporter/jmx_prometheus_javaagent.jar
   ```

2. **Rebaixar novamente se necessário:**
   ```bash
   ./download-jmx-exporter.sh
   ```

3. **Reiniciar containers:**
   ```bash
   docker-compose restart
   ```

### Dashboard vazio ou com "No Data"

1. **Aguardar alguns minutos** - Prometheus precisa coletar dados primeiro
2. **Gerar tráfego no Kafka:**
   ```bash
   python3 producer_example.py
   ```
3. **Verificar intervalo de tempo no Grafana** - Certifique-se de que está visualizando "Last 1 hour"

## 📝 Personalização

### Adicionar novas métricas ao JMX Exporter

Edite: `jmx-exporter/kafka-config.yml`

Exemplo:
```yaml
rules:
  - pattern: kafka.server<type=YourMetricType, name=(.+)><>Value
    name: kafka_server_yourmetric_$1
    type: GAUGE
```

### Modificar intervalo de scrape do Prometheus

Edite: `prometheus.yml`

```yaml
global:
  scrape_interval: 15s  # Altere para o intervalo desejado
```

### Adicionar novos painéis ao dashboard

1. Acesse Grafana: http://localhost:3000
2. Vá para o dashboard "Kafka Cluster Overview"
3. Clique em "Add Panel"
4. Configure sua query PromQL
5. Salve o dashboard

## 📚 Recursos Adicionais

- [Kafka Monitoring Documentation](https://kafka.apache.org/documentation/#monitoring)
- [JMX Exporter GitHub](https://github.com/prometheus/jmx_exporter)
- [Prometheus Kafka Metrics](https://docs.confluent.io/platform/current/kafka/monitoring.html)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)

## 🎯 Alertas Recomendados

### Partições Under-Replicated
```promql
kafka_server_replicamanager_underreplicatedpartitions > 0
```

### Sem Controller Ativo
```promql
sum(kafka_controller_kafkacontroller_activecontrollercount) != 1
```

### Alta Latência de Produce
```promql
kafka_network_requestmetrics_totaltimems{request="Produce",quantile="0.99"} > 100
```

### Broker Offline
```promql
up{job="kafka-brokers"} == 0
```

## 🤝 Contribuindo

Para adicionar novas métricas ou melhorar os dashboards:
1. Edite os arquivos de configuração
2. Teste localmente
3. Documente as mudanças
4. Compartilhe com a equipe

---

**Nota:** Este ambiente foi configurado para desenvolvimento. Para produção, considere:
- Autenticação/autorização
- TLS/SSL
- Retenção de dados do Prometheus
- Backup dos dashboards do Grafana
- Alertmanager para notificações
