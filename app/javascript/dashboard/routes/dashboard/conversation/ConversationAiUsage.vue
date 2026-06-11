<script setup>
import { ref, onMounted, computed } from 'vue';
import conversationsAPI from 'dashboard/api/conversations';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
});

const usage = ref(null);
const loading = ref(false);

onMounted(async () => {
  loading.value = true;
  try {
    const { data } = await conversationsAPI.getAiUsage(props.conversationId);
    usage.value = data;
  } catch {
    usage.value = null;
  } finally {
    loading.value = false;
  }
});

const formattedCost = computed(() => {
  if (!usage.value?.ai_cost_usd) return '—';
  return `$${Number(usage.value.ai_cost_usd).toFixed(6)}`;
});

const formattedDuration = computed(() => {
  if (!usage.value?.ai_duration_seconds) return '—';
  return `${Number(usage.value.ai_duration_seconds).toFixed(2)}s`;
});

const formattedAvgLatency = computed(() => {
  if (!usage.value?.ai_avg_latency_ms) return '—';
  return `${Math.round(usage.value.ai_avg_latency_ms)} ms`;
});

const formattedP95Latency = computed(() => {
  if (!usage.value?.ai_p95_latency_ms) return '—';
  return `${Math.round(usage.value.ai_p95_latency_ms)} ms`;
});

const costByModelEntries = computed(() => {
  const byModel = usage.value?.ai_cost_by_model;
  if (!byModel || typeof byModel !== 'object') return [];
  return Object.entries(byModel).map(([model, data]) => {
    const costUsd = typeof data === 'object' ? data.cost_usd : data;
    return {
      model,
      cost: `$${Number(costUsd).toFixed(6)}`,
    };
  });
});
</script>

<template>
  <div>
    <div v-if="loading" class="flex justify-center px-4 py-4">
      <span class="text-sm text-n-slate-11">{{ $t('LOADING') }}</span>
    </div>

    <div v-else-if="!usage" class="px-4 py-3">
      <p class="text-sm text-n-slate-11">
        {{ $t('CONVERSATION_SIDEBAR.AI_USAGE.NO_DATA') }}
      </p>
    </div>

    <div v-else>
      <div
        class="flex items-center justify-between px-4 py-2 border-b border-n-weak"
      >
        <span class="text-xs text-n-slate-11">
          {{ $t('CONVERSATION_SIDEBAR.AI_USAGE.INPUT_TOKENS') }}
        </span>
        <span class="text-xs font-medium text-n-slate-12">
          {{ usage.ai_input_tokens?.toLocaleString() ?? '—' }}
        </span>
      </div>
      <div
        class="flex items-center justify-between px-4 py-2 border-b border-n-weak"
      >
        <span class="text-xs text-n-slate-11">
          {{ $t('CONVERSATION_SIDEBAR.AI_USAGE.OUTPUT_TOKENS') }}
        </span>
        <span class="text-xs font-medium text-n-slate-12">
          {{ usage.ai_output_tokens?.toLocaleString() ?? '—' }}
        </span>
      </div>
      <div
        class="flex items-center justify-between px-4 py-2 border-b border-n-weak"
      >
        <span class="text-xs text-n-slate-11">
          {{ $t('CONVERSATION_SIDEBAR.AI_USAGE.COST') }}
        </span>
        <span class="text-xs font-medium text-n-teal-11">
          {{ formattedCost }}
        </span>
      </div>
      <div
        class="flex items-center justify-between px-4 py-2 border-b border-n-weak"
      >
        <span class="text-xs text-n-slate-11">
          {{ $t('CONVERSATION_SIDEBAR.AI_USAGE.DURATION') }}
        </span>
        <span class="text-xs font-medium text-n-slate-12">
          {{ formattedDuration }}
        </span>
      </div>
      <div
        class="flex items-center justify-between px-4 py-2 border-b border-n-weak"
      >
        <span class="text-xs text-n-slate-11">
          {{ $t('CONVERSATION_SIDEBAR.AI_USAGE.LLM_CALLS') }}
        </span>
        <span class="text-xs font-medium text-n-slate-12">
          {{ usage.ai_llm_calls ?? '—' }}
        </span>
      </div>
      <div
        class="flex items-center justify-between px-4 py-2 border-b border-n-weak"
      >
        <span class="text-xs text-n-slate-11">
          {{ $t('CONVERSATION_SIDEBAR.AI_USAGE.GRAPH_INVOCATIONS') }}
        </span>
        <span class="text-xs font-medium text-n-slate-12">
          {{ usage.ai_graph_invocations ?? '—' }}
        </span>
      </div>
      <div
        class="flex items-center justify-between px-4 py-2 border-b border-n-weak"
      >
        <span class="text-xs text-n-slate-11">
          {{ $t('CONVERSATION_SIDEBAR.AI_USAGE.AVG_LATENCY') }}
        </span>
        <span class="text-xs font-medium text-n-slate-12">
          {{ formattedAvgLatency }}
        </span>
      </div>
      <div
        class="flex items-center justify-between px-4 py-2 border-b border-n-weak"
      >
        <span class="text-xs text-n-slate-11">
          {{ $t('CONVERSATION_SIDEBAR.AI_USAGE.P95_LATENCY') }}
        </span>
        <span class="text-xs font-medium text-n-slate-12">
          {{ formattedP95Latency }}
        </span>
      </div>
      <div
        class="flex items-center justify-between px-4 py-2"
        :class="
          usage.ai_models_used || costByModelEntries.length
            ? 'border-b border-n-weak'
            : ''
        "
      >
        <span class="text-xs text-n-slate-11">
          {{ $t('CONVERSATION_SIDEBAR.AI_USAGE.ERRORS') }}
        </span>
        <span
          class="text-xs font-medium"
          :class="
            usage.ai_error_count > 0 ? 'text-n-ruby-11' : 'text-n-slate-12'
          "
        >
          {{ usage.ai_error_count ?? '—' }}
        </span>
      </div>

      <!-- Modelos usados -->
      <div v-if="usage.ai_models_used" class="px-4 py-2 border-b border-n-weak">
        <span class="text-xs text-n-slate-11 block mb-1">
          {{ $t('CONVERSATION_SIDEBAR.AI_USAGE.MODELS_USED') }}
        </span>
        <span class="text-xs font-medium text-n-slate-12 break-words">
          {{ usage.ai_models_used }}
        </span>
      </div>

      <!-- Costo por modelo -->
      <div v-if="costByModelEntries.length" class="px-4 py-2">
        <span class="text-xs text-n-slate-11 block mb-1.5">
          {{ $t('CONVERSATION_SIDEBAR.AI_USAGE.COST_BY_MODEL') }}
        </span>
        <div
          v-for="entry in costByModelEntries"
          :key="entry.model"
          class="flex items-center justify-between py-0.5"
        >
          <span class="text-xs text-n-slate-11 truncate mr-2">
            {{ entry.model }}
          </span>
          <span class="text-xs font-medium text-n-teal-11 flex-shrink-0">
            {{ entry.cost }}
          </span>
        </div>
      </div>
    </div>
  </div>
</template>
