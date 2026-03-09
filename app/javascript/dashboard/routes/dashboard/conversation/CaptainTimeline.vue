<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import conversationsAPI from 'dashboard/api/conversations';

const { t } = useI18n();
const route = useRoute();
const activities = ref([]);
const loading = ref(false);
const error = ref(null);
const selectedActivity = ref(null);

const conversationId = computed(() => route.params.conversation_id);

const fetchActivities = async () => {
  if (!conversationId.value) return;

  loading.value = true;
  error.value = null;

  try {
    const response = await conversationsAPI.getCaptainActivities(
      conversationId.value
    );
    activities.value = response.data.activities || [];
  } catch (err) {
    error.value = t('CAPTAIN_TIMELINE.ERROR');
    activities.value = [];
  } finally {
    loading.value = false;
  }
};

const statusIcon = status => {
  const icons = {
    success: 'i-lucide-check-circle',
    failed: 'i-lucide-x-circle',
    pending: 'i-lucide-clock',
  };
  return icons[status] || 'i-lucide-circle';
};

const statusColor = status => {
  const colors = {
    success: 'text-n-green-11',
    failed: 'text-n-ruby-11',
    pending: 'text-n-amber-11',
  };
  return colors[status] || 'text-n-slate-11';
};

const statusLabel = status => {
  const labels = {
    success: t('CAPTAIN_TIMELINE.STATUS.SUCCESS'),
    failed: t('CAPTAIN_TIMELINE.STATUS.FAILED'),
    pending: t('CAPTAIN_TIMELINE.STATUS.PENDING'),
  };
  return labels[status] || status;
};

const formatDate = dateString => {
  if (!dateString) return '-';
  const date = new Date(dateString);
  const now = new Date();
  const diffMins = Math.floor((now - date) / 60000);

  if (diffMins < 1) return t('CAPTAIN_TIMELINE.JUST_NOW');
  if (diffMins < 60) return `${diffMins}m ${t('CAPTAIN_TIMELINE.AGO')}`;

  const diffHours = Math.floor(diffMins / 60);
  if (diffHours < 24) return `${diffHours}h ${t('CAPTAIN_TIMELINE.AGO')}`;

  const diffDays = Math.floor(diffHours / 24);
  if (diffDays < 7) return `${diffDays}d ${t('CAPTAIN_TIMELINE.AGO')}`;

  return date.toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
};

const formatFullDate = dateString => {
  if (!dateString) return '-';
  return new Date(dateString).toLocaleString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
};

const openModal = activity => {
  selectedActivity.value = activity;
};

const closeModal = () => {
  selectedActivity.value = null;
};

const handleKeydown = e => {
  if (e.key === 'Escape') closeModal();
};

onMounted(() => {
  fetchActivities();
  document.addEventListener('keydown', handleKeydown);
});

onUnmounted(() => {
  document.removeEventListener('keydown', handleKeydown);
});
</script>

