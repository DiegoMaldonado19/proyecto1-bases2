#!/bin/bash

PROXY_HOST="0.0.0.0"
PROXY_PORT="6033"
DB_USER="app_user"
DB_PASS="app_password"
DB_NAME="test_db"

DURATION=300

READ_WORKERS=30

echo "=========================================="
echo "PRUEBA DE CARGA AL 100% - SOLO NODO 3"
echo "=========================================="
echo "Duración: $DURATION segundos"
echo "Readers: $READ_WORKERS procesos"
echo "=========================================="
echo ""
echo "IMPORTANTE: Antes de continuar, detener Master1 y Master2:"
echo ""
echo "   En Laptop 1: docker stop mysql-master1"
echo "   En Laptop 2: docker stop mysql-master2"
echo ""
read -p "¿Masters detenidos? Presiona Enter para continuar o Ctrl+C para cancelar..."
echo ""

do_reads() {
    local worker_id=$1
    local end_time=$(($(date +%s) + DURATION))
    local count=0
    local errors=0
    
    while [ $(date +%s) -lt $end_time ]; do
        case $((RANDOM % 6)) in
            0) result=$(mysql -h$PROXY_HOST -P$PROXY_PORT -u$DB_USER -p$DB_PASS $DB_NAME \
                   -e "SELECT COUNT(*) FROM test_replication;" 2>&1) ;;
            1) result=$(mysql -h$PROXY_HOST -P$PROXY_PORT -u$DB_USER -p$DB_PASS $DB_NAME \
                   -e "SELECT * FROM test_replication ORDER BY created_at DESC LIMIT 50;" 2>&1) ;;
            2) result=$(mysql -h$PROXY_HOST -P$PROXY_PORT -u$DB_USER -p$DB_PASS $DB_NAME \
                   -e "SELECT * FROM test_replication WHERE id > $((RANDOM % 10000)) LIMIT 30;" 2>&1) ;;
            3) result=$(mysql -h$PROXY_HOST -P$PROXY_PORT -u$DB_USER -p$DB_PASS $DB_NAME \
                   -e "SELECT source, COUNT(*), MAX(created_at) FROM test_replication GROUP BY source;" 2>&1) ;;
            4) result=$(mysql -h$PROXY_HOST -P$PROXY_PORT -u$DB_USER -p$DB_PASS $DB_NAME \
                   -e "SELECT * FROM test_replication WHERE id BETWEEN $((RANDOM % 5000)) AND $((RANDOM % 5000 + 100));" 2>&1) ;;
            5) result=$(mysql -h$PROXY_HOST -P$PROXY_PORT -u$DB_USER -p$DB_PASS $DB_NAME \
                   -e "SELECT DATE(created_at) as day, COUNT(*) FROM test_replication GROUP BY day;" 2>&1) ;;
        esac
        
        if [ $? -eq 0 ]; then
            ((count++))
        else
            ((errors++))
        fi
        
    done
    
    echo "[Reader-$worker_id] Completado: $count lecturas, $errors errores"
}

# Monitor simple en background
monitor() {
    local end_time=$(($(date +%s) + DURATION))
    
    while [ $(date +%s) -lt $end_time ]; do
        sleep 10
        remaining=$((end_time - $(date +%s)))
        echo "[Monitor] Tiempo restante: $remaining segundos"
    done
}

monitor &
MONITOR_PID=$!

echo "Iniciando $READ_WORKERS readers con carga máxima..."
echo ""

for i in $(seq 1 $READ_WORKERS); do
    do_reads $i &
    sleep 0.1
done

echo "Prueba en progreso... generando carga máxima"
echo "Presiona Ctrl+C para detener"
echo ""

wait

echo ""
echo "=========================================="
echo "PRUEBA COMPLETADA"
echo "=========================================="