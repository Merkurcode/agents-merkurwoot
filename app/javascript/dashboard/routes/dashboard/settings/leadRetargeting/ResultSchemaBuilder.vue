<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const props = defineProps({
  modelValue: { type: Array, default: () => [] },
});
const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const FIELD_TYPES = ['text', 'number', 'select', 'boolean'];

const TYPE_ICONS = {
  text: 'i-lucide-type',
  number: 'i-lucide-hash',
  select: 'i-lucide-chevrons-up-down',
  boolean: 'i-lucide-toggle-left',
};

const typeLabel = type => t(`LEAD_RETARGETING.RESULT_SCHEMA.TYPES.${type}`);

const toLocal = f => ({
  ...f,
  optionsString: (f.options || []).map(o => o.label).join(', '),
});

// Local copy prevents focus loss on every keystroke
const localFields = ref(props.modelValue.map(toLocal));

watch(
  () => props.modelValue,
  newVal => {
    const newKeys = newVal.map(f => f.key).join(',');
    const localKeys = localFields.value.map(f => f.key).join(',');
    if (newKeys !== localKeys) {
      localFields.value = newVal.map(toLocal);
    }
  }
);

const emitUpdate = () => {
  emit(
    'update:modelValue',
    // Strip internal optionsString before emitting
    localFields.value.map(({ optionsString, ...f }) => f)
  );
};

const addField = () => {
  localFields.value.push({
    key: `field_${Date.now()}`,
    label: '',
    type: 'text',
    required: false,
    options: [],
    optionsString: '',
  });
  emitUpdate();
};

const removeField = index => {
  localFields.value.splice(index, 1);
  emitUpdate();
};

const onLabelBlur = index => {
  const field = localFields.value[index];
  if (field.label) {
    field.key = field.label
      .toLowerCase()
      .replace(/\s+/g, '_')
      .replace(/[^a-z0-9_]/g, '');
  }
  emitUpdate();
};

const setType = (index, type) => {
  const field = localFields.value[index];
  field.type = type;
  if (type !== 'select') {
    field.options = [];
    field.optionsString = '';
  }
  emitUpdate();
};

const toggleRequired = index => {
  localFields.value[index].required = !localFields.value[index].required;
  emitUpdate();
};

const finalizeOptions = index => {
  const field = localFields.value[index];
  field.options = (field.optionsString || '')
    .split(',')
    .map(o => o.trim())
    .filter(Boolean)
    .map(o => ({ label: o, value: o.toLowerCase().replace(/\s+/g, '_') }));
  emitUpdate();
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <p class="text-sm text-n-slate-11">
      {{ t('LEAD_RETARGETING.RESULT_SCHEMA.SECTION_DESCRIPTION') }}
    </p>

    <div
      v-for="(field, index) in localFields"
      :key="field.key"
      class="rounded-lg border border-n-weak"
    >
      <div class="flex flex-col gap-2.5 p-3">
        <!-- Label input row -->
        <div class="flex items-center gap-2">
          <span
            class="flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-n-slate-3 text-xs font-semibold text-n-slate-10"
          >
            {{ index + 1 }}
          </span>
          <div class="flex-1" @blur.capture="onLabelBlur(index)">
            <Input
              v-model="field.label"
              :placeholder="
                t('LEAD_RETARGETING.RESULT_SCHEMA.FIELD_LABEL_PLACEHOLDER')
              "
            />
          </div>
          <Button
            ghost
            ruby
            xs
            icon="i-lucide-trash-2"
            :aria-label="t('LEAD_RETARGETING.RESULT_SCHEMA.REMOVE_FIELD')"
            @click="removeField(index)"
          />
        </div>

        <!-- Auto-generated key preview -->
        <p v-if="field.label" class="pl-7 font-mono text-xs text-n-slate-9">
          {{ t('LEAD_RETARGETING.RESULT_SCHEMA.FIELD_KEY_LABEL') }}
          {{ field.key }}
        </p>

        <!-- Type pills + Required toggle -->
        <div class="flex flex-wrap items-center gap-1.5 pl-7">
          <button
            v-for="type in FIELD_TYPES"
            :key="type"
            type="button"
            class="flex items-center gap-1 rounded-full px-2.5 py-0.5 text-xs font-medium transition-colors"
            :class="
              field.type === type
                ? 'bg-n-blue-3 text-n-blue-11 ring-1 ring-n-blue-6'
                : 'text-n-slate-10 hover:bg-n-slate-3'
            "
            @click="setType(index, type)"
          >
            <span :class="TYPE_ICONS[type]" class="h-3 w-3" />
            {{ typeLabel(type) }}
          </button>

          <div class="mx-0.5 h-3 w-px bg-n-weak" />

          <button
            type="button"
            class="flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-xs font-medium transition-colors"
            :class="
              field.required
                ? 'bg-n-amber-3 text-n-amber-11 ring-1 ring-n-amber-6'
                : 'text-n-slate-10 hover:bg-n-slate-3'
            "
            @click="toggleRequired(index)"
          >
            <span class="i-lucide-asterisk h-3 w-3" />
            {{ t('LEAD_RETARGETING.RESULT_SCHEMA.FIELD_REQUIRED') }}
          </button>
        </div>

        <!-- Options input (select type only) -->
        <div
          v-if="field.type === 'select'"
          class="pl-7"
          @blur.capture="finalizeOptions(index)"
        >
          <Input
            v-model="field.optionsString"
            :label="t('LEAD_RETARGETING.RESULT_SCHEMA.FIELD_OPTIONS')"
            :placeholder="
              t('LEAD_RETARGETING.RESULT_SCHEMA.FIELD_OPTIONS_PLACEHOLDER')
            "
          />
        </div>
      </div>
    </div>

    <Button
      ghost
      slate
      sm
      icon="i-lucide-plus"
      :label="t('LEAD_RETARGETING.RESULT_SCHEMA.ADD_FIELD')"
      class="self-start"
      @click="addField"
    />
  </div>
</template>
