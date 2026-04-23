<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { debounce } from '@chatwoot/utils';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { format } from 'date-fns';

import TasksListLayout from '../components/TasksListLayout.vue';
import TaskModal from '../components/TaskModal.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const DEBOUNCE_DELAY = 300;
const ITEMS_PER_PAGE = 15;

const { t } = useI18n();
const store = useStore();
const { updateUISettings, uiSettings } = useUISettings();

const tasks = useMapGetter('tasks/getTasks');
const uiFlags = useMapGetter('tasks/getUIFlags');
const meta = useMapGetter('tasks/getMeta');

const isLoading = computed(() => uiFlags.value.isFetching);
const hasTasks = computed(() => tasks.value.length > 0);
const currentPage = computed(() => meta.value?.currentPage || 1);
const totalItems = computed(() => meta.value?.count || 0);

const parseSortSettings = (sortString = '-created_at') => {
  const hasDescending = sortString.startsWith('-');
  const sortField = hasDescending ? sortString.slice(1) : sortString;
  return { sort: sortField || 'created_at', order: hasDescending ? '-' : '' };
};

const buildSortAttr = () => `${sortState.activeOrdering}${sortState.activeSort}`;

const { tasks_sort_by: taskSortBy = '-created_at' } = uiSettings.value ?? {};
const { sort: initialSort, order: initialOrder } = parseSortSettings(taskSortBy);

const sortState = reactive({
  activeSort: initialSort,
  activeOrdering: initialOrder,
});

const searchValue = ref('');
const showModal = ref(false);
const selectedTask = ref(null);
const bulkDeleteDialogRef = ref(null);
const taskToDelete = ref(null);

const statusClasses = {
  pending: 'bg-amber-100 text-amber-800 dark:bg-amber-900/20 dark:text-amber-400',
  in_progress: 'bg-blue-100 text-blue-800 dark:bg-blue-900/20 dark:text-blue-400',
  completed: 'bg-teal-100 text-teal-800 dark:bg-teal-900/20 dark:text-teal-400',
  cancelled: 'bg-slate-100 text-slate-800 dark:bg-slate-900/20 dark:text-slate-400',
};

const actionTypeIcons = {
  general: 'i-lucide-clipboard-list',
  schedule_appointment: 'i-lucide-calendar-plus',
  send_message: 'i-lucide-send',
  assign_conversation: 'i-lucide-user-check',
};

const entityIcons = {
  Conversation: 'i-lucide-message-square',
  Contact: 'i-lucide-user',
  Appointment: 'i-lucide-calendar-check',
};

const formatDate = dateString => {
  if (!dateString) return '';
  return format(new Date(dateString), 'MMM d, yyyy');
};

const formatSchedule = task => {
  const config = task.execution_config || {};
  const parts = [];
  if (config.days_of_week?.length) {
    const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    parts.push(config.days_of_week.map(d => dayNames[d]).join(', '));
  }
  if (config.time_from && config.time_to) {
    parts.push(`${config.time_from} – ${config.time_to}`);
  } else if (config.time_from) {
    parts.push(`from ${config.time_from}`);
  }
  return parts.join(' · ') || '–';
};

const fetchTasks = async (page = 1) => {
  await store.dispatch('tasks/get', { page, sortAttr: buildSortAttr() });
};

const searchTasks = debounce(async (value, page = 1) => {
  searchValue.value = value;
  if (!value) {
    await fetchTasks(page);
    return;
  }
  await store.dispatch('tasks/search', {
    search: value,
    page,
    sortAttr: buildSortAttr(),
  });
}, DEBOUNCE_DELAY);

const handleSort = async ({ sort, order }) => {
  Object.assign(sortState, { activeSort: sort, activeOrdering: order });
  await updateUISettings({ tasks_sort_by: buildSortAttr() });
  if (searchValue.value) {
    await store.dispatch('tasks/search', {
      search: searchValue.value,
      page: 1,
      sortAttr: buildSortAttr(),
    });
  } else {
    await fetchTasks(1);
  }
};

