# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

require "open-uri"

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

  # Sample recipes
  recipes_data = [
    {
      name: "Classic Spaghetti Carbonara",
      prep_time: 10,
      cook_time: 20,
      servings: 4,
      favorite: true,
      image_seed: 101,
      ingredients: [
        "400g spaghetti",
        "200g guanciale or pancetta, diced",
        "4 large egg yolks",
        "100g Pecorino Romano, finely grated",
        "Freshly ground black pepper",
        "Salt for pasta water"
      ],
      instructions: [
        "Bring a large pot of salted water to boil. Cook spaghetti until al dente.",
        "While pasta cooks, fry guanciale in a large pan until crispy.",
        "Whisk egg yolks with Pecorino and plenty of black pepper.",
        "Reserve 1 cup pasta water, then drain pasta.",
        "Toss hot pasta with guanciale (off heat), then quickly mix in egg mixture.",
        "Add pasta water as needed for silky sauce. Serve immediately."
      ],
      tags: [ "Dinner", "Quick & Easy" ]
    },
    {
      name: "Overnight Oats",
      prep_time: 5,
      cook_time: 0,
      servings: 1,
      favorite: false,
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
      name: "Banana Bread",
      prep_time: 15,
      cook_time: 60,
      servings: 8,
      favorite: true,
      image_seed: 202,
      notes: "Best with very ripe bananas - the blacker the better!",
      ingredients: [
        "3 very ripe bananas",
        "75g melted butter",
        "150g sugar",
        "1 egg, beaten",
        "1 tsp vanilla extract",
        "1 tsp baking soda",
        "Pinch of salt",
        "190g all-purpose flour"
      ],
      instructions: [
        "Preheat oven to 175°C. Butter a loaf pan.",
        "Mash bananas in a bowl until smooth.",
        "Mix in melted butter, sugar, egg, and vanilla.",
        "Add baking soda and salt, then fold in flour until just combined.",
        "Pour into loaf pan and bake for 60 minutes until golden.",
        "Cool in pan for 10 minutes before removing."
      ],
      tags: [ "Baking", "Dessert", "Vegetarian" ]
    },
    {
      name: "Quick Veggie Stir Fry",
      prep_time: 10,
      cook_time: 10,
      servings: 2,
      favorite: false,
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
      name: "Chocolate Chip Cookies",
      prep_time: 20,
      cook_time: 12,
      servings: 24,
      favorite: true,
      image_seed: 303,
      notes: "Don't overbake - they'll firm up as they cool!",
      ingredients: [
        "225g butter, softened",
        "200g brown sugar",
        "100g white sugar",
        "2 eggs",
        "1 tsp vanilla",
        "350g flour",
        "1 tsp baking soda",
        "1 tsp salt",
        "300g chocolate chips"
      ],
      instructions: [
        "Cream butter and sugars until fluffy.",
        "Beat in eggs and vanilla.",
        "Mix flour, baking soda, and salt. Add to wet ingredients.",
        "Fold in chocolate chips.",
        "Chill dough for 30 minutes.",
        "Scoop onto baking sheets, bake at 190°C for 10-12 minutes.",
        "Cool on pan for 5 minutes before transferring."
      ],
      tags: [ "Baking", "Dessert" ]
    },
    {
      name: "Greek Salad",
      prep_time: 15,
      cook_time: 0,
      servings: 4,
      favorite: false,
      image_seed: 404,
      ingredients: [
        "4 large tomatoes, chunked",
        "1 cucumber, sliced",
        "1 red onion, thinly sliced",
        "200g feta cheese, cubed",
        "100g Kalamata olives",
        "2 tbsp olive oil",
        "1 tbsp red wine vinegar",
        "1 tsp dried oregano",
        "Salt and pepper"
      ],
      instructions: [
        "Combine tomatoes, cucumber, and onion in a large bowl.",
        "Add feta and olives on top.",
        "Whisk olive oil, vinegar, oregano, salt, and pepper.",
        "Drizzle dressing over salad. Serve immediately."
      ],
      tags: [ "Lunch", "Quick & Easy", "Vegetarian" ]
    },
    {
      name: "Beef Tacos",
      prep_time: 15,
      cook_time: 20,
      servings: 4,
      favorite: true,
      image_seed: 505,
      ingredients: [
        "500g ground beef",
        "1 onion, diced",
        "2 cloves garlic, minced",
        "2 tbsp taco seasoning",
        "8 taco shells",
        "Shredded lettuce",
        "Diced tomatoes",
        "Shredded cheese",
        "Sour cream",
        "Salsa"
      ],
      instructions: [
        "Brown beef in a skillet, breaking it up as it cooks.",
        "Add onion and garlic, cook until softened.",
        "Stir in taco seasoning and 1/4 cup water. Simmer 5 minutes.",
        "Warm taco shells according to package directions.",
        "Fill shells with beef and top with desired toppings."
      ],
      tags: [ "Dinner" ]
    },
    {
      name: "Fluffy Pancakes",
      prep_time: 10,
      cook_time: 15,
      servings: 4,
      favorite: false,
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
      name: "Tomato Basil Soup",
      prep_time: 10,
      cook_time: 30,
      servings: 6,
      favorite: true,
      image_seed: 606,
      notes: "Pairs perfectly with grilled cheese sandwiches.",
      ingredients: [
        "2 tbsp olive oil",
        "1 onion, diced",
        "3 cloves garlic, minced",
        "800g canned crushed tomatoes",
        "500ml vegetable broth",
        "1/4 cup fresh basil, chopped",
        "1/2 cup heavy cream",
        "Salt and pepper"
      ],
      instructions: [
        "Heat oil in a pot, sauté onion until soft.",
        "Add garlic, cook 1 minute.",
        "Add tomatoes and broth, bring to a boil.",
        "Reduce heat, simmer 20 minutes.",
        "Blend until smooth with an immersion blender.",
        "Stir in cream and basil. Season to taste."
      ],
      tags: [ "Lunch", "Dinner", "Vegetarian" ]
    },
    {
      name: "Garlic Butter Shrimp",
      prep_time: 10,
      cook_time: 8,
      servings: 2,
      favorite: false,
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
      name: "Chicken Alfredo",
      prep_time: 15,
      cook_time: 25,
      servings: 4,
      favorite: true,
      image_seed: 707,
      ingredients: [
        "400g fettuccine",
        "2 chicken breasts",
        "2 tbsp olive oil",
        "4 cloves garlic, minced",
        "500ml heavy cream",
        "150g Parmesan, grated",
        "Salt and pepper",
        "Fresh parsley for garnish"
      ],
      instructions: [
        "Cook pasta according to package directions.",
        "Season chicken, cook in olive oil until done. Slice.",
        "In same pan, sauté garlic 1 minute.",
        "Add cream, bring to simmer.",
        "Stir in Parmesan until melted and smooth.",
        "Toss pasta with sauce, top with chicken and parsley."
      ],
      tags: [ "Dinner" ]
    },
    {
      name: "Caprese Salad",
      prep_time: 10,
      cook_time: 0,
      servings: 2,
      favorite: false,
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
    },
    {
      name: "Slow Cooker Pulled Pork",
      prep_time: 20,
      cook_time: 480,
      servings: 10,
      favorite: true,
      image_seed: 808,
      notes: "8 hours on low or 4 hours on high. Great for meal prep!",
      source_url: "https://example.com/pulled-pork",
      ingredients: [
        "2kg pork shoulder",
        "2 tbsp brown sugar",
        "1 tbsp paprika",
        "1 tbsp garlic powder",
        "1 tsp cumin",
        "Salt and pepper",
        "250ml apple cider vinegar",
        "250ml BBQ sauce",
        "Burger buns for serving"
      ],
      instructions: [
        "Mix brown sugar and spices, rub all over pork.",
        "Place pork in slow cooker, pour vinegar around it.",
        "Cook on low for 8 hours until falling apart.",
        "Shred pork with two forks, discard fat.",
        "Mix shredded pork with BBQ sauce.",
        "Serve on buns with coleslaw."
      ],
      tags: [ "Dinner" ]
    }
  ]

  recipes_data.each do |recipe_data|
    tag_names = recipe_data.delete(:tags)
    image_seed = recipe_data.delete(:image_seed)

    recipe = test_user.recipes.find_or_create_by!(name: recipe_data[:name]) do |r|
      r.assign_attributes(recipe_data)
    end
    recipe.tags = Tag.where(name: tag_names)

    # Attach placeholder image if specified and not already attached
    if image_seed && !recipe.cover_image.attached?
      # picsum.photos provides consistent images based on seed
      image_url = "https://picsum.photos/seed/#{image_seed}/800/600"
      begin
        image_file = URI.open(image_url)
        recipe.cover_image.attach(
          io: image_file,
          filename: "#{recipe.name.parameterize}.jpg",
          content_type: "image/jpeg"
        )
        print "."
      rescue OpenURI::HTTPError => e
        puts "  ⚠ Could not download image for #{recipe.name}: #{e.message}"
      end
    end
  end

  puts ""
  puts "✓ Created #{test_user.recipes.count} recipes for test user"
end
