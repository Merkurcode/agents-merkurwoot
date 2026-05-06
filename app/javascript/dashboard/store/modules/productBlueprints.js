import types from '../mutation-types';
import ProductBlueprintsAPI from '../../api/productBlueprints';

export const state = {
  records: [],
  current: null,
  meta: {
    current_page: 1,
    total_pages: 1,
    total_count: 0,
    per_page: 50,
  },
  uiFlags: {
    isFetching: false,
    isFetchingItem: false,
    isUploading: false,
  },
};

export const getters = {
  getUIFlags: _state => _state.uiFlags,
  getProductBlueprints: _state => _state.records,
  getProductBlueprint: _state => _state.current,
  getMeta: _state => _state.meta,
};

export const actions = {
  get: async ({ commit }, { page = 1, per_page = 50, name, id } = {}) => {
    commit(types.SET_PRODUCT_BLUEPRINT_UI_FLAG, { isFetching: true });
    try {
      const response = await ProductBlueprintsAPI.get({
        page,
        per_page,
        name,
        id,
      });
      commit(types.SET_PRODUCT_BLUEPRINTS, response.data.data);
      commit(types.SET_PRODUCT_BLUEPRINT_META, response.data.meta);
      return response.data;
    } finally {
      commit(types.SET_PRODUCT_BLUEPRINT_UI_FLAG, { isFetching: false });
    }
  },

  show: async ({ commit }, blueprintId) => {
    commit(types.SET_PRODUCT_BLUEPRINT_UI_FLAG, { isFetchingItem: true });
    try {
      const response = await ProductBlueprintsAPI.show(blueprintId);
      commit(types.SET_PRODUCT_BLUEPRINT, response.data);
      return response.data;
    } finally {
      commit(types.SET_PRODUCT_BLUEPRINT_UI_FLAG, { isFetchingItem: false });
    }
  },

  showByName: async ({ commit }, name) => {
    commit(types.SET_PRODUCT_BLUEPRINT_UI_FLAG, { isFetchingItem: true });
    try {
      const response = await ProductBlueprintsAPI.getByName(name);
      commit(types.SET_PRODUCT_BLUEPRINT, response.data);
      return response.data;
    } finally {
      commit(types.SET_PRODUCT_BLUEPRINT_UI_FLAG, { isFetchingItem: false });
    }
  },

  yamlUpload: async ({ commit }, file) => {
    commit(types.SET_PRODUCT_BLUEPRINT_UI_FLAG, { isUploading: true });
    try {
      const response = await ProductBlueprintsAPI.yamlUpload(file);
      return response.data;
    } catch (error) {
      if (error.response?.status === 429) {
        const retryAfter = error.response?.data?.retry_after || 15;
        const rateLimitError = new Error(`RATE_LIMITED:${retryAfter}`);
        rateLimitError.isRateLimited = true;
        rateLimitError.retryAfter = retryAfter;
        throw rateLimitError;
      }
      const errorMessage =
        error.response?.data?.error || error.message || 'Upload failed';
      throw new Error(errorMessage);
    } finally {
      commit(types.SET_PRODUCT_BLUEPRINT_UI_FLAG, { isUploading: false });
    }
  },
};

export const mutations = {
  [types.SET_PRODUCT_BLUEPRINT_UI_FLAG](_state, data) {
    _state.uiFlags = { ..._state.uiFlags, ...data };
  },
  [types.SET_PRODUCT_BLUEPRINTS](_state, data) {
    _state.records = data;
  },
  [types.SET_PRODUCT_BLUEPRINT](_state, data) {
    _state.current = data;
  },
  [types.SET_PRODUCT_BLUEPRINT_META](_state, data) {
    _state.meta = { ..._state.meta, ...data };
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
