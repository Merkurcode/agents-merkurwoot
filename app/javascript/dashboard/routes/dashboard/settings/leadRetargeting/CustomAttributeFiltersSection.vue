<script setup>
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  OPERATOR_I18N_KEYS,
  OPERATORS_BY_TYPE,
  needsTwoValues,
  needsNoValue,
} from 'dashboard/composables/useCustomAttributeFilterOperators';

const { t } = useI18n();

const props = defineProps({
  filters: {
    type: Array,
    default: () => [],
  },
  contactAttributes: {
    type: Array,
    default: () => [],
  },
  conversationAttributes: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['update:filters']);

const getAttributesForEntity = entity => {
  if (entity === 'contact') return props.contactAttributes;
  if (entity === 'conversation') return props.conversationAttributes;
  return [];
};

const getAttributeForKey = (entity, attributeKey) => {
  return getAttributesForEntity(entity).find(
    a => a.attributeKey === attributeKey
  );
};

const getAttributeDisplayType = (entity, attributeKey) => {
  return getAttributeForKey(entity, attributeKey)?.attributeDisplayType || 'text';
};

const getAttributeValues = (entity, attributeKey) => {
  return getAttributeForKey(entity, attributeKey)?.attributeValues || [];
};

const getOperatorsForFilter = filter => {
  if (!filter.attribute_key || !filter.entity) return [];
  const type = getAttributeDisplayType(filter.entity, filter.attribute_key);
  return (OPERATORS_BY_TYPE[type] || []).map(op => ({
    value: op,
    label: t(OPERATOR_I18N_KEYS[op]),
  }));
};

const addFilter = () => {
  emit('update:filters', [
    ...props.filters,
    {
      id: `caf_${Date.now()}`,
      entity: 'contact',
      attribute_key: '',
      attribute_display_type: 'text',
      operator: 'equals',
      value: '',
      value2: '',
    },
  ]);
};

const removeFilter = index => {
  emit(
    'update:filters',
    props.filters.filter((_, i) => i !== index)
  );
};

// Handles entity change: resets all dependent fields in a single emit
const onEntityChange = (index, newEntity) => {
  emit(
    'update:filters',
    props.filters.map((f, i) => {
      if (i !== index) return f;
      return {
        ...f,
        entity: newEntity,
        attribute_key: '',
        attribute_display_type: 'text',
        operator: 'equals',
        value: '',
        value2: '',
      };
    })
  );
};

// Handles attribute change: resolves type + first valid operator in a single emit
const onAttributeChange = (index, newAttributeKey) => {
  const filter = props.filters[index];
  const type = getAttributeDisplayType(filter.entity, newAttributeKey);
  const ops = OPERATORS_BY_TYPE[type] || [];
  emit(
    'update:filters',
    props.filters.map((f, i) => {
      if (i !== index) return f;
      return {
        ...f,
        attribute_key: newAttributeKey,
        attribute_display_type: type,
        operator: ops[0] || 'equals',
        value: '',
        value2: '',
      };
    })
  );
};

// Handles operator change: resets values in a single emit
const onOperatorChange = (index, newOperator) => {
  emit(
    'update:filters',
    props.filters.map((f, i) => {
      if (i !== index) return f;
      return { ...f, operator: newOperator, value: '', value2: '' };
    })
  );
};

const updateValue = (index, value) => {
  emit(
    'update:filters',
    props.filters.map((f, i) => (i !== index ? f : { ...f, value }))
  );
};

const updateValue2 = (index, value2) => {
  emit(
    'update:filters',
    props.filters.map((f, i) => (i !== index ? f : { ...f, value2 }))
  );
};
</script>

<template>
  <div class="border border-n-weak/60 rounded-lg p-4 space-y-4">
    <div class="flex items-center justify-between">
      <div>
        <h4 class="font-semibold text-sm text-n-slate-12">
          {{
            t(
              'LEAD_RETARGETING.FORM.CUSTOM_ATTRIBUTE_FILTERS.TITLE'
            )
          }}
        </h4>
        <p class="text-xs text-n-slate-11 mt-1">
          {{
            t(
              'LEAD_RETARGETING.FORM.CUSTOM_ATTRIBUTE_FILTERS.SUBTITLE'
            )
          }}
        </p>
      </div>
      <Button
        xs
        slate
        faded
        :label="t('LEAD_RETARGETING.FORM.CUSTOM_ATTRIBUTE_FILTERS.ADD_FILTER')"
        icon="i-lucide-sliders-horizontal"
        :disabled="filters.length >= 10"
        @click="addFilter"
      />
    </div>

    <div
      v-if="filters.length === 0"
      class="text-center py-6 border border-dashed border-n-weak rounded"
    >
      <i class="i-lucide-sliders-horizontal text-2xl text-n-slate-11 mb-2" />
      <p class="text-sm text-n-slate-11">
        {{
          t(
            'LEAD_RETARGETING.FORM.CUSTOM_ATTRIBUTE_FILTERS.EMPTY_STATE'
          )
        }}
      </p>
    </div>

    <div v-else class="space-y-3">
      <div
        v-for="(filter, index) in filters"
        :key="filter.id"
        class="border border-n-weak/60 rounded-lg p-3 space-y-3"
      >
        <div class="flex items-center justify-between">
          <span class="text-xs font-medium text-n-slate-11">
            {{
              t('LEAD_RETARGETING.FORM.CUSTOM_ATTRIBUTE_FILTERS.FILTER_LABEL')
            }}
            {{ index + 1 }}
          </span>
          <button
            type="button"
            class="text-n-red-11 hover:text-n-red-12 transition-colors"
            @click="removeFilter(index)"
          >
            <i class="i-lucide-trash-2 text-sm" />
          </button>
        </div>

        <!-- Row 1: Entity + Attribute -->
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="block text-xs font-medium text-n-slate-12 mb-1">
              {{
                t(
                  'LEAD_RETARGETING.FORM.CUSTOM_ATTRIBUTE_FILTERS.ENTITY_LABEL'
                )
              }}
            </label>
            <select
              :value="filter.entity"
              class="w-full text-sm"
              @change="e => onEntityChange(index, e.target.value)"
            >
              <option value="contact">
                {{
                  t(
                    'LEAD_RETARGETING.FORM.CUSTOM_ATTRIBUTE_FILTERS.ENTITY_CONTACT'
                  )
                }}
              </option>
              <option value="conversation">
                {{
                  t(
                    'LEAD_RETARGETING.FORM.CUSTOM_ATTRIBUTE_FILTERS.ENTITY_CONVERSATION'
                  )
                }}
              </option>
            </select>
          </div>

          <div>
            <label class="block text-xs font-medium text-n-slate-12 mb-1">
              {{
                t(
                  'LEAD_RETARGETING.FORM.CUSTOM_ATTRIBUTE_FILTERS.ATTRIBUTE_LABEL'
                )
              }}
            </label>
            <select
              :value="filter.attribute_key"
              class="w-full text-sm"
              @change="e => onAttributeChange(index, e.target.value)"
            >
              <option value="">
                {{
                  t(
                    'LEAD_RETARGETING.FORM.CUSTOM_ATTRIBUTE_FILTERS.SELECT_ATTRIBUTE'
                  )
                }}
              </option>
              <option
                v-for="attr in getAttributesForEntity(filter.entity)"
                :key="attr.attributeKey"
                :value="attr.attributeKey"
              >
                {{ attr.attributeDisplayName }}
              </option>
            </select>
          </div>
        </div>

        <!-- Row 2: Operator + Value(s) — only when attribute is selected -->
        <div
          v-if="filter.attribute_key"
          class="grid gap-3"
          :class="
            needsTwoValues(filter.operator) ? 'grid-cols-3' : 'grid-cols-2'
          "
        >
          <!-- Operator -->
          <div>
            <label class="block text-xs font-medium text-n-slate-12 mb-1">
              {{
                t(
                  'LEAD_RETARGETING.FORM.CUSTOM_ATTRIBUTE_FILTERS.OPERATOR_LABEL'
                )
              }}
            </label>
            <select
              :value="filter.operator"
              class="w-full text-sm"
              @change="e => onOperatorChange(index, e.target.value)"
            >
              <option
                v-for="op in getOperatorsForFilter(filter)"
                :key="op.value"
                :value="op.value"
              >
                {{ op.label }}
              </option>
            </select>
          </div>

          <!-- Value input — only when operator needs a value -->
          <template v-if="!needsNoValue(filter.operator)">
            <!-- checkbox: true/false select -->
            <div v-if="filter.attribute_display_type === 'checkbox'">
              <label class="block text-xs font-medium text-n-slate-12 mb-1">
                {{
                  t(
                    'LEAD_RETARGETING.FORM.CUSTOM_ATTRIBUTE_FILTERS.VALUE_LABEL'
                  )
                }}
              </label>
              <select
                :value="filter.value"
                class="w-full text-sm"
                @change="e => updateValue(index, e.target.value)"
              >
                <option value="true">
                  {{
                    t(
                      'LEAD_RETARGETING.FORM.CUSTOM_ATTRIBUTE_FILTERS.BOOL_TRUE'
                    )
                  }}
                </option>
                <option value="false">
                  {{
                    t(
                      'LEAD_RETARGETING.FORM.CUSTOM_ATTRIBUTE_FILTERS.BOOL_FALSE'
                    )
                  }}
                </option>
              </select>
            </div>

            <!-- list + includes_any: multi-select -->
            <div
              v-else-if="
                filter.attribute_display_type === 'list' &&
                filter.operator === 'includes_any'
              "
            >
              <label class="block text-xs font-medium text-n-slate-12 mb-1">
                {{
                  t(
                    'LEAD_RETARGETING.FORM.CUSTOM_ATTRIBUTE_FILTERS.VALUES_LABEL'
                  )
                }}
              </label>
              <select
                multiple
                :value="Array.isArray(filter.value) ? filter.value : []"
                class="w-full text-sm"
                @change="
                  e =>
                    updateValue(
                      index,
                      Array.from(e.target.selectedOptions).map(o => o.value)
                    )
                "
              >
                <option
                  v-for="val in getAttributeValues(
                    filter.entity,
                    filter.attribute_key
                  )"
                  :key="val"
                  :value="val"
                >
                  {{ val }}
                </option>
              </select>
            </div>

            <!-- list + equals/not_equals: single select -->
            <div
              v-else-if="filter.attribute_display_type === 'list'"
            >
              <label class="block text-xs font-medium text-n-slate-12 mb-1">
                {{
                  t(
                    'LEAD_RETARGETING.FORM.CUSTOM_ATTRIBUTE_FILTERS.VALUE_LABEL'
                  )
                }}
              </label>
              <select
                :value="filter.value"
                class="w-full text-sm"
                @change="e => updateValue(index, e.target.value)"
              >
                <option value="">
                  {{
                    t(
                      'LEAD_RETARGETING.FORM.CUSTOM_ATTRIBUTE_FILTERS.SELECT_VALUE'
                    )
                  }}
                </option>
                <option
                  v-for="val in getAttributeValues(
                    filter.entity,
                    filter.attribute_key
                  )"
                  :key="val"
                  :value="val"
                >
                  {{ val }}
                </option>
              </select>
            </div>

            <!-- number / currency / percent -->
            <div
              v-else-if="
                ['number', 'currency', 'percent'].includes(
                  filter.attribute_display_type
                )
              "
            >
              <label class="block text-xs font-medium text-n-slate-12 mb-1">
                {{
                  t(
                    'LEAD_RETARGETING.FORM.CUSTOM_ATTRIBUTE_FILTERS.VALUE_LABEL'
                  )
                }}
              </label>
              <input
                type="number"
                :value="filter.value"
                class="w-full text-sm"
                @input="e => updateValue(index, e.target.value)"
              />
            </div>

            <!-- date -->
            <div v-else-if="filter.attribute_display_type === 'date'">
              <label class="block text-xs font-medium text-n-slate-12 mb-1">
                {{
                  t(
                    'LEAD_RETARGETING.FORM.CUSTOM_ATTRIBUTE_FILTERS.DATE_LABEL'
                  )
                }}
              </label>
              <input
                type="date"
                :value="filter.value"
                class="w-full text-sm"
                @change="e => updateValue(index, e.target.value)"
              />
            </div>

            <!-- datetime -->
            <div v-else-if="filter.attribute_display_type === 'datetime'">
              <label class="block text-xs font-medium text-n-slate-12 mb-1">
                {{
                  t(
                    'LEAD_RETARGETING.FORM.CUSTOM_ATTRIBUTE_FILTERS.DATETIME_LABEL'
                  )
                }}
              </label>
              <input
                type="datetime-local"
                :value="filter.value"
                class="w-full text-sm"
                @change="e => updateValue(index, e.target.value)"
              />
            </div>

            <!-- text / link (default) -->
            <div v-else>
              <label class="block text-xs font-medium text-n-slate-12 mb-1">
                {{
                  t(
                    'LEAD_RETARGETING.FORM.CUSTOM_ATTRIBUTE_FILTERS.VALUE_LABEL'
                  )
                }}
              </label>
              <input
                type="text"
                :value="filter.value"
                class="w-full text-sm"
                @input="e => updateValue(index, e.target.value)"
              />
            </div>

            <!-- Second value for "between" -->
            <div v-if="needsTwoValues(filter.operator)">
              <label class="block text-xs font-medium text-n-slate-12 mb-1">
                {{
                  t(
                    'LEAD_RETARGETING.FORM.CUSTOM_ATTRIBUTE_FILTERS.VALUE2_LABEL'
                  )
                }}
              </label>
              <input
                v-if="
                  ['number', 'currency', 'percent'].includes(
                    filter.attribute_display_type
                  )
                "
                type="number"
                :value="filter.value2"
                class="w-full text-sm"
                @input="e => updateValue2(index, e.target.value)"
              />
              <input
                v-else-if="filter.attribute_display_type === 'date'"
                type="date"
                :value="filter.value2"
                class="w-full text-sm"
                @change="e => updateValue2(index, e.target.value)"
              />
              <input
                v-else-if="filter.attribute_display_type === 'datetime'"
                type="datetime-local"
                :value="filter.value2"
                class="w-full text-sm"
                @change="e => updateValue2(index, e.target.value)"
              />
              <input
                v-else
                type="text"
                :value="filter.value2"
                class="w-full text-sm"
                @input="e => updateValue2(index, e.target.value)"
              />
            </div>
          </template>
        </div>
      </div>
    </div>

    <div
      v-if="filters.length >= 10"
      class="text-xs text-n-amber-11 p-2 bg-n-amber-2 dark:bg-n-amber-3 rounded"
    >
      {{
        t(
          'LEAD_RETARGETING.FORM.CUSTOM_ATTRIBUTE_FILTERS.MAX_FILTERS_WARNING'
        )
      }}
    </div>
  </div>
</template>
