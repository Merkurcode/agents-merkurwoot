<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import SettingsFieldSection from 'dashboard/components-next/Settings/SettingsFieldSection.vue';
import LoadingState from 'dashboard/components/widgets/LoadingState.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import SelectInput from 'dashboard/components-next/select/Select.vue';
import FaqCategorySelector from './FaqCategorySelector.vue';

export default {
  components: {
    LoadingState,
    SettingsFieldSection,
    NextButton,
    SelectInput,
    FaqCategorySelector,
  },
  props: {
    inbox: {
      type: Object,
      default: () => ({}),
    },
  },
  data() {
    return {
      selectedAgentBotId: null,
      selectedSurveyId: null,
    };
  },
  computed: {
    ...mapGetters({
      agentBots: 'agentBots/getBots',
      uiFlags: 'agentBots/getUIFlags',
      surveys: 'surveys/getSurveys',
      isFetchingSurveys: 'surveys/getUIFlags',
    }),
    currentInboxId() {
      return this.inbox?.id || this.$route.params.inboxId;
    },
    activeInbox() {
      return this.inbox;
    },
    activeAgentBot() {
      return this.$store.getters['agentBots/getActiveAgentBot'](
        this.currentInboxId
      );
    },
    activeSurvey() {
      return this.$store.getters['surveys/getSurvey'](
        this.activeInbox?.survey_id
      );
    },
  },
  watch: {
    activeAgentBot() {
      this.selectedAgentBotId = this.activeAgentBot?.id || null;
    },
    'activeInbox.survey_id': {
      immediate: true,
      handler(surveyId) {
        if (surveyId) {
          this.selectedSurveyId = surveyId;
        }
      },
    },
  },
  mounted() {
    this.fetchBotData();
    this.fetchSurveys();
  },

  methods: {
    fetchBotData() {
      this.$store.dispatch('agentBots/get');
      this.$store.dispatch('agentBots/fetchAgentBotInbox', this.currentInboxId);
    },
    async fetchSurveys() {
      try {
        await this.$store.dispatch('surveys/get');
      } catch (error) {
        useAlert(this.$t('AGENT_BOTS.BOT_CONFIGURATION.ERROR_MESSAGE'));
      }
    },
    async updateActiveAgentBot() {
      try {
        await this.$store.dispatch('agentBots/setAgentBotInbox', {
          inboxId: this.inbox.id,
          botId: this.selectedAgentBotId || undefined,
        });

        // Save FAQ categories selection if component is available
        if (this.$refs.faqCategorySelector?.saveSelection) {
          await this.$refs.faqCategorySelector.saveSelection();
        }

        useAlert(this.$t('AGENT_BOTS.BOT_CONFIGURATION.SUCCESS_MESSAGE'));
      } catch (error) {
        useAlert(this.$t('AGENT_BOTS.BOT_CONFIGURATION.ERROR_MESSAGE'));
      }
    },
    async updateSurveyAssignment() {
      try {
        await this.$store.dispatch('inboxes/setSurvey', {
          inboxId: this.inbox.id,
          surveyId: this.selectedSurveyId,
        });
        useAlert(this.$t('AGENT_BOTS.SURVEY.SUCCESS_MESSAGE'));
      } catch (error) {
        useAlert(this.$t('AGENT_BOTS.SURVEY.ERROR_MESSAGE'));
      }
    },
    async disconnectBot() {
      try {
        await this.$store.dispatch('agentBots/disconnectBot', {
          inboxId: this.inbox.id,
        });
        useAlert(
          this.$t('AGENT_BOTS.BOT_CONFIGURATION.DISCONNECTED_SUCCESS_MESSAGE')
        );
      } catch (error) {
        useAlert(
          error?.message ||
            this.$t('AGENT_BOTS.BOT_CONFIGURATION.DISCONNECTED_ERROR_MESSAGE')
        );
      }
    },
  },
};
</script>

<template>
  <div class="mx-6 max-w-4xl">
    <LoadingState
      v-if="
        uiFlags.isFetching ||
        uiFlags.isFetchingAgentBot ||
        isFetchingSurveys.isFetching
      "
    />
    <form v-else @submit.prevent="updateActiveAgentBot">
      <SettingsFieldSection
        :label="$t('AGENT_BOTS.BOT_CONFIGURATION.TITLE')"
        :help-text="$t('AGENT_BOTS.BOT_CONFIGURATION.DESC')"
        class="[&>div]:!items-start"
      >
        <SelectInput
          v-model="selectedAgentBotId"
          :placeholder="$t('AGENT_BOTS.BOT_CONFIGURATION.SELECT_PLACEHOLDER')"
          :options="agentBots.map(bot => ({ value: bot.id, label: bot.name }))"
        />
        <template #extra>
          <div class="grid grid-cols-1 lg:grid-cols-8 mt-3">
            <div class="col-span-1 lg:col-span-2 invisible" />
            <div class="col-span-1 lg:col-span-6 flex gap-2 mx-1">
              <NextButton
                type="submit"
                :label="$t('AGENT_BOTS.BOT_CONFIGURATION.SUBMIT')"
                :is-loading="uiFlags.isSettingAgentBot"
              />
              <NextButton
                type="button"
                :disabled="!selectedAgentBotId"
                :is-loading="uiFlags.isDisconnecting"
                faded
                ruby
                @click="disconnectBot"
              >
                {{ $t('AGENT_BOTS.BOT_CONFIGURATION.DISCONNECT') }}
              </NextButton>
            </div>
          </div>
        </template>
      </SettingsFieldSection>

      <SettingsFieldSection
        :label="$t('AGENT_BOTS.SURVEY.TITLE')"
        :help-text="$t('AGENT_BOTS.SURVEY.DESC')"
        class="mt-6 [&>div]:!items-start"
      >
        <SelectInput
          v-model="selectedSurveyId"
          :placeholder="$t('AGENT_BOTS.SURVEY.SELECT_PLACEHOLDER')"
          :options="[
            { value: null, label: $t('AGENT_BOTS.SURVEY.SELECT_PLACEHOLDER') },
            ...surveys.map(s => ({ value: s.id, label: s.name })),
          ]"
          @update:model-value="updateSurveyAssignment"
        />
      </SettingsFieldSection>

      <SettingsFieldSection
        :label="$t('INBOX_MGMT.FAQ_CONFIGURATION.TITLE')"
        :help-text="$t('INBOX_MGMT.FAQ_CONFIGURATION.DESC')"
        class="mt-6 [&>div]:!items-start"
      >
        <FaqCategorySelector ref="faqCategorySelector" :inbox-id="inbox.id" />
      </SettingsFieldSection>
    </form>
  </div>
</template>
