# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create tags
[ "Breakfast", "Lunch", "Dinner", "Baking", "Dessert", "Quick & Easy", "Vegetarian" ].each do |tag_name|
  Tag.find_or_create_by!(name: tag_name)
end

puts "✓ Created #{Tag.count} tags"
