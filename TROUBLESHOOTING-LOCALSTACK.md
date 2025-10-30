# Troubleshooting - LocalStack

## ✅ Problema Resolvido: `/tmp/localstack` Device or Resource Busy

### Sintoma
```
ERROR: 'rm -rf "/tmp/localstack"': exit code 1; output: b"rm: cannot remove '/tmp/localstack': Device or resource busy\n"
OSError: [Errno 16] Device or resource busy: '/tmp/localstack'
```

### Causa
O LocalStack estava tentando usar `/tmp/localstack` como diretório de dados, mas esse diretório pode ter conflitos com montagens do Podman/Docker.

### Solução Aplicada

Alteramos o `docker-compose.yml` para:

1. **Mudar DATA_DIR** de `/tmp/localstack/data` para `/var/lib/localstack`
2. **Mudar volume mount** de `/tmp/localstack` para `/var/lib/localstack`
3. **Adicionar tmpfs** separado para `/tmp`
4. **Mudar scripts init** de `/docker-entrypoint-initaws.d` para `/etc/localstack/init/ready.d`

```yaml
localstack:
  image: localstack/localstack:latest
  container_name: localstack
  environment:
    SERVICES: s3
    DEBUG: 0
    DATA_DIR: /var/lib/localstack          # ← Mudado
    HOSTNAME_EXTERNAL: localstack
    AWS_DEFAULT_REGION: us-east-1
    PERSIST_STORAGE: 1                      # ← Adicionado
    DOCKER_FLAGS: "--rm"                    # ← Adicionado
  ports:
    - "4566:4566"
  volumes:
    - localstack-data:/var/lib/localstack  # ← Mudado
    - ./localstack-init:/etc/localstack/init/ready.d  # ← Mudado
  tmpfs:
    - /tmp                                  # ← Adicionado
```

### Verificação

Após aplicar a correção:

```bash
# 1. Reiniciar LocalStack
podman-compose down
podman-compose up -d

# 2. Verificar saúde
curl http://localhost:4566/_localstack/health | jq '.services.s3'
# Deve mostrar: "running"

# 3. Verificar bucket
podman exec localstack awslocal s3 ls
# Deve mostrar: kafka-events-bucket
```

### Resultado

✅ LocalStack S3 rodando corretamente  
✅ Bucket `kafka-events-bucket` criado automaticamente  
✅ Sem erros de "Device or resource busy"  

---

## Outros Problemas Comuns

### LocalStack não inicia

```bash
# Ver logs detalhados
podman logs localstack

# Reiniciar clean
podman rm -f localstack
podman volume rm kafka-project_localstack-data
podman-compose up -d localstack
```

### Bucket não foi criado

```bash
# Criar manualmente
podman exec localstack awslocal s3 mb s3://kafka-events-bucket

# Verificar script de init
cat localstack-init/01-create-bucket.sh
```

### Não consegue acessar S3

```bash
# Verificar porta
curl http://localhost:4566/_localstack/health

# Verificar conectividade do Kafka Connect
podman exec kafka-connect curl http://localstack:4566/_localstack/health
```

### Permissão negada ao listar arquivos

```bash
# LocalStack usa credenciais fake: test/test
# Configure no conector:
"aws.access.key.id": "test"
"aws.secret.access.key": "test"
```

---

**Data da correção:** 29/10/2025  
**Versão LocalStack:** 4.9.3.dev77  
**Status:** ✅ Resolvido
