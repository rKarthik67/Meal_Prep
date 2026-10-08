import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../state/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cards.dart';
import '../../widgets/common.dart';
import 'cook_detail_screen.dart';

const kCuisines = ['South Indian', 'North Indian', 'Kerala', 'Karnataka', 'Chettinad', 'Andhra', 'Mughlai', 'Bengali'];

class FindCooksScreen extends StatefulWidget {
  const FindCooksScreen({super.key, this.cuisine, this.pincode, this.mealType, this.mealPlanId});
  final int? mealPlanId;
  final String? cuisine;
  final String? pincode;
  final String? mealType;

  @override
  State<FindCooksScreen> createState() => _FindCooksScreenState();
}

enum _Sort { recommended, rating, price }

class _FindCooksScreenState extends State<FindCooksScreen> {
  late final _pincode = TextEditingController(text: widget.pincode ?? '');
  late String? _cuisine = widget.cuisine;
  bool _vegOnly = false;
  _Sort _sort = _Sort.recommended;
  final _listKey = GlobalKey<AsyncListState<Cook>>();

  @override
  void dispose() {
    _pincode.dispose();
    super.dispose();
  }

  void _search() => _listKey.currentState?.reload();

  Future<List<Cook>> _load() async {
    final cooks = await context.read<Session>().api.searchCooks(
          pincode: _pincode.text.length == 6 ? _pincode.text : null,
          cuisine: _cuisine,
          vegOnly: _vegOnly,
        );
    switch (_sort) {
      case _Sort.rating:
        cooks.sort((a, b) => b.ratingAvg.compareTo(a.ratingAvg));
      case _Sort.price:
        cooks.sort((a, b) => a.hourlyRate.compareTo(b.hourlyRate));
      case _Sort.recommended:
        break;
    }
    return cooks;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find a cook'),
        actions: [
          PopupMenuButton<_Sort>(
            icon: const Icon(Icons.sort_rounded),
            initialValue: _sort,
            onSelected: (s) {
              setState(() => _sort = s);
              _search();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: _Sort.recommended, child: Text('Recommended')),
              PopupMenuItem(value: _Sort.rating, child: Text('Rating: high to low')),
              PopupMenuItem(value: _Sort.price, child: Text('Price: low to high')),
            ],
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: TextField(
            controller: _pincode,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            onSubmitted: (_) => _search(),
            onChanged: (v) {
              if (v.length == 6 || v.isEmpty) _search();
            },
            decoration: InputDecoration(
              hintText: 'Pincode (e.g. 560034)',
              prefixIcon: const Icon(Icons.location_on_outlined),
              suffixIcon: IconButton(icon: const Icon(Icons.search_rounded), onPressed: _search),
            ),
          ),
        ),
        SizedBox(
          height: 58,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            children: [
              _chip(
                FilterChip(
                  avatar: const Icon(Icons.eco_rounded, size: 16, color: AppColors.veg),
                  label: const Text('Pure veg'),
                  selected: _vegOnly,
                  onSelected: (v) {
                    setState(() => _vegOnly = v);
                    _search();
                  },
                ),
              ),
              for (final c in kCuisines)
                _chip(
                  ChoiceChip(
                    label: Text('${cuisineEmoji(c)} $c'),
                    selected: _cuisine == c,
                    onSelected: (v) {
                      setState(() => _cuisine = v ? c : null);
                      _search();
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: AsyncList<Cook>(
            key: _listKey,
            load: _load,
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 40),
            empty: const EmptyState(
              emoji: '🧑‍🍳',
              title: 'No cooks match yet',
              message: 'Try another pincode or cuisine, or clear the filters.',
            ),
            itemBuilder: (context, cook, _) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: CookCard(
                cook: cook,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CookDetailScreen(cookId: cook.userId, mealType: widget.mealType, mealPlanId: widget.mealPlanId)),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _chip(Widget child) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: child);
}
