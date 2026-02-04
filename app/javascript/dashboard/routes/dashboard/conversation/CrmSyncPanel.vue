<script setup>
import { computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStoreGetters, useStore } from 'dashboard/composables/store';

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
});

const executions = computed(() =>
  getters['crmFlows/getConversationExecutions'].value(props.conversationId)
);

onMounted(() => {
  store.dispatch('crmFlows/getConversationExecutions', props.conversationId);
});

function statusClass(status) {
  switch (status) {
    case 'success': return 'text-green-600';
    case 'failed':  return 'text-red-500';
    case 'partial': return 'text-amber-600';
    default:        return 'text-n-slate-9';
  }
}

function statusBg(status) {
  switch (status) {
    case 'success': return 'bg-green-100 text-green-700';
    case 'failed':  return 'bg-red-100 text-red-700';
    case 'partial': return 'bg-amber-100 text-amber-700';
    default:        return 'bg-n-slate-3 text-n-slate-11';
  }
}

function formatTime(dateStr) {
  if (!dateStr) return '';
  const d = new Date(dateStr);
  return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

function resultIcon(status) {
  switch (status) {
    case 'success': return '✓';
    case 'skipped': return '●';
    case 'failed':  return '✗';
    default:        return '—';
  }
}

function resultColor(status) {
  switch (status) {
    case 'success': return 'text-green-600';
    case 'skipped': return 'text-n-slate-9';
    case 'failed':  return 'text-red-500';
    default:        return 'text-n-slate-9';
  }
}

// CRM dashboard URLs para links directos
function crmUrl(crm, externalId) {
  if (!externalId) return null;
  switch (crm) {
    case 'salesforce': return `https://na1.salesforce.com/o/Lead/${externalId}`;
    case 'zoho':       return `https://crm.zoho.com/crm/private#/CRM/Leads/${externalId}`;
    default:           return null;
  }
}
</script>

<template>
  <div class="px-1 py-2">
    <!-- Estado vacío -->
    <p v-if="!executions.length" class="text-xs text-n-slate-9 text-center py-3">
      {{ $t('CRM_FLOWS.CRM_SYNC.EMPTY') }}
    </p>

    <!-- Lista de ejecuciones -->
    <div v-else class="flex flex-col gap-3">
      <div
        v-for="exec in executions"
        :key="exec.id"
        class="border border-n-weak rounded-lg p-2.5"
      >
        <!-- Header de la ejecución -->
        <div class="flex items-center justify-between mb-1.5">
          <span class="text-xs font-semibold text-n-slate-12">{{ exec.flow_name }}</span>
          <span :class="statusBg(exec.status)" class="text-xs font-medium rounded-full px-2 py-0.5">
            {{ $t(`CRM_FLOWS.CRM_SYNC.STATUS.${exec.status.toUpperCase()}`) }}
          </span>
        </div>
        <span class="text-xs text-n-slate-9">
          {{ $t('CRM_FLOWS.CRM_SYNC.EXECUTED_AT', { time: formatTime(exec.created_at) }) }}
        </span>

        <!-- Resultados por acción -->
        <div class="mt-2 flex flex-col gap-1">
          <div
            v-for="(result, idx) in (exec.results || [])"
            :key="idx"
            class="flex items-start gap-1.5"
          >
            <span :class="resultColor(result.status)" class="text-xs font-bold leading-4">
              {{ resultIcon(result.status) }}
            </span>
            <div class="flex-1">
              <span class="text-xs text-n-slate-11">
                {{ result.action?.replace(/_/g, ' ') }}
                <span v-if="result.crm" class="text-n-slate-9">en {{ result.crm }}</span>
              </span>
              <!-- Link al CRM si hay external_id -->
              <a
                v-if="result.external_id && crmUrl(result.crm, result.external_id)"
                :href="crmUrl(result.crm, result.external_id)"
                target="_blank"
                rel="noopener noreferrer"
                class="ml-1 text-xs text-blue-600 hover:underline"
              >
                → Open
              </a>
              <!-- Error message -->
              <span v-if="result.status === 'failed' && result.error" class="text-xs text-red-500 ml-1">
                — {{ result.error }}
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
