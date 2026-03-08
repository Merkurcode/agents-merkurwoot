<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'next/button/Button.vue';

const props = defineProps({
  filter: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['close']);

const { t } = useI18n();
const store = useStore();
const router = useRouter();

const dialogRef = ref(null);
const runNow = ref(true);
const scheduledAt = ref('');
const message = ref('');
const error = ref('');

const uiFlags = useMapGetter('captainAssistantFilterRuns/getUIFlags');
const isCreating = computed(() => uiFlags.value.creatingItem);

const minDateTime = computed(() => {
  const now = new Date();
  now.setMinutes(now.getMinutes() + 1);
  const pad = n => String(n).padStart(2, '0');
  return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}T${pad(now.getHours())}:${pad(now.getMinutes())}`;
});

const resetForm = () => {
  runNow.value = true;
  scheduledAt.value = '';
  message.value = '';
  error.value = '';
};

watch(
  () => props.filter,
  val => {
    if (val) resetForm();
  }
);

const handleSubmit = async () => {
  error.value = '';

  if (!runNow.value && !scheduledAt.value) {
    error.value = t('CAPTAIN.FILTER_RUNS.FORM.SCHEDULED_AT_REQUIRED');
    return;
  }

  const payload = {
    assistant_filter_id: props.filter.id,
    message: message.value.trim() || null,
    scheduled_at: runNow.value ? null : new Date(scheduledAt.value).toISOString(),
  };

  try {
    const run = await store.dispatch(
      'captainAssistantFilterRuns/create',
      payload
    );
    useAlert(
      runNow.value
        ? t('CAPTAIN.FILTER_RUNS.CREATE.SUCCESS_NOW')
        : t('CAPTAIN.FILTER_RUNS.CREATE.SUCCESS_SCHEDULED')
    );
    resetForm();
    dialogRef.value.close();

    router.push({
      name: 'captain_assistants_filter_run_detail',
      params: {
        ...router.currentRoute.value.params,
        runId: run.id,
      },
    });
  } catch (err) {
    error.value = err?.message || t('CAPTAIN.FILTER_RUNS.CREATE.ERROR_MESSAGE');
  }
};

const handleClose = () => {
  resetForm();
  emit('close');
};

defineExpose({ dialogRef });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="create"
    :title="$t('CAPTAIN.FILTER_RUNS.CREATE.TITLE')"
    :show-cancel-button="false"
    :show-confirm-button="false"
    @close="handleClose"
  >
    <div class="flex flex-col gap-4 py-2">
      <p class="text-sm text-n-slate-11">
        {{ $t('CAPTAIN.FILTER_RUNS.FORM.FILTER_NAME') }}:
        <span class="font-medium text-n-slate-12">{{ filter?.name }}</span>
      </p>

      <div class="flex flex-col gap-2">
        <span class="text-sm font-medium text-n-slate-12">
          {{ $t('CAPTAIN.FILTER_RUNS.FORM.WHEN_LABEL') }}
        </span>
        <div class="flex gap-3">
          <label class="flex items-center gap-2 cursor-pointer">
            <input
              v-model="runNow"
              type="radio"
              :value="true"
              class="accent-n-brand"
            />
            <span class="text-sm text-n-slate-12">
              {{ $t('CAPTAIN.FILTER_RUNS.FORM.RUN_NOW') }}
            </span>
          </label>
          <label class="flex items-center gap-2 cursor-pointer">
            <input
              v-model="runNow"
              type="radio"
              :value="false"
              class="accent-n-brand"
            />
            <span class="text-sm text-n-slate-12">
              {{ $t('CAPTAIN.FILTER_RUNS.FORM.SCHEDULE') }}
            </span>
          </label>
        </div>
      </div>

      <div v-if="!runNow" class="flex flex-col gap-1">
        <label class="text-sm font-medium text-n-slate-12">
          {{ $t('CAPTAIN.FILTER_RUNS.FORM.SCHEDULED_AT_LABEL') }}
        </label>
        <input
          v-model="scheduledAt"
          type="datetime-local"
          :min="minDateTime"
          class="w-full px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-alpha-black2 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
        />
      </div>

      <div class="flex flex-col gap-1">
        <label class="text-sm font-medium text-n-slate-12">
          {{ $t('CAPTAIN.FILTER_RUNS.FORM.MESSAGE_LABEL') }}
        </label>
        <textarea
          v-model="message"
          rows="3"
          :placeholder="$t('CAPTAIN.FILTER_RUNS.FORM.MESSAGE_PLACEHOLDER')"
          class="w-full px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-alpha-black2 text-n-slate-12 placeholder-n-slate-9 focus:outline-none focus:ring-2 focus:ring-n-brand resize-none"
        />
        <p class="text-xs text-n-slate-10">
          {{ $t('CAPTAIN.FILTER_RUNS.FORM.MESSAGE_HINT') }}
        </p>
      </div>

      <p v-if="error" class="text-sm text-n-ruby-11">{{ error }}</p>

      <div class="flex justify-end gap-2 pt-2">
        <Button sm faded slate @click="dialogRef.close()">
          {{ $t('CANCEL') }}
        </Button>
        <Button sm solid blue :disabled="isCreating" @click="handleSubmit">
          {{
            runNow
              ? $t('CAPTAIN.FILTER_RUNS.FORM.RUN_NOW_BUTTON')
              : $t('CAPTAIN.FILTER_RUNS.FORM.SCHEDULE_BUTTON')
          }}
        </Button>
      </div>
    </div>
    <template #footer />
  </Dialog>
</template>
