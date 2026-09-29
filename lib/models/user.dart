class User {
  final String id;
  final String username;
  final String email;
  final String password; // Should be hashed in production
  final List<String> accessibleChannelIds;
  final bool isSubscribed;
  final DateTime subscriptionExpiry;

  const User({
    required this.id,
    required this.username,
    required this.email,
    required this.password,
    required this.accessibleChannelIds,
    required this.isSubscribed,
    required this.subscriptionExpiry,
  });

  bool hasAccessToChannel(String channelId) {
    return accessibleChannelIds.contains(channelId) && isSubscribed && subscriptionExpiry.isAfter(DateTime.now());
  }
}