<template>
  <div class="captain-timeline max-h-[600px] overflow-y-auto pb-2">
    <div v-if="loading" class="p-4 text-center">
      <div class="inline-block animate-spin i-lucide-loader-2 text-n-slate-11" />
      <p class="mt-2 text-xs text-n-slate-11">{{ t('CAPTAIN_TIMELINE.LOADING') }}</p>
    </div>

    <div v-else-if="error" class="p-4 text-center">
      <i class="i-lucide-alert-circle text-n-ruby-11 text-xl" />
      <p class="mt-2 text-xs text-n-ruby-11">{{ error }}</p>
    </div>

    <div v-else-if="!activities.length" class="p-4 text-center">
      <i class="i-lucide-bot text-n-slate-11 text-xl" />
      <p class="mt-2 text-xs text-n-slate-11">{{ t('CAPTAIN_TIMELINE.EMPTY') }}</p>
    </div>

    <div v-else class="flex flex-col">
      <button
        v-for="activity in activities"
        :key="activity.id"
        class="group relative flex gap-3 p-3 hover:bg-n-weak/50 transition-colors border-b border-n-weak last:border-0 text-left w-full"
        @click="openModal(activity)"
      >
        <div class="absolute left-[22px] top-10 bottom-0 w-px bg-n-weak group-last:hidden" />

        <div class="flex-shrink-0 relative z-10">
          <div class="flex items-center justify-center w-6 h-6 rounded-full bg-n-background border border-n-weak">
            <i
              class="text-sm"
              :class="[statusIcon(activity.status), statusColor(activity.status)]"
            />
          </div>
        </div>

        <div class="flex-1 min-w-0">
          <div v-if="activity.assistant_name" class="flex items-center gap-1 mb-1">
            <span class="text-[10px] uppercase tracking-wider font-bold text-n-slate-11 bg-n-weak/30 px-1.5 py-0.5 rounded border border-n-weak/50">
              {{ activity.assistant_name }}
            </span>
          </div>

          <p class="text-sm text-n-slate-12 font-medium truncate">
            {{ activity.filter_name }}
          </p>

          <p v-if="activity.message" class="text-xs text-n-slate-11 mt-0.5 line-clamp-2">
            {{ activity.message }}
          </p>

          <p v-if="activity.error_message" class="text-xs text-n-ruby-11 mt-0.5 truncate">
            {{ activity.error_message }}
          </p>

          <div class="flex items-center gap-2 mt-1">
            <span class="text-xs text-n-slate-11">
              {{ formatDate(activity.processed_at || activity.created_at) }}
            </span>
            <span v-if="activity.triggered_by" class="text-xs text-n-slate-11">
              · {{ activity.triggered_by }}
            </span>
            <span v-else-if="activity.scheduled_at" class="text-xs text-n-slate-11">
              · {{ t('CAPTAIN_TIMELINE.SCHEDULED') }}
            </span>
          </div>
        </div>

        <div class="flex-shrink-0 self-center opacity-0 group-hover:opacity-100 transition-opacity">
          <i class="i-lucide-chevron-right text-n-slate-11 text-sm" />
        </div>
      </button>
    </div>
  </div>

  <!-- Modal -->
  <Teleport to="body">
    <div
      v-if="selectedActivity"
      class="fixed inset-0 z-[60] flex items-center justify-center p-6 bg-n-slate-1/90 backdrop-blur-sm"
      @click.self="closeModal"
    >
      <div class="bg-n-background rounded-xl border border-n-weak shadow-2xl w-full max-w-lg max-h-[80vh] flex flex-col">
        <!-- Header -->
        <div class="flex items-start justify-between p-4 border-b border-n-weak">
          <div class="flex-1 min-w-0">
            <div v-if="selectedActivity.assistant_name" class="mb-1">
              <span class="text-[10px] uppercase tracking-wider font-bold text-n-slate-11 bg-n-weak/30 px-1.5 py-0.5 rounded border border-n-weak/50">
                {{ selectedActivity.assistant_name }}
              </span>
            </div>
            <h3 class="text-sm font-semibold text-n-slate-12">
              {{ selectedActivity.filter_name }}
            </h3>
          </div>
          <button
            class="ml-3 p-1.5 text-n-slate-11 hover:text-n-slate-12 hover:bg-n-slate-3 rounded-lg transition-colors"
            @click="closeModal"
          >
            <i class="i-lucide-x w-4 h-4" />
          </button>
        </div>

        <!-- Body -->
        <div class="flex-1 overflow-y-auto p-4 space-y-4">
          <!-- Status -->
          <div class="flex items-center gap-2">
            <i class="text-base" :class="[statusIcon(selectedActivity.status), statusColor(selectedActivity.status)]" />
            <span class="text-sm font-medium" :class="statusColor(selectedActivity.status)">
              {{ statusLabel(selectedActivity.status) }}
            </span>
          </div>

          <!-- Message -->
          <div v-if="selectedActivity.message">
            <p class="text-xs font-semibold text-n-slate-11 uppercase tracking-wider mb-1">
              {{ t('CAPTAIN_TIMELINE.MODAL.MESSAGE') }}
            </p>
            <p class="text-sm text-n-slate-12 whitespace-pre-wrap bg-n-slate-2 rounded-lg p-3">
              {{ selectedActivity.message }}
            </p>
          </div>

          <!-- Error -->
          <div v-if="selectedActivity.error_message">
            <p class="text-xs font-semibold text-n-ruby-11 uppercase tracking-wider mb-1">
              {{ t('CAPTAIN_TIMELINE.MODAL.ERROR') }}
            </p>
            <p class="text-sm text-n-ruby-11 bg-n-ruby-2 rounded-lg p-3 whitespace-pre-wrap">
              {{ selectedActivity.error_message }}
            </p>
          </div>

          <!-- Meta -->
          <div class="space-y-2 pt-2 border-t border-n-weak">
            <div v-if="selectedActivity.triggered_by" class="flex justify-between text-sm">
              <span class="text-n-slate-11">{{ t('CAPTAIN_TIMELINE.MODAL.TRIGGERED_BY') }}</span>
              <span class="text-n-slate-12 font-medium">{{ selectedActivity.triggered_by }}</span>
            </div>
            <div v-else-if="selectedActivity.scheduled_at" class="flex justify-between text-sm">
              <span class="text-n-slate-11">{{ t('CAPTAIN_TIMELINE.MODAL.SCHEDULED_AT') }}</span>
              <span class="text-n-slate-12 font-medium">{{ formatFullDate(selectedActivity.scheduled_at) }}</span>
            </div>
            <div v-if="selectedActivity.processed_at" class="flex justify-between text-sm">
              <span class="text-n-slate-11">{{ t('CAPTAIN_TIMELINE.MODAL.PROCESSED_AT') }}</span>
              <span class="text-n-slate-12">{{ formatFullDate(selectedActivity.processed_at) }}</span>
            </div>
            <div class="flex justify-between text-sm">
              <span class="text-n-slate-11">{{ t('CAPTAIN_TIMELINE.MODAL.CREATED_AT') }}</span>
              <span class="text-n-slate-12">{{ formatFullDate(selectedActivity.created_at) }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </Teleport>
</template>
