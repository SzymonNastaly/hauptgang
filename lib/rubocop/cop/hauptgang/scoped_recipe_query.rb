# frozen_string_literal: true

module RuboCop
  module Cop
    module Hauptgang
      # Detects unscoped Recipe queries that may leak data across users.
      #
      # In a multi-user application, queries like `Recipe.count` or
      # `Recipe.where(...).count` return data for ALL users, not just
      # the current user. This is a security vulnerability.
      #
      # @example Bad
      #   Recipe.count
      #   Recipe.all
      #   Recipe.where(favorite: true).count
      #   Recipe.find(params[:id])
      #
      # @example Good
      #   Current.user.recipes.count
      #   Current.user.recipes.favorited.count
      #   Current.user.recipes.find(params[:id])
      #
      class ScopedRecipeQuery < Base
        MSG = "Avoid unscoped `Recipe` queries. Use `Current.user.recipes` " \
              "to ensure data is scoped to the current user."

        # These are ActiveRecord query methods that, when called on Recipe directly,
        # will return data for all users instead of just the current user.
        QUERY_METHODS = %i[
          count all where find find_by first last pluck ids
          exists? any? none? many? sum average minimum maximum
          order limit offset select distinct
        ].to_set.freeze

        # Pattern: Recipe.count, Recipe.all, Recipe.where, etc.
        # This matches (send (const nil? :Recipe) <method>)
        # - (send ...) is a method call
        # - (const nil? :Recipe) is the constant Recipe at the top level
        # - The method name is captured by the code below
        def on_send(node)
          return unless unscoped_recipe_query?(node)
          return unless in_app_code?
          return if in_test_file?

          add_offense(node)
        end

        private

        def unscoped_recipe_query?(node)
          receiver = node.receiver
          return false unless receiver

          # Check if receiver is the Recipe constant
          return false unless receiver.const_type?
          return false unless receiver.children == [ nil, :Recipe ]

          # Check if the method is a query method
          QUERY_METHODS.include?(node.method_name)
        end

        def in_app_code?
          path = processed_source.file_path.to_s
          path.include?("/app/") || path.include?("/lib/")
        end

        def in_test_file?
          path = processed_source.file_path.to_s
          path.include?("/test/") || path.include?("/spec/")
        end
      end
    end
  end
end
