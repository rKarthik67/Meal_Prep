class AppUser {
  final int id;
  final String phone;
  final String name;
  final String? email;
  final String role; // customer | cook | admin

  AppUser({required this.id, required this.phone, required this.name, this.email, required this.role});

  bool get isCook => role == 'cook';

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as int,
        phone: j['phone'] as String,
        name: j['name'] as String,
        email: j['email'] as String?,
        role: j['role'] as String,
      );
}

class Address {
  final int id;
  final String label;
  final String line1;
  final String area;
  final String city;
  final String pincode;

  Address({
    required this.id,
    required this.label,
    required this.line1,
    required this.area,
    required this.city,
    required this.pincode,
  });

  String get short => '$label · $area $pincode';

  factory Address.fromJson(Map<String, dynamic> j) => Address(
        id: j['id'] as int,
        label: j['label'] as String,
        line1: j['line1'] as String,
        area: j['area'] as String,
        city: j['city'] as String,
        pincode: j['pincode'] as String,
      );
}

class Dish {
  final int id;
  final String name;
  final String cuisine;
  final bool isVeg;
  final int prepMinutes;

  Dish({required this.id, required this.name, required this.cuisine, required this.isVeg, required this.prepMinutes});

  factory Dish.fromJson(Map<String, dynamic> j) => Dish(
        id: j['id'] as int,
        name: j['name'] as String,
        cuisine: j['cuisine'] as String,
        isVeg: j['is_veg'] as bool,
        prepMinutes: j['prep_minutes'] as int,
      );
}

List<String> _strings(dynamic v) => (v as List).map((e) => e as String).toList();

class Cook {
  final int userId;
  final String name;
  final String bio;
  final List<String> cuisines;
  final List<String> languages;
  final List<String> servicePincodes;
  final bool vegOnly;
  final int experienceYears;
  final int hourlyRate;
  final double ratingAvg;
  final int ratingCount;
  final bool verified;
  final bool isActive;
  final List<Dish> dishes;

  Cook({
    required this.userId,
    required this.name,
    required this.bio,
    required this.cuisines,
    required this.languages,
    required this.servicePincodes,
    required this.vegOnly,
    required this.experienceYears,
    required this.hourlyRate,
    required this.ratingAvg,
    required this.ratingCount,
    required this.verified,
    required this.isActive,
    this.dishes = const [],
  });

  factory Cook.fromJson(Map<String, dynamic> j) => Cook(
        userId: j['user_id'] as int,
        name: j['name'] as String,
        bio: j['bio'] as String,
        cuisines: _strings(j['cuisines']),
        languages: _strings(j['languages']),
        servicePincodes: _strings(j['service_pincodes']),
        vegOnly: j['veg_only'] as bool,
        experienceYears: j['experience_years'] as int,
        hourlyRate: j['hourly_rate'] as int,
        ratingAvg: (j['rating_avg'] as num).toDouble(),
        ratingCount: j['rating_count'] as int,
        verified: j['verified'] as bool,
        isActive: j['is_active'] as bool,
        dishes: j['dishes'] == null
            ? const []
            : (j['dishes'] as List).map((d) => Dish.fromJson(d as Map<String, dynamic>)).toList(),
      );
}

class Quote {
  final int cookFee;
  final int extraGuestFee;
  final int platformFee;
  final int total;

  Quote({required this.cookFee, required this.extraGuestFee, required this.platformFee, required this.total});

  factory Quote.fromJson(Map<String, dynamic> j) => Quote(
        cookFee: j['cook_fee'] as int,
        extraGuestFee: j['extra_guest_fee'] as int,
        platformFee: j['platform_fee'] as int,
        total: j['total'] as int,
      );
}

const mealTypeIcons = <String, String>{
  'breakfast': '🍳',
  'lunch': '🍛',
  'dinner': '🍲',
  'meal_prep': '🍱',
  'party': '🎉',
};

const mealTypes = <String, String>{
  'breakfast': 'Breakfast',
  'lunch': 'Lunch',
  'dinner': 'Dinner',
  'meal_prep': 'Weekly meal prep',
  'party': 'Party / guests',
};

class Booking {
  final int id;
  final int customerId;
  final String customerName;
  final int cookId;
  final String cookName;
  final Address address;
  final String serviceDate; // yyyy-mm-dd
  final String startTime; // HH:MM:SS
  final int durationHours;
  final String mealType;
  final int guests;
  final String groceriesBy;
  final String notes;
  final String status;
  final int priceEstimate;
  final int? rating;
  final int? mealPlanId;
  final String? mealPlanTitle;
  final List<String> cookCuisines;

