<script setup>
import { computed, ref, nextTick, onMounted } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useRoute } from 'vue-router';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import AssistantFilterCard from 'dashboard/components-next/captain/assistant/AssistantFilterCard.vue';
import AssistantFilterDialog from 'dashboard/components-next/captain/pageComponents/filters/AssistantFilterDialog.vue';
import DeleteDialog from 'dashboard/components-next/captain/pageComponents/DeleteDialog.vue';

const store = useStore();
const route = useRoute();

const assistantId = computed(() => Number(route.params.assistantId));
const uiFlags = useMapGetter('captainAssistantFilters/getUIFlags');
const allFilters = useMapGetter('captainAssistantFilters/getRecords');

const assistantFilters = computed(() =>
  allFilters.value.filter(f => f.captain_assistant_id === assistantId.value)
);

const isFetching = computed(() => uiFlags.value.fetchingList);

const selectedFilter = ref(null);
const filterDialogRef = ref(null);
const deleteDialogRef = ref(null);
const isEditing = ref(false);

const handleCreate = () => {
  isEditing.value = false;
  selectedFilter.value = null;
  nextTick(() => filterDialogRef.value?.dialogRef?.open());
};

const handleAction = ({ action, id }) => {
  selectedFilter.value = assistantFilters.value.find(f => f.id === id);
  nextTick(() => {
    if (action === 'edit') {
      isEditing.value = true;
      filterDialogRef.value?.dialogRef?.open();
    } else if (action === 'delete') {
      deleteDialogRef.value?.dialogRef?.open();
    }
  });
};

const handleDialogClose = () => {
  selectedFilter.value = null;
  isEditing.value = false;
};

const handleDeleteSuccess = () => {
  selectedFilter.value = null;
};

onMounted(() => {
  store.dispatch('captainAssistantFilters/get');
});
</script>

<template>
  <PageLayout
    :header-title="$t('CAPTAIN.FILTERS.HEADER')"
    :button-label="$t('CAPTAIN.FILTERS.ADD_NEW')"
    :button-policy="['administrator']"
    :is-fetching="isFetching"
    :is-empty="!assistantFilters.length"
    :show-pagination-footer="false"
    :show-know-more="false"
    :feature-flag="FEATURE_FLAGS.CAPTAIN"
    @click="handleCreate"
  >
    <template #emptyState>
      <div class="flex flex-col items-center gap-3 py-12 text-center">
        <span class="i-lucide-filter text-3xl text-n-slate-11" />
        <p class="text-sm text-n-slate-11">
          {{ $t('CAPTAIN.FILTERS.EMPTY_STATE') }}
        </p>
      </div>
    </template>

    <template #body>
      <div class="flex flex-col gap-4">
        <AssistantFilterCard
          v-for="f in assistantFilters"
          :key="f.id"
          :filter="f"
          @action="handleAction"
        />
      </div>
    </template>
  </PageLayout>

  <AssistantFilterDialog
    ref="filterDialogRef"
    :assistant-id="assistantId"
    :filter="isEditing ? selectedFilter : null"
    @close="handleDialogClose"
  />

  <DeleteDialog
    v-if="selectedFilter && !isEditing"
    ref="deleteDialogRef"
    :entity="selectedFilter"
    type="AssistantFilters"
    translation-key="FILTERS"
    @delete-success="handleDeleteSuccess"
  />
</template>
