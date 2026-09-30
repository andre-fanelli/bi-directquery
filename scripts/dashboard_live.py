#!/usr/bin/env python3
"""
Dashboard Web em Tempo Real - Power BI DirectQuery Monitor
Permite visualizar em tempo real a chegada de novos pedidos no PostgreSQL via DirectQuery SQL.
"""
import sys
import json
import subprocess
from http.server import HTTPServer, BaseHTTPRequestHandler
import urllib.parse

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

PORT = 8080

def query_postgres_json():
    sql = """
    SELECT json_build_object(
        'kpis', (
            SELECT json_build_object(
                'total_sales', ROUND(SUM(net_sales_amount), 2),
                'total_orders', COUNT(DISTINCT order_id),
                'margin_pct', ROUND((SUM(margin_amount) / NULLIF(SUM(net_sales_amount), 0)) * 100, 2),
                'today_sales', ROUND(COALESCE(SUM(CASE WHEN order_date_key = (to_char(CURRENT_DATE, 'YYYYMMDD'))::int THEN net_sales_amount ELSE 0 END), 0), 2),
                'today_orders', COUNT(DISTINCT CASE WHEN order_date_key = (to_char(CURRENT_DATE, 'YYYYMMDD'))::int THEN order_id ELSE NULL END)
            ) FROM dw.fact_sales WHERE order_status <> 'Cancelado'
        ),
        'categories', (
            SELECT json_agg(c) FROM (
                SELECT p.category, ROUND(SUM(f.net_sales_amount), 2) AS sales
                FROM dw.fact_sales f
                JOIN dw.dim_product p ON p.product_key = f.product_key
                WHERE f.order_status <> 'Cancelado'
                GROUP BY p.category
                ORDER BY sales DESC
            ) c
        ),
        'regions', (
            SELECT json_agg(r) FROM (
                SELECT s.region, ROUND(SUM(f.net_sales_amount), 2) AS sales
                FROM dw.fact_sales f
                JOIN dw.dim_store s ON s.store_key = f.store_key
                WHERE f.order_status <> 'Cancelado'
                GROUP BY s.region
                ORDER BY sales DESC
            ) r
        ),
        'recent_sales', (
            SELECT json_agg(s) FROM (
                SELECT order_id, order_time, customer_name, product_name, store_name, channel_name, quantity, net_sales_amount, margin_amount
                FROM dw.vw_live_recent_sales
                LIMIT 12
            ) s
        )
    );
    """
    cmd = [
        "docker", "exec", "pbi-postgres-dw",
        "psql", "-U", "postgres", "-d", "dw_sales",
        "-t", "-A", "-c", sql
    ]
    res = subprocess.run(cmd, capture_output=True, encoding="utf-8", errors="replace", check=True)
    return res.stdout.strip()

def generate_live_sale():
    cmd = [
        "docker", "exec", "pbi-postgres-dw",
        "psql", "-U", "postgres", "-d", "dw_sales",
        "-t", "-A", "-c", "SELECT * FROM dw.fn_generate_live_sale(1);"
    ]
    res = subprocess.run(cmd, capture_output=True, encoding="utf-8", errors="replace", check=True)
    return res.stdout.strip()