  Booking({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.cookId,
    required this.cookName,
    required this.address,
    required this.serviceDate,
    required this.startTime,
    required this.durationHours,
    required this.mealType,
    required this.guests,
    required this.groceriesBy,
    required this.notes,
    required this.status,
    required this.priceEstimate,
    this.rating,
    this.mealPlanId,
    this.mealPlanTitle,
    this.cookCuisines = const [],
  });

  DateTime get date => DateTime.parse(serviceDate);
  bool get isActive => status == 'requested' || status == 'accepted' || status == 'in_progress';

  String get when => '$serviceDate · ${startTime.substring(0, 5)} · ${durationHours}h';

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
        id: j['id'] as int,
        customerId: j['customer_id'] as int,
        customerName: j['customer_name'] as String,
        cookId: j['cook_id'] as int,
        cookName: j['cook_name'] as String,
        address: Address.fromJson(j['address'] as Map<String, dynamic>),
        serviceDate: j['service_date'] as String,
        startTime: j['start_time'] as String,
        durationHours: j['duration_hours'] as int,
        mealType: j['meal_type'] as String,
        guests: j['guests'] as int,
        groceriesBy: j['groceries_by'] as String,
        notes: j['notes'] as String,
        status: j['status'] as String,
        priceEstimate: j['price_estimate'] as int,
        rating: j['rating'] as int?,
        mealPlanId: j['meal_plan_id'] as int?,
        mealPlanTitle: j['meal_plan_title'] as String?,
        cookCuisines: j['cook_cuisines'] == null ? const [] : _strings(j['cook_cuisines']),
      );
}


// ---------------------------------------------------------------- meal plans
double _d(dynamic v) => (v as num).toDouble();

class Macros {
  final int kcal;
  final double protein;
  final double carbs;
  final double fat;
  final double fibre;

  const Macros({required this.kcal, required this.protein, required this.carbs, required this.fat, required this.fibre});

  factory Macros.fromJson(Map<String, dynamic> j) => Macros(
        kcal: (j['kcal'] as num).round(),
        protein: _d(j['protein']),
        carbs: _d(j['carbs']),
        fat: _d(j['fat']),
        fibre: _d(j['fibre']),
      );
}

class MealPlanSummary {
  final int id;
  final String title;
  final String subtitle;
  final String emoji;
  final String color;
  final String goal;
  final String goalLabel;
  final String diet;
  final String cuisine;
  final List<String> tags;
  final bool isTemplate;
  final bool createdByAi;
  final int daysCount;
  final int avgKcal;
  final double avgProtein;

  MealPlanSummary({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.color,
    required this.goal,
    required this.goalLabel,
    required this.diet,
    required this.cuisine,
    required this.tags,
    required this.isTemplate,
    required this.createdByAi,
    required this.daysCount,
    required this.avgKcal,
    required this.avgProtein,
  });

  factory MealPlanSummary.fromJson(Map<String, dynamic> j) => MealPlanSummary(
        id: j['id'] as int,
        title: j['title'] as String,
        subtitle: (j['subtitle'] ?? '') as String,
        emoji: (j['emoji'] ?? '🍛') as String,
        color: (j['color'] ?? '#E5632B') as String,
        goal: j['goal'] as String,
        goalLabel: (j['goal_label'] ?? j['goal']) as String,
        diet: j['diet'] as String,
        cuisine: (j['cuisine'] ?? '') as String,
        tags: j['tags'] == null ? const [] : _strings(j['tags']),
        isTemplate: (j['is_template'] ?? true) as bool,
        createdByAi: (j['created_by_ai'] ?? false) as bool,
        daysCount: (j['days_count'] ?? 7) as int,
        avgKcal: (j['avg_kcal'] as num).round(),
        avgProtein: _d(j['avg_protein']),
      );
}

class PlanMeal {
  final String slot;
  final String name;
  final String emoji;
  final String cuisine;
  final String diet;
  final double servings;
  final Macros macros;

  PlanMeal({
    required this.slot,
    required this.name,
    required this.emoji,
    required this.cuisine,
    required this.diet,
    required this.servings,
    required this.macros,
  });

