import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:whatsapp_clone/common/enums/message_enum.dart';
import 'package:whatsapp_clone/common/provider/message_reply_provider.dart';
import 'package:whatsapp_clone/common/repositories/common_firebase_storage_repository.dart';
import 'package:whatsapp_clone/common/utils/utils.dart';
import 'package:whatsapp_clone/models/chat_contact.dart';
import 'package:whatsapp_clone/models/group.dart';
import 'package:whatsapp_clone/models/message.dart';
import 'package:whatsapp_clone/models/user_model.dart';

final chatRepositoryProvider = Provider((ref) => ChatRepository(
      firestore: FirebaseFirestore.instance,
      auth: FirebaseAuth.instance,
    ));

class ChatRepository {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  ChatRepository({
    required this.firestore,
    required this.auth,
  });

  // Get all chat contact
  Stream<List<ChatContact>> getChatContacts() {
    return firestore
        .collection('users')
        .doc(auth.currentUser!.uid)
        .collection('chats')
        .snapshots()
        .asyncMap((event) async {
      List<ChatContact> contacts = [];
      for (var document in event.docs) {
        var chatContact = ChatContact.fromMap(document.data());
        var userData = await firestore
            .collection('users')
            .doc(chatContact.contactId)
            .get();
        var user = UserModel.fromMap(userData.data()!);

        contacts.add(
          ChatContact(
            name: user.name,
            profilePic: user.profilePic,
            contactId: chatContact.contactId,
            timeSent: chatContact.timeSent,
            lastMessage: chatContact.lastMessage,
          ),
        );
      }
      return contacts;
    });
  }

  // Get all chat group
  Stream<List<Group>> getChatGroups() {
    return firestore.collection('groups').snapshots().map((event) {
      List<Group> groups = [];
      for (var document in event.docs) {
        var group = Group.fromMap(document.data());
        if (group.membersUid.contains(auth.currentUser!.uid)) {
          groups.add(group);
        }
      }
      return groups;
    });
  }

  // Get all message between sender and reciever
  Stream<List<Message>> getChatStream(String recieverUserId) {
    return firestore
        .collection('users')
        .doc(auth.currentUser!.uid)
        .collection('chats')
        .doc(recieverUserId)
        .collection('messages')
        .orderBy('timeSent')
        .snapshots()
        .map((event) {
      List<Message> messages = [];
      for (var document in event.docs) {
        messages.add(Message.fromMap(document.data()));
      }
      return messages;
    });
  }

  // Get all message chat in group
  Stream<List<Message>> getGroupChatStream(String groupId) {
    return firestore
        .collection('groups')
        .doc(groupId)
        .collection('chats')
        .orderBy('timeSent')
        .snapshots()
        .map((event) {
      List<Message> messages = [];
      for (var document in event.docs) {
        messages.add(Message.fromMap(document.data()));
      }
      return messages;
    });
  }

  // Save lasest message for sender and reciever
  void _saveDataToContactsSubcollection(
    UserModel senderUserData,
    UserModel? recieverUserData,
    String text,
    DateTime timeSent,
    String recieverUserId,
    bool isGroupChat,
  ) async {
    if (isGroupChat) {
      await firestore.collection('groups').doc(recieverUserId).update({
        'lastMessage': text,
        'timeSent': DateTime.now().microsecondsSinceEpoch,
      });
    } else {
      var recieverChatContact = ChatContact(
        name: senderUserData.name,
        profilePic: senderUserData.profilePic,
        contactId: senderUserData.uid,
        timeSent: timeSent,
        lastMessage: text,
      );

      await firestore
          .collection('users')
          .doc(recieverUserId)
          .collection('chats')
          .doc(auth.currentUser!.uid)
          .set(recieverChatContact.toMap());

      var senderChatContact = ChatContact(
        name: recieverUserData!.name,
        profilePic: recieverUserData.profilePic,
        contactId: recieverUserData.uid,
        timeSent: timeSent,
        lastMessage: text,
      );

      await firestore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .collection('chats')
          .doc(recieverUserId)
          .set(senderChatContact.toMap());
    }
  }

  // Save message to list message of sender and reciever
  void _saveMessageToMessageSubcollection({
    required String recieverUserId,
    required String text,
    required DateTime timeSent,
    required String messageId,
    required String senderUsername,
    required String? recieverUsername,
    required MessageEnum messageType,
    required MessageReply? messageReply,
    required bool isGroupChat,
  }) async {
    final message = Message(
      senderId: auth.currentUser!.uid,
      recieverId: recieverUserId,
      text: text,
      type: messageType,
      timeSent: timeSent,
      messageId: messageId,
      isSeen: false,
      repliedMessage: messageReply == null ? '' : messageReply.message,
      repliedTo: messageReply == null
          ? ''
          : messageReply.isMe
              ? senderUsername
              : recieverUsername ?? '',
      repliedMessageType:
          messageReply == null ? MessageEnum.text : messageReply.messageEnum,
    );

    if (isGroupChat) {
      await firestore
          .collection('groups')
          .doc(recieverUserId)
          .collection('chats')
          .doc(messageId)
          .set(message.toMap());
    } else {
      await firestore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .collection('chats')
          .doc(recieverUserId)
          .collection('messages')
          .doc(messageId)
          .set(message.toMap());

      await firestore
          .collection('users')
          .doc(recieverUserId)
          .collection('chats')
          .doc(auth.currentUser!.uid)
          .collection('messages')
          .doc(messageId)
          .set(message.toMap());
    }
  }