HTML_CONTENT = """<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Monitor DirectQuery em Tempo Real - Power BI DW</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        @keyframes pulse-fast { 0%, 100% { opacity: 1; transform: scale(1); } 50% { opacity: .7; transform: scale(1.05); } }
        .live-dot { animation: pulse-fast 1.5s infinite; }
        .row-new { animation: highlight 2s ease-out; }
        @keyframes highlight { from { background-color: rgba(16, 185, 129, 0.3); } to { background-color: transparent; } }
    </style>
</head>
<body class="bg-slate-950 text-slate-100 min-h-screen font-sans antialiased">
    <!-- Navbar -->
    <header class="bg-slate-900 border-b border-slate-800 sticky top-0 z-50">
        <div class="max-w-7xl mx-auto px-4 py-3 flex flex-wrap items-center justify-between gap-4">
            <div class="flex items-center gap-3">
                <div class="w-3.5 h-3.5 bg-emerald-500 rounded-full live-dot"></div>
                <div>
                    <h1 class="text-lg font-bold tracking-tight text-white flex items-center gap-2">
                        DirectQuery Live Monitor
                        <span class="text-xs font-semibold px-2 py-0.5 rounded bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">PostgreSQL DW</span>
                    </h1>
                    <p class="text-xs text-slate-400">Host: localhost:5433 | Database: dw_sales | Auto-Refresh: 3s</p>
                </div>
            </div>
            <div class="flex items-center gap-3">
                <button onclick="triggerSale()" class="bg-amber-600 hover:bg-amber-500 text-white font-medium text-xs px-3.5 py-2 rounded-lg transition-all flex items-center gap-1.5 shadow-md shadow-amber-900/20 active:scale-95">
                    <span>➕</span> Injetar Pedido Simulado
                </button>
                <button onclick="fetchData()" class="bg-indigo-600 hover:bg-indigo-500 text-white font-medium text-xs px-3.5 py-2 rounded-lg transition-all flex items-center gap-1.5 shadow-md shadow-indigo-900/20 active:scale-95">
                    <span>⚡</span> Atualizar Agora
                </button>
                <div class="flex items-center gap-2 bg-slate-800/80 px-3 py-1.5 rounded-lg border border-slate-700/50 text-xs">
                    <span class="text-slate-400">Auto-Refresh:</span>
                    <span id="refreshTimer" class="font-mono text-emerald-400 font-bold">3s</span>
                </div>
            </div>
        </div>
    </header>

    <main class="max-w-7xl mx-auto px-4 py-6 space-y-6">
        <!-- Live KPI Cards -->
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            <div class="bg-slate-900/90 border border-emerald-500/30 rounded-xl p-5 relative overflow-hidden shadow-lg">
                <div class="absolute -right-4 -bottom-4 w-24 h-24 bg-emerald-500/10 rounded-full blur-xl"></div>
                <div class="text-xs font-semibold uppercase tracking-wider text-emerald-400">Vendas Hoje (Tempo Real)</div>
                <div id="kpiTodaySales" class="text-3xl font-extrabold text-white mt-2 font-mono">R$ 0,00</div>
                <div class="text-xs text-slate-400 mt-1 flex items-center gap-1">
                    <span class="text-emerald-400 font-bold">●</span> Atualizado via DirectQuery
                </div>
            </div>

            <div class="bg-slate-900/90 border border-indigo-500/30 rounded-xl p-5 relative overflow-hidden shadow-lg">
                <div class="absolute -right-4 -bottom-4 w-24 h-24 bg-indigo-500/10 rounded-full blur-xl"></div>
                <div class="text-xs font-semibold uppercase tracking-wider text-indigo-400">Pedidos Hoje</div>
                <div id="kpiTodayOrders" class="text-3xl font-extrabold text-white mt-2 font-mono">0</div>
                <div class="text-xs text-slate-400 mt-1">Transações registradas hoje</div>
            </div>

            <div class="bg-slate-900/90 border border-cyan-500/30 rounded-xl p-5 relative overflow-hidden shadow-lg">
                <div class="absolute -right-4 -bottom-4 w-24 h-24 bg-cyan-500/10 rounded-full blur-xl"></div>
                <div class="text-xs font-semibold uppercase tracking-wider text-cyan-400">Margem Média %</div>
                <div id="kpiMarginPct" class="text-3xl font-extrabold text-white mt-2 font-mono">0,0%</div>
                <div class="text-xs text-slate-400 mt-1">Rentabilidade operacional</div>
            </div>

            <div class="bg-slate-900/90 border border-purple-500/30 rounded-xl p-5 relative overflow-hidden shadow-lg">
                <div class="absolute -right-4 -bottom-4 w-24 h-24 bg-purple-500/10 rounded-full blur-xl"></div>
                <div class="text-xs font-semibold uppercase tracking-wider text-purple-400">Total Acumulado Fato</div>
                <div id="kpiTotalSales" class="text-2xl font-bold text-white mt-2 font-mono">R$ 0,00</div>
                <div id="kpiTotalOrders" class="text-xs text-slate-400 mt-1">0 pedidos históricos</div>
            </div>
        </div>

        <!-- Charts Grid -->
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <div class="bg-slate-900/80 border border-slate-800 rounded-xl p-5 lg:col-span-2 shadow-lg">
                <h3 class="text-sm font-semibold text-slate-200 mb-4 flex items-center justify-between">
                    <span>Faturamento por Categoria (DirectQuery)</span>
                    <span class="text-xs text-slate-500 font-normal">Soma de dw.fact_sales</span>
                </h3>
                <div class="h-64">
                    <canvas id="categoryChart"></canvas>
                </div>
            </div>

            <div class="bg-slate-900/80 border border-slate-800 rounded-xl p-5 shadow-lg">
                <h3 class="text-sm font-semibold text-slate-200 mb-4 flex items-center justify-between">
                    <span>Distribuição Regional</span>
                    <span class="text-xs text-slate-500 font-normal">Lojas Físicas / Brasil</span>
                </h3>
                <div class="h-64 flex items-center justify-center">
                    <canvas id="regionChart"></canvas>
                </div>
            </div>
        </div>

        <!-- Live Sales Stream Table -->
        <div class="bg-slate-900/80 border border-slate-800 rounded-xl p-5 shadow-lg">
            <div class="flex items-center justify-between mb-4">
                <div>
                    <h3 class="text-sm font-semibold text-white flex items-center gap-2">
                        <span class="w-2.5 h-2.5 rounded-full bg-emerald-500 animate-ping"></span>
                        Últimos Pedidos Registrados no Banco (Feed em Tempo Real)
                    </h3>
                    <p class="text-xs text-slate-400 mt-0.5">Visão direta de dw.vw_live_recent_sales</p>
                </div>
                <div id="lastSyncTime" class="text-xs text-slate-400 font-mono">Aguardando dados...</div>
            </div>

            <div class="overflow-x-auto">
                <table class="w-full text-left text-xs">
                    <thead>
                        <tr class="border-b border-slate-800 text-slate-400 uppercase tracking-wider font-semibold">
                            <th class="py-2.5 px-3">Horário</th>
                            <th class="py-2.5 px-3">Pedido ID</th>
                            <th class="py-2.5 px-3">Cliente</th>
                            <th class="py-2.5 px-3">Produto</th>
                            <th class="py-2.5 px-3">Loja / Canal</th>
                            <th class="py-2.5 px-3 text-center">Qtd</th>
                            <th class="py-2.5 px-3 text-right">Valor Líquido</th>
                            <th class="py-2.5 px-3 text-right">Lucro</th>
                        </tr>
                    </thead>
                    <tbody id="salesTableBody" class="divide-y divide-slate-800/60 font-mono">
                        <tr><td colspan="8" class="text-center py-6 text-slate-500">Carregando dados do PostgreSQL...</td></tr>
                    </tbody>
                </table>
            </div>
        </div>
    </main>

    <script>
        let catChartInstance = null;
        let regChartInstance = null;
        let countdown = 3;

        function formatBRL(val) {
            return new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(val);
        }

        async function fetchData() {
            try {
                const res = await fetch('/api/data');
                const data = await res.json();
                
                // KPIs
                document.getElementById('kpiTodaySales').innerText = formatBRL(data.kpis.today_sales || 0);
                document.getElementById('kpiTodayOrders').innerText = (data.kpis.today_orders || 0).toLocaleString('pt-BR');
                document.getElementById('kpiMarginPct').innerText = (data.kpis.margin_pct || 0) + '%';
                document.getElementById('kpiTotalSales').innerText = formatBRL(data.kpis.total_sales || 0);
                document.getElementById('kpiTotalOrders').innerText = (data.kpis.total_orders || 0).toLocaleString('pt-BR') + ' pedidos acumulados';

                // Table
                const tbody = document.getElementById('salesTableBody');
                if (data.recent_sales && data.recent_sales.length > 0) {
                    tbody.innerHTML = data.recent_sales.map((s, idx) => `
                        <tr class="hover:bg-slate-800/40 transition-colors ${idx === 0 ? 'row-new font-medium text-emerald-300' : 'text-slate-300'}">
                            <td class="py-2.5 px-3 text-slate-400">${s.order_time}</td>
                            <td class="py-2.5 px-3 text-cyan-400 font-semibold">${s.order_id}</td>
                            <td class="py-2.5 px-3 font-sans text-slate-200">${s.customer_name}</td>
                            <td class="py-2.5 px-3 font-sans text-amber-300/90">${s.product_name}</td>
                            <td class="py-2.5 px-3 font-sans text-slate-400 text-xs">${s.store_name} <span class="text-slate-600">(${s.channel_name})</span></td>
                            <td class="py-2.5 px-3 text-center text-slate-300">${s.quantity}</td>
                            <td class="py-2.5 px-3 text-right text-emerald-400 font-bold">${formatBRL(s.net_sales_amount)}</td>
                            <td class="py-2.5 px-3 text-right text-indigo-400">${formatBRL(s.margin_amount)}</td>
                        </tr>
                    `).join('');
                }

                // Charts
                renderCategoryChart(data.categories || []);
                renderRegionChart(data.regions || []);

                const now = new Date();
                document.getElementById('lastSyncTime').innerText = 'Última consulta: ' + now.toLocaleTimeString('pt-BR');
                countdown = 3;
            } catch (err) {
                console.error("Erro ao carregar dados:", err);
            }
        }

        async function triggerSale() {
            try {
                await fetch('/api/generate');
                fetchData();
            } catch (e) {
                console.error(e);
            }
        }

        function renderCategoryChart(categories) {
            const labels = categories.map(c => c.category);
            const values = categories.map(c => c.sales);

            if (catChartInstance) {
                catChartInstance.data.labels = labels;
                catChartInstance.data.datasets[0].data = values;
                catChartInstance.update();
                return;
            }

            const ctx = document.getElementById('categoryChart').getContext('2d');
            catChartInstance = new Chart(ctx, {
                type: 'bar',
                data: {
                    labels: labels,
                    datasets: [{
                        label: 'Faturamento (R$)',
                        data: values,
                        backgroundColor: '#6366f1',
                        borderRadius: 6
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: { legend: { display: false } },
                    scales: {
                        x: { grid: { color: 'rgba(255,255,255,0.05)' }, ticks: { color: '#94a3b8', font: { size: 10 } } },
                        y: { grid: { color: 'rgba(255,255,255,0.05)' }, ticks: { color: '#94a3b8', callback: v => 'R$ ' + (v/1000000).toFixed(0) + 'M' } }
                    }
                }
            });
        }

        function renderRegionChart(regions) {
            const labels = regions.map(r => r.region);
            const values = regions.map(r => r.sales);

            if (regChartInstance) {
                regChartInstance.data.labels = labels;
                regChartInstance.data.datasets[0].data = values;
                regChartInstance.update();
                return;
            }

            const ctx = document.getElementById('regionChart').getContext('2d');
            regChartInstance = new Chart(ctx, {
                type: 'doughnut',
                data: {
                    labels: labels,
                    datasets: [{
                        data: values,
                        backgroundColor: ['#3b82f6', '#10b981', '#f59e0b', '#ec4899', '#8b5cf6'],
                        borderWidth: 0
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: { position: 'bottom', labels: { color: '#cbd5e1', font: { size: 10 }, boxWidth: 12 } }
                    }
                }
            });
        }

        // Auto Refresh Interval
        setInterval(() => {
            countdown--;
            document.getElementById('refreshTimer').innerText = countdown + 's';
            if (countdown <= 0) {
                fetchData();
            }
        }, 1000);

        fetchData();
    </script>
</body>
</html>
"""

class DirectQueryHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/" or parsed.path == "/index.html":
            self.send_response(200)
            self.send_header("Content-type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(HTML_CONTENT.encode("utf-8"))
        elif parsed.path == "/api/data":
            try:
                data_json = query_postgres_json()
                self.send_response(200)
                self.send_header("Content-type", "application/json; charset=utf-8")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                self.wfile.write(data_json.encode("utf-8"))
            except Exception as e:
                self.send_response(500)
                self.end_headers()
                self.wfile.write(json.dumps({"error": str(e)}).encode("utf-8"))
        elif parsed.path == "/api/generate":
            try:
                res = generate_live_sale()
                self.send_response(200)
                self.send_header("Content-type", "application/json; charset=utf-8")
                self.end_headers()
                self.wfile.write(json.dumps({"status": "ok", "sale": res}).encode("utf-8"))
            except Exception as e:
                self.send_response(500)
                self.end_headers()
                self.wfile.write(json.dumps({"error": str(e)}).encode("utf-8"))
        else:
            self.send_response(404)
            self.end_headers()

def main():
    print("=" * 65)
    print("   🌐 INICIANDO DASHBOARD LIVE DIRECTQUERY - POWER BI DW        ")
    print("=" * 65)
    print(f"Acesse no navegador: http://localhost:{PORT}")
    print("Pressione [Ctrl + C] para encerrar o servidor.\n")
    server = HTTPServer(("0.0.0.0", PORT), DirectQueryHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[INFO] Servidor web encerrado.")

if __name__ == "__main__":
    main()
