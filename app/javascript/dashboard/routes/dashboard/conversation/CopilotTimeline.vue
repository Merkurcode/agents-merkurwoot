<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import conversationsAPI from 'dashboard/api/conversations';
import leadFollowUpSequencesAPI from 'dashboard/api/leadFollowUpSequences';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const { t } = useI18n();

const route = useRoute();
const events = ref([]);
const loading = ref(false);
const error = ref(null);

// Enrollment result state
const resultLoading = ref(false);
const enrollmentData = ref(null);
const resultValues = ref({});
const isSaving = ref(false);

const conversationId = computed(() => route.params.conversation_id);

const hasActiveEnrollment = computed(
  () => enrollmentData.value?.enrollment_id != null
);
const hasResultSchema = computed(
  () => (enrollmentData.value?.result_schema || []).length > 0
);
const resultCapturedBy = computed(
  () => enrollmentData.value?.result_captured_by
);
const resultComplete = computed(() => enrollmentData.value?.result_complete);

const capturedByLabel = computed(() => {
  if (resultCapturedBy.value === 'agent_bot')
    return t('LEAD_RETARGETING.RESULT_FORM.CAPTURED_BY_BOT');
  if (resultCapturedBy.value === 'human')
    return t('LEAD_RETARGETING.RESULT_FORM.CAPTURED_BY_HUMAN');
  return null;
});

const fetchEnrollmentResultSchema = async () => {
  if (!conversationId.value) return;
  resultLoading.value = true;
  try {
    const response = await conversationsAPI.getEnrollmentResultSchema(
      conversationId.value
    );
    enrollmentData.value = response.data;
    resultValues.value = { ...(response.data.current_result || {}) };
  } catch {
    enrollmentData.value = null;
  } finally {
    resultLoading.value = false;
  }
};

const saveResult = async () => {
  if (!enrollmentData.value?.enrollment_id) return;
  isSaving.value = true;
  try {
    const response = await leadFollowUpSequencesAPI.submitEnrollmentResult(
      enrollmentData.value.sequence_id,
      enrollmentData.value.enrollment_id,
      resultValues.value
    );
    enrollmentData.value.result_captured_by = 'human';
    enrollmentData.value.result_complete = response.data.result_complete;
    useAlert(t('LEAD_RETARGETING.RESULT_FORM.SUCCESS'));
  } catch {
    useAlert(t('LEAD_RETARGETING.RESULT_FORM.ERROR'));
  } finally {
    isSaving.value = false;
  }
};

const fetchCopilotEvents = async () => {
  if (!conversationId.value) return;

  loading.value = true;
  error.value = null;

  try {
    const response = await conversationsAPI.getCopilotEvents(
      conversationId.value
    );
    events.value = response.data.events || [];
  } catch {
    error.value = 'Error al cargar eventos de copilots';
    events.value = [];
  } finally {
    loading.value = false;
  }
};

const getEventIcon = eventType => {
  const icons = {
    enrolled: 'i-lucide-user-plus',
    step_executed: 'i-lucide-check-circle',
    step_failed: 'i-lucide-x-circle',
    message_sent: 'i-lucide-message-square',
    template_sent: 'i-lucide-file-text',
    sms_sent: 'i-lucide-mail',
    ai_response_received: 'i-lucide-sparkles',
    label_added: 'i-lucide-tag',
    label_removed: 'i-lucide-tag',
    agent_assigned: 'i-lucide-user-check',
    team_assigned: 'i-lucide-users',
    pipeline_status_updated: 'i-lucide-workflow',
    webhook_called: 'i-lucide-webhook',
    completed: 'i-lucide-check-check',
    cancelled: 'i-lucide-x',
    failed: 'i-lucide-alert-triangle',
    paused: 'i-lucide-pause-circle',
    resumed: 'i-lucide-play-circle',
  };
  return icons[eventType] || 'i-lucide-circle';
};

const getEventColor = eventType => {
  const colors = {
    enrolled: 'text-n-teal-11',
    step_executed: 'text-n-green-11',
    step_failed: 'text-n-ruby-11',
    message_sent: 'text-n-blue-11',
    template_sent: 'text-n-blue-11',
    sms_sent: 'text-n-blue-11',
    ai_response_received: 'text-n-purple-11',
    label_added: 'text-n-amber-11',
    label_removed: 'text-n-amber-11',
    agent_assigned: 'text-n-indigo-11',
    team_assigned: 'text-n-indigo-11',
    pipeline_status_updated: 'text-n-violet-11',
    webhook_called: 'text-n-cyan-11',
    completed: 'text-n-teal-11',
    cancelled: 'text-n-slate-11',
    failed: 'text-n-ruby-11',
    paused: 'text-n-amber-11',
    resumed: 'text-n-green-11',
  };
  return colors[eventType] || 'text-n-slate-11';
};

