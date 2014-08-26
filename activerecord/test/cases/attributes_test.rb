require 'cases/helper'

class OverloadedType < ActiveRecord::Base
  attribute :overloaded_float, Type::Integer.new
  attribute :overloaded_string_with_limit, Type::String.new(limit: 50)
  attribute :non_existent_decimal, Type::Decimal.new
  attribute :string_with_default, Type::String.new, default: 'the overloaded default'
end

class ChildOfOverloadedType < OverloadedType
end

class GrandchildOfOverloadedType < ChildOfOverloadedType
  attribute :overloaded_float, Type::Float.new
end

class UnoverloadedType < ActiveRecord::Base
  self.table_name = 'overloaded_types'
end

module ActiveRecord
  class CustomPropertiesTest < ActiveRecord::TestCase
    def test_overloading_types
      data = OverloadedType.new

      data.overloaded_float = "1.1"
      data.unoverloaded_float = "1.1"

      assert_equal 1, data.overloaded_float
      assert_equal 1.1, data.unoverloaded_float
    end

    def test_overloaded_properties_save
      data = OverloadedType.new

      data.overloaded_float = "2.2"
      data.save!
      data.reload

      assert_equal 2, data.overloaded_float
      assert_kind_of Fixnum, OverloadedType.last.overloaded_float
      assert_equal 2.0, UnoverloadedType.last.overloaded_float
      assert_kind_of Float, UnoverloadedType.last.overloaded_float
    end

    def test_properties_assigned_in_constructor
      data = OverloadedType.new(overloaded_float: '3.3')

      assert_equal 3, data.overloaded_float
    end

    def test_overloaded_properties_with_limit
      assert_equal 50, OverloadedType.columns_hash['overloaded_string_with_limit'].limit
      assert_equal 255, UnoverloadedType.columns_hash['overloaded_string_with_limit'].limit
    end

    def test_nonexistent_attribute
      data = OverloadedType.new(non_existent_decimal: 1)

      assert_equal BigDecimal.new(1), data.non_existent_decimal
      assert_raise ActiveRecord::UnknownAttributeError do
        UnoverloadedType.new(non_existent_decimal: 1)
      end
    end

    def test_changing_defaults
      data = OverloadedType.new
      unoverloaded_data = UnoverloadedType.new

      assert_equal 'the overloaded default', data.string_with_default
      assert_equal 'the original default', unoverloaded_data.string_with_default
    end

    def test_children_inherit_custom_properties
      data = ChildOfOverloadedType.new(overloaded_float: '4.4')

      assert_equal 4, data.overloaded_float
    end

    def test_children_can_override_parents
      data = GrandchildOfOverloadedType.new(overloaded_float: '4.4')

      assert_equal 4.4, data.overloaded_float
    end

    def test_overloading_properties_does_not_change_column_order
      column_names = OverloadedType.column_names
      assert_equal %w(id overloaded_float unoverloaded_float overloaded_string_with_limit string_with_default non_existent_decimal), column_names
    end

    def test_caches_are_cleared
      klass = Class.new(OverloadedType)

      assert_equal 6, klass.columns.length
      assert_not klass.columns_hash.key?('wibble')
      assert_equal 6, klass.column_types.length
      assert_equal 6, klass.column_defaults.length
      assert_not klass.column_names.include?('wibble')
      assert_equal 5, klass.content_columns.length

      klass.attribute :wibble, Type::Value.new

      assert_equal 7, klass.columns.length
      assert klass.columns_hash.key?('wibble')
      assert_equal 7, klass.column_types.length
      assert_equal 7, klass.column_defaults.length
      assert klass.column_names.include?('wibble')
      assert_equal 6, klass.content_columns.length
    end
  end
end
