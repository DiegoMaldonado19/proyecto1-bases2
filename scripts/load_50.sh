#!/bin/bash

PROXY_HOST="0.0.0.0"
PROXY_PORT="6033"
DB_USER="app_user"
DB_PASS="app_password"
DB_NAME="test_db"

DURATION=300

WRITE_WORKERS=5
READ_WORKERS=10

echo "=========================================="
echo "PRUEBA DE CARGA AL 50%"
echo "=========================================="
echo "Duración: $DURATION segundos"
echo "Writers: $WRITE_WORKERS procesos"
echo "Readers: $READ_WORKERS procesos"
echo "=========================================="
echo ""

do_writes() {
    local worker_id=$1
    local end_time=$(($(date +%s) + DURATION))
    local count=0
    
    while [ $(date +%s) -lt $end_time ]; do
        mysql -h$PROXY_HOST -P$PROXY_PORT -u$DB_USER -p$DB_PASS $DB_NAME \
            -e "INSERT INTO test_replication (source, data) VALUES ('writer-$worker_id', 'data-$(date +%s)');" \
            2>/dev/null
        
        ((count++))
        sleep 0.1
    done
    
    echo "[Writer-$worker_id] Completado: $count escrituras"
}

do_reads() {
    local worker_id=$1
    local end_time=$(($(date +%s) + DURATION))
    local count=0
    
    while [ $(date +%s) -lt $end_time ]; do
        case $((RANDOM % 4)) in
            0) mysql -h$PROXY_HOST -P$PROXY_PORT -u$DB_USER -p$DB_PASS $DB_NAME \
                   -e "SELECT COUNT(*) FROM test_replication;" 2>/dev/null ;;
            1) mysql -h$PROXY_HOST -P$PROXY_PORT -u$DB_USER -p$DB_PASS $DB_NAME \
                   -e "SELECT * FROM test_replication ORDER BY created_at DESC LIMIT 10;" 2>/dev/null ;;
            2) mysql -h$PROXY_HOST -P$PROXY_PORT -u$DB_USER -p$DB_PASS $DB_NAME \
                   -e "SELECT * FROM test_replication WHERE id > $((RANDOM % 5000)) LIMIT 20;" 2>/dev/null ;;
            3) mysql -h$PROXY_HOST -P$PROXY_PORT -u$DB_USER -p$DB_PASS $DB_NAME \
                   -e "SELECT source, COUNT(*) FROM test_replication GROUP BY source;" 2>/dev/null ;;
        esac
        
        ((count++))
        sleep 0.05
    done
    
    echo "[Reader-$worker_id] Completado: $count lecturas"
}

echo "Iniciando $WRITE_WORKERS writers..."
for i in $(seq 1 $WRITE_WORKERS); do
    do_writes $i &
done

echo "Iniciando $READ_WORKERS readers..."
for i in $(seq 1 $READ_WORKERS); do
    do_reads $i &
done

echo ""
echo "Prueba en progreso... (esperando $DURATION segundos)"
echo "Presiona Ctrl+C para detener"
echo ""

wait

echo ""
echo "=========================================="
echo "PRUEBA COMPLETADA"
echo "=========================================="