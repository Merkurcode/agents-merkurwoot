<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  modelValue: {
    type: Array,
    default: () => [],
  },
  products: {
    type: Array,
    default: () => [],
  },
  placeholder: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const search = ref('');
const open = ref(false);
const containerRef = ref(null);
const dropdownRef = ref(null);
const searchDebounceTimer = ref(null);
const debouncedSearch = ref('');

// Selected products based on modelValue
const selectedProducts = computed(() => {
  return props.products.filter(p => props.modelValue.includes(p.id));
});

// Filter products by search term (ID or name)
const filteredProducts = computed(() => {
  if (!debouncedSearch.value) {
    return props.products.slice(0, 50); // Limit initial display
  }
  const term = debouncedSearch.value.toLowerCase();
  return props.products.filter(p => {
    const productId = p.product_id?.toLowerCase() || '';
    const name = p.productName?.toLowerCase() || '';
    return productId.includes(term) || name.includes(term);
  }).slice(0, 50);
});

const isSelected = (id) => props.modelValue.includes(id);

const toggleProduct = (product) => {
  const currentIds = [...props.modelValue];
  const index = currentIds.indexOf(product.id);
  if (index > -1) {
    currentIds.splice(index, 1);
  } else {
    currentIds.push(product.id);
  }
  emit('update:modelValue', currentIds);
};

const removeProduct = (id) => {
  const currentIds = props.modelValue.filter(pid => pid !== id);
  emit('update:modelValue', currentIds);
};

// Debounce search
watch(search, (newVal) => {
  if (searchDebounceTimer.value) {
    clearTimeout(searchDebounceTimer.value);
  }
  searchDebounceTimer.value = setTimeout(() => {
    debouncedSearch.value = newVal;
  }, 300);
});

// Handle click outside
const handleClickOutside = (event) => {
  const isInsideContainer = containerRef.value?.contains(event.target);
  const isInsideDropdown = dropdownRef.value?.contains(event.target);
  if (!isInsideContainer && !isInsideDropdown) {
    open.value = false;
  }
};

// Handle blur (for TAB navigation)
const handleBlur = () => {
  setTimeout(() => {
    const activeElement = document.activeElement;
    const isInsideContainer = containerRef.value?.contains(activeElement);
    const isInsideDropdown = dropdownRef.value?.contains(activeElement);
    if (!isInsideContainer && !isInsideDropdown) {
      open.value = false;
    }
  }, 100);
};

onMounted(() => {
  document.addEventListener('mousedown', handleClickOutside);
});

onUnmounted(() => {
  document.removeEventListener('mousedown', handleClickOutside);
  if (searchDebounceTimer.value) {
    clearTimeout(searchDebounceTimer.value);
  }
});
</script>

<template>
  <div ref="containerRef" class="relative w-full">
    <!-- Selected product chips and search input -->
    <div
      class="flex flex-wrap gap-2 p-2 border border-n-weak rounded-lg min-h-[42px] bg-n-alpha-1 cursor-text focus-within:ring-2 focus-within:ring-n-blue-9 focus-within:border-n-blue-9"
      @click="open = true"
    >
      <!-- Selected chips -->
      <div
        v-for="product in selectedProducts"
        :key="product.id"
        class="flex items-center gap-1 px-2 py-0.5 rounded-md bg-n-blue-3 text-n-blue-11 text-sm"
      >
        <span class="font-mono text-xs bg-n-blue-4 px-1 rounded">{{ product.product_id }}</span>
        <span class="truncate max-w-32">{{ product.productName }}</span>
        <button
          type="button"
          class="hover:bg-n-blue-4 rounded p-0.5"
          @click.stop="removeProduct(product.id)"
        >
          <Icon icon="i-lucide-x" class="w-3 h-3" />
        </button>
      </div>

      <!-- Search input -->
      <input
        v-model="search"
        type="text"
        :placeholder="selectedProducts.length === 0 ? (placeholder || t('KNOWLEDGE_BASE.RESOURCES.PRODUCT_SEARCH.PLACEHOLDER')) : ''"
        class="flex-1 min-w-[120px] bg-transparent border-none outline-none text-sm text-n-slate-12 placeholder:text-n-slate-9"
        @focus="open = true"
        @blur="handleBlur"
      />
    </div>

    <!-- Dropdown with filtered products -->
    <Teleport to="body">
      <div
        v-if="open"
        ref="dropdownRef"
        class="fixed z-[9999] bg-n-solid-1 border border-n-weak rounded-lg shadow-lg max-h-64 overflow-auto"
        :style="{
          top: containerRef ? `${containerRef.getBoundingClientRect().bottom + 4}px` : '0',
          left: containerRef ? `${containerRef.getBoundingClientRect().left}px` : '0',
          width: containerRef ? `${containerRef.getBoundingClientRect().width}px` : 'auto',
        }"
      >
        <div v-if="filteredProducts.length === 0" class="p-4 text-center text-sm text-n-slate-11">
          {{ t('KNOWLEDGE_BASE.RESOURCES.PRODUCT_SEARCH.NO_RESULTS') }}
        </div>

        <button
          v-for="product in filteredProducts"
          :key="product.id"
          type="button"
          class="w-full flex items-center gap-3 px-3 py-2 text-left hover:bg-n-alpha-2 transition-colors"
          :class="{ 'bg-n-blue-2': isSelected(product.id) }"
          @click="toggleProduct(product)"
        >
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2">
              <span class="font-mono text-xs bg-n-slate-3 px-1.5 py-0.5 rounded text-n-slate-11">
                {{ product.product_id }}
              </span>
              <span class="text-sm font-medium text-n-slate-12 truncate">
                {{ product.productName }}
              </span>
            </div>
            <div class="text-xs text-n-slate-10 mt-0.5">
              {{ product.type }} <span v-if="product.industry">{{ product.industry }}</span>
            </div>
          </div>
          <Icon
            v-if="isSelected(product.id)"
            icon="i-lucide-check"
            class="w-4 h-4 text-n-blue-11 flex-shrink-0"
          />
        </button>
      </div>
    </Teleport>
  </div>
</template>
