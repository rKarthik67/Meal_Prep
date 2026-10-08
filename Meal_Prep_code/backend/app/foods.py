"""Reference food database: typical home-style Indian dishes.

Nutrition is per single adult serving and approximate (home recipes vary).
Ingredients are per serving and are used to build grocery lists.
Diet: "veg" | "egg" | "nonveg".  Grocery categories keep the list readable.
"""

from dataclasses import dataclass

VEG, EGG, NONVEG = "veg", "egg", "nonveg"

# grocery categories
VEGGIES, GRAINS, PULSES, DAIRY, SPICES, OILS, MEAT, FRUIT, OTHER = (
    "Vegetables", "Grains & Flours", "Pulses & Lentils", "Dairy & Eggs",
    "Spices & Masalas", "Oils & Ghee", "Meat & Seafood", "Fruits & Nuts", "Other",
)


@dataclass(frozen=True)
class Food:
    key: str
    name: str
    emoji: str
    cuisine: str
    diet: str
    kcal: int
    protein: float
    carbs: float
    fat: float
    fibre: float
    ingredients: tuple  # ((item, qty, unit, category), ...)

    def macros(self, servings: float = 1) -> dict:
        return {
            "kcal": round(self.kcal * servings),
            "protein": round(self.protein * servings, 1),
            "carbs": round(self.carbs * servings, 1),
            "fat": round(self.fat * servings, 1),
            "fibre": round(self.fibre * servings, 1),
        }


def _f(key, name, emoji, cuisine, diet, kcal, p, c, f, fi, *ing):
    return Food(key, name, emoji, cuisine, diet, kcal, p, c, f, fi, tuple(ing))


