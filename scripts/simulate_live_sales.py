#!/usr/bin/env python3
"""
Simulador de Streaming de Vendas em Tempo Real para Power BI DirectQuery.
Usa subprocess e docker exec sem requerer dependências pip externas (psycopg2/sqlalchemy).
"""
import sys
import time
import argparse
import subprocess
from datetime import datetime

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

def run_psql_command(query: str) -> str:
    cmd = [
        "docker", "exec", "pbi-postgres-dw",
        "psql", "-U", "postgres", "-d", "dw_sales",
        "-t", "-A", "-F", "|", "-c", query
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    return result.stdout.strip()

def main():
    parser = argparse.ArgumentParser(description="Simulador de Vendas Live DirectQuery")
    parser.add_argument("--interval", "-i", type=float, default=3.0, help="Intervalo em segundos entre pedidos")
    parser.add_argument("--batch", "-b", type=int, default=0, help="Inserir N pedidos de uma vez e sair")
    args = parser.parse_args()

    print("=" * 65)
    print("   🚀 SIMULADOR DE STREAMING DE VENDAS - POWER BI DIRECTQUERY    ")
    print("=" * 65)
    print("Banco: dw_sales | Host: localhost:5433 | Container: pbi-postgres-dw\n")

    if args.batch > 0:
        print(f"[INFO] Inserindo lote de {args.batch} pedidos...")
        raw_output = run_psql_command(f"SELECT * FROM dw.fn_generate_live_sale({args.batch});")
        for line in raw_output.splitlines():
            parts = line.split("|")
            if len(parts) >= 8:
                print(f"  ✨ [LOTE] {parts[0]} | {parts[1]} | {parts[2]} | Qtd: {parts[5]} | R$ {float(parts[6]):,.2f}")
        print(f"\n✅ Lote de {args.batch} pedidos inserido com sucesso!")
        return

    print(f"[INFO] Modo Streaming Contínuo ativo (Intervalo: {args.interval}s).")
    print("[DICA] No Power BI Desktop, ative 'Atualização Automática de Página' (ex: a cada 5s).")
    print("Pressione [Ctrl + C] para parar a simulação.\n")

    counter = 0
    try:
        while True:
            counter += 1
            raw = run_psql_command("SELECT * FROM dw.fn_generate_live_sale(1);")
            parts = raw.split("|")
            if len(parts) >= 8:
                ord_id, cust, prod, store, channel, qty, net_sales, margin = parts[:8]
                now_str = datetime.now().strftime("%H:%M:%S")
                print(f"[{now_str}] #{counter:04d} {ord_id} | {cust[:20]:20s} | {prod[:30]:30s} (x{qty}) | R$ {float(net_sales):>9,.2f} | Margem: R$ {float(margin):>8,.2f}")
            time.sleep(args.interval)
    except KeyboardInterrupt:
        print("\n[INFO] Simulação encerrada.")

if __name__ == "__main__":
    main()