const updateCurrentPage = async page => {
  if (searchValue.value) {
    await store.dispatch('tasks/search', {
      search: searchValue.value,
      page,
      sortAttr: buildSortAttr(),
    });
  } else {
    await fetchTasks(page);
  }
};

const openAddModal = () => {
  selectedTask.value = null;
  showModal.value = true;
};

const editTask = task => {
  selectedTask.value = task;
  showModal.value = true;
};

const closeModal = () => {
  showModal.value = false;
  selectedTask.value = null;
  fetchTasks(currentPage.value);
};

const openDeleteConfirmation = task => {
  taskToDelete.value = task;
  bulkDeleteDialogRef.value?.open?.();
};

const executeTask = async task => {
  try {
    await store.dispatch('tasks/execute', task.id);
    useAlert(t('TASKS.EXECUTE.SUCCESS'));
  } catch {
    useAlert(t('TASKS.EXECUTE.ERROR'));
  }
};

const confirmDelete = async () => {
  try {
    await store.dispatch('tasks/delete', taskToDelete.value.id);
    await fetchTasks(currentPage.value);
    useAlert(t('TASKS.DELETE.SUCCESS'));
    bulkDeleteDialogRef.value?.close?.();
    taskToDelete.value = null;
  } catch {
    useAlert(t('TASKS.DELETE.ERROR'));
  }
};

onMounted(() => fetchTasks());
</script>

