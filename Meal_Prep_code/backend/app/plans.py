"""Meal-plan ("diet chart") templates and the maths behind them: nutrition and grocery lists."""

from collections import defaultdict

from .foods import FOODS, find_food

SLOTS = ["breakfast", "lunch", "snack", "dinner"]
DAY_NAMES = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

GOALS = {
    "balanced": "Balanced",
    "weight_loss": "Weight loss",
    "muscle_gain": "High protein",
    "diabetic_friendly": "Low GI",
    "kids": "Kids",
    "traditional": "Traditional",
}


def _rotate(b: list[str], l: list[str], d: list[str], s: list[str] | None = None,
            portions: dict[str, float] | None = None) -> list[dict]:
    """Build 7 days by cycling through breakfast/lunch/snack/dinner options.
    `portions` lets a plan scale a slot (e.g. bigger lunches for a high-protein plan)."""
    portions = portions or {}
    s = s or ["buttermilk_chana", "fruit_nuts", "sundal", "makhana"]

    def meal(slot, dish):
        m = {"slot": slot, "dish": dish}
        if portions.get(slot, 1) != 1:
            m["servings"] = portions[slot]
        return m

    return [
        {"day": i + 1, "meals": [
            meal("breakfast", b[i % len(b)]),
            meal("lunch", l[i % len(l)]),
            meal("snack", s[i % len(s)]),
            meal("dinner", d[i % len(d)]),
        ]}
        for i in range(7)
    ]


