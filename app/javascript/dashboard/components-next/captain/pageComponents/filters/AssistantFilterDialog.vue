<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import {
  useSnakeCase,
  useCamelCase,
} from 'dashboard/composables/useTransformKeys';
import { useConversationFilterContext } from 'dashboard/components-next/filter/provider.js';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'next/button/Button.vue';
import ConditionRow from 'dashboard/components-next/filter/ConditionRow.vue';

const props = defineProps({
  assistantId: {
    type: Number,
    required: true,
  },
  filter: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['close']);
const { t } = useI18n();
const store = useStore();
const { filterTypes } = useConversationFilterContext();

const dialogRef = ref(null);
const name = ref('');
const filters = ref([]);
const error = ref('');
const conditionsRef = ref([]);

const DEFAULT_FILTER = {
  attributeKey: 'status',
  filterOperator: 'equal_to',
  values: [],
  queryOperator: 'and',
};

const resetForm = () => {
  if (props.filter) {
    name.value = props.filter.name;
    filters.value = useCamelCase(
      JSON.parse(JSON.stringify(props.filter.filters))
    );
  } else {
    name.value = '';
    filters.value = [{ ...DEFAULT_FILTER }];
  }
  error.value = '';
};

watch(() => props.filter, resetForm, { immediate: true });

const addFilter = () => {
  filters.value.push({ ...DEFAULT_FILTER });
};

const removeFilter = index => {
  if (filters.value.length === 1) {
    filters.value = [{ ...DEFAULT_FILTER }];
  } else {
    filters.value.splice(index, 1);
  }
};

const isConditionsValid = () => {
  return conditionsRef.value.every(c => c.validate());
};

const handleSubmit = async () => {
  error.value = '';
  if (!name.value.trim()) {
    error.value = t('CAPTAIN.FILTERS.FORM.NAME_REQUIRED');
    return;
  }
  if (!isConditionsValid()) return;

  const payload = {
    name: name.value.trim(),
    filters: useSnakeCase(JSON.parse(JSON.stringify(filters.value))),
    captain_assistant_id: props.assistantId,
  };

  try {
    if (props.filter) {
      await store.dispatch('captainAssistantFilters/update', {
        id: props.filter.id,
        ...payload,
      });
      useAlert(t('CAPTAIN.FILTERS.EDIT.SUCCESS_MESSAGE'));
    } else {
      await store.dispatch('captainAssistantFilters/create', payload);
      useAlert(t('CAPTAIN.FILTERS.CREATE.SUCCESS_MESSAGE'));
    }
    dialogRef.value.close();
  } catch (err) {
    error.value = err?.message || t('CAPTAIN.FILTERS.CREATE.ERROR_MESSAGE');
  }
};

const handleClose = () => {
  emit('close');
};

defineExpose({ dialogRef });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :type="filter ? 'edit' : 'create'"
    :title="filter ? $t('CAPTAIN.FILTERS.EDIT.TITLE') : $t('CAPTAIN.FILTERS.CREATE.TITLE')"
    :show-cancel-button="false"
    :show-confirm-button="false"
    @close="handleClose"
  >
    <div class="flex flex-col gap-4 py-2">
      <Input
        v-model="name"
        :label="$t('CAPTAIN.FILTERS.FORM.NAME_LABEL')"
        :placeholder="$t('CAPTAIN.FILTERS.FORM.NAME_PLACEHOLDER')"
      />

      <div class="flex flex-col gap-3">
        <span class="text-sm font-medium text-n-slate-12">
          {{ $t('CAPTAIN.FILTERS.FORM.CONDITIONS_LABEL') }}
        </span>

        <ul class="grid gap-3 list-none">
          <template v-for="(filter, index) in filters" :key="index">
            <ConditionRow
              v-if="index === 0"
              ref="conditionsRef"
              v-model:attribute-key="filter.attributeKey"
              v-model:filter-operator="filter.filterOperator"
              v-model:values="filter.values"
              :filter-types="filterTypes"
              :show-query-operator="false"
              @remove="removeFilter(index)"
            />
            <ConditionRow
              v-else
              ref="conditionsRef"
              v-model:attribute-key="filter.attributeKey"
              v-model:filter-operator="filter.filterOperator"
              v-model:query-operator="filters[index - 1].queryOperator"
              v-model:values="filter.values"
              :filter-types="filterTypes"
              show-query-operator
              @remove="removeFilter(index)"
            />
          </template>
        </ul>

        <Button sm ghost blue class="self-start" @click="addFilter">
          {{ $t('FILTER.ADD_NEW_FILTER') }}
        </Button>
      </div>

      <p v-if="error" class="text-sm text-n-ruby-11">{{ error }}</p>

      <div class="flex justify-end gap-2 pt-2">
        <Button sm faded slate @click="dialogRef.close()">
          {{ $t('CANCEL') }}
        </Button>
        <Button sm solid blue @click="handleSubmit">
          {{ filter ? $t('CAPTAIN.FILTERS.EDIT.BUTTON') : $t('CAPTAIN.FILTERS.CREATE.BUTTON') }}
        </Button>
      </div>
    </div>
    <template #footer />
  </Dialog>
</template>
