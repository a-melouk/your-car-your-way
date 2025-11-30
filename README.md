# 🚗 YourCarYourWay - Chat Support (PoC)

## 📋 Description

Ce projet est une Preuve de Concept (PoC) pour le module de support client en temps réel de la plateforme de location YourCarYourWay. Il démontre la capacité technique à établir une communication bidirectionnelle instantanée entre un client et le service support via une architecture WebSocket robuste.

L'interface utilisateur a été conçue avec une approche "Cyber-Automotive", offrant une expérience moderne, sombre et immersive, tandis que le backend assure la persistance et la diffusion des messages.

## Architecture Technique

Le projet est une application monolithique Spring Boot servant à la fois l'API et le contenu statique :

```
your-car-your-way/
├── src/main/java       # Logique métier (Controller, Model, Config)
└── src/main/resources
    └── static/         # Interface Utilisateur (HTML, CSS, JS)
```

## Stack Technologique

### Backend :

- **Langage :** Java 21
- **Framework :** Spring Boot 3.4.5
- **Protocole :** WebSocket (surcouche STOMP & SockJS)
- **Base de données :** H2 (In-Memory) avec Spring Data JPA
- **Outils :** Maven, Lombok

### Frontend :

- **Technologies :** HTML5, CSS3 (Variables, Flexbox, Animations), Vanilla JS
- **Design :** Phosphor Icons, Google Fonts (Inter)
- **Communication :** SockJS Client, Stomp.js

## Guide de Démarrage

### Prérequis

- JDK 21 installé
- Un navigateur web moderne (Chrome, Firefox, Edge)

### Démarrage de l'application

L'application (Backend + Frontend) se lance via une unique commande Maven.

```bash
# Sur Windows
./mvnw.cmd spring-boot:run

# Sur Mac/Linux
./mvnw spring-boot:run
```

Une fois le serveur démarré, accédez à l'application via : `http://localhost:8080`

## 🔌 Documentation API & WebSocket

### Endpoints de Connexion

| Type       | URL / Endpoint          | Description                                         |
| ---------- | ----------------------- | --------------------------------------------------- |
| HTTP       | `http://localhost:8080` | URL Base du serveur                                 |
| WebSocket  | `/ycyw-chat-ws`         | Point d'entrée SockJS                               |
| H2 Console | `/h2-console`           | Accès Base de données (User: `sa`, Pwd: `password`) |

### Canaux STOMP (Pub/Sub)

| Action          | Destination          | Payload JSON Attendu                                               |
| --------------- | -------------------- | ------------------------------------------------------------------ |
| S'abonner       | `/topic/public`      | (Reçoit tous les messages)                                         |
| Envoyer Message | `/app/chat.send`     | `{ "sender": "Nom", "messageContent": "Message", "type": "CHAT" }` |
| S'inscrire      | `/app/chat.register` | `{ "sender": "Nom", "type": "JOIN" }`                              |

## Base de Données (H2)

Pour vérifier les messages enregistrés durant la session :

1. Allez sur : http://localhost:8080/h2-console
2. **Driver Class :** `org.h2.Driver`
3. **JDBC URL :** `jdbc:h2:mem:testdb`
4. **User :** `sa` / **Password :** `password`

Exécutez la requête SQL :

```sql
SELECT * FROM CHAT_MESSAGES
```

## Fonctionnalités Clés

- **Connexion Temps Réel :** Latence minimale grâce aux WebSockets
- **Persistance Sélective :** Seuls les messages textuels sont sauvegardés en BDD (pas les statuts de connexion)
- **Interface Moderne :** Thème sombre, indicateurs de statut "Pulse", design responsive
- **Réponses Rapides :** Système de "Chips" pour envoyer des messages pré-définis
- **Gestion des Erreurs :** Feedback visuel en cas de perte de connexion serveur