const getEventDescription = event => {
  const { event_type: type, metadata } = event;
  const i18nKey = `LEAD_RETARGETING.EVENTS.${type}`;

  switch (type) {
    case 'enrolled':
      return t(i18nKey, { name: event.copilot_name || '' });
    case 'step_executed':
      return t(i18nKey, { name: metadata.step_name || event.step_id });
    case 'step_failed':
      return t(i18nKey, { error: metadata.error_message });
    case 'message_sent':
      return t(i18nKey, { channel: metadata.channel || 'WhatsApp' });
    case 'template_sent':
      return t(i18nKey, { name: metadata.template_name });
    case 'label_added':
    case 'label_removed':
      return t(i18nKey, { labels: (metadata.labels || []).join(', ') });
    case 'agent_assigned':
      return t(i18nKey, { name: metadata.agent_name });
    case 'team_assigned':
      return t(i18nKey, { name: metadata.team_name });
    case 'pipeline_status_updated':
      return t(i18nKey, { name: metadata.status_name });
    case 'webhook_called':
      return t(i18nKey, { url: metadata.url });
    case 'completed':
      return t(i18nKey, { reason: metadata.completion_reason || '' });
    case 'cancelled':
      return t(i18nKey, { reason: metadata.cancellation_reason || '' });
    case 'failed':
      return t(i18nKey, { error: metadata.error_message });
    default:
      return t(i18nKey);
  }
};

const formatDate = dateString => {
  if (!dateString) return '-';
  const date = new Date(dateString);
  const now = new Date();
  const diffMs = now - date;
  const diffMins = Math.floor(diffMs / 60000);

  if (diffMins < 1)
    return t('LEAD_RETARGETING.TIMELINE.JUST_NOW') || 'Hace un momento';
  if (diffMins < 60)
    return `${t('LEAD_RETARGETING.TIMELINE.AGO')} ${diffMins}min`;

  const diffHours = Math.floor(diffMins / 60);
  if (diffHours < 24)
    return `${t('LEAD_RETARGETING.TIMELINE.AGO')} ${diffHours}h`;

  const diffDays = Math.floor(diffHours / 24);
  if (diffDays < 7) return `${t('LEAD_RETARGETING.TIMELINE.AGO')} ${diffDays}d`;

  return date.toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
};

const hasEvents = computed(() => events.value.length > 0);

onMounted(() => {
  fetchEnrollmentResultSchema();
  fetchCopilotEvents();
});
</script>

