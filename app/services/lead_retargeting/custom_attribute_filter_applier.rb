# frozen_string_literal: true

module LeadRetargeting
  class CustomAttributeFilterApplier
    MAX_FILTERS = 10

    TEXT_OPERATORS   = %w[equals not_equals contains not_contains starts_with ends_with present blank].freeze
    NUMBER_OPERATORS = %w[equals not_equals greater_than less_than gte lte between present blank].freeze
    DATE_OPERATORS   = %w[before after between present blank].freeze
    LIST_OPERATORS   = %w[equals not_equals includes_any present blank].freeze
    BOOL_OPERATORS   = %w[equals present blank].freeze

    OPERATORS_BY_TYPE = {
      'text' => TEXT_OPERATORS,
      'link' => TEXT_OPERATORS,
      'number' => NUMBER_OPERATORS,
      'currency' => NUMBER_OPERATORS,
      'percent' => NUMBER_OPERATORS,
      'date' => DATE_OPERATORS,
      'datetime' => DATE_OPERATORS,
      'checkbox' => BOOL_OPERATORS,
      'list' => LIST_OPERATORS
    }.freeze

    def self.call(scope, filters)
      new(scope, filters).apply
    end

    def initialize(scope, filters)
      @scope   = scope
      @filters = Array(filters).first(MAX_FILTERS)
    end

    def apply
      needs_contact_join = @filters.any? { |f| f['entity'] == 'contact' }
      result = needs_contact_join ? @scope.joins(:contact) : @scope

      @filters.each do |filter|
        next unless valid_filter?(filter)

        result = apply_filter(result, filter)
      end

      result
    end

    private

    def valid_filter?(filter_obj)
      filter_obj['entity'].in?(%w[contact conversation]) &&
        filter_obj['attribute_key'].present? &&
        filter_obj['operator'].present?
    end

    def apply_filter(scope, filter)
      table    = filter['entity'] == 'contact' ? 'contacts' : 'conversations'
      key      = filter['attribute_key']
      operator = filter['operator']
      value    = filter['value']
      value2   = filter['value2']
      attr_type = filter['attribute_display_type'] || 'text'

      sql, binds = build_condition(table, key, operator, value, value2, attr_type)
      return scope unless sql

      scope.where(sql, *binds)
    end

    def build_condition(table, key, operator, value, value2, attr_type) # rubocop:disable Metrics/MethodLength,Metrics/CyclomaticComplexity,Metrics/ParameterLists,Metrics/PerceivedComplexity
      col = "#{table}.custom_attributes"

      case operator
      when 'present'
        ["#{col}->>? IS NOT NULL", [key]]
      when 'blank'
        ["(#{col}->>? IS NULL OR #{col}->>? = '')", [key, key]]
      when 'equals'
        cast_equals(col, key, value, attr_type)
      when 'not_equals'
        sql, binds = cast_equals(col, key, value, attr_type)
        return unless sql

        ["NOT (#{sql})", binds]
      when 'contains'
        ["#{col}->>? ILIKE ?", [key, "%#{sanitize_like(value)}%"]]
      when 'not_contains'
        ["#{col}->>? NOT ILIKE ?", [key, "%#{sanitize_like(value)}%"]]
      when 'starts_with'
        ["#{col}->>? ILIKE ?", [key, "#{sanitize_like(value)}%"]]
      when 'ends_with'
        ["#{col}->>? ILIKE ?", [key, "%#{sanitize_like(value)}"]]
      when 'greater_than', 'after'
        numeric_or_date_op(col, key, '>', value, attr_type)
      when 'less_than', 'before'
        numeric_or_date_op(col, key, '<', value, attr_type)
      when 'gte'
        numeric_or_date_op(col, key, '>=', value, attr_type)
      when 'lte'
        numeric_or_date_op(col, key, '<=', value, attr_type)
      when 'between'
        between_condition(col, key, value, value2, attr_type)
      when 'includes_any'
        values = Array(value).map(&:to_s)
        return if values.empty?

        placeholders = values.map { '?' }.join(', ')
        ["#{col}->>? IN (#{placeholders})", [key, *values]]
      end
    end

    def cast_equals(col, key, value, type)
      case type
      when 'number', 'currency', 'percent'
        ["(#{col}->>?)::numeric = ?", [key, value.to_f]]
      when 'date'
        ["(#{col}->>?)::date = ?", [key, value.to_s]]
      when 'datetime'
        ["(#{col}->>?)::timestamptz = ?", [key, value.to_s]]
      when 'checkbox'
        bool = ActiveModel::Type::Boolean.new.cast(value)
        ["(#{col}->>?)::boolean = ?", [key, bool]]
      else
        # text y list: usa @> para aprovechar GIN index en igualdad exacta
        ["#{col} @> jsonb_build_object(?, ?::text)", [key, value.to_s]]
      end
    end

    def numeric_or_date_op(col, key, operator, value, type)
      cast = resolve_cast(type)
      return unless cast

      ["(#{col}->>?)::#{cast} #{operator} ?", [key, value]]
    end

    def between_condition(col, key, value, value2, type)
      return unless value.present? && value2.present?

      cast = resolve_cast(type)
      return unless cast

      ["(#{col}->>?)::#{cast} BETWEEN ? AND ?", [key, value, value2]]
    end

    def resolve_cast(type)
      case type
      when 'number', 'currency', 'percent' then 'numeric'
      when 'date'                           then 'date'
      when 'datetime'                       then 'timestamptz'
      end
    end

    def sanitize_like(value)
      ActiveRecord::Base.sanitize_sql_like(value.to_s)
    end
  end
end