  factory PlanMeal.fromJson(Map<String, dynamic> j) => PlanMeal(
        slot: j['slot'] as String,
        name: j['name'] as String,
        emoji: (j['emoji'] ?? '🍽️') as String,
        cuisine: (j['cuisine'] ?? '') as String,
        diet: (j['diet'] ?? 'veg') as String,
        servings: j['servings'] == null ? 1 : _d(j['servings']),
        macros: Macros.fromJson(j),
      );
}

class PlanDay {
  final int day;
  final String label;
  final List<PlanMeal> meals;
  final Macros totals;

  PlanDay({required this.day, required this.label, required this.meals, required this.totals});

  factory PlanDay.fromJson(Map<String, dynamic> j) => PlanDay(
        day: j['day'] as int,
        label: j['label'] as String,
        meals: (j['meals'] as List).map((m) => PlanMeal.fromJson(m as Map<String, dynamic>)).toList(),
        totals: Macros.fromJson(j['totals'] as Map<String, dynamic>),
      );
}

class Nutrition {
  final List<(String, Macros)> perDay;
  final Macros dailyAverage;
  final int proteinPct;
  final int carbsPct;
  final int fatPct;

  Nutrition({
    required this.perDay,
    required this.dailyAverage,
    required this.proteinPct,
    required this.carbsPct,
    required this.fatPct,
  });

  factory Nutrition.fromJson(Map<String, dynamic> j) {
    final split = j['macro_split_pct'] as Map<String, dynamic>;
    return Nutrition(
      perDay: (j['per_day'] as List)
          .map((d) => ((d as Map<String, dynamic>)['label'] as String, Macros.fromJson(d)))
          .toList(),
      dailyAverage: Macros.fromJson(j['daily_average'] as Map<String, dynamic>),
      proteinPct: split['protein'] as int,
      carbsPct: split['carbs'] as int,
      fatPct: split['fat'] as int,
    );
  }
}

class MealPlanDetail {
  final MealPlanSummary summary;
  final String description;
  final List<PlanDay> days;
  final Nutrition nutrition;

  MealPlanDetail({required this.summary, required this.description, required this.days, required this.nutrition});

  factory MealPlanDetail.fromJson(Map<String, dynamic> j) => MealPlanDetail(
        summary: MealPlanSummary.fromJson(j),
        description: (j['description'] ?? '') as String,
        days: (j['days'] as List).map((d) => PlanDay.fromJson(d as Map<String, dynamic>)).toList(),
        nutrition: Nutrition.fromJson(j['nutrition'] as Map<String, dynamic>),
      );
}

class GroceryItem {
  final String item;
  final num qty;
  final String unit;

  GroceryItem({required this.item, required this.qty, required this.unit});

  String get amount => '${qty is double && qty == qty.roundToDouble() ? qty.toInt() : qty} $unit';

  factory GroceryItem.fromJson(Map<String, dynamic> j) =>
      GroceryItem(item: j['item'] as String, qty: j['qty'] as num, unit: j['unit'] as String);
}

class GroceryCategory {
  final String category;
  final List<GroceryItem> items;

  GroceryCategory({required this.category, required this.items});

  factory GroceryCategory.fromJson(Map<String, dynamic> j) => GroceryCategory(
        category: j['category'] as String,
        items: (j['items'] as List).map((i) => GroceryItem.fromJson(i as Map<String, dynamic>)).toList(),
      );

  static List<GroceryCategory> listFrom(dynamic v) =>
      (v as List).map((c) => GroceryCategory.fromJson(c as Map<String, dynamic>)).toList();
}

const goalLabels = <String, String>{
  'balanced': 'Balanced',
  'weight_loss': 'Weight loss',
  'muscle_gain': 'High protein',
  'diabetic_friendly': 'Low GI',
  'kids': 'Kids',
  'traditional': 'Traditional',
};

const slotLabels = <String, String>{
  'breakfast': 'Breakfast',
  'lunch': 'Lunch',
  'snack': 'Snack',
  'dinner': 'Dinner',
};

// ---------------------------------------------------------------- insights
class Stats {
  final String role;
  final List<(String, int)> monthly;
  final int totalAmount;
  final int completed;
  final int upcoming;
  final Map<String, int> byStatus;
  final Map<String, int> byMealType;
  final Map<String, int> byCuisine;
  final int hoursSaved;
  final double? ratingAvg;
  final int? ratingCount;
  final int pendingRequests;

