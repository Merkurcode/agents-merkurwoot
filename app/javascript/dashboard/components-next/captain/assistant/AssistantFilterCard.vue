<script setup>
import { computed } from 'vue';
import { useToggle } from '@vueuse/core';
import { useI18n } from 'vue-i18n';

import CardLayout from 'dashboard/components-next/CardLayout.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Policy from 'dashboard/components/policy.vue';

const props = defineProps({
  filter: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['action']);
const { t } = useI18n();

const [showActionsDropdown, toggleDropdown] = useToggle();

const conditionsSummary = computed(() => {
  const conditions = props.filter.filters || [];
  if (!conditions.length) return '—';
  return conditions.map(c => c.attribute_key || c.attributeKey).join(', ');
});

const matchingCount = computed(
  () => props.filter.matching_conversations_count ?? null
);
const hasNoConversations = computed(() => matchingCount.value === 0);

const menuItems = computed(() => [
  {
    label: t('CAPTAIN.FILTERS.OPTIONS.EDIT'),
    value: 'edit',
    action: 'edit',
    icon: 'i-lucide-pencil',
  },
  {
    label: t('CAPTAIN.FILTERS.OPTIONS.VIEW_RUNS'),
    value: 'view_runs',
    action: 'view_runs',
    icon: 'i-lucide-history',
  },
  {
    label: t('CAPTAIN.FILTERS.OPTIONS.DELETE'),
    value: 'delete',
    action: 'delete',
    icon: 'i-lucide-trash',
  },
]);

const handleAction = ({ action }) => {
  toggleDropdown(false);
  emit('action', { action, id: props.filter.id });
};
</script>

<template>
  <CardLayout>
    <div class="flex justify-between w-full gap-2">
      <div class="flex flex-col gap-1 min-w-0">
        <span class="text-base font-medium text-n-slate-12 truncate">
          {{ filter.name }}
        </span>
        <span class="text-xs text-n-slate-11 truncate">
          {{ $t('CAPTAIN.FILTERS.CARD.CONDITIONS') }}: {{ conditionsSummary }}
        </span>
        <span
          v-if="matchingCount !== null"
          class="text-xs truncate"
          :class="hasNoConversations ? 'text-n-ruby-11' : 'text-n-teal-11'"
        >
          <template v-if="hasNoConversations">
            {{ $t('CAPTAIN.FILTERS.CARD.NO_CONVERSATIONS') }}
          </template>
          <template v-else>
            {{
              $t('CAPTAIN.FILTERS.CARD.MATCHING_CONVERSATIONS', {
                count: matchingCount,
              })
            }}
          </template>
        </span>
      </div>
      <div class="flex items-center gap-2 flex-shrink-0">
        <Policy :permissions="['administrator']">
          <Button
            v-tooltip="
              hasNoConversations
                ? $t('CAPTAIN.FILTERS.CARD.NO_CONVERSATIONS_TOOLTIP')
                : undefined
            "
            size="xs"
            color="blue"
            class="rounded-md"
            :disabled="hasNoConversations"
            @click.stop="emit('action', { action: 'run', id: filter.id })"
          >
            <span class="i-lucide-play mr-1" />
            {{ $t('CAPTAIN.FILTERS.OPTIONS.RUN') }}
          </Button>
        </Policy>
        <Policy
          v-on-clickaway="() => toggleDropdown(false)"
          :permissions="['administrator']"
          class="relative flex items-center group"
        >
          <Button
            icon="i-lucide-ellipsis-vertical"
            color="slate"
            size="xs"
            class="rounded-md group-hover:bg-n-alpha-2"
            @click="toggleDropdown()"
          />
          <DropdownMenu
            v-if="showActionsDropdown"
            :menu-items="menuItems"
            class="mt-1 ltr:right-0 rtl:left-0 top-full"
            @action="handleAction($event)"
          />
        </Policy>
      </div>
    </div>
  </CardLayout>
</template>