TEMPLATES = [
    dict(slug="south-indian-veg", title="Namma South Indian Veg Week", emoji="🍛", color="#E8772E",
         subtitle="Idli, dosa, sambar & ragi: comfort food done right", goal="traditional", diet="veg",
         cuisine="South Indian", tags=["Bestseller", "Family"],
         description="A classic Bengaluru home week: fermented breakfasts, dal-rich lunches and light dinners.",
         days=_rotate(["idli_sambar", "ragi_dosa", "pongal", "masala_dosa", "upma", "kids_idli_podi", "poha"],
                      ["sambar_rice", "bisi_bele_bath", "rasam_rice", "ragi_mudde", "veg_pulao", "avial_rice", "sambar_rice"],
                      ["curd_rice", "dal_tadka_roti", "rasam_rice", "mixed_veg_roti", "curd_rice", "khichdi_kadhi", "millet_bowl"])),
    dict(slug="high-protein", title="High-Protein Fitness", emoji="💪", color="#2E7D5B",
         subtitle="~120 g protein a day from chicken, eggs, paneer & dal", goal="muscle_gain", diet="nonveg",
         cuisine="Mixed", tags=["Gym", "Protein 100g+"],
         description="Built for strength training: lean meats, eggs and paneer at every meal, balanced carbs.",
         days=_rotate(["egg_bhurji_toast", "moong_chilla", "masala_omelette", "besan_chilla", "egg_bhurji_toast", "sprouts_salad", "masala_omelette"],
                      ["chicken_curry_rice", "paneer_bhurji_roti", "fish_curry_rice", "chicken_roti", "soya_pulao", "grilled_chicken_salad", "chicken_biryani"],
                      ["grilled_chicken_salad", "tofu_stirfry", "chicken_soup", "palak_paneer_roti", "grilled_chicken_salad", "egg_curry_rice", "chicken_soup"], ["chicken_tikka", "boiled_eggs", "paneer_tikka", "curd_fruit"], {"lunch": 1.3, "dinner": 1.3})),
    dict(slug="light-and-lean", title="Light & Lean (~1,200 kcal)", emoji="🥗", color="#4C9A2A",
         subtitle="Calorie-smart vegetarian week for steady weight loss", goal="weight_loss", diet="veg",
         cuisine="Mixed", tags=["Low calorie", "High fibre"],
         description="High-fibre, protein-forward veg meals that keep you full while staying around 1,200 kcal a day (add tea/milk as you like).",
         days=_rotate(["oats_upma", "sprouts_salad", "besan_chilla", "ragi_porridge", "moong_chilla", "oats_upma", "idli_sambar"],
                      ["millet_bowl", "dal_tadka_roti", "rasam_rice", "methi_roti_dal", "dalia_khichdi", "mixed_veg_roti", "ragi_mudde"],
                      ["veg_soup_salad", "dalia_khichdi", "veg_soup_salad", "tofu_stirfry", "veg_soup_salad", "khichdi_kadhi", "veg_soup_salad"], ["makhana", "buttermilk_chana", "curd_fruit"])),
    dict(slug="low-gi-millet", title="Low-GI Millet Week", emoji="🌾", color="#8D6E3F",
         subtitle="Millets, ragi & dals for steady blood sugar", goal="diabetic_friendly", diet="veg",
         cuisine="Karnataka", tags=["Millets", "Low GI"],
         description="Swaps white rice for millets and ragi, with plenty of dal and vegetables. "
                     "Not medical advice: check portions with your doctor or dietitian.",
         days=_rotate(["ragi_dosa", "besan_chilla", "oats_upma", "moong_chilla", "ragi_porridge", "sprouts_salad", "ragi_dosa"],
                      ["ragi_mudde", "millet_bowl", "methi_roti_dal", "dalia_khichdi", "bhindi_dal_roti", "millet_bowl", "ragi_mudde"],
                      ["veg_soup_salad", "dal_tadka_roti", "tofu_stirfry", "mixed_veg_roti", "veg_soup_salad", "methi_roti_dal", "palak_paneer_roti"], ["sundal", "buttermilk_chana", "makhana", "curd_fruit"])),
    dict(slug="north-indian-ghar", title="North Indian Ghar Ka Khana", emoji="🫓", color="#C0392B",
         subtitle="Dal, sabzi, phulka: the way Maa makes it", goal="balanced", diet="veg",
         cuisine="North Indian", tags=["Family", "Comfort"],
         description="Everyday Punjabi and UP home food with weekend treats like rajma-chawal and chole.",
         days=_rotate(["aloo_paratha", "poha", "besan_chilla", "thepla", "moong_chilla", "aloo_paratha", "upma"],
                      ["rajma_chawal", "dal_tadka_roti", "chole_roti", "bhindi_dal_roti", "veg_pulao", "dal_makhani_rice", "chole_roti"],
                      ["mixed_veg_roti", "palak_paneer_roti", "khichdi_kadhi", "paneer_bhurji_roti", "dal_tadka_roti", "veg_biryani", "mixed_veg_roti"])),
    dict(slug="kids-lunchbox", title="Kids' Lunchbox Week", emoji="🧒", color="#F2A541",
         subtitle="Tiffin-friendly, colourful, not too spicy", goal="kids", diet="veg",
         cuisine="Mixed", tags=["Tiffin", "Mild"],
         description="Easy-to-eat, mild meals that travel well in a lunchbox, plus wholesome dinners.",
         days=_rotate(["kids_idli_podi", "ragi_porridge", "besan_chilla", "poha", "masala_dosa", "thepla", "upma"],
                      ["kids_paneer_wrap", "kids_pasta", "veg_pulao", "kids_idli_podi", "curd_rice", "kids_paneer_wrap", "kids_pasta"],
                      ["dal_tadka_roti", "khichdi_kadhi", "mixed_veg_roti", "sambar_rice", "palak_paneer_roti", "veg_pulao", "curd_rice"], ["milk_banana", "fruit_nuts", "makhana"])),
    dict(slug="kerala-coastal", title="Kerala Coastal Week", emoji="🥥", color="#1E8C93",
         subtitle="Appam, puttu, fish curry & matta rice", goal="traditional", diet="nonveg",
         cuisine="Kerala", tags=["Seafood", "Coconut"],
         description="God's own kitchen: coconut, curry leaves and fresh catch with red matta rice.",
         days=_rotate(["appam_stew", "puttu_kadala", "idiyappam_egg", "appam_stew", "puttu_kadala", "idli_sambar", "idiyappam_egg"],
                      ["fish_curry_rice", "avial_rice", "prawn_masala_rice", "fish_curry_rice", "avial_rice", "chicken_curry_rice", "fish_curry_rice"],
                      ["egg_curry_rice", "chicken_soup", "avial_rice", "curd_rice", "chettinad_chicken", "egg_curry_rice", "rasam_rice"])),
    dict(slug="jain-sattvic", title="Jain Sattvic Week", emoji="🪷", color="#B07CC6",
         subtitle="No onion, garlic or root vegetables", goal="traditional", diet="veg",
         cuisine="Jain", tags=["Jain", "No onion-garlic"],
         description="Sattvic, root-free cooking with dals, paneer and green vegetables.",
         days=_rotate(["moong_chilla", "ragi_porridge", "oats_upma", "moong_chilla", "ragi_porridge", "oats_upma", "moong_chilla"],
                      ["jain_dal_roti", "jain_paneer_roti", "khichdi_kadhi", "jain_dal_roti", "jain_paneer_roti", "khichdi_kadhi", "jain_dal_roti"],
                      ["khichdi_kadhi", "jain_dal_roti", "jain_paneer_roti", "dalia_khichdi", "jain_dal_roti", "jain_paneer_roti", "khichdi_kadhi"], ["fruit_nuts", "makhana", "curd_fruit"])),
    dict(slug="eggetarian", title="Eggetarian Everyday", emoji="🥚", color="#E0A800",
         subtitle="Veg plus eggs: easy protein for busy weeks", goal="balanced", diet="egg",
         cuisine="Mixed", tags=["Quick", "Protein"],
         description="Vegetarian staples boosted with eggs for an easy protein win.",
         days=_rotate(["masala_omelette", "idli_sambar", "egg_bhurji_toast", "poha", "masala_omelette", "idiyappam_egg", "besan_chilla"],
                      ["egg_curry_rice", "dal_tadka_roti", "egg_fried_rice", "sambar_rice", "rajma_chawal", "egg_curry_rice", "veg_biryani"],
                      ["mixed_veg_roti", "egg_curry_rice", "palak_paneer_roti", "egg_bhurji_toast", "dalia_khichdi", "tofu_stirfry", "curd_rice"], ["boiled_eggs", "fruit_nuts", "buttermilk_chana"])),
    dict(slug="family-feast", title="Family Feast Week", emoji="🍗", color="#8E44AD",
         subtitle="Weekday balance, weekend biryani", goal="balanced", diet="nonveg",
         cuisine="Mixed", tags=["Family", "Weekend special"],
         description="Light weekdays and a proper Sunday biryani spread for the whole family.",
         days=_rotate(["idli_sambar", "aloo_paratha", "poha", "masala_dosa", "egg_bhurji_toast", "puttu_kadala", "masala_dosa"],
                      ["sambar_rice", "chicken_curry_rice", "dal_tadka_roti", "fish_curry_rice", "veg_pulao", "mutton_curry_rice", "chicken_biryani"],
                      ["mixed_veg_roti", "curd_rice", "chicken_roti", "dal_tadka_roti",
                       "egg_curry_rice", "chettinad_chicken", "curd_rice"])),
]


