# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create tags
[ "Breakfast", "Lunch", "Dinner", "Baking", "Dessert", "Quick & Easy", "Vegetarian" ].each do |tag_name|
  Tag.find_or_create_by!(name: tag_name)
end

puts "✓ Created #{Tag.count} tags"

# Development seed data
if Rails.env.development?
  # Create test user
  test_user = User.find_or_create_by!(email_address: "test@example.com") do |user|
    user.password = "password123"
  end
  puts "✓ Test user: test@example.com / password123"

  test_cookbook = test_user.cookbooks.personal.first

  # Sample recipes
  recipes_data = [
    {
      name: "Overnight Oats",
      prep_time: 5,
      cook_time: 0,
      servings: 1,
      favorite: false,
      image_file: "overnight-oats.jpg",
      ingredients: [
        "50g rolled oats",
        "150ml milk of choice",
        "1 tbsp chia seeds",
        "1 tbsp maple syrup",
        "Pinch of salt",
        "Fresh berries for topping"
      ],
      instructions: [
        "Combine oats, milk, chia seeds, maple syrup, and salt in a jar.",
        "Stir well, cover, and refrigerate overnight.",
        "In the morning, top with fresh berries and enjoy cold."
      ],
      tags: [ "Breakfast", "Quick & Easy", "Vegetarian" ]
    },
    {
      name: "Quick Veggie Stir Fry",
      prep_time: 10,
      cook_time: 10,
      servings: 2,
      favorite: false,
      image_file: "quick-veggie-stir-fry.jpg",
      source_url: "https://example.com/stir-fry",
      ingredients: [
        "2 tbsp vegetable oil",
        "2 cloves garlic, minced",
        "1 bell pepper, sliced",
        "1 zucchini, sliced",
        "150g broccoli florets",
        "3 tbsp soy sauce",
        "1 tbsp sesame oil",
        "Cooked rice for serving"
      ],
      instructions: [
        "Heat oil in a wok over high heat.",
        "Add garlic and stir for 30 seconds.",
        "Add vegetables and stir fry for 5-7 minutes until tender-crisp.",
        "Add soy sauce and sesame oil, toss to coat.",
        "Serve immediately over rice."
      ],
      tags: [ "Dinner", "Quick & Easy", "Vegetarian" ]
    },
    {
      name: "Fluffy Pancakes",
      prep_time: 10,
      cook_time: 15,
      servings: 4,
      favorite: false,
      image_file: "fluffy-pancakes.jpg",
      ingredients: [
        "200g all-purpose flour",
        "2 tbsp sugar",
        "2 tsp baking powder",
        "1/2 tsp salt",
        "1 egg",
        "250ml milk",
        "30g melted butter",
        "1 tsp vanilla extract"
      ],
      instructions: [
        "Whisk flour, sugar, baking powder, and salt in a bowl.",
        "In another bowl, beat egg with milk, butter, and vanilla.",
        "Pour wet ingredients into dry, stir until just combined (lumps are fine).",
        "Heat a griddle over medium heat, lightly grease.",
        "Pour 1/4 cup batter per pancake, cook until bubbles form.",
        "Flip and cook until golden. Serve with maple syrup."
      ],
      tags: [ "Breakfast", "Vegetarian" ]
    },
    {
      name: "Garlic Butter Shrimp",
      prep_time: 10,
      cook_time: 8,
      servings: 2,
      favorite: false,
      image_file: "garlic-butter-shrimp.jpg",
      ingredients: [
        "400g large shrimp, peeled and deveined",
        "4 tbsp butter",
        "6 cloves garlic, minced",
        "1/4 cup white wine",
        "Juice of 1 lemon",
        "2 tbsp fresh parsley, chopped",
        "Salt and pepper",
        "Crusty bread for serving"
      ],
      instructions: [
        "Pat shrimp dry, season with salt and pepper.",
        "Melt butter in a large skillet over medium-high heat.",
        "Add shrimp in single layer, cook 2 minutes per side.",
        "Remove shrimp, add garlic to pan, cook 30 seconds.",
        "Add wine and lemon juice, scrape up any bits.",
        "Return shrimp, toss with parsley. Serve with bread."
      ],
      tags: [ "Dinner", "Quick & Easy" ]
    },
    {
      name: "Avocado Toast",
      prep_time: 5,
      cook_time: 3,
      servings: 1,
      favorite: false,
      image_file: "avocado-toast.jpg",
      ingredients: [
        "2 slices sourdough bread",
        "1 ripe avocado",
        "1/2 lemon, juiced",
        "Red pepper flakes",
        "Flaky sea salt",
        "Everything bagel seasoning (optional)"
      ],
      instructions: [
        "Toast bread until golden and crispy.",
        "Mash avocado with lemon juice and a pinch of salt.",
        "Spread avocado on toast.",
        "Top with red pepper flakes and flaky salt."
      ],
      tags: [ "Breakfast", "Quick & Easy", "Vegetarian" ]
    },
    {
      name: "Caprese Salad",
      prep_time: 10,
      cook_time: 0,
      servings: 2,
      favorite: false,
      image_file: "caprese-salad.jpg",
      ingredients: [
        "3 large ripe tomatoes, sliced",
        "250g fresh mozzarella, sliced",
        "Fresh basil leaves",
        "3 tbsp extra virgin olive oil",
        "1 tbsp balsamic glaze",
        "Flaky sea salt",
        "Freshly ground black pepper"
      ],
      instructions: [
        "Arrange tomato and mozzarella slices alternating on a platter.",
        "Tuck basil leaves between slices.",
        "Drizzle with olive oil and balsamic glaze.",
        "Season with salt and pepper. Serve immediately."
      ],
      tags: [ "Lunch", "Quick & Easy", "Vegetarian" ]
    }
  ]

  IMAGE_CONTENT_TYPES = {
    ".jpg" => "image/jpeg",
    ".jpeg" => "image/jpeg",
    ".png" => "image/png",
    ".webp" => "image/webp"
  }.freeze

  recipes_by_name = {}

  recipes_data.each do |recipe_data|
    tag_names = recipe_data.delete(:tags)
    image_file = recipe_data.delete(:image_file)

    recipe = test_user.recipes.find_or_create_by!(name: recipe_data[:name]) do |r|
      r.cookbook = test_cookbook
      r.assign_attributes(recipe_data)
    end
    recipe.update!(cookbook: test_cookbook) if recipe.cookbook_id != test_cookbook.id
    recipe.tags = Tag.where(name: tag_names)
    recipes_by_name[recipe.name] = recipe

    next if image_file.blank? || recipe.cover_image.attached?

    image_path = Rails.root.join("db/seeds_assets/recipes", image_file)
    unless File.exist?(image_path)
      puts "  ⚠ Missing seed image: #{image_path} — skipping attachment for #{recipe.name}"
      next
    end

    content_type = IMAGE_CONTENT_TYPES[File.extname(image_file).downcase] || "image/jpeg"
    File.open(image_path, "rb") do |io|
      recipe.cover_image.attach(io: io, filename: image_file, content_type: content_type)
    end
    print "."
  end

  puts ""
  puts "✓ Created #{test_user.recipes.count} recipes for test user"

  # Shopping list items
  shopping_items = [
    { client_id: "seed-milk", name: "Milk", checked_at: nil },
    { client_id: "seed-olive-oil", name: "Olive oil", checked_at: nil },
    { client_id: "seed-bananas", name: "Bananas", checked_at: nil },
    { client_id: "seed-shrimp", name: "Large shrimp", checked_at: nil, source_recipe: recipes_by_name["Garlic Butter Shrimp"] },
    { client_id: "seed-mozzarella", name: "Fresh mozzarella", checked_at: nil, source_recipe: recipes_by_name["Caprese Salad"] },
    { client_id: "seed-bread", name: "Sourdough bread", checked_at: 5.minutes.ago },
    { client_id: "seed-eggs", name: "Eggs", checked_at: 2.hours.ago }
  ]

  shopping_items.each do |attrs|
    test_cookbook.shopping_list_items.find_or_create_by!(client_id: attrs[:client_id]) do |item|
      item.user = test_user
      item.name = attrs[:name]
      item.checked_at = attrs[:checked_at]
      item.source_recipe = attrs[:source_recipe]
    end
  end

  puts "✓ Created #{test_cookbook.shopping_list_items.count} shopping list items"

  # Meal plan
  today_plan = test_cookbook.meal_plans.find_or_create_by!(date: Date.current)
  [ "Caprese Salad", "Garlic Butter Shrimp" ].each do |recipe_name|
    recipe = recipes_by_name[recipe_name]
    next unless recipe

    today_plan.entries.find_or_create_by!(recipe: recipe) do |entry|
      entry.proposed_by_user = test_user
    end
  end

  tomorrow_plan = test_cookbook.meal_plans.find_or_create_by!(date: Date.current + 1)
  if (stir_fry = recipes_by_name["Quick Veggie Stir Fry"])
    tomorrow_plan.entries.find_or_create_by!(recipe: stir_fry) do |entry|
      entry.proposed_by_user = test_user
    end
  end

  selected_plan = test_cookbook.meal_plans.find_or_create_by!(date: Date.current + 3)
  picks = [ recipes_by_name["Fluffy Pancakes"], recipes_by_name["Avocado Toast"] ].compact
  picks.each do |recipe|
    selected_plan.entries.find_or_create_by!(recipe: recipe) do |entry|
      entry.proposed_by_user = test_user
    end
  end

  if selected_plan.selected_entry_id.nil? && (chosen = selected_plan.entries.find_by(recipe: picks.first))
    selected_plan.update!(
      selected_entry: chosen,
      selected_by_user: test_user,
      selected_at: 1.hour.ago
    )
  end

  puts "✓ Created #{test_cookbook.meal_plans.count} meal plans (#{MealPlanEntry.where(meal_plan: test_cookbook.meal_plans).count} entries)"
end
