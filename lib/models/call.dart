class Call {
  final String callerId;
  final String callerName;
  final String callerPic;
  final String recieverId;
  final String recieverName;
  final String recieverPic;
  final String callId;
  final bool hasDialled;
  Call({
    required this.callerId,
    required this.callerName,
    required this.callerPic,
    required this.recieverId,
    required this.recieverName,
    required this.recieverPic,
    required this.callId,
    required this.hasDialled,
  });

  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{};

    result.addAll({'callerId': callerId});
    result.addAll({'callerName': callerName});
    result.addAll({'callerPic': callerPic});
    result.addAll({'recieverId': recieverId});
    result.addAll({'recieverName': recieverName});
    result.addAll({'recieverPic': recieverPic});
    result.addAll({'callId': callId});
    result.addAll({'hasDialled': hasDialled});

    return result;
  }

  factory Call.fromMap(Map<String, dynamic> map) {
    return Call(
      callerId: map['callerId'] ?? '',
      callerName: map['callerName'] ?? '',
      callerPic: map['callerPic'] ?? '',
      recieverId: map['recieverId'] ?? '',
      recieverName: map['recieverName'] ?? '',
      recieverPic: map['recieverPic'] ?? '',
      callId: map['callId'] ?? '',
      hasDialled: map['hasDialled'] ?? false,
    );
  }
}