def resolve_meal(meal: dict, servings: float = 1) -> dict:
    """Expand a stored meal ({slot, dish} or custom {slot, name, kcal...}) into display data."""
    food = FOODS.get(meal.get("dish", "")) or (find_food(meal["name"]) if meal.get("name") else None)
    if food:
        return {
            "slot": meal["slot"], "dish": food.key, "name": food.name, "emoji": food.emoji, "servings": servings,
            "cuisine": food.cuisine, "diet": food.diet, **food.macros(servings),
        }
    return {
        "slot": meal["slot"], "dish": None, "name": meal.get("name", "Custom dish"), "emoji": "🍽️", "servings": servings,
        "cuisine": meal.get("cuisine", ""), "diet": meal.get("diet", "veg"),
        "kcal": round(meal.get("kcal", 400) * servings), "protein": round(meal.get("protein", 12) * servings, 1),
        "carbs": round(meal.get("carbs", 55) * servings, 1), "fat": round(meal.get("fat", 12) * servings, 1),
        "fibre": round(meal.get("fibre", 5) * servings, 1),
    }


def resolve_days(days: list[dict]) -> list[dict]:
    out = []
    for d in days:
        meals = [resolve_meal(m, m.get("servings", 1)) for m in d["meals"]]
        totals = {k: round(sum(m[k] for m in meals), 1) for k in ("kcal", "protein", "carbs", "fat", "fibre")}
        totals["kcal"] = round(totals["kcal"])
        out.append({"day": d["day"], "label": DAY_NAMES[(d["day"] - 1) % 7], "meals": meals, "totals": totals})
    return out


def nutrition_summary(days: list[dict]) -> dict:
    resolved = resolve_days(days)
    n = max(len(resolved), 1)
    avg = {k: round(sum(d["totals"][k] for d in resolved) / n, 1) for k in ("kcal", "protein", "carbs", "fat", "fibre")}
    avg["kcal"] = round(avg["kcal"])
    # energy split from macros (4/4/9 kcal per gram)
    p, c, f = avg["protein"] * 4, avg["carbs"] * 4, avg["fat"] * 9
    total = p + c + f or 1
    return {
        "per_day": [{"day": d["day"], "label": d["label"], **d["totals"]} for d in resolved],
        "daily_average": avg,
        "macro_split_pct": {"protein": round(p * 100 / total), "carbs": round(c * 100 / total), "fat": round(f * 100 / total)},
    }


def grocery_list(days: list[dict], people: int = 2) -> list[dict]:
    """Aggregate ingredient quantities for the whole plan, grouped by category."""
    agg: dict[tuple, float] = defaultdict(float)
    for d in days:
        for m in d["meals"]:
            food = FOODS.get(m.get("dish", "")) or (find_food(m["name"]) if m.get("name") else None)
            if not food:
                continue
            for item, qty, unit, cat in food.ingredients:
                agg[(cat, item, unit)] += qty * people * m.get("servings", 1)
    by_cat: dict[str, list] = defaultdict(list)
    for (cat, item, unit), qty in sorted(agg.items()):
        by_cat[cat].append({"item": item, "qty": _pretty_qty(qty, unit), "unit": _pretty_unit(qty, unit)})
    order = ["Vegetables", "Grains & Flours", "Pulses & Lentils", "Dairy & Eggs", "Meat & Seafood",
             "Fruits & Nuts", "Oils & Ghee", "Spices & Masalas", "Other"]
    return [{"category": c, "items": by_cat[c]} for c in order if c in by_cat]


def _pretty_qty(qty: float, unit: str):
    if unit in ("g", "ml") and qty >= 1000:
        return round(qty / 1000, 2)
    if unit in ("g", "ml"):
        return int(round(qty / 50) * 50) or int(qty)  # round to 50 g for shopping
    return int(qty) if float(qty).is_integer() else round(qty, 1)


def _pretty_unit(qty: float, unit: str) -> str:
    if unit == "g" and qty >= 1000:
        return "kg"
    if unit == "ml" and qty >= 1000:
        return "L"
    return unit
