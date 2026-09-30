<#
.SYNOPSIS
    Simulador de Vendas em Tempo Real para Power BI DirectQuery.
.DESCRIPTION
    Insere novos pedidos com o timestamp atual na tabela dw.fact_sales do PostgreSQL.
    Permite visualizar a atualização instantânea do Power BI em DirectQuery com Atualização Automática de Página (APR).
.EXAMPLE
    .\scripts\simulate_live_sales.ps1 -IntervalSeconds 3
    .\scripts\simulate_live_sales.ps1 -Batch 20
#>

param(
    [int]$IntervalSeconds = 3,
    [int]$Batch = 0
)

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "   🚀 SIMULADOR DE STREAMING DE VENDAS - POWER BI DIRECTQUERY    " -ForegroundColor Yellow
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "Banco: dw_sales | Host: localhost:5433 | Container: pbi-postgres-dw" -ForegroundColor Gray

if ($Batch -gt 0) {
    Write-Host "[INFO] Inserindo lote de $Batch pedidos no banco..." -ForegroundColor Green
    $cmd = "docker exec pbi-postgres-dw psql -U postgres -d dw_sales -t -A -F '|' -c `"SELECT * FROM dw.fn_generate_live_sale($Batch);`""
    $results = Invoke-Expression $cmd
    foreach ($line in $results) {
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            $parts = $line.Split('|')
            if ($parts.Length -ge 8) {
                Write-Host "  ✨ [LOTE] $($parts[0]) | $($parts[1]) | $($parts[2]) | Qtd: $($parts[5]) | R$ $($parts[6])" -ForegroundColor Green
            }
        }
    }
    Write-Host "✅ Lote de $Batch pedidos inserido com sucesso!" -ForegroundColor Cyan
    exit 0
}

Write-Host "[INFO] Modo Streaming Contínuo ativo (Intervalo: ${IntervalSeconds}s)." -ForegroundColor Green
Write-Host "[DICA] Abra seu Dashboard no Power BI Desktop e veja os números atualizarem!" -ForegroundColor Yellow
Write-Host "Pressione [Ctrl + C] para interromper a simulação a qualquer momento.`n" -ForegroundColor DarkGray

$counter = 0
try {
    while ($true) {
        $counter++
        $cmd = "docker exec pbi-postgres-dw psql -U postgres -d dw_sales -t -A -F '|' -c `"SELECT * FROM dw.fn_generate_live_sale(1);`""
        $output = Invoke-Expression $cmd
        
        if (-not [string]::IsNullOrWhiteSpace($output)) {
            $parts = $output.Trim().Split('|')
            if ($parts.Length -ge 8) {
                $ordId   = $parts[0]
                $cust    = $parts[1]
                $prod    = $parts[2]
                $store   = $parts[3]
                $channel = $parts[4]
                $qty     = $parts[5]
                $netVal  = [decimal]$parts[6]
                $margin  = [decimal]$parts[7]
                $time    = (Get-Date).ToString("HH:mm:ss")
                
                Write-Host "[$time] #$counter " -NoNewline -ForegroundColor DarkGray
                Write-Host "$ordId " -NoNewline -ForegroundColor Cyan
                Write-Host "| $cust " -NoNewline -ForegroundColor White
                Write-Host "| $prod (x$qty) " -NoNewline -ForegroundColor Yellow
                Write-Host "| R$ $('{0:N2}' -f $netVal) " -NoNewline -ForegroundColor Green
                Write-Host "(Margem: R$ $('{0:N2}' -f $margin))" -ForegroundColor Magenta
            }
        }
        Start-Sleep -Seconds $IntervalSeconds
    }
}
catch {
    Write-Host "`n[INFO] Simulação encerrada pelo usuário." -ForegroundColor Yellow
}
