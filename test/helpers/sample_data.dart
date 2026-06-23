import 'package:delime/models/person.dart';
import 'package:delime/models/purchase.dart';
import 'package:delime/models/trip.dart';

/// A canonical trip fixture for repository/state tests.
const sampleTrip = Trip(
  id: 'trip',
  name: 'Greece',
  type: TripType.vacation,
  coverColor: 0xFF34D399,
  createdAt: 1,
  updatedAt: 1,
);

/// Shared fixtures for the spec's four-friends example scenario.
const john = Person(id: 'john', name: 'John', colorValue: 0xFF34D399);
const eve = Person(id: 'eve', name: 'Eve', colorValue: 0xFF60A5FA);
const marc = Person(id: 'marc', name: 'Marc', colorValue: 0xFFF472B6);
const amy = Person(id: 'amy', name: 'Amy', colorValue: 0xFFFBBF24);

const fourFriends = [john, eve, marc, amy];

/// €10 dinner: Marc and John each pay €5; split equally four ways.
const dinner = Purchase(
  id: 'dinner',
  name: 'Dinner',
  totalCents: 1000,
  createdAt: 1,
  payers: [
    Contribution(personId: 'marc', amountCents: 500),
    Contribution(personId: 'john', amountCents: 500),
  ],
  splits: [
    Contribution(personId: 'john', amountCents: 250),
    Contribution(personId: 'eve', amountCents: 250),
    Contribution(personId: 'marc', amountCents: 250),
    Contribution(personId: 'amy', amountCents: 250),
  ],
);
