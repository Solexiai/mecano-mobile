/// Additional action on an existing delivery offer. Acceptance continues to use
/// MissionRepository.acceptMission; this interface does not assign a mission.
abstract interface class DeliveryOfferActions {
  Future<void> declineOffer(String offerId);
}