<template>
  <TasksListLayout
    :header-title="$t('TASKS.HEADER.TITLE')"
    :search-value="searchValue"
    :show-pagination-footer="hasTasks && !isLoading"
    :current-page="currentPage"
    :total-items="totalItems"
    :items-per-page="ITEMS_PER_PAGE"
    :is-fetching-list="isLoading"
    :active-sort="sortState.activeSort"
    :active-ordering="sortState.activeOrdering"
    @update:current-page="updateCurrentPage"
    @search="searchTasks"
    @update:sort="handleSort"
    @create="openAddModal"
  >
    <!-- Loading -->
    <div v-if="isLoading && !hasTasks" class="flex items-center justify-center py-20 text-n-slate-11">
      <Spinner />
    </div>

    <!-- Empty state -->
    <div
      v-else-if="!hasTasks"
      class="flex flex-col items-center justify-center py-20"
    >
      <Icon icon="i-lucide-clipboard-x" class="w-16 h-16 mx-auto mb-4 text-n-slate-9" />
      <h3 class="text-lg font-semibold text-n-slate-12 mb-2">
        {{ $t('TASKS.EMPTY_STATE_TITLE') }}
      </h3>
      <p class="text-n-slate-11">
        {{ $t('TASKS.EMPTY_STATE_DESCRIPTION') }}
      </p>
    </div>

    <!-- Tasks table -->
    <div
      v-else
      class="bg-white dark:bg-n-slate-1 rounded-lg border border-n-weak"
    >
      <table class="min-w-full divide-y divide-n-weak">
        <tbody class="divide-y divide-n-weak">
          <tr
            v-for="task in tasks"
            :key="task.id"
            class="hover:bg-n-slate-2 transition-colors"
          >
            <!-- Title + description -->
            <td class="py-4 px-4">
              <div class="font-medium text-n-slate-12 truncate max-w-[200px]">
                {{ task.title }}
              </div>
              <div
                v-if="task.description"
                class="text-sm text-n-slate-11 truncate max-w-[200px]"
                :title="task.description"
              >
                {{ task.description }}
              </div>
              <div v-else class="text-sm text-n-slate-9 italic">
                {{ $t('TASKS.NO_DESCRIPTION') }}
              </div>
            </td>

            <!-- Status + Action type -->
            <td class="py-4 px-4">
              <div class="flex flex-col gap-1">
                <span
                  :class="statusClasses[task.status]"
                  class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium whitespace-nowrap"
                >
                  {{ $t(`TASKS.STATUS.${task.status.toUpperCase()}`) }}
                </span>
                <span
                  v-if="task.action_type && task.action_type !== 'general'"
                  class="inline-flex items-center gap-1 text-xs text-n-slate-11"
                >
                  <Icon
                    :icon="actionTypeIcons[task.action_type] || 'i-lucide-clipboard-list'"
                    class="w-3 h-3"
                  />
                  {{ $t(`TASKS.ACTION_TYPE.${task.action_type.toUpperCase()}`) }}
                </span>
              </div>
            </td>

            <!-- Scheduled at / Execution schedule -->
            <td class="py-4 px-4">
              <div v-if="task.scheduled_at" class="text-sm text-n-slate-11">
                {{ format(new Date(task.scheduled_at), 'MMM d, yyyy HH:mm') }}
              </div>
              <div
                v-else
                class="text-sm text-n-slate-11 max-w-[180px] truncate"
                :title="formatSchedule(task)"
              >
                {{ formatSchedule(task) }}
              </div>
            </td>

            <!-- Assignee -->
            <td class="py-4 px-4">
              <div v-if="task.assignee" class="flex items-center gap-1">
                <Icon icon="i-lucide-user" class="w-3 h-3 text-n-slate-11" />
                <span class="text-sm text-n-slate-11 truncate max-w-[120px]">{{ task.assignee.name }}</span>
              </div>
              <div v-else-if="task.ai_agent" class="flex items-center gap-1">
                <Icon icon="i-lucide-bot" class="w-3 h-3 text-woot-500" />
                <span class="text-sm text-woot-500 truncate max-w-[120px]">{{ task.ai_agent.name }}</span>
              </div>
              <span v-else class="text-sm text-n-slate-9">–</span>
            </td>

            <!-- Linked entity -->
            <td class="py-4 px-4">
              <div v-if="task.entity_type" class="flex items-center gap-2">
                <Icon
                  :icon="entityIcons[task.entity_type] || 'i-lucide-link'"
                  class="w-4 h-4 text-n-slate-11"
                />
                <div>
                  <div class="text-sm font-medium text-n-slate-12">
                    {{ $t(`TASKS.ENTITY_TYPE.${task.entity_type.toUpperCase()}`) }}
                  </div>
                  <div class="text-xs text-n-slate-9">#{{ task.entity_id }}</div>
                </div>
              </div>
              <span v-else class="text-sm text-n-slate-9">–</span>
            </td>

            <!-- Created at -->
            <td class="py-4 px-4">
              <span class="text-sm text-n-slate-11">
                {{ formatDate(task.created_at) }}
              </span>
            </td>

            <!-- Actions -->
            <td class="py-4 px-4">
              <div class="flex justify-end gap-1">
                <Button
                  v-if="task.status === 'pending'"
                  v-tooltip.top="$t('TASKS.ACTIONS.EXECUTE')"
                  icon="i-lucide-play"
                  xs
                  faded
                  @click="executeTask(task)"
                />
                <Button
                  v-tooltip.top="$t('TASKS.ACTIONS.EDIT')"
                  icon="i-lucide-pen"
                  slate
                  xs
                  faded
                  @click="editTask(task)"
                />
                <Button
                  v-tooltip.top="$t('TASKS.ACTIONS.DELETE')"
                  icon="i-lucide-trash-2"
                  xs
                  ruby
                  faded
                  @click="openDeleteConfirmation(task)"
                />
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </TasksListLayout>

  <!-- Create / Edit modal -->
  <woot-modal v-model:show="showModal" size="medium" :on-close="closeModal">
    <TaskModal v-if="showModal" :task="selectedTask" :on-close="closeModal" />
  </woot-modal>

  <!-- Delete confirmation -->
  <Dialog
    ref="bulkDeleteDialogRef"
    type="alert"
    :title="$t('TASKS.DELETE.CONFIRM_TITLE')"
    :description="$t('TASKS.DELETE.CONFIRM_MESSAGE')"
    :confirm-button-label="$t('TASKS.DELETE.YES')"
    @confirm="confirmDelete"
  />
</template>