  // Send text message
  void sendTextMessage({
    required BuildContext context,
    required String text,
    required String recieverUserId,
    required UserModel senderUser,
    required MessageReply? messageReply,
    required bool isGroupChat,
  }) async {
    try {
      var timeSent = DateTime.now();
      UserModel? recieverUserData;

      if (!isGroupChat) {
        var userDataMap =
            await firestore.collection('users').doc(recieverUserId).get();
        recieverUserData = UserModel.fromMap(userDataMap.data()!);
      }

      var messageId = const Uuid().v1();

      _saveDataToContactsSubcollection(
        senderUser,
        recieverUserData,
        text,
        timeSent,
        recieverUserId,
        isGroupChat,
      );

      _saveMessageToMessageSubcollection(
        recieverUserId: recieverUserId,
        text: text,
        timeSent: timeSent,
        messageType: MessageEnum.text,
        messageId: messageId,
        recieverUsername: recieverUserData?.name,
        senderUsername: senderUser.name,
        messageReply: messageReply,
        isGroupChat: isGroupChat,
      );
    } catch (e) {
      showSnackBar(context: context, content: e.toString());
    }
  }

  // Send file message
  void sendFileMessage({
    required BuildContext context,
    required File file,
    required String recieverUserId,
    required UserModel senderUserData,
    required ProviderRef ref,
    required MessageEnum messageEnum,
    required MessageReply? messageReply,
    required bool isGroupChat,
  }) async {
    try {
      var timeSent = DateTime.now();
      var messageId = const Uuid().v1();

      String imageUrl = await ref
          .read(commonFirebaseStorageRepositoryProvider)
          .storeFileToFirebase(
            'chat/${messageEnum.type}/${senderUserData.uid}/$recieverUserId/$messageId',
            file,
          );

      UserModel? recieverUserData;
      if (!isGroupChat) {
        var userDataMap =
            await firestore.collection('users').doc(recieverUserId).get();
        recieverUserData = UserModel.fromMap(userDataMap.data()!);
      }

      String contactMsg;

      switch (messageEnum) {
        case MessageEnum.image:
          contactMsg = '📸 Photo';
        case MessageEnum.video:
          contactMsg = '📹 Video';
        case MessageEnum.audio:
          contactMsg = '🎶 Audio';
        case MessageEnum.gif:
          contactMsg = 'GIF';
        default:
          contactMsg = 'GIF';
      }

      _saveDataToContactsSubcollection(
        senderUserData,
        recieverUserData,
        contactMsg,
        timeSent,
        recieverUserId,
        isGroupChat,
      );

      _saveMessageToMessageSubcollection(
        recieverUserId: recieverUserId,
        text: imageUrl,
        timeSent: timeSent,
        messageId: messageId,
        senderUsername: senderUserData.name,
        recieverUsername: recieverUserData?.name,
        messageType: messageEnum,
        messageReply: messageReply,
        isGroupChat: isGroupChat,
      );
    } catch (e) {
      showSnackBar(context: context, content: e.toString());
    }
  }

  // Send GIF message
  void sendGIFMessage({
    required BuildContext context,
    required String gifURL,
    required String recieverUserId,
    required UserModel senderUser,
    required MessageReply? messageReply,
    required bool isGroupChat,
  }) async {
    try {
      var timeSent = DateTime.now();
      UserModel? recieverUserData;
      if (!isGroupChat) {
        var userDataMap =
            await firestore.collection('users').doc(recieverUserId).get();
        recieverUserData = UserModel.fromMap(userDataMap.data()!);
      }

      var messageId = const Uuid().v1();

      _saveDataToContactsSubcollection(
        senderUser,
        recieverUserData,
        'GIF',
        timeSent,
        recieverUserId,
        isGroupChat,
      );

      _saveMessageToMessageSubcollection(
        recieverUserId: recieverUserId,
        text: gifURL,
        timeSent: timeSent,
        messageType: MessageEnum.gif,
        messageId: messageId,
        recieverUsername: recieverUserData?.name,
        senderUsername: senderUser.name,
        messageReply: messageReply,
        isGroupChat: isGroupChat,
      );
    } catch (e) {
      showSnackBar(context: context, content: e.toString());
    }
  }

  // Set isSeen of message
  void setChatMessageSeen(
    BuildContext context,
    String recieverUserId,
    String messageId,
  ) async {
    try {
      await firestore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .collection('chats')
          .doc(recieverUserId)
          .collection('messages')
          .doc(messageId)
          .update({
        'isSeen': true,
      });

      await firestore
          .collection('users')
          .doc(recieverUserId)
          .collection('chats')
          .doc(auth.currentUser!.uid)
          .collection('messages')
          .doc(messageId)
          .update({
        'isSeen': true,
      });
    } catch (e) {
      showSnackBar(context: context, content: e.toString());
    }
  }
}
