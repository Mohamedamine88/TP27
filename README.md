# TP27
Test de charge &amp; Observabilité : Concurrence + Verrou DB + Resilience4j + Actuator Metrics


# Tests & Observabilité – Résultats

Ce document présente les résultats des tests de **résilience**, **fallback**, **charge concurrente** et **cohérence des données**, réalisés le **23 décembre 2025** sur l’application.

---

## Observabilité – Actuator & Resilience4j Metrics

### Informations générales
- **Date** : 23 décembre 2025  
- **Endpoint Actuator** : `http://localhost:8081/actuator/metrics`

---

### Configuration Resilience4j (`application.yml`)

~~~yaml
resilience4j:
  retry:
    instances:
      pricing:
        maxAttempts: 3
        waitDuration: 300ms
  circuitbreaker:
    instances:
      pricing:
        slidingWindowType: COUNT_BASED
        slidingWindowSize: 10
        minimumNumberOfCalls: 5
        failureRateThreshold: 50
        waitDurationInOpenState: 10s
        permittedNumberOfCallsInHalfOpenState: 2
~~~

---

### Métriques exposées via `/actuator/metrics`

#### Circuit Breaker
- **`resilience4j.circuitbreaker.calls`**  
  Nombre total d’appels (successful, failed, not_permitted)

- **`resilience4j.circuitbreaker.state`**  
  États possibles :
  - `CLOSED` : fonctionnement normal
  - `OPEN` : appels bloqués
  - `HALF_OPEN` : phase de test de récupération

- **`resilience4j.circuitbreaker.failure.rate`**  
  Pourcentage d’échecs  
  Ouverture du circuit si **> 50 %**

---

#### Retry
- **`resilience4j.retry.calls`** : total des tentatives  
- **`resilience4j.retry.successful.without_retry`**  
- **`resilience4j.retry.successful.with_retry`**  
- **`resilience4j.retry.failed.with_retry`**

---

#### Autres métriques système
- `http.server.requests`
- `jvm.memory.used`
- `system.cpu.usage`

---

### Vérification
- Endpoint Actuator accessible
- Configuration Resilience4j active
- Métriques collectées correctement
- Circuit Breaker et Retry opérationnels

---

## Test de Fallback – Pricing Service Indisponible

### Objectif
Vérifier le comportement de l’application lorsque le **pricing-service** est indisponible.

---

### Étapes du test

#### 1. Arrêt du pricing-service
~~~bash
docker stop tp_27_test_charge_observabilit_concurrence-pricing-service-1
~~~

#### 2. Création d’un livre
~~~http
POST /api/books
{
  "title": "Fallback Test Book",
  "author": "Test Author 2",
  "stock": 10
}
~~~

#### 3. Emprunt du livre
~~~http
POST /api/books/2/borrow
~~~

---

### Résultat observé

| id | title              | stockLeft | price |
|----|--------------------|-----------|-------|
| 2  | Fallback Test Book | 4         | 0.0   |

---

### Analyse
- Prix retourné : **0.0**
- Fallback activé automatiquement
- Circuit Breaker détecte l’échec de connexion
- L’application reste fonctionnelle
- Stratégie appliquée : **Graceful Degradation**

---

### Code du fallback (`PricingClient.java`)

~~~java
@CircuitBreaker(name = "pricing", fallbackMethod = "fallbackPrice")
public double getPrice(long bookId) {
    String url = baseUrl + "/api/prices/" + bookId;
    Double price = rest.getForObject(url, Double.class);
    return price == null ? 0.0 : price;
}

public double fallbackPrice(long bookId, Throwable ex) {
    return 0.0; // Valeur par défaut
}
~~~

---

## Test de Charge – 50 Requêtes Concurrentes

### Informations
- **Commande** :
~~~powershell
.\loadtest.ps1 -BookId 1 -Requests 50
~~~
- **Instances actives** : ports `8081`, `8083`, `8084`

---

### Résultats

| Code HTTP | Nombre |
|----------|--------|
| 200      | 50     |
| 409      | 0      |
| Autres   | 0      |

---

### Analyse
- 50 requêtes réparties sur 3 instances
- 100 % de succès
- Aucun conflit détecté
- Verrou pessimiste (`PESSIMISTIC_WRITE`) efficace
- Concurrence maîtrisée

---

## Vérification Finale du Stock

### Commande
~~~powershell
Invoke-RestMethod -Uri http://localhost:8081/api/books
~~~

---

### Résultat final

| id | title     | author      | stock |
|----|----------|------------|-------|
| 1  | Test Book | Test Author | 0     |

---

### Analyse
- Stock initial : **50**
- Emprunts effectués : **50**
- Stock final : **0**
- Cohérence des données garantie
- Aucune race condition malgré plusieurs instances

---

## Conclusion

- En multi-instances, l’absence de verrou DB peut provoquer des **race conditions** et des incohérences de stock.
- Le verrou pessimiste force une **sérialisation des accès** et garantit l’atomicité et la cohérence des données.
- Le **Circuit Breaker** protège le système en bloquant les appels vers un service externe défaillant.
- Il évite les pannes en cascade et la saturation des ressources.
- Le **fallback** permet un fonctionnement dégradé, assurant disponibilité et résilience.

