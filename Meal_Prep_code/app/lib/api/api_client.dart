import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models.dart';

class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);
  @override
  String toString() => message;
}

/// Thin wrapper over the FastAPI backend. [tokenProvider] returns either a
/// Firebase ID token or a dev token ("dev:<phone>").
class ApiClient {
  ApiClient(this.tokenProvider, {http.Client? client}) : _http = client ?? http.Client();

  final Future<String?> Function() tokenProvider;
  final http.Client _http;

  Future<dynamic> _send(String method, String path, {Object? body, Map<String, String>? query}) async {
    final token = await tokenProvider();
    final uri = Uri.parse('$apiBaseUrl$path').replace(queryParameters: query);
    final req = http.Request(method, uri)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (body != null) req.body = jsonEncode(body);

    final res = await http.Response.fromStream(await _http.send(req));
    if (res.statusCode == 204 || res.body.isEmpty) return null;
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 400) {
      final detail = decoded is Map ? decoded['detail'] : null;
      final msg = detail is String
          ? detail
          : detail is List && detail.isNotEmpty
              ? (detail.first as Map)['msg'].toString()
              : 'Request failed (${res.statusCode})';
      throw ApiException(res.statusCode, msg);
    }
    return decoded;
  }

  List<Map<String, dynamic>> _list(dynamic v) => (v as List).cast<Map<String, dynamic>>();

  // ---- me ----
  Future<AppUser> me() async => AppUser.fromJson(await _send('GET', '/me'));
  Future<AppUser> updateMe({String? name, String? role}) async => AppUser.fromJson(await _send('PATCH', '/me', body: {
        if (name != null) 'name': name,
        if (role != null) 'role': role,
      }));

  Future<List<Address>> addresses() async =>
      _list(await _send('GET', '/me/addresses')).map(Address.fromJson).toList();
  Future<Address> addAddress(Map<String, dynamic> body) async =>
      Address.fromJson(await _send('POST', '/me/addresses', body: body));
  Future<void> deleteAddress(int id) => _send('DELETE', '/me/addresses/$id');

  // ---- cooks ----
  Future<List<Cook>> searchCooks({String? pincode, String? cuisine, bool vegOnly = false}) async {
    final q = <String, String>{
      if (pincode != null && pincode.isNotEmpty) 'pincode': pincode,
      if (cuisine != null && cuisine.isNotEmpty) 'cuisine': cuisine,
      if (vegOnly) 'veg_only': 'true',
    };
    return _list(await _send('GET', '/cooks', query: q.isEmpty ? null : q)).map(Cook.fromJson).toList();
  }

  Future<Cook> cook(int id) async => Cook.fromJson(await _send('GET', '/cooks/$id'));

  Future<Cook?> myCookProfile() async {
    try {
      return Cook.fromJson(await _send('GET', '/cooks/me'));
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  Future<Cook> saveCookProfile(Map<String, dynamic> body) async =>
      Cook.fromJson(await _send('PUT', '/cooks/me', body: body));
  Future<void> addDish(Map<String, dynamic> body) => _send('POST', '/cooks/me/dishes', body: body);
  Future<void> deleteDish(int id) => _send('DELETE', '/cooks/me/dishes/$id');

  // ---- bookings ----
  Future<Quote> quote(int cookId, int hours, int guests) async => Quote.fromJson(await _send('GET', '/bookings/quote',
      query: {'cook_id': '$cookId', 'duration_hours': '$hours', 'guests': '$guests'}));

  Future<Booking> createBooking(Map<String, dynamic> body) async =>
      Booking.fromJson(await _send('POST', '/bookings', body: body));

  Future<List<Booking>> bookings() async => _list(await _send('GET', '/bookings')).map(Booking.fromJson).toList();

  Future<Booking> act(int bookingId, String action) async =>
      Booking.fromJson(await _send('POST', '/bookings/$bookingId/$action'));

  Future<Booking> review(int bookingId, int rating, String comment) async => Booking.fromJson(
      await _send('POST', '/bookings/$bookingId/review', body: {'rating': rating, 'comment': comment}));

  // ---- meal plans ----
  Future<List<MealPlanSummary>> mealPlans({String? goal, String? diet, bool mine = false}) async {
    final q = <String, String>{
      if (goal != null) 'goal': goal,
      if (diet != null) 'diet': diet,
      if (mine) 'mine': 'true',
    };
    return _list(await _send('GET', '/meal-plans', query: q.isEmpty ? null : q)).map(MealPlanSummary.fromJson).toList();
  }

  Future<MealPlanDetail> mealPlan(int id) async => MealPlanDetail.fromJson(await _send('GET', '/meal-plans/$id'));

  Future<List<GroceryCategory>> grocery(int planId, int people) async {
    final res = await _send('GET', '/meal-plans/$planId/grocery', query: {'people': '$people'});
    return GroceryCategory.listFrom((res as Map<String, dynamic>)['categories']);
  }

  Future<void> deletePlan(int id) => _send('DELETE', '/meal-plans/$id');

  // ---- insights ----
  Future<Stats> stats() async => Stats.fromJson(await _send('GET', '/me/stats'));

  // ---- AI ----
  Future<AiCatalog> aiCatalog() async => AiCatalog.fromJson(await _send('GET', '/ai/agents'));

  Future<ChatReply> aiChat({
    required String agent,
    required String message,
    int? conversationId,
    String? provider,
  }) async =>
      ChatReply.fromJson(await _send('POST', '/ai/chat', body: {
        'agent': agent,
        'message': message,
        if (conversationId != null) 'conversation_id': conversationId,
        if (provider != null) 'provider': provider,
      }));

  Future<List<Conversation>> conversations() async =>
      _list(await _send('GET', '/ai/conversations')).map(Conversation.fromJson).toList();

  Future<Conversation> conversation(int id) async => Conversation.fromJson(await _send('GET', '/ai/conversations/$id'));

  Future<void> deleteConversation(int id) => _send('DELETE', '/ai/conversations/$id');

  /// Confirms a booking drafted by an AI agent (payload comes straight from the draft card).
  Future<Booking> createBookingFromDraft(Map<String, dynamic> payload) async =>
      Booking.fromJson(await _send('POST', '/bookings', body: payload));
}
