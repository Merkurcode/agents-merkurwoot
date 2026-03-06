<script setup>
import { useI18n } from 'vue-i18n';

const props = defineProps({
  form: { type: Object, required: true },
});

const { t } = useI18n();

const questions = () => props.form.agent_behavior_config.qualification_questions;

const addQuestion = () => {
  questions().push('');
};

const removeQuestion = index => {
  questions().splice(index, 1);
};
</script>

<template>
  <div class="flex flex-col gap-8">
    <!-- Qualification questions -->
    <div class="flex flex-col gap-3">
      <div class="flex flex-col gap-1">
        <h3 class="text-sm font-semibold text-n-slate-12">
          {{ $t('AGENT_BOTS.CONFIG.CONTENT.QUESTIONS_TITLE') }}
        </h3>
        <p class="text-xs text-n-slate-11">{{ $t('AGENT_BOTS.CONFIG.CONTENT.QUESTIONS_HINT') }}</p>
      </div>

      <div class="flex flex-col gap-2 border border-n-weak rounded-xl p-4">
        <div
          v-for="(question, idx) in form.agent_behavior_config.qualification_questions"
          :key="idx"
          class="flex items-center gap-2"
        >
          <span class="text-xs text-n-slate-10 w-5 shrink-0 text-right">{{ idx + 1 }}.</span>
          <input
            type="text"
            :value="question"
            class="flex-1 px-3 py-2 text-sm rounded-lg border border-n-weak bg-n-background text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
            :placeholder="$t('AGENT_BOTS.CONFIG.CONTENT.QUESTION_PLACEHOLDER')"
            @input="e => (form.agent_behavior_config.qualification_questions[idx] = e.target.value)"
          />
          <button
            type="button"
            class="text-n-slate-9 hover:text-ruby-800 shrink-0"
            @click="removeQuestion(idx)"
          >
            <span class="i-lucide-trash-2 w-4 h-4" />
          </button>
        </div>

        <button
          type="button"
          class="text-sm text-n-brand hover:underline text-left mt-1"
          @click="addQuestion"
        >
          {{ $t('AGENT_BOTS.CONFIG.CONTENT.QUESTIONS_ADD') }}
        </button>
      </div>
    </div>

    <div class="border-t border-n-weak" />

    <!-- Additional instructions -->
    <div class="flex flex-col gap-3">
      <div class="flex flex-col gap-1">
        <h3 class="text-sm font-semibold text-n-slate-12">
          {{ $t('AGENT_BOTS.CONFIG.CONTENT.INSTRUCTIONS_TITLE') }}
        </h3>
        <p class="text-xs text-n-slate-11">{{ $t('AGENT_BOTS.CONFIG.CONTENT.INSTRUCTIONS_HINT') }}</p>
      </div>

      <textarea
        v-model="form.agent_behavior_config.additional_instructions"
        rows="6"
        class="w-full px-3 py-2 text-sm rounded-lg border border-n-weak bg-n-background text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand resize-none"
        :placeholder="$t('AGENT_BOTS.CONFIG.CONTENT.INSTRUCTIONS_PLACEHOLDER')"
      />
    </div>
  </div>
</template>
