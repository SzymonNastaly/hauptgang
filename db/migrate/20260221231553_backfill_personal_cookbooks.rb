class BackfillPersonalCookbooks < ActiveRecord::Migration[8.1]
  def up
    users = execute("SELECT id FROM users")
    users.each do |row|
      user_id = row["id"]
      now = Time.current.utc.strftime("%Y-%m-%d %H:%M:%S.%6N")

      execute(<<~SQL)
        INSERT INTO cookbooks (name, personal, created_at, updated_at)
        VALUES ('My Recipes', 1, '#{now}', '#{now}')
      SQL

      cookbook_id = execute("SELECT last_insert_rowid() AS id").first["id"]

      execute(<<~SQL)
        INSERT INTO cookbook_memberships (cookbook_id, user_id, role, created_at, updated_at)
        VALUES (#{cookbook_id}, #{user_id}, 0, '#{now}', '#{now}')
      SQL

      execute("UPDATE recipes SET cookbook_id = #{cookbook_id} WHERE user_id = #{user_id} AND cookbook_id IS NULL")
      execute("UPDATE shopping_list_items SET cookbook_id = #{cookbook_id} WHERE user_id = #{user_id} AND cookbook_id IS NULL")
    end
  end

  def down
    execute("UPDATE recipes SET cookbook_id = NULL")
    execute("UPDATE shopping_list_items SET cookbook_id = NULL")
    execute("DELETE FROM cookbook_memberships")
    execute("DELETE FROM cookbooks")
  end
end
