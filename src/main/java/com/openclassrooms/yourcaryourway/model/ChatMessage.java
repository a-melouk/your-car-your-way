package com.openclassrooms.yourcaryourway.model;

import jakarta.persistence.*;
import lombok.*;

@Data
@AllArgsConstructor
@NoArgsConstructor
@Builder
@Entity
@Table(name = "chat_messages")
public class ChatMessage {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String messageContent;

    @Column(nullable = false)
    private String sender;

    @Enumerated(EnumType.STRING)
    private MessageType type;
}