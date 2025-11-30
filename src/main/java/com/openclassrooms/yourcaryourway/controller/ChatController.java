package com.openclassrooms.yourcaryourway.controller;

import com.openclassrooms.yourcaryourway.model.ChatMessage;
import com.openclassrooms.yourcaryourway.repository.ChatMessageRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.messaging.handler.annotation.SendTo;
import org.springframework.messaging.simp.SimpMessageHeaderAccessor;
import org.springframework.stereotype.Controller;

import java.util.Objects;

@Controller
@RequiredArgsConstructor
@Slf4j
public class ChatController {

    private final ChatMessageRepository repository;

    @MessageMapping("/chat.send")
    @SendTo("/topic/public")
    public ChatMessage processMessage(@Payload ChatMessage chatMessage) {
        // Sauvegarde en base de données pour historique (optionnel selon specs POC)
        repository.save(chatMessage);
        return chatMessage;
    }

    @MessageMapping("/chat.register")
    @SendTo("/topic/public")
    public ChatMessage registerUser(@Payload ChatMessage chatMessage,
                                    SimpMessageHeaderAccessor headerAccessor) {
        // Association du nom d'utilisateur à la session WebSocket
        Objects.requireNonNull(headerAccessor.getSessionAttributes()).put("username", chatMessage.getSender());

        log.info("Nouvel utilisateur enregistré : {}", chatMessage.getSender());
        return chatMessage;
    }
}