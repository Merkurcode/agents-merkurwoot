<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';
import CaptainAssistantFilterRunsAPI from 'dashboard/api/captain/assistantFilterRuns';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const run = ref(null);
const isLoading = ref(true);
const pollingInterval = ref(null);
const currentPage = ref(1);

const conversations = computed(() => run.value?.conversations || []);
const stats = computed(
  () => run.value?.stats || { total: 0, pending: 0, success: 0, failed: 0 }
);
const paginationMeta = computed(() => run.value?.conversations_meta || {});
const totalConversations = computed(
  () => paginationMeta.value.total_count || 0
);
const isRunning = computed(
  () => run.value?.status === 'running' || run.value?.status === 'pending'
);

const statusColors = {
  pending: 'bg-n-yellow-3 text-n-yellow-11',
  running: 'bg-n-brand-3 text-n-brand-11',
  completed: 'bg-n-teal-3 text-n-teal-11',
  failed: 'bg-n-ruby-3 text-n-ruby-11',
};

const convStatusColors = {
  pending: 'bg-n-yellow-3 text-n-yellow-11',
  success: 'bg-n-teal-3 text-n-teal-11',
  failed: 'bg-n-ruby-3 text-n-ruby-11',
};

const formatDate = date => {
  if (!date) return '—';
  return new Date(date).toLocaleString();
};

const goBack = () => {
  router.push({
    name: 'captain_assistants_filters_index',
    params: route.params,
  });
};

const stopPolling = () => {
  if (pollingInterval.value) {
    clearInterval(pollingInterval.value);
    pollingInterval.value = null;
  }
};

const fetchRun = async () => {
  try {
    const response = await CaptainAssistantFilterRunsAPI.show(
      route.params.runId,
      { page: currentPage.value }
    );
    run.value = response.data;

    if (isRunning.value && !pollingInterval.value) {
      pollingInterval.value = setInterval(fetchRun, 3000);
    } else if (!isRunning.value && pollingInterval.value) {
      stopPolling();
    }
  } catch {
    // silently handled
  }
};

const handlePageChange = newPage => {
  currentPage.value = newPage;
  fetchRun();
};

onMounted(async () => {
  await fetchRun();
  isLoading.value = false;
});

onUnmounted(stopPolling);
</script>

