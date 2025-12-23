# Script simplifié pour capturer les résultats des tests

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  TESTS TP - Charge et Observabilité" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Attendre que les services soient prêts
Write-Host "[1/5] Attente démarrage des services (40s)..." -ForegroundColor Yellow
Start-Sleep -Seconds 40

Write-Host "  Vérification health endpoint..." -ForegroundColor Gray
$health = Invoke-RestMethod -Uri http://localhost:8081/actuator/health
Write-Host "  Status: $($health.status)" -ForegroundColor Green
Write-Host ""

# Test 1: Créer un livre avec stock 50
Write-Host "[2/5] Création livre de test (stock=50)..." -ForegroundColor Yellow
$book = @{
    title = "Test Book TP"
    author = "Test Author"
    stock = 50
} | ConvertTo-Json

$createdBook = Invoke-RestMethod -Uri http://localhost:8081/api/books -Method POST -Body $book -ContentType "application/json"
Write-Host "  Livre créé - ID: $($createdBook.id), Stock: $($createdBook.stock)" -ForegroundColor Green
$bookId = $createdBook.id
Write-Host ""

# Test 2: Load test avec 50 requêtes
Write-Host "[3/5] Lancement load test (50 requêtes)..." -ForegroundColor Yellow
Write-Host "==================== LOAD TEST ====================" -ForegroundColor Cyan
.\loadtest.ps1 -BookId $bookId -Requests 50
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

# Test 3: Vérifier stock final = 0
Write-Host "[4/5] Vérification stock final..." -ForegroundColor Yellow
$books = Invoke-RestMethod -Uri http://localhost:8081/api/books
$testBook = $books | Where-Object { $_.id -eq $bookId }
Write-Host "==================== STOCK FINAL ==================" -ForegroundColor Cyan
Write-Host "  ID      : $($testBook.id)" -ForegroundColor White
Write-Host "  Title   : $($testBook.title)" -ForegroundColor White
Write-Host "  Author  : $($testBook.author)" -ForegroundColor White
Write-Host "  Stock   : $($testBook.stock)" -ForegroundColor $(if ($testBook.stock -eq 0) { "Green" } else { "Red" })
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

# Test 4: Test fallback - arrêter pricing-service
Write-Host "[5/5] Test Fallback (arrêt pricing-service)..." -ForegroundColor Yellow
Write-Host "  Arrêt du pricing-service..." -ForegroundColor Gray
docker stop tp_27_test_charge_observabilit_concurrence-pricing-service-1 | Out-Null
Start-Sleep -Seconds 3

Write-Host "  Création d'un nouveau livre..." -ForegroundColor Gray
$book2 = @{
    title = "Fallback Test Book"
    author = "Test Author 2"
    stock = 10
} | ConvertTo-Json

$createdBook2 = Invoke-RestMethod -Uri http://localhost:8081/api/books -Method POST -Body $book2 -ContentType "application/json"
$bookId2 = $createdBook2.id

Write-Host "  Test emprunt avec pricing-service arrêté..." -ForegroundColor Gray
$result = Invoke-RestMethod -Uri "http://localhost:8081/api/books/$bookId2/borrow" -Method POST

Write-Host "================= RESULTAT FALLBACK ===============" -ForegroundColor Cyan
Write-Host "  ID        : $($result.id)" -ForegroundColor White
Write-Host "  Title     : $($result.title)" -ForegroundColor White
Write-Host "  Stock Left: $($result.stockLeft)" -ForegroundColor White
Write-Host "  Price     : $($result.price)" -ForegroundColor $(if ($result.price -eq 0) { "Green" } else { "Red" })
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

# Redémarrer pricing-service
Write-Host "  Redémarrage pricing-service..." -ForegroundColor Gray
docker start tp_27_test_charge_observabilit_concurrence-pricing-service-1 | Out-Null

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  ✓ TOUS LES TESTS TERMINÉS" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Métriques disponibles sur:" -ForegroundColor Yellow
Write-Host "  http://localhost:8081/actuator/metrics" -ForegroundColor Cyan
