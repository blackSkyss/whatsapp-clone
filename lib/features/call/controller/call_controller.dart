import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:whatsapp_clone/features/auth/controller/auth_controller.dart';
import 'package:whatsapp_clone/features/call/repository/call_repository.dart';
import 'package:whatsapp_clone/models/call.dart';

final callControllerProvider = Provider((ref) {
  final callRepository = ref.read(callRepositoryProvider);
  return CallController(
    callRepository: callRepository,
    ref: ref,
  );
});

class CallController {
  final CallRepository callRepository;
  final ProviderRef ref;
  CallController({
    required this.callRepository,
    required this.ref,
  });

  // Call stream
  Stream<DocumentSnapshot> get callStream => callRepository.callStream;

  // Make call
  void makeCall(
    BuildContext context,
    String recieverUserName,
    String recieverUserId,
    String recieverProfilePic,
    bool isGroupChat,
  ) {
    ref.read(userDataAuthProvider).whenData(
      (value) {
        String callId = const Uuid().v1();
        Call senderCallData = Call(
          callerId: value!.uid,
          callerName: value.name,
          callerPic: value.profilePic,
          recieverId: recieverUserId,
          recieverName: recieverUserName,
          recieverPic: recieverProfilePic,
          callId: callId,
          hasDialled: true,
        );

        Call recieverCallData = Call(
          callerId: value.uid,
          callerName: value.name,
          callerPic: value.profilePic,
          recieverId: recieverUserId,
          recieverName: recieverUserName,
          recieverPic: recieverProfilePic,
          callId: callId,
          hasDialled: false,
        );

        if (isGroupChat) {
          callRepository.makeGroupCall(
            senderCallData,
            context,
            recieverCallData,
          );
        } else {
          callRepository.makeCall(
            senderCallData,
            context,
            recieverCallData,
          );
        }
      },
    );
  }

  // End call
  void endCall(
    String callerId,
    String recieverId,
    BuildContext context,
  ) {
    callRepository.endCall(callerId, recieverId, context);
  }
}