<template>
  <div class="flex flex-col w-full h-full">
    <div
      class="flex items-center justify-between px-12 py-4 border-b border-n-slate-6"
    >
      <div class="flex items-center gap-4">
        <Button
          variant="faded"
          color="slate"
          icon="i-lucide-arrow-left"
          @click="goBack"
        />
        <div>
          <h1 class="text-2xl font-semibold text-n-slate-12">
            {{ run?.assistant_filter?.name || '—' }}
          </h1>
          <p class="text-sm text-n-slate-11 mt-1">
            {{ t('CAPTAIN.FILTER_RUNS.DETAIL.ASSISTANT') }}:
            <span class="font-medium">{{
              run?.assistant_filter?.captain_assistant_name
            }}</span>
          </p>
        </div>
      </div>
      <div class="flex items-center gap-3">
        <span
          v-if="run"
          class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium"
          :class="statusColors[run.status]"
        >
          {{ t(`CAPTAIN.FILTER_RUNS.STATUS.${run.status.toUpperCase()}`) }}
        </span>
      </div>
    </div>

    <div
      v-if="isRunning && !isLoading"
      class="mx-12 mt-6 p-4 bg-n-blue-2 border border-n-blue-6 rounded-lg"
    >
      <div class="flex items-center justify-between mb-2">
        <div class="flex items-center gap-2">
          <Spinner class="w-4 h-4" />
          <p class="text-sm font-medium text-n-blue-12">
            {{ t('CAPTAIN.FILTER_RUNS.DETAIL.PROCESSING') }}
          </p>
        </div>
        <p class="text-sm text-n-blue-11">
          {{ run.conversations_processed }} / {{ run.conversations_total }}
        </p>
      </div>
      <div class="w-full bg-n-blue-3 rounded-full h-2">
        <div
          class="bg-n-blue-9 h-2 rounded-full transition-all duration-300"
          :style="{
            width:
              run.conversations_total > 0
                ? `${(run.conversations_processed / run.conversations_total) * 100}%`
                : '0%',
          }"
        />
      </div>
    </div>

    <div v-if="!isLoading" class="grid grid-cols-4 gap-4 px-12 py-6">
      <div
        class="p-4 border border-n-slate-6 shadow outline-1 outline outline-n-container rounded-2xl bg-n-solid-2"
      >
        <p class="text-sm text-n-slate-11">
          {{ t('CAPTAIN.FILTER_RUNS.STATS.TOTAL') }}
        </p>
        <p class="text-2xl font-semibold text-n-slate-12 mt-1">
          {{ stats.total }}
        </p>
      </div>
      <div
        class="p-4 border border-n-slate-6 shadow outline-1 outline outline-n-container rounded-2xl bg-n-solid-2"
      >
        <p class="text-sm text-n-yellow-11">
          {{ t('CAPTAIN.FILTER_RUNS.STATS.PENDING') }}
        </p>
        <p class="text-2xl font-semibold text-n-yellow-12 mt-1">
          {{ stats.pending }}
        </p>
      </div>
      <div
        class="p-4 border border-n-slate-6 shadow outline-1 outline outline-n-container rounded-2xl bg-n-solid-2"
      >
        <p class="text-sm text-n-teal-11">
          {{ t('CAPTAIN.FILTER_RUNS.STATS.SUCCESS') }}
        </p>
        <p class="text-2xl font-semibold text-n-teal-12 mt-1">
          {{ stats.success }}
        </p>
      </div>
      <div
        class="p-4 border border-n-slate-6 shadow outline-1 outline outline-n-container rounded-2xl bg-n-solid-2"
      >
        <p class="text-sm text-n-ruby-11">
          {{ t('CAPTAIN.FILTER_RUNS.STATS.FAILED') }}
        </p>
        <p class="text-2xl font-semibold text-n-ruby-12 mt-1">
          {{ stats.failed }}
        </p>
      </div>
    </div>

    <div v-if="isLoading" class="flex items-center justify-center py-20">
      <Spinner />
    </div>

    <div v-else class="flex-1 overflow-auto px-12 pb-12">
      <div class="bg-n-white dark:bg-n-slate-1 rounded-lg border border-n-slate-6 overflow-hidden">
        <table class="w-full">
          <thead class="bg-n-solid-2 border-b border-n-slate-6">
            <tr>
              <th class="text-left px-4 py-3 text-sm font-medium text-n-slate-12">
                {{ t('CAPTAIN.FILTER_RUNS.TABLE.CONVERSATION') }}
              </th>
              <th class="text-left px-4 py-3 text-sm font-medium text-n-slate-12">
                {{ t('CAPTAIN.FILTER_RUNS.TABLE.STATUS') }}
              </th>
              <th class="text-left px-4 py-3 text-sm font-medium text-n-slate-12">
                {{ t('CAPTAIN.FILTER_RUNS.TABLE.PROCESSED_AT') }}
              </th>
              <th class="text-left px-4 py-3 text-sm font-medium text-n-slate-12">
                {{ t('CAPTAIN.FILTER_RUNS.TABLE.ERROR') }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="rc in conversations"
              :key="rc.id"
              class="border-b border-n-slate-6 hover:bg-n-slate-2 cursor-pointer"
              @click="
                router.push(
                  `/app/accounts/${route.params.accountId}/conversations/${rc.conversation?.display_id}`
                )
              "
            >
              <td class="px-4 py-3">
                <div class="flex items-center gap-2">
                  <span class="i-lucide-message-square text-n-slate-9" />
                  <span class="text-sm font-medium text-n-slate-12">
                    #{{ rc.conversation?.display_id }}
                  </span>
                </div>
              </td>
              <td class="px-4 py-3">
                <span
                  :class="convStatusColors[rc.status]"
                  class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium"
                >
                  {{ t(`CAPTAIN.FILTER_RUNS.CONV_STATUS.${rc.status.toUpperCase()}`) }}
                </span>
              </td>
              <td class="px-4 py-3 text-sm text-n-slate-11">
                {{ formatDate(rc.processed_at) }}
              </td>
              <td class="px-4 py-3 text-sm text-n-ruby-11">
                {{ rc.error_message || '—' }}
              </td>
            </tr>
          </tbody>
        </table>

        <div v-if="conversations.length === 0" class="py-16 text-center">
          <p class="text-n-slate-11">
            {{ t('CAPTAIN.FILTER_RUNS.DETAIL.NO_CONVERSATIONS') }}
          </p>
        </div>

        <div v-if="totalConversations > 0" class="border-t border-n-slate-6 px-4 py-3">
          <PaginationFooter
            :current-page="currentPage"
            :total-items="totalConversations"
            :items-per-page="25"
            @update:current-page="handlePageChange"
          />
        </div>
      </div>
    </div>
  </div>
</template>
