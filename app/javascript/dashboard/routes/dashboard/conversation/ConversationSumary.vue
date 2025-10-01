<script setup>
import MarkdownIt from 'markdown-it';
import { computed } from 'vue';

const props = defineProps({
  rawSumary: {
    type: String,
    default: null,
  },
});

const sumary = computed(() => {
  const md = new MarkdownIt();

  return md.render(props.rawSumary);
});
</script>

<template>
  <div v-html="sumary" />
</template>
