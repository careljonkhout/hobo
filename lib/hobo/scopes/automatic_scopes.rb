module Hobo
  
  module Scopes
    
    module AutomaticScopes
      
      def create_automatic_scope(name)
        ScopeBuilder.new(self, name).create_scope
      end
      
    end
    
    # The methods on this module add scopes to the given class
    class ScopeBuilder
      
      def initialize(klass, name)
        @klass = klass
        @name  = name.to_s
      end
      
      attr_reader :name
      
      def create_scope
        matched_scope = true
        
        # with_players(player1, player2)
        if name =~ /^with_(.*)/ && (refl = reflection($1))
          
          def_scope do |*records|
            records = records.flatten.compact.map {|r| find_if_named(refl, r) }
            exists_sql = ([exists_sql_condition(refl)] * records.length).join(" AND ")
            { :conditions => [exists_sql] + records }
          end

        # with_player(a_player)
        elsif name =~ /^with_(.*)/ && (refl = reflection($1.pluralize))
          
          exists_sql = exists_sql_condition(refl)
          def_scope do |record|
            record = find_if_named(refl, record)
            { :conditions => [exists_sql, record] }
          end
          
        # without_players(player1, player2)
        elsif name =~ /^without_(.*)/ && (refl = reflection($1))
          
          def_scope do |*records|
            records = records.flatten.compact.map {|r| find_if_named(refl, r) }
            exists_sql = ([exists_sql_condition(refl)] * records.length).join(" AND ")
            { :conditions => ["NOT (#{exists_sql})"] + records }
          end

        # without_player(a_player)
        elsif name =~ /^without_(.*)/ && (refl = reflection($1.pluralize))
          
          exists_sql = exists_sql_condition(refl)
          def_scope do |record|
            record = find_if_named(refl, record)
            { :conditions => ["NOT #{exists_sql}", record] }
          end


        # team_is(a_team)
        elsif name =~ /^(.*)_is$/ && (refl = reflection($1)) && refl.macro.in?([:has_one, :belongs_to])
          
          if refl.options[:polymorphic]
            def_scope do |record|
              record = find_if_named(refl, record)
              { :conditions => ["#{foreign_key_column refl} = ? AND #{$1}_type = ?", record, record.class.name] }
            end
          else
            def_scope do |record|
              record = find_if_named(refl, record)
              { :conditions => ["#{foreign_key_column refl} = ?", record] }
            end
          end
            
        # team_is(a_team)
        elsif name =~ /^(.*)_is_not$/ && (refl = reflection($1)) && refl.macro.in?([:has_one, :belongs_to])
          
          if refl.options[:polymorphic]
            def_scope do |record|
              record = find_if_named(refl, record)
              { :conditions => ["#{foreign_key_column refl} <> ? OR #{name}_type <> ?", record, record.class.name] }
            end
          else
            def_scope do |record|
              record = find_if_named(refl, record)
              { :conditions => ["#{foreign_key_column refl} <> ?", record] }
            end
          end
          
        else
        
          case name
            
          when "recent"
            def_scope do |*args|
              count = args.first || 3
              { :limit => count, :order => "#{table_name}.created_at DESC" }
            end
            
          when "limit"
            def_scope do |count|
              { :limit => count }
            end
            
          else
            matched_scope = false
          end
          
        end
        matched_scope
      end
      
      
      def exists_sql_condition(reflection)
        owner = @klass
        owner_primary_key = "#{owner.table_name}.#{owner.primary_key}"
        if reflection.options[:through]
          join_table   = reflection.through_reflection.klass.table_name
          source_fkey  = reflection.source_reflection.primary_key_name
          owner_fkey   = reflection.through_reflection.primary_key_name
          "EXISTS (SELECT * FROM #{join_table} " + 
            "WHERE #{join_table}.#{source_fkey} = ? AND #{join_table}.#{owner_fkey} = #{owner_primary_key})"
        else
          related     = reflection.klass
          foreign_key = reflection.primary_key_name
          
          "EXISTS (SELECT * FROM #{related.table_name} " + 
            "WHERE #{related.table_name}.#{foreign_key} = #{owner_primary_key} AND " +
            "#{related.table_name}.#{related.primary_key} = ?"
        end
      end
        
      
      
      def find_if_named(reflection, string_or_record)
        if string_or_record.is_a?(String)
          name = string_or_record
          reflection.klass.named(name)
        else
          string_or_record
        end
      end
      
      
      def reflection(name)
        @klass.reflections[name.to_sym]
      end
      
      def def_scope(options={}, &block)
        @klass.send(:def_scope, name, options, &block)
      end
      
      def primary_key_column(refl)
        "#{refl.klass.table_name}.#{refl.klass.primary_key}"
      end
      
      def foreign_key_column(refl)
        "#{@klass.table_name}.#{refl.primary_key_name}"
      end
            
    end
    
  end
  
end
