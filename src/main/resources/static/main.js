"use strict";

/**
 * CONFIGURATION DU POC
 * Pointant vers le backend Spring Boot local
 */
const BACKEND_URL = "http://localhost:8080";
const ENDPOINT_WS = "/ycyw-chat-ws";
const TOPIC_SUB = "/topic/public";
const APP_SEND = "/app/chat.send";
const APP_REGISTER = "/app/chat.register";

// --- Éléments du DOM ---
const loginScreen = document.getElementById("login-screen");
const chatScreen = document.getElementById("chat-screen");
const loginForm = document.getElementById("loginForm");
const messageForm = document.getElementById("messageForm");
const messageInput = document.getElementById("message-input");
const messageArea = document.getElementById("message-area");
const usernameInput = document.getElementById("username-input");

// --- État de l'application ---
let stompClient = null;
let currentUser = null;

/**
 * 1. INITIALISATION DE LA SESSION
 */
function connect(event) {
  event.preventDefault();
  const username = usernameInput.value.trim();

  if (username) {
    currentUser = username;

    // Transition visuelle
    loginScreen.classList.remove("active");
    loginScreen.classList.add("hidden");
    chatScreen.classList.remove("hidden");
    setTimeout(() => chatScreen.classList.add("active"), 100);

    // Connexion Socket
    const socket = new SockJS(BACKEND_URL + ENDPOINT_WS);
    stompClient = Stomp.over(socket);

    // On désactive le debug console intempestif de Stomp pour faire pro
    stompClient.debug = null;

    stompClient.connect({}, onConnected, onError);
  }
}

/**
 * 2. CONNEXION RÉUSSIE
 */
function onConnected() {
  // Abonnement au canal public
  stompClient.subscribe(TOPIC_SUB, onMessageReceived);

  // Envoi du message JOIN au serveur
  stompClient.send(
    APP_REGISTER,
    {},
    JSON.stringify({
      sender: currentUser,
      type: "JOIN",
      messageContent: "Connection init", // Valeur dummy pour éviter null en DB
    })
  );
}

function onError(error) {
  const errorMsg = document.createElement("div");
  errorMsg.className = "system-message";
  errorMsg.innerHTML = `<span style="color: #ef4444">Erreur de connexion au serveur. Réessayez.</span>`;
  messageArea.appendChild(errorMsg);
}

/**
 * 3. ENVOI DE MESSAGE
 */
function sendMessage(event) {
  event.preventDefault();
  const messageContent = messageInput.value.trim();

  if (messageContent && stompClient) {
    const chatMessage = {
      sender: currentUser,
      messageContent: messageContent,
      type: "CHAT",
    };

    stompClient.send(APP_SEND, {}, JSON.stringify(chatMessage));
    messageInput.value = "";
  }
}

/**
 * 4. RÉCEPTION ET AFFICHAGE
 */
function onMessageReceived(payload) {
  const message = JSON.parse(payload.body);
  const messageElement = document.createElement("div");

  // Gestion des Types de Messages (JOIN/LEAVE/CHAT)
  if (message.type === "JOIN") {
    messageElement.className = "system-message";
    messageElement.innerHTML = `<span><i class="ph-bold ph-sign-in"></i> <b>${message.sender}</b> a rejoint le canal</span>`;
  } else if (message.type === "LEAVE") {
    messageElement.className = "system-message";
    messageElement.innerHTML = `<span><i class="ph-bold ph-sign-out"></i> <b>${message.sender}</b> est parti</span>`;
  } else {
    // C'est un vrai message de chat
    const isMyMessage = message.sender === currentUser;
    messageElement.className = `message ${
      isMyMessage ? "outgoing" : "incoming"
    }`;

    // Calcul de l'avatar (Initiale)
    const initial = message.sender.charAt(0).toUpperCase();

    // Template HTML du message
    messageElement.innerHTML = `
            <div class="message-content">
                ${message.messageContent}
            </div>
            <div class="message-meta">
                <span>${message.sender}</span>
                <span>• ${new Date().toLocaleTimeString([], {
                  hour: "2-digit",
                  minute: "2-digit",
                })}</span>
            </div>
        `;

    // Petit son si ce n'est pas moi qui écris
    if (!isMyMessage) {
      // playSound(); // Fonction optionnelle
    }
  }

  messageArea.appendChild(messageElement);
  messageArea.scrollTop = messageArea.scrollHeight; // Auto-scroll
}

/**
 * UX: Helper pour les "Quick Chips" (Réponses rapides)
 */
window.fillInput = function (text) {
  messageInput.value = text;
  messageInput.focus();
};

// Écouteurs d'événements
loginForm.addEventListener("submit", connect, true);
messageForm.addEventListener("submit", sendMessage, true);

// Bouton logout
document.getElementById("logout-btn").addEventListener("click", () => {
  window.location.reload();
});
