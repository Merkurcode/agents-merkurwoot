<script setup>
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const { t } = useI18n();

const props = defineProps({
  modelValue: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['update:modelValue']);

const FIELD_TYPES = ['text', 'select', 'number', 'boolean'];

const typeLabel = type =>
  t(`LEAD_RETARGETING.RESULT_SCHEMA.TYPES.${type}`);

const addField = () => {
  const newKey = `field_${Date.now()}`;
  emit('update:modelValue', [
    ...props.modelValue,
    { key: newKey, label: '', type: 'text', required: false, options: [] },
  ]);
};

const removeField = index => {
  emit(
    'update:modelValue',
    props.modelValue.filter((_, i) => i !== index)
  );
};

const updateField = (index, patch) => {
  emit(
    'update:modelValue',
    props.modelValue.map((f, i) => {
      if (i !== index) return f;
      const updated = { ...f, ...patch };
      if (patch.label !== undefined) {
        updated.key = patch.label
          .toLowerCase()
          .replace(/\s+/g, '_')
          .replace(/[^a-z0-9_]/g, '');
      }
      if (patch.type !== undefined && patch.type !== 'select') {
        updated.options = [];
      }
      return updated;
    })
  );
};

const updateOptions = (index, rawValue) => {
  const options = rawValue
    .split(',')
    .map(o => o.trim())
    .filter(Boolean)
    .map(o => ({ label: o, value: o.toLowerCase().replace(/\s+/g, '_') }));
  updateField(index, { options });
};

const optionsAsString = field =>
  (field.options || []).map(o => o.label).join(', ');
</script>

<template>
  <div class="flex flex-col gap-3">
    <p class="text-sm text-n-slate-11">
      {{ t('LEAD_RETARGETING.RESULT_SCHEMA.SECTION_DESCRIPTION') }}
    </p>

    <div
      v-for="(field, index) in modelValue"
      :key="field.key"
      class="flex flex-col gap-2 rounded-lg border border-n-weak p-3"
    >
      <div class="flex items-start gap-2">
        <div class="flex-1">
          <Input
            :model-value="field.label"
            :label="t('LEAD_RETARGETING.RESULT_SCHEMA.FIELD_LABEL')"
            :placeholder="
              t(
                'LEAD_RETARGETING.RESULT_SCHEMA.FIELD_LABEL_PLACEHOLDER'
              )
            "
            @update:model-value="v => updateField(index, { label: v })"
          />
        </div>

        <div class="w-36 pt-5">
          <select
            :value="field.type"
            class="w-full rounded-lg border border-n-weak bg-n-background px-3 py-2 text-sm text-n-slate-12 focus:outline-none focus:ring-1 focus:ring-n-blue-8"
            @change="e => updateField(index, { type: e.target.value })"
          >
            <option v-for="type in FIELD_TYPES" :key="type" :value="type">
              {{ typeLabel(type) }}
            </option>
          </select>
        </div>

        <div class="flex items-center gap-1.5 pt-7">
          <input
            :id="`required-${index}`"
            type="checkbox"
            :checked="field.required"
            class="h-4 w-4 rounded border-n-weak text-n-blue-9"
            @change="e => updateField(index, { required: e.target.checked })"
          />
          <label :for="`required-${index}`" class="text-xs text-n-slate-11">
            {{ t('LEAD_RETARGETING.RESULT_SCHEMA.FIELD_REQUIRED') }}
          </label>
        </div>

        <Button
          ghost
          ruby
          xs
          icon="i-lucide-x"
          class="mt-5 shrink-0"
          :aria-label="
            t('LEAD_RETARGETING.RESULT_SCHEMA.REMOVE_FIELD')
          "
          @click="removeField(index)"
        />
      </div>

      <Input
        v-if="field.type === 'select'"
        :model-value="optionsAsString(field)"
        :label="t('LEAD_RETARGETING.RESULT_SCHEMA.FIELD_OPTIONS')"
        :placeholder="
          t(
            'LEAD_RETARGETING.RESULT_SCHEMA.FIELD_OPTIONS_PLACEHOLDER'
          )
        "
        @update:model-value="v => updateOptions(index, v)"
      />
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
