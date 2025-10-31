#!/bin/bash
# Download JMX Prometheus Exporter

JMX_EXPORTER_VERSION="0.20.0"
JMX_EXPORTER_JAR="jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar"
DOWNLOAD_URL="https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/${JMX_EXPORTER_VERSION}/${JMX_EXPORTER_JAR}"
TARGET_DIR="./jmx-exporter"
TARGET_FILE="${TARGET_DIR}/jmx_prometheus_javaagent.jar"

echo "================================================"
echo "Downloading JMX Prometheus Exporter"
echo "Version: ${JMX_EXPORTER_VERSION}"
echo "================================================"

# Create directory if it doesn't exist
mkdir -p "${TARGET_DIR}"

# Check if file already exists
if [ -f "${TARGET_FILE}" ]; then
    echo "✓ JMX Exporter already exists at ${TARGET_FILE}"
    echo "File size: $(ls -lh ${TARGET_FILE} | awk '{print $5}')"
    exit 0
fi

# Download the JAR
echo "Downloading from: ${DOWNLOAD_URL}"
echo "Saving to: ${TARGET_FILE}"

if command -v curl &> /dev/null; then
    curl -L -o "${TARGET_FILE}" "${DOWNLOAD_URL}"
elif command -v wget &> /dev/null; then
    wget -O "${TARGET_FILE}" "${DOWNLOAD_URL}"
else
    echo "❌ Error: Neither curl nor wget is available. Please install one of them."
    exit 1
fi

# Check if download was successful
if [ $? -eq 0 ] && [ -f "${TARGET_FILE}" ]; then
    echo "✓ Successfully downloaded JMX Exporter"
    echo "File size: $(ls -lh ${TARGET_FILE} | awk '{print $5}')"
    echo ""
    echo "================================================"
    echo "JMX Exporter is ready!"
    echo "================================================"
    exit 0
else
    echo "❌ Failed to download JMX Exporter"
    exit 1
fi
