<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import leadFollowUpSequencesAPI from 'dashboard/api/leadFollowUpSequences';
import { useAlert } from 'dashboard/composables';

const props = defineProps({
  sequenceId: { type: Number, required: true },
  enrollmentId: { type: Number, required: true },
  resultSchema: { type: Array, default: () => [] },
  initialValues: { type: Object, default: () => ({}) },
  capturedBy: { type: String, default: null },
});

const emit = defineEmits(['saved']);

const { t } = useI18n();

const values = ref({ ...props.initialValues });
const isSaving = ref(false);

const capturedByLabel = computed(() => {
  if (props.capturedBy === 'agent_bot')
    return t('LEAD_RETARGETING.RESULT_FORM.CAPTURED_BY_BOT');
  if (props.capturedBy === 'human')
    return t('LEAD_RETARGETING.RESULT_FORM.CAPTURED_BY_HUMAN');
  return null;
});

const saveResult = async () => {
  isSaving.value = true;
  try {
    await leadFollowUpSequencesAPI.submitEnrollmentResult(
      props.sequenceId,
      props.enrollmentId,
      values.value
    );
    useAlert(t('LEAD_RETARGETING.RESULT_FORM.SUCCESS'));
    emit('saved', values.value);
  } catch {
    useAlert(t('LEAD_RETARGETING.RESULT_FORM.ERROR'));
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <div class="flex items-center justify-between">
      <div>
        <p class="text-sm font-medium text-n-slate-12">
          {{ t('LEAD_RETARGETING.RESULT_FORM.TITLE') }}
        </p>
        <p class="text-xs text-n-slate-11">
          {{ t('LEAD_RETARGETING.RESULT_FORM.SUBTITLE') }}
        </p>
      </div>
      <span
        v-if="capturedByLabel"
        class="rounded-full bg-n-slate-3 px-2 py-0.5 text-xs text-n-slate-11"
      >
        {{ capturedByLabel }}
      </span>
    </div>

    <div
      v-for="field in resultSchema"
      :key="field.key"
      class="flex flex-col gap-1"
    >
      <label class="text-xs font-medium text-n-slate-11">
        {{ field.label }}
        <span v-if="field.required" class="text-n-ruby-9">*</span>
      </label>

      <select
        v-if="field.type === 'select'"
        v-model="values[field.key]"
        class="w-full rounded-lg border border-n-weak bg-n-background px-3 py-2 text-sm text-n-slate-12 focus:outline-none focus:ring-1 focus:ring-n-blue-8"
      >
        <option value="">—</option>
        <option
          v-for="opt in field.options"
          :key="opt.value"
          :value="opt.value"
        >
          {{ opt.label }}
        </option>
      </select>

      <input
        v-else-if="field.type === 'boolean'"
        v-model="values[field.key]"
        type="checkbox"
        class="h-4 w-4 rounded border-n-weak text-n-blue-9"
        true-value="true"
        false-value="false"
      />

      <Input
        v-else
        v-model="values[field.key]"
        :type="field.type === 'number' ? 'number' : 'text'"
      />
    </div>

    <Button
      blue
      sm
      solid
      :label="
        isSaving
          ? t('LEAD_RETARGETING.RESULT_FORM.SAVING')
          : t('LEAD_RETARGETING.RESULT_FORM.SAVE')
      "
      :is-loading="isSaving"
      @click="saveResult"
    />
  </div>
</template>
