<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import AccountAPI from 'dashboard/api/account';
import NextButton from 'dashboard/components-next/button/Button.vue';
import SectionLayout from './SectionLayout.vue';

const { t } = useI18n();
const store = useStore();
const { currentAccount } = useAccount();

const slotDuration = ref(30);
const isUpdating = ref(false);

watch(
  currentAccount,
  account => {
    if (account) {
      slotDuration.value =
        account.settings?.appointment_slot_duration_minutes ?? 30;
    }
  },
  { immediate: true }
);

const save = async () => {
  const minutes = Number(slotDuration.value);
  if (!minutes || minutes < 15 || minutes > 480) {
    useAlert(t('GENERAL_SETTINGS.FORM.APPOINTMENT_SLOT_DURATION.VALIDATION_ERROR'));
    return;
  }

  isUpdating.value = true;
  try {
    const response = await AccountAPI.update('', {
      appointment_slot_duration_minutes: minutes,
    });
    store.commit('accounts/EDIT_ACCOUNT', response.data);
    useAlert(t('GENERAL_SETTINGS.FORM.APPOINTMENT_SLOT_DURATION.API.SUCCESS'));
  } catch {
    useAlert(t('GENERAL_SETTINGS.FORM.APPOINTMENT_SLOT_DURATION.API.ERROR'));
  } finally {
    isUpdating.value = false;
  }
};
</script>

<template>
  <SectionLayout
    :title="$t('GENERAL_SETTINGS.FORM.APPOINTMENT_SLOT_DURATION.TITLE')"
    :description="$t('GENERAL_SETTINGS.FORM.APPOINTMENT_SLOT_DURATION.NOTE')"
  >
    <div class="flex items-center gap-4">
      <div class="flex items-center gap-2">
        <input
          v-model.number="slotDuration"
          type="number"
          min="15"
          max="480"
          step="15"
          class="w-24 rounded-lg border border-slate-200 px-3 py-2 text-sm text-slate-800 dark:border-slate-700 dark:text-slate-100 dark:bg-slate-900"
        />
        <span class="text-sm text-slate-600 dark:text-slate-400">
          {{ $t('GENERAL_SETTINGS.FORM.APPOINTMENT_SLOT_DURATION.MINUTES_LABEL') }}
        </span>
      </div>
      <NextButton blue :is-loading="isUpdating" @click="save">
        {{ $t('GENERAL_SETTINGS.FORM.APPOINTMENT_SLOT_DURATION.UPDATE_BUTTON') }}
      </NextButton>
    </div>
  </SectionLayout>
</template>