  Stats({
    required this.role,
    required this.monthly,
    required this.totalAmount,
    required this.completed,
    required this.upcoming,
    required this.byStatus,
    required this.byMealType,
    required this.byCuisine,
    required this.hoursSaved,
    this.ratingAvg,
    this.ratingCount,
    this.pendingRequests = 0,
  });

  static Map<String, int> _counts(dynamic v) =>
      (v as Map<String, dynamic>).map((k, val) => MapEntry(k, (val as num).toInt()));

  factory Stats.fromJson(Map<String, dynamic> j) => Stats(
        role: j['role'] as String,
        monthly: (j['monthly'] as List)
            .map((m) => ((m as Map<String, dynamic>)['label'] as String, (m['amount'] as num).toInt()))
            .toList(),
        totalAmount: (j['total_amount'] as num).toInt(),
        completed: j['completed'] as int,
        upcoming: j['upcoming'] as int,
        byStatus: _counts(j['by_status']),
        byMealType: _counts(j['by_meal_type']),
        byCuisine: _counts(j['by_cuisine']),
        hoursSaved: (j['hours_saved'] as num).toInt(),
        ratingAvg: j['rating_avg'] == null ? null : _d(j['rating_avg']),
        ratingCount: j['rating_count'] as int?,
        pendingRequests: (j['pending_requests'] ?? 0) as int,
      );
}

// ---------------------------------------------------------------- AI
class AiAgent {
  final String key;
  final String title;
  final String tagline;
  final String icon;
  final String color;
  final List<String> starters;

  AiAgent({
    required this.key,
    required this.title,
    required this.tagline,
    required this.icon,
    required this.color,
    required this.starters,
  });

  factory AiAgent.fromJson(Map<String, dynamic> j) => AiAgent(
        key: j['key'] as String,
        title: j['title'] as String,
        tagline: j['tagline'] as String,
        icon: j['icon'] as String,
        color: j['color'] as String,
        starters: _strings(j['starters']),
      );
}

class AiCatalog {
  final List<AiAgent> agents;
  final List<(String, String)> providers; // (key, label)
  final String defaultProvider;

  AiCatalog({required this.agents, required this.providers, required this.defaultProvider});

  factory AiCatalog.fromJson(Map<String, dynamic> j) => AiCatalog(
        agents: (j['agents'] as List).map((a) => AiAgent.fromJson(a as Map<String, dynamic>)).toList(),
        providers: (j['providers'] as List)
            .map((p) => ((p as Map<String, dynamic>)['key'] as String, p['label'] as String))
            .toList(),
        defaultProvider: j['default_provider'] as String,
      );
}

class ChatMessage {
  final String role; // user | assistant
  final String content;
  final List<Map<String, dynamic>> blocks;
  final List<String> suggestions;

  ChatMessage({required this.role, required this.content, this.blocks = const [], this.suggestions = const []});

  bool get isUser => role == 'user';

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        role: j['role'] as String,
        content: (j['content'] ?? j['reply'] ?? '') as String,
        blocks: j['blocks'] == null ? const [] : (j['blocks'] as List).cast<Map<String, dynamic>>(),
        suggestions: j['suggestions'] == null ? const [] : _strings(j['suggestions']),
      );
}

class ChatReply {
  final int conversationId;
  final ChatMessage message;
  final String provider;

  ChatReply({required this.conversationId, required this.message, required this.provider});

  factory ChatReply.fromJson(Map<String, dynamic> j) => ChatReply(
        conversationId: j['conversation_id'] as int,
        message: ChatMessage(
          role: 'assistant',
          content: j['reply'] as String,
          blocks: (j['blocks'] as List).cast<Map<String, dynamic>>(),
          suggestions: _strings(j['suggestions']),
        ),
        provider: j['provider'] as String,
      );
}

class Conversation {
  final int id;
  final String agent;
  final String title;
  final String preview;
  final DateTime updatedAt;
  final List<ChatMessage> messages;

  Conversation({
    required this.id,
    required this.agent,
    required this.title,
    required this.preview,
    required this.updatedAt,
    this.messages = const [],
  });

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        id: j['id'] as int,
        agent: j['agent'] as String,
        title: j['title'] as String,
        preview: (j['preview'] ?? '') as String,
        updatedAt: DateTime.parse(j['updated_at'] as String),
        messages: j['messages'] == null
            ? const []
            : (j['messages'] as List).map((m) => ChatMessage.fromJson(m as Map<String, dynamic>)).toList(),
      );
}
