<script setup>
import { ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import NextButton from '../../../../components-next/button/Button.vue';
import scheduleBlocksAPI from '../../../../api/scheduleBlocks';

const props = defineProps({
  agentId: {
    type: Number,
    required: true,
  },
});

const { t } = useI18n();
const blocks = ref([]);
const isLoading = ref(false);

const DAY_NAMES = [
  t('SCHEDULE_BLOCKS.DAYS.SUNDAY'),
  t('SCHEDULE_BLOCKS.DAYS.MONDAY'),
  t('SCHEDULE_BLOCKS.DAYS.TUESDAY'),
  t('SCHEDULE_BLOCKS.DAYS.WEDNESDAY'),
  t('SCHEDULE_BLOCKS.DAYS.THURSDAY'),
  t('SCHEDULE_BLOCKS.DAYS.FRIDAY'),
  t('SCHEDULE_BLOCKS.DAYS.SATURDAY'),
];

const newBlock = ref({
  day_of_week: 1,
  start_hour: 12,
  start_minutes: 0,
  end_hour: 13,
  end_minutes: 0,
  reason: '',
});
const showAddForm = ref(false);

const fetchBlocks = async () => {
  try {
    const { data } = await scheduleBlocksAPI.getForAgent(props.agentId);
    blocks.value = data;
  } catch {
    useAlert(t('SCHEDULE_BLOCKS.ERRORS.FETCH'));
  }
};

const addBlock = async () => {
  isLoading.value = true;
  try {
    await scheduleBlocksAPI.create(props.agentId, { ...newBlock.value });
    await fetchBlocks();
    showAddForm.value = false;
    newBlock.value = { day_of_week: 1, start_hour: 12, start_minutes: 0, end_hour: 13, end_minutes: 0, reason: '' };
    useAlert(t('SCHEDULE_BLOCKS.SUCCESS.CREATED'));
  } catch {
    useAlert(t('SCHEDULE_BLOCKS.ERRORS.CREATE'));
  } finally {
    isLoading.value = false;
  }
};

const removeBlock = async (blockId) => {
  try {
    await scheduleBlocksAPI.destroy(props.agentId, blockId);
    await fetchBlocks();
    useAlert(t('SCHEDULE_BLOCKS.SUCCESS.DELETED'));
  } catch {
    useAlert(t('SCHEDULE_BLOCKS.ERRORS.DELETE'));
  }
};

const formatTime = (hour, minutes) =>
  `${String(hour).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;

onMounted(fetchBlocks);
</script>

<template>
  <div class="flex flex-col gap-4">
    <div v-if="blocks.length === 0" class="text-sm text-slate-500">
      {{ t('SCHEDULE_BLOCKS.EMPTY') }}
    </div>

    <div v-for="block in blocks" :key="block.id" class="flex items-center gap-3 rounded-lg border border-slate-200 px-4 py-2">
      <span class="w-28 text-sm font-medium text-slate-700">{{ DAY_NAMES[block.day_of_week] }}</span>
      <span class="text-sm text-slate-600">
        {{ formatTime(block.start_hour, block.start_minutes) }} – {{ formatTime(block.end_hour, block.end_minutes) }}
      </span>
      <span v-if="block.reason" class="flex-1 text-sm text-slate-400 italic">{{ block.reason }}</span>
      <NextButton
        variant="clear"
        color-scheme="alert"
        size="small"
        :label="t('SCHEDULE_BLOCKS.DELETE')"
        @click="removeBlock(block.id)"
      />
    </div>

    <div v-if="showAddForm" class="flex flex-col gap-3 rounded-lg border border-slate-200 p-4">
      <div class="flex flex-wrap gap-3">
        <div class="flex flex-col gap-1">
          <label class="text-xs font-medium text-slate-600">{{ t('SCHEDULE_BLOCKS.DAY') }}</label>
          <select v-model.number="newBlock.day_of_week" class="rounded border border-slate-300 px-2 py-1 text-sm">
            <option v-for="(name, idx) in DAY_NAMES" :key="idx" :value="idx">{{ name }}</option>
          </select>
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-xs font-medium text-slate-600">{{ t('SCHEDULE_BLOCKS.START') }}</label>
          <div class="flex gap-1">
            <input v-model.number="newBlock.start_hour" type="number" min="0" max="23" class="w-14 rounded border border-slate-300 px-2 py-1 text-sm" />
            <input v-model.number="newBlock.start_minutes" type="number" min="0" max="59" step="15" class="w-14 rounded border border-slate-300 px-2 py-1 text-sm" />
          </div>
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-xs font-medium text-slate-600">{{ t('SCHEDULE_BLOCKS.END') }}</label>
          <div class="flex gap-1">
            <input v-model.number="newBlock.end_hour" type="number" min="0" max="23" class="w-14 rounded border border-slate-300 px-2 py-1 text-sm" />
            <input v-model.number="newBlock.end_minutes" type="number" min="0" max="59" step="15" class="w-14 rounded border border-slate-300 px-2 py-1 text-sm" />
          </div>
        </div>
        <div class="flex flex-col gap-1 flex-1">
          <label class="text-xs font-medium text-slate-600">{{ t('SCHEDULE_BLOCKS.REASON') }}</label>
          <input v-model="newBlock.reason" type="text" :placeholder="t('SCHEDULE_BLOCKS.REASON_PLACEHOLDER')" class="rounded border border-slate-300 px-2 py-1 text-sm" />
        </div>
      </div>
      <div class="flex gap-2">
        <NextButton
          type="button"
          size="small"
          :label="t('SCHEDULE_BLOCKS.SAVE')"
          :is-loading="isLoading"
          @click="addBlock"
        />
        <NextButton
          type="button"
          variant="clear"
          size="small"
          :label="t('GENERAL.CANCEL')"
          @click="showAddForm = false"
        />
      </div>
    </div>

    <div>
      <NextButton
        v-if="!showAddForm"
        type="button"
        variant="clear"
        size="small"
        :label="t('SCHEDULE_BLOCKS.ADD')"
        @click="showAddForm = true"
      />
    </div>
  </div>
</template>
