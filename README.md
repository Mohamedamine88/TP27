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

```yaml
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
