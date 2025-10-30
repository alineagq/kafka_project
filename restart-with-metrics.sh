#!/bin/bash
# Script para reiniciar o ambiente Kafka com métricas

echo "================================================"
echo "Reiniciando ambiente Kafka com métricas..."
echo "================================================"

# Parar containers
echo ""
echo "1. Parando containers..."
docker compose down

# Iniciar containers
echo ""
echo "2. Iniciando containers..."
docker compose up -d

# Aguardar containers iniciarem
echo ""
echo "3. Aguardando containers iniciarem..."
sleep 10

# Verificar status
echo ""
echo "4. Status dos containers:"
docker compose ps

echo ""
echo "================================================"
echo "Verificando endpoints de métricas..."
echo "================================================"

echo ""
echo "Testando JMX Exporter endpoints (pode demorar um pouco)..."
sleep 5

# Função para testar endpoint
test_endpoint() {
    local name=$1
    local url=$2
    
    if curl -s "${url}" | grep -q "kafka"; then
        echo "✓ ${name}: OK"
    else
        echo "⚠ ${name}: Aguardando..."
    fi
}

echo ""
echo "Brokers:"
test_endpoint "Broker 1" "http://localhost:7071/metrics"
test_endpoint "Broker 2" "http://localhost:7072/metrics"
test_endpoint "Broker 3" "http://localhost:7073/metrics"

echo ""
echo "Controllers:"
test_endpoint "Controller 1" "http://localhost:17071/metrics"
test_endpoint "Controller 2" "http://localhost:17072/metrics"
test_endpoint "Controller 3" "http://localhost:17073/metrics"

echo ""
echo "================================================"
echo "Serviços disponíveis:"
echo "================================================"
echo "• Kafka Brokers:  localhost:9092-9094"
echo "• AKHQ:           http://localhost:8080"
echo "• Prometheus:     http://localhost:9090"
echo "• Grafana:        http://localhost:3000 (admin/admin)"
echo "• Schema Registry: http://localhost:8081"
echo "• Kafka Connect:  http://localhost:8083"
echo ""
echo "Dashboards Grafana:"
echo "• Kafka Cluster Overview"
echo "================================================"
