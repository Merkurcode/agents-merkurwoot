<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';
import CaptainAssistantFilterRunsAPI from 'dashboard/api/captain/assistantFilterRuns';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const runs = ref([]);
const meta = ref({});
const isLoading = ref(true);
const currentPage = ref(1);

const totalRuns = computed(() => meta.value.total_count || 0);

const statusColors = {
  pending: 'bg-n-yellow-3 text-n-yellow-11',
  running: 'bg-n-brand-3 text-n-brand-11',
  completed: 'bg-n-teal-3 text-n-teal-11',
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

const fetchRuns = async () => {
  try {
    const response = await CaptainAssistantFilterRunsAPI.get({
      assistant_filter_id: route.params.filterId,
      page: currentPage.value,
    });
    runs.value = response.data.payload || [];
    meta.value = response.data.meta || {};
  } catch {
    // silently handled
  }
};

const handlePageChange = newPage => {
  currentPage.value = newPage;
  fetchRuns();
};

const goToDetail = run => {
  router.push({
    name: 'captain_assistants_filter_run_detail',
    params: { ...route.params, runId: run.id },
  });
};

onMounted(async () => {
  await fetchRuns();
  isLoading.value = false;
});
</script>

<template>
  <div class="flex flex-col w-full h-full">
    <div class="flex items-center gap-4 px-12 py-4 border-b border-n-slate-6">
      <Button
        variant="faded"
        color="slate"
        icon="i-lucide-arrow-left"
        @click="goBack"
      />
      <h1 class="text-2xl font-semibold text-n-slate-12">
        {{ t('CAPTAIN.FILTER_RUNS.INDEX.TITLE') }}
      </h1>
    </div>

    <div v-if="isLoading" class="flex items-center justify-center py-20">
      <Spinner />
    </div>

    <div v-else class="flex-1 overflow-auto px-12 py-12">
      <div class="bg-n-white dark:bg-n-slate-1 rounded-lg border border-n-slate-6 overflow-hidden">
        <table class="w-full">
          <thead class="bg-n-solid-2 border-b border-n-slate-6">
            <tr>
              <th class="text-left px-4 py-3 text-sm font-medium text-n-slate-12">
                {{ t('CAPTAIN.FILTER_RUNS.INDEX.TABLE.FILTER') }}
              </th>
              <th class="text-left px-4 py-3 text-sm font-medium text-n-slate-12">
                {{ t('CAPTAIN.FILTER_RUNS.INDEX.TABLE.STATUS') }}
              </th>
              <th class="text-left px-4 py-3 text-sm font-medium text-n-slate-12">
                {{ t('CAPTAIN.FILTER_RUNS.INDEX.TABLE.CREATED_AT') }}
              </th>
              <th class="text-left px-4 py-3 text-sm font-medium text-n-slate-12">
                {{ t('CAPTAIN.FILTER_RUNS.INDEX.TABLE.PROGRESS') }}
              </th>
              <th class="px-4 py-3" />
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="run in runs"
              :key="run.id"
              class="border-b border-n-slate-6"
            >
              <td class="px-4 py-3">
                <span class="text-sm font-medium text-n-slate-12">
                  {{ run.assistant_filter?.name }}
                </span>
              </td>
              <td class="px-4 py-3">
                <span
                  :class="statusColors[run.status]"
                  class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium"
                >
                  {{ t(`CAPTAIN.FILTER_RUNS.STATUS.${run.status.toUpperCase()}`) }}
                </span>
              </td>
              <td class="px-4 py-3 text-sm text-n-slate-11">
                {{ formatDate(run.created_at) }}
              </td>
              <td class="px-4 py-3 text-sm text-n-slate-11">
                {{ run.conversations_processed }} /
                {{ run.conversations_total }}
              </td>
              <td class="px-4 py-3 text-right">
                <Button
                  variant="faded"
                  color="slate"
                  size="sm"
                  icon="i-lucide-eye"
                  @click="goToDetail(run)"
                />
              </td>
            </tr>
          </tbody>
        </table>

        <div v-if="runs.length === 0" class="py-16 text-center">
          <p class="text-n-slate-11">
            {{ t('CAPTAIN.FILTER_RUNS.INDEX.EMPTY_STATE') }}
          </p>
        </div>

        <div v-if="totalRuns > 0" class="border-t border-n-slate-6 px-4 py-3">
          <PaginationFooter
            :current-page="currentPage"
            :total-items="totalRuns"
            :items-per-page="25"
            @update:current-page="handlePageChange"
          />
        </div>
      </div>
    </div>
  </div>
</template>
