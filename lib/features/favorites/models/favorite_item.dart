import '../../../core/models/listing.dart';

/// Domain model representing a product saved in the user's favorites list.
/// The favorites API endpoint returns the same product shape as the catalog,
/// so [FavoriteItem] is a type alias for [Listing].
typedef FavoriteItem = Listing;
