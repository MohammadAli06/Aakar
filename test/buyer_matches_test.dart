import 'package:flutter_test/flutter_test.dart';
import 'package:craft_connect/features/commerce/domain/commerce_engine.dart';

void main() {
  test(
      'Title-first matching prioritizes direct title and craft keyword matches',
      () {
    final state = {
      'products': [
        {
          'id': 'p1',
          'title': 'Handcrafted Terracotta Planter',
          'category': 'Pottery',
          'material': 'Terracotta',
          'craft': 'Pottery',
          'description': 'Clay planter pot',
          'price': 150,
          'moq': 10,
          'stock': 200,
          'capacity': 500,
          'lead_days': 15,
          'location': 'Jaipur, Rajasthan',
          'status': 'published',
          'approved': true,
          'available': true,
          'customizable': true,
        },
        {
          'id': 'p2',
          'title': 'Handwoven Bamboo Fruit Basket',
          'category': 'Bamboo',
          'material': 'Bamboo',
          'craft': 'Cane Weaving',
          'description': 'Natural basket for dining table',
          'price': 220,
          'moq': 20,
          'stock': 300,
          'capacity': 400,
          'lead_days': 20,
          'location': 'Assam',
          'status': 'published',
          'approved': true,
          'available': true,
          'customizable': true,
        },
        {
          'id': 'p3',
          'title': 'Brass Diya Lamp',
          'category': 'Metalcraft',
          'material': 'Brass',
          'craft': 'Casting',
          'description': 'Traditional pooja oil diya lamp',
          'price': 350,
          'moq': 5,
          'stock': 100,
          'capacity': 200,
          'lead_days': 10,
          'location': 'Moradabad, UP',
          'status': 'published',
          'approved': true,
          'available': true,
          'customizable': false,
        },
      ],
      'orders': [],
    };

    // Case 1: Searching for bamboo basket in English
    final basketMatches = CommerceEngine.matches(state, {
      'product': 'Bamboo Basket',
      'quantity': 25,
      'budget': 250,
      'lead_days': 25,
      'location': 'Kolkata',
    });

    expect(basketMatches.first['id'], 'p2');
    expect(basketMatches.first['match_score'], greaterThan(80));
    expect(
        basketMatches.first['reasons'], contains('Strong title & craft match'));

    // Case 2: Searching in Hindi for terracotta/clay pot ('मिट्टी का गमला')
    final hindiMatches = CommerceEngine.matches(state, {
      'product': 'मिट्टी का गमला (planter)',
      'quantity': 50,
      'budget': 200,
      'lead_days': 20,
      'location': 'Jaipur',
    });

    expect(hindiMatches.first['id'], 'p1');
    expect(hindiMatches.first['match_score'], greaterThan(80));

    // Case 3: Searching for Diya in Hindi ('पीतल का दीया')
    final diyaMatches = CommerceEngine.matches(state, {
      'product': 'पीतल का दीपक दीया',
      'quantity': 10,
      'budget': 400,
      'lead_days': 15,
      'location': 'Delhi',
    });

    expect(diyaMatches.first['id'], 'p3');
    expect(diyaMatches.first['match_score'], greaterThan(85));
  });
}