FOODS: dict[str, Food] = {f.key: f for f in [
    # ---------------- breakfasts ----------------
    _f("idli_sambar", "Idli with Sambar", "🍥", "South Indian", VEG, 290, 10, 54, 4, 6,
       ("Idli rice", 60, "g", GRAINS), ("Urad dal", 20, "g", PULSES), ("Toor dal", 25, "g", PULSES),
       ("Mixed vegetables", 80, "g", VEGGIES), ("Sambar powder", 5, "g", SPICES), ("Tamarind", 5, "g", SPICES)),
    _f("masala_dosa", "Masala Dosa", "🌯", "South Indian", VEG, 390, 9, 58, 13, 5,
       ("Dosa rice", 70, "g", GRAINS), ("Urad dal", 20, "g", PULSES), ("Potato", 120, "g", VEGGIES),
       ("Onion", 40, "g", VEGGIES), ("Oil", 10, "ml", OILS)),
    _f("ragi_dosa", "Ragi Dosa with Chutney", "🫓", "Karnataka", VEG, 260, 7, 44, 6, 7,
       ("Ragi flour", 60, "g", GRAINS), ("Coconut", 25, "g", FRUIT), ("Roasted gram", 10, "g", PULSES), ("Oil", 5, "ml", OILS)),
    _f("pongal", "Ven Pongal", "🍚", "South Indian", VEG, 340, 10, 52, 10, 3,
       ("Raw rice", 60, "g", GRAINS), ("Moong dal", 30, "g", PULSES), ("Ghee", 10, "g", OILS),
       ("Black pepper & cumin", 3, "g", SPICES)),
    _f("upma", "Rava Upma", "🥣", "South Indian", VEG, 280, 7, 44, 8, 4,
       ("Rava (semolina)", 60, "g", GRAINS), ("Mixed vegetables", 60, "g", VEGGIES), ("Oil", 8, "ml", OILS)),
    _f("poha", "Kanda Poha", "🍛", "Maharashtrian", VEG, 270, 6, 46, 7, 3,
       ("Poha (flattened rice)", 60, "g", GRAINS), ("Onion", 50, "g", VEGGIES), ("Peanuts", 15, "g", FRUIT),
       ("Oil", 8, "ml", OILS)),
    _f("aloo_paratha", "Aloo Paratha with Curd", "🫓", "North Indian", VEG, 430, 11, 60, 16, 6,
       ("Wheat atta", 80, "g", GRAINS), ("Potato", 120, "g", VEGGIES), ("Curd", 100, "g", DAIRY), ("Ghee", 10, "g", OILS)),
    _f("besan_chilla", "Besan Chilla", "🥞", "North Indian", VEG, 250, 13, 30, 8, 6,
       ("Besan (gram flour)", 60, "g", PULSES), ("Onion & tomato", 60, "g", VEGGIES), ("Oil", 6, "ml", OILS)),
    _f("moong_chilla", "Moong Dal Chilla with Paneer", "🥞", "North Indian", VEG, 310, 20, 30, 11, 6,
       ("Moong dal", 60, "g", PULSES), ("Paneer", 40, "g", DAIRY), ("Oil", 6, "ml", OILS)),
    _f("oats_upma", "Vegetable Oats Upma", "🥣", "Fusion", VEG, 230, 8, 36, 6, 6,
       ("Rolled oats", 50, "g", GRAINS), ("Mixed vegetables", 80, "g", VEGGIES), ("Oil", 5, "ml", OILS)),
    _f("egg_bhurji_toast", "Egg Bhurji with Toast", "🍳", "North Indian", EGG, 360, 19, 30, 18, 3,
       ("Eggs", 2, "pcs", DAIRY), ("Whole-wheat bread", 2, "slices", GRAINS), ("Onion & tomato", 60, "g", VEGGIES),
       ("Oil", 6, "ml", OILS)),
    _f("masala_omelette", "Masala Omelette & Fruit", "🍳", "Fusion", EGG, 300, 17, 22, 16, 3,
       ("Eggs", 2, "pcs", DAIRY), ("Onion & chilli", 40, "g", VEGGIES), ("Seasonal fruit", 150, "g", FRUIT), ("Oil", 5, "ml", OILS)),
    _f("appam_stew", "Appam with Veg Stew", "🥥", "Kerala", VEG, 360, 7, 56, 12, 5,
       ("Appam rice", 70, "g", GRAINS), ("Coconut milk", 100, "ml", FRUIT), ("Mixed vegetables", 100, "g", VEGGIES)),
    _f("puttu_kadala", "Puttu with Kadala Curry", "🥥", "Kerala", VEG, 410, 15, 66, 10, 11,
       ("Puttu rice flour", 70, "g", GRAINS), ("Black chana", 40, "g", PULSES), ("Coconut", 30, "g", FRUIT)),
    _f("thepla", "Methi Thepla with Curd", "🫓", "Gujarati", VEG, 330, 10, 44, 13, 6,
       ("Wheat atta", 60, "g", GRAINS), ("Methi leaves", 30, "g", VEGGIES), ("Curd", 100, "g", DAIRY), ("Oil", 8, "ml", OILS)),
    _f("sprouts_salad", "Sprouts Chaat", "🥗", "Fusion", VEG, 180, 11, 28, 3, 8,
       ("Moong sprouts", 100, "g", PULSES), ("Onion, tomato & cucumber", 80, "g", VEGGIES), ("Lemon", 1, "pcs", FRUIT)),
    _f("ragi_porridge", "Ragi Malt Porridge", "🥛", "Karnataka", VEG, 220, 7, 38, 5, 5,
       ("Ragi flour", 40, "g", GRAINS), ("Milk", 200, "ml", DAIRY), ("Jaggery", 10, "g", OTHER)),
    _f("idiyappam_egg", "Idiyappam with Egg Curry", "🍜", "Kerala", EGG, 420, 18, 58, 13, 3,
       ("Idiyappam rice flour", 70, "g", GRAINS), ("Eggs", 2, "pcs", DAIRY), ("Coconut milk", 80, "ml", FRUIT)),

    # ---------------- snacks ----------------
    _f("buttermilk_chana", "Masala Buttermilk & Roasted Chana", "🥛", "South Indian", VEG, 170, 9, 20, 5, 5,
       ("Curd", 150, "g", DAIRY), ("Roasted gram", 30, "g", PULSES)),
    _f("fruit_nuts", "Fruit Bowl with Nuts", "🍎", "Fusion", VEG, 230, 5, 32, 10, 6,
       ("Seasonal fruit", 200, "g", FRUIT), ("Almonds & walnuts", 15, "g", FRUIT)),
    _f("sundal", "Chana Sundal", "🫘", "South Indian", VEG, 190, 10, 28, 4, 8,
       ("Kabuli chana", 45, "g", PULSES), ("Coconut", 10, "g", FRUIT)),
    _f("curd_fruit", "Hung Curd with Fruit & Seeds", "🍓", "Fusion", VEG, 210, 13, 24, 7, 4,
       ("Curd", 200, "g", DAIRY), ("Seasonal fruit", 100, "g", FRUIT), ("Mixed seeds", 10, "g", FRUIT)),
    _f("boiled_eggs", "Boiled Eggs & Cucumber", "🥚", "Fusion", EGG, 170, 13, 4, 10, 1,
       ("Eggs", 2, "pcs", DAIRY), ("Cucumber", 100, "g", VEGGIES)),
    _f("paneer_tikka", "Paneer Tikka", "🍢", "North Indian", VEG, 260, 18, 8, 17, 2,
       ("Paneer", 100, "g", DAIRY), ("Capsicum & onion", 60, "g", VEGGIES), ("Curd", 30, "g", DAIRY)),
    _f("chicken_tikka", "Chicken Tikka", "🍢", "North Indian", NONVEG, 240, 34, 4, 10, 1,
       ("Chicken breast", 150, "g", MEAT), ("Curd", 30, "g", DAIRY)),
    _f("makhana", "Roasted Makhana & Green Tea", "🍵", "North Indian", VEG, 140, 5, 20, 4, 3,
       ("Makhana (fox nuts)", 30, "g", FRUIT), ("Ghee", 4, "g", OILS)),
    _f("milk_banana", "Milk & Banana", "🍌", "Fusion", VEG, 230, 9, 38, 5, 3,
       ("Milk", 200, "ml", DAIRY), ("Banana", 1, "pcs", FRUIT)),

    # ---------------- mains (lunch / dinner) ----------------
    _f("sambar_rice", "Sambar Rice & Poriyal", "🍛", "South Indian", VEG, 460, 14, 78, 9, 9,
       ("Sona masoori rice", 80, "g", GRAINS), ("Toor dal", 35, "g", PULSES), ("Mixed vegetables", 150, "g", VEGGIES),
       ("Sambar powder", 6, "g", SPICES), ("Oil", 8, "ml", OILS)),
    _f("bisi_bele_bath", "Bisi Bele Bath", "🍲", "Karnataka", VEG, 480, 15, 76, 13, 9,
       ("Sona masoori rice", 70, "g", GRAINS), ("Toor dal", 40, "g", PULSES), ("Mixed vegetables", 120, "g", VEGGIES),
       ("BBB masala", 8, "g", SPICES), ("Ghee", 8, "g", OILS)),
    _f("rasam_rice", "Rasam Rice & Beans Palya", "🍲", "South Indian", VEG, 400, 11, 72, 7, 8,
       ("Sona masoori rice", 80, "g", GRAINS), ("Toor dal", 20, "g", PULSES), ("Tomato", 80, "g", VEGGIES),
       ("Beans", 100, "g", VEGGIES), ("Rasam powder", 5, "g", SPICES)),
    _f("curd_rice", "Curd Rice & Pickle", "🍚", "South Indian", VEG, 330, 10, 54, 8, 2,
       ("Sona masoori rice", 70, "g", GRAINS), ("Curd", 150, "g", DAIRY), ("Cucumber & pomegranate", 50, "g", VEGGIES)),
    _f("ragi_mudde", "Ragi Mudde with Soppu Saaru", "🍲", "Karnataka", VEG, 380, 12, 70, 6, 12,
       ("Ragi flour", 90, "g", GRAINS), ("Greens (soppu)", 120, "g", VEGGIES), ("Toor dal", 25, "g", PULSES)),
    _f("veg_pulao", "Vegetable Pulao & Raita", "🍚", "North Indian", VEG, 450, 11, 72, 13, 6,
       ("Basmati rice", 80, "g", GRAINS), ("Mixed vegetables", 120, "g", VEGGIES), ("Curd", 100, "g", DAIRY),
       ("Whole spices", 3, "g", SPICES), ("Ghee", 8, "g", OILS)),
    _f("dal_tadka_roti", "Dal Tadka with Phulka", "🫓", "North Indian", VEG, 420, 17, 66, 10, 12,
       ("Wheat atta", 70, "g", GRAINS), ("Toor dal", 50, "g", PULSES), ("Onion & tomato", 80, "g", VEGGIES),
       ("Ghee", 6, "g", OILS)),
    _f("rajma_chawal", "Rajma Chawal", "🍛", "North Indian", VEG, 520, 19, 86, 10, 14,
       ("Rajma (kidney beans)", 60, "g", PULSES), ("Basmati rice", 80, "g", GRAINS), ("Onion & tomato", 100, "g", VEGGIES),
       ("Oil", 8, "ml", OILS)),
    _f("chole_roti", "Chole with Phulka", "🫓", "North Indian", VEG, 480, 18, 72, 13, 15,
       ("Kabuli chana", 60, "g", PULSES), ("Wheat atta", 60, "g", GRAINS), ("Onion & tomato", 100, "g", VEGGIES),
       ("Chole masala", 6, "g", SPICES), ("Oil", 8, "ml", OILS)),
    _f("palak_paneer_roti", "Palak Paneer with Phulka", "🥬", "North Indian", VEG, 470, 22, 44, 23, 8,
       ("Spinach", 150, "g", VEGGIES), ("Paneer", 80, "g", DAIRY), ("Wheat atta", 60, "g", GRAINS), ("Ghee", 6, "g", OILS)),
    _f("paneer_bhurji_roti", "Paneer Bhurji with Phulka", "🧀", "North Indian", VEG, 500, 26, 42, 25, 6,
       ("Paneer", 100, "g", DAIRY), ("Wheat atta", 60, "g", GRAINS), ("Onion, tomato & capsicum", 100, "g", VEGGIES)),
    _f("dal_makhani_rice", "Dal Makhani & Jeera Rice", "🍲", "North Indian", VEG, 560, 18, 74, 20, 12,
       ("Whole urad", 50, "g", PULSES), ("Rajma (kidney beans)", 10, "g", PULSES), ("Basmati rice", 70, "g", GRAINS),
       ("Butter & cream", 20, "g", DAIRY)),
    _f("mixed_veg_roti", "Mixed Veg Sabzi with Phulka", "🥕", "North Indian", VEG, 380, 11, 58, 11, 10,
       ("Mixed vegetables", 200, "g", VEGGIES), ("Wheat atta", 70, "g", GRAINS), ("Oil", 8, "ml", OILS)),
    _f("bhindi_dal_roti", "Bhindi Masala, Dal & Phulka", "🫛", "North Indian", VEG, 440, 15, 64, 13, 13,
       ("Bhindi (okra)", 150, "g", VEGGIES), ("Moong dal", 35, "g", PULSES), ("Wheat atta", 60, "g", GRAINS), ("Oil", 10, "ml", OILS)),
    _f("khichdi_kadhi", "Moong Khichdi with Kadhi", "🥣", "Gujarati", VEG, 430, 16, 68, 10, 7,
       ("Raw rice", 50, "g", GRAINS), ("Moong dal", 40, "g", PULSES), ("Curd", 100, "g", DAIRY), ("Besan (gram flour)", 15, "g", PULSES)),
    _f("millet_bowl", "Foxtail Millet Veg Bowl", "🥗", "Fusion", VEG, 390, 13, 62, 10, 11,
       ("Foxtail millet", 70, "g", GRAINS), ("Mixed vegetables", 150, "g", VEGGIES), ("Chickpeas", 30, "g", PULSES), ("Oil", 6, "ml", OILS)),
    _f("avial_rice", "Kerala Matta Rice, Avial & Thoran", "🥥", "Kerala", VEG, 470, 11, 78, 13, 11,
       ("Kerala matta rice", 80, "g", GRAINS), ("Mixed vegetables", 180, "g", VEGGIES), ("Coconut", 30, "g", FRUIT),
       ("Coconut oil", 8, "ml", OILS)),
    _f("veg_biryani", "Veg Dum Biryani & Raita", "🍛", "Hyderabadi", VEG, 540, 12, 82, 18, 7,
       ("Basmati rice", 90, "g", GRAINS), ("Mixed vegetables", 120, "g", VEGGIES), ("Curd", 100, "g", DAIRY),
       ("Biryani masala", 6, "g", SPICES), ("Ghee", 12, "g", OILS)),
    _f("soya_pulao", "Soya Chunk Pulao", "🍚", "North Indian", VEG, 470, 24, 70, 10, 8,
       ("Soya chunks", 40, "g", PULSES), ("Basmati rice", 70, "g", GRAINS), ("Mixed vegetables", 80, "g", VEGGIES)),
    _f("tofu_stirfry", "Tofu & Veg Stir-fry with Brown Rice", "🥦", "Fusion", VEG, 430, 22, 52, 14, 8,
       ("Tofu", 120, "g", DAIRY), ("Brown rice", 60, "g", GRAINS), ("Broccoli & capsicum", 150, "g", VEGGIES)),
    _f("egg_curry_rice", "Egg Curry & Rice", "🥚", "South Indian", EGG, 520, 21, 70, 17, 5,
       ("Eggs", 2, "pcs", DAIRY), ("Sona masoori rice", 80, "g", GRAINS), ("Onion & tomato", 120, "g", VEGGIES), ("Oil", 10, "ml", OILS)),
    _f("chicken_curry_rice", "Chicken Curry & Rice", "🍗", "South Indian", NONVEG, 610, 36, 72, 18, 4,
       ("Chicken (curry cut)", 150, "g", MEAT), ("Sona masoori rice", 80, "g", GRAINS), ("Onion & tomato", 120, "g", VEGGIES),
       ("Chicken masala", 8, "g", SPICES), ("Oil", 10, "ml", OILS)),
    _f("grilled_chicken_salad", "Tandoori Chicken & Salad", "🥗", "North Indian", NONVEG, 380, 42, 14, 16, 5,
       ("Chicken breast", 180, "g", MEAT), ("Curd", 50, "g", DAIRY), ("Salad vegetables", 150, "g", VEGGIES), ("Lemon", 1, "pcs", FRUIT)),
    _f("chicken_roti", "Chicken Masala with Phulka", "🍗", "North Indian", NONVEG, 560, 38, 50, 21, 6,
       ("Chicken (curry cut)", 150, "g", MEAT), ("Wheat atta", 60, "g", GRAINS), ("Onion & tomato", 120, "g", VEGGIES), ("Oil", 10, "ml", OILS)),
    _f("chicken_biryani", "Chicken Dum Biryani & Raita", "🍛", "Hyderabadi", NONVEG, 680, 35, 80, 23, 4,
       ("Chicken (curry cut)", 150, "g", MEAT), ("Basmati rice", 90, "g", GRAINS), ("Curd", 100, "g", DAIRY),
       ("Biryani masala", 6, "g", SPICES), ("Ghee", 12, "g", OILS)),
    _f("fish_curry_rice", "Kerala Fish Curry & Matta Rice", "🐟", "Kerala", NONVEG, 540, 32, 70, 14, 5,
       ("Fish (seer / pomfret)", 150, "g", MEAT), ("Kerala matta rice", 80, "g", GRAINS), ("Coconut", 30, "g", FRUIT),
       ("Kodampuli", 5, "g", SPICES)),
    _f("chettinad_chicken", "Chettinad Chicken & Parotta", "🌶️", "Chettinad", NONVEG, 690, 36, 62, 32, 4,
       ("Chicken (curry cut)", 150, "g", MEAT), ("Maida", 70, "g", GRAINS), ("Chettinad masala", 8, "g", SPICES), ("Oil", 15, "ml", OILS)),
    _f("mutton_curry_rice", "Mutton Curry & Rice", "🍖", "South Indian", NONVEG, 690, 34, 72, 28, 4,
       ("Mutton", 150, "g", MEAT), ("Sona masoori rice", 80, "g", GRAINS), ("Onion & tomato", 120, "g", VEGGIES), ("Oil", 12, "ml", OILS)),
    _f("prawn_masala_rice", "Prawn Masala & Rice", "🦐", "Coastal", NONVEG, 520, 30, 70, 13, 4,
       ("Prawns", 150, "g", MEAT), ("Sona masoori rice", 80, "g", GRAINS), ("Coconut", 20, "g", FRUIT), ("Oil", 10, "ml", OILS)),
    _f("egg_fried_rice", "Egg Fried Rice & Veg Manchurian", "🍳", "Indo-Chinese", EGG, 560, 18, 78, 19, 5,
       ("Basmati rice", 80, "g", GRAINS), ("Eggs", 2, "pcs", DAIRY), ("Cabbage, carrot & beans", 150, "g", VEGGIES),
       ("Soy & chilli sauce", 15, "ml", OTHER)),
    _f("jain_dal_roti", "Jain Dal & Lauki Sabzi with Phulka", "🫓", "Jain", VEG, 400, 15, 64, 9, 11,
       ("Moong dal", 45, "g", PULSES), ("Lauki (bottle gourd)", 150, "g", VEGGIES), ("Wheat atta", 60, "g", GRAINS), ("Ghee", 6, "g", OILS)),
    _f("jain_paneer_roti", "Jain Paneer Tomato Sabzi & Phulka", "🧀", "Jain", VEG, 480, 24, 44, 23, 6,
       ("Paneer", 90, "g", DAIRY), ("Tomato", 120, "g", VEGGIES), ("Wheat atta", 60, "g", GRAINS)),
    _f("kids_pasta", "Veggie Whole-wheat Pasta", "🍝", "Fusion", VEG, 420, 15, 64, 12, 7,
       ("Whole-wheat pasta", 70, "g", GRAINS), ("Tomato & carrot", 120, "g", VEGGIES), ("Cheese", 20, "g", DAIRY)),
    _f("kids_paneer_wrap", "Paneer Kathi Roll", "🌯", "Fusion", VEG, 440, 20, 46, 19, 5,
       ("Wheat atta", 60, "g", GRAINS), ("Paneer", 70, "g", DAIRY), ("Capsicum & onion", 60, "g", VEGGIES)),
    _f("kids_idli_podi", "Mini Idli with Podi & Ghee", "🍥", "South Indian", VEG, 300, 9, 52, 7, 4,
       ("Idli rice", 60, "g", GRAINS), ("Urad dal", 20, "g", PULSES), ("Ghee", 6, "g", OILS), ("Podi", 8, "g", SPICES)),
    _f("veg_soup_salad", "Clear Veg Soup & Paneer Salad", "🥗", "Fusion", VEG, 280, 17, 22, 13, 7,
       ("Mixed vegetables", 150, "g", VEGGIES), ("Paneer", 60, "g", DAIRY), ("Salad vegetables", 100, "g", VEGGIES)),
    _f("chicken_soup", "Pepper Chicken Soup & Salad", "🍲", "South Indian", NONVEG, 300, 30, 14, 13, 4,
       ("Chicken (curry cut)", 120, "g", MEAT), ("Salad vegetables", 120, "g", VEGGIES), ("Black pepper & cumin", 4, "g", SPICES)),
    _f("dalia_khichdi", "Dalia Veg Khichdi", "🥣", "North Indian", VEG, 340, 13, 58, 7, 11,
       ("Broken wheat (dalia)", 60, "g", GRAINS), ("Moong dal", 30, "g", PULSES), ("Mixed vegetables", 100, "g", VEGGIES)),
    _f("methi_roti_dal", "Methi Roti, Dal & Salad", "🫓", "North Indian", VEG, 390, 16, 58, 10, 13,
       ("Multigrain atta", 70, "g", GRAINS), ("Methi leaves", 30, "g", VEGGIES), ("Masoor dal", 40, "g", PULSES)),
]}


# Quick name/alias lookup for user/LLM-supplied dish names.
def find_food(query: str) -> Food | None:
    q = query.strip().lower()
    if q in FOODS:
        return FOODS[q]
    for f in FOODS.values():
        if f.name.lower() == q:
            return f
    for f in FOODS.values():
        if q in f.name.lower() or f.name.lower() in q:
            return f
    return None


def search_foods(query: str = "", diet: str | None = None, limit: int = 20) -> list[Food]:
    q = query.strip().lower()
    out = [
        f for f in FOODS.values()
        if (not q or q in f.name.lower() or q in f.cuisine.lower())
        and (diet is None or _diet_ok(f.diet, diet))
    ]
    return out[:limit]


def _diet_ok(food_diet: str, wanted: str) -> bool:
    order = {VEG: 0, EGG: 1, NONVEG: 2}
    return order.get(food_diet, 2) <= order.get(wanted, 2)