<template>
  <div class="copilot-timeline">
    <!-- Result capture form (active enrollment only) -->
    <div v-if="resultLoading" class="border-b border-n-weak p-4 text-center">
      <div
        class="inline-block animate-spin i-lucide-loader-2 text-n-slate-11"
      />
      <p class="mt-1 text-xs text-n-slate-11">
        {{ t('LEAD_RETARGETING.RESULT_FORM.LOADING') }}
      </p>
    </div>

    <div
      v-else-if="hasActiveEnrollment && hasResultSchema"
      class="border-b border-n-weak p-4"
    >
      <!-- Header -->
      <div class="mb-3 flex items-center justify-between">
        <div>
          <p class="text-sm font-medium text-n-slate-12">
            {{ t('LEAD_RETARGETING.RESULT_FORM.TITLE') }}
          </p>
          <p class="text-xs text-n-slate-11">
            {{ enrollmentData.sequence_name }}
          </p>
        </div>
        <div class="flex items-center gap-1.5">
          <span
            v-if="capturedByLabel"
            class="rounded-full bg-n-slate-3 px-2 py-0.5 text-xs text-n-slate-11"
          >
            {{ capturedByLabel }}
          </span>
          <span
            v-if="resultComplete"
            class="inline-flex items-center gap-1 rounded-full bg-n-teal-3 px-2 py-0.5 text-xs text-n-teal-11"
          >
            <span class="i-lucide-check h-3 w-3" />
            {{ t('LEAD_RETARGETING.RESULT_FORM.COMPLETE') }}
          </span>
          <span
            v-else
            class="rounded-full bg-n-amber-3 px-2 py-0.5 text-xs text-n-amber-11"
          >
            {{ t('LEAD_RETARGETING.RESULT_FORM.PENDING') }}
          </span>
        </div>
      </div>

      <!-- Fields -->
      <div class="flex flex-col gap-3">
        <div
          v-for="field in enrollmentData.result_schema"
          :key="field.key"
          class="flex flex-col gap-1.5"
        >
          <label class="text-xs font-medium text-n-slate-11">
            {{ field.label
            }}<span v-if="field.required" class="ml-0.5 text-n-ruby-9">*</span>
          </label>

          <!-- Select: styled native dropdown -->
          <select
            v-if="field.type === 'select'"
            v-model="resultValues[field.key]"
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

          <!-- Boolean: Sí / No pill buttons -->
          <div v-else-if="field.type === 'boolean'" class="flex gap-2">
            <button
              type="button"
              class="flex flex-1 items-center justify-center gap-1.5 rounded-lg border px-3 py-2 text-sm font-medium transition-colors"
              :class="
                resultValues[field.key] === 'true'
                  ? 'border-n-teal-7 bg-n-teal-3 text-n-teal-11'
                  : 'border-n-weak bg-n-background text-n-slate-11 hover:bg-n-slate-3'
              "
              @click="resultValues[field.key] = 'true'"
            >
              <span
                v-if="resultValues[field.key] === 'true'"
                class="i-lucide-check h-3.5 w-3.5"
              />
              {{ t('LEAD_RETARGETING.RESULT_FORM.YES') }}
            </button>
            <button
              type="button"
              class="flex flex-1 items-center justify-center gap-1.5 rounded-lg border px-3 py-2 text-sm font-medium transition-colors"
              :class="
                resultValues[field.key] === 'false'
                  ? 'border-n-ruby-7 bg-n-ruby-3 text-n-ruby-11'
                  : 'border-n-weak bg-n-background text-n-slate-11 hover:bg-n-slate-3'
              "
              @click="resultValues[field.key] = 'false'"
            >
              <span
                v-if="resultValues[field.key] === 'false'"
                class="i-lucide-x h-3.5 w-3.5"
              />
              {{ t('LEAD_RETARGETING.RESULT_FORM.NO') }}
            </button>
          </div>

          <!-- Number / Text -->
          <Input
            v-else
            v-model="resultValues[field.key]"
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
    </div>

    <!-- Loading State (events) -->
    <div v-if="loading" class="p-4 text-center">
      <div
        class="inline-block animate-spin i-lucide-loader-2 text-n-slate-11"
      />
      <p class="mt-2 text-xs text-n-slate-11">
        {{ t('LEAD_RETARGETING.TIMELINE.LOADING') }}
      </p>
    </div>

    <!-- Error State -->
    <div v-else-if="error" class="p-4 text-center">
      <i class="i-lucide-alert-circle text-n-ruby-11 text-xl" />
      <p class="mt-2 text-xs text-n-ruby-11">
        {{ error }}
      </p>
    </div>

    <!-- Empty State -->
    <div v-else-if="!hasEvents" class="p-4 text-center">
      <i class="i-lucide-info text-n-slate-11 text-xl" />
      <p class="mt-2 text-xs text-n-slate-11">
        {{ t('LEAD_RETARGETING.TIMELINE.EMPTY_STATE') }}
      </p>
    </div>

    <!-- Events List -->
    <div v-else class="flex flex-col">
      <div
        v-for="event in events"
        :key="event.id"
        class="group relative flex gap-3 p-3 hover:bg-n-weak/50 transition-colors border-b border-n-weak last:border-0"
      >
        <!-- Timeline Line -->
        <div
          class="absolute left-[22px] top-10 bottom-0 w-px bg-n-weak group-last:hidden"
        />

        <!-- Event Icon -->
        <div class="flex-shrink-0 relative z-10">
          <div
            class="flex items-center justify-center w-6 h-6 rounded-full bg-n-background border border-n-weak"
          >
            <i
              class="text-sm"
              :class="[
                getEventIcon(event.event_type),
                getEventColor(event.event_type),
              ]"
            />
          </div>
        </div>

        <!-- Event Content -->
        <div class="flex-1 min-w-0">
          <!-- Copilot Name -->
          <div v-if="event.copilot_name" class="flex items-center gap-1 mb-1">
            <span
              class="text-[10px] uppercase tracking-wider font-bold text-n-slate-11 bg-n-weak/30 px-1.5 py-0.5 rounded border border-n-weak/50"
            >
              {{ event.copilot_name }}
            </span>
          </div>

          <!-- Event Description -->
          <p class="text-sm text-n-slate-12 font-medium">
            {{ getEventDescription(event) }}
          </p>

          <!-- Status / Reason -->
          <div
            v-if="
              event.metadata &&
              (event.metadata.completion_reason ||
                event.metadata.cancellation_reason ||
                event.metadata.error_message)
            "
            class="mt-1"
          >
            <p
              class="text-xs"
              :class="
                event.metadata.error_message
                  ? 'text-n-ruby-11'
                  : 'text-n-slate-11'
              "
            >
              {{
                event.metadata.error_message ||
                event.metadata.completion_reason ||
                event.metadata.cancellation_reason
              }}
            </p>
          </div>

          <!-- Timestamp -->
          <div class="mt-1">
            <span class="text-xs text-n-slate-11">
              {{ formatDate(event.occurred_at) }}
            </span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.copilot-timeline {
  max-height: 600px;
  overflow-y: auto;
}
</style>
