#!/bin/bash
# Helper script para executar comandos de qualquer lugar no projeto

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
    echo "Kafka Project - Helper Script"
    echo ""
    echo "Uso: ./kafka.sh [comando]"
    echo ""
    echo "Comandos disponíveis:"
    echo ""
    echo "  Cluster:"
    echo "    start              - Inicia o cluster Kafka"
    echo "    stop               - Para o cluster Kafka"
    echo "    restart            - Reinicia o cluster Kafka"
    echo "    restart-metrics    - Reinicia com verificação de métricas"
    echo "    status             - Mostra status dos containers"
    echo "    logs [service]     - Mostra logs (opcional: especifique o serviço)"
    echo ""
    echo "  Testes:"
    echo "    test-connection    - Testa conectividade Kafka"
    echo "    test-pipeline      - Teste end-to-end Kafka → S3"
    echo ""
    echo "  Producer:"
    echo "    run-producer       - Executa o producer de exemplo"
    echo ""
    echo "  S3 Connector:"
    echo "    connector-create   - Cria o S3 Sink Connector"
    echo "    connector-status   - Mostra status do connector"
    echo "    connector-delete   - Deleta o connector"
    echo "    connector-restart  - Reinicia o connector"
    echo "    connector-list     - Lista todos os connectors"
    echo "    s3-list            - Lista arquivos no S3"
    echo ""
    echo "  Métricas:"
    echo "    metrics            - Abre URLs de métricas"
    echo ""
    echo "  Ajuda:"
    echo "    help               - Mostra esta mensagem"
    echo ""
}

case "$1" in
    start)
        cd "$SCRIPT_DIR/clusters" && podman-compose up -d
        ;;
    stop)
        cd "$SCRIPT_DIR/clusters" && podman-compose down
        ;;
    restart)
        cd "$SCRIPT_DIR/clusters" && podman-compose restart
        ;;
    restart-metrics)
        cd "$SCRIPT_DIR/tools" && ./restart-with-metrics.sh
        ;;
    status)
        cd "$SCRIPT_DIR/clusters" && podman ps
        ;;
    logs)
        cd "$SCRIPT_DIR/clusters"
        if [ -z "$2" ]; then
            podman logs -f
        else
            podman logs -f "$2"
        fi
        ;;
    test-connection)
        cd "$SCRIPT_DIR/tools" && python test_connection.py
        ;;
    test-pipeline)
        cd "$SCRIPT_DIR/tools" && ./test-s3-pipeline.sh
        ;;
    run-producer)
        cd "$SCRIPT_DIR/producers" && python producer_example.py
        ;;
    connector-create)
        cd "$SCRIPT_DIR/connects" && ./s3-connector.sh create
        ;;
    connector-status)
        cd "$SCRIPT_DIR/connects" && ./s3-connector.sh status
        ;;
    connector-delete)
        cd "$SCRIPT_DIR/connects" && ./s3-connector.sh delete
        ;;
    connector-restart)
        cd "$SCRIPT_DIR/connects" && ./s3-connector.sh restart
        ;;
    connector-list)
        cd "$SCRIPT_DIR/connects" && ./s3-connector.sh list
        ;;
    s3-list)
        cd "$SCRIPT_DIR/connects" && ./s3-connector.sh show-s3
        ;;
    metrics)
        echo "Abrindo endpoints de métricas:"
        echo "  Prometheus: http://localhost:9090"
        echo "  Grafana: http://localhost:3000 (admin/admin)"
        echo "  AKHQ: http://localhost:8080"
        echo "  JMX Broker1: http://localhost:7071/metrics"
        echo "  JMX Broker2: http://localhost:7072/metrics"
        echo "  JMX Broker3: http://localhost:7073/metrics"
        ;;
    help|"")
        show_help
        ;;
    *)
        echo "Comando desconhecido: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
