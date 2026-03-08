import CaptainAssistantFilterRunsAPI from 'dashboard/api/captain/assistantFilterRuns';
import { throwErrorMessage } from 'dashboard/store/utils/api';

const state = {
  records: [],
  currentRun: null,
  meta: {},
  uiFlags: {
    fetchingList: false,
    fetchingItem: false,
    creatingItem: false,
  },
};

export const getters = {
  getRecords: $state => $state.records,
  getCurrentRun: $state => $state.currentRun,
  getMeta: $state => $state.meta,
  getUIFlags: $state => $state.uiFlags,
};

export const actions = {
  get: async ({ commit }, params = {}) => {
    commit('SET_UI_FLAG', { fetchingList: true });
    try {
      const response = await CaptainAssistantFilterRunsAPI.get(params);
      commit('SET_RECORDS', response.data.payload);
      commit('SET_META', response.data.meta);
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit('SET_UI_FLAG', { fetchingList: false });
    }
  },

  show: async ({ commit }, { id, page = 1 }) => {
    commit('SET_UI_FLAG', { fetchingItem: true });
    try {
      const response = await CaptainAssistantFilterRunsAPI.show(id, { page });
      commit('SET_CURRENT_RUN', response.data);
    } catch (error) {
      throwErrorMessage(error);
    } finally {
      commit('SET_UI_FLAG', { fetchingItem: false });
    }
  },

  create: async ({ commit }, params) => {
    commit('SET_UI_FLAG', { creatingItem: true });
    try {
      const response = await CaptainAssistantFilterRunsAPI.create(params);
      commit('ADD_RECORD', response.data);
      return response.data;
    } catch (error) {
      return throwErrorMessage(error);
    } finally {
      commit('SET_UI_FLAG', { creatingItem: false });
    }
  },
};

export const mutations = {
  SET_UI_FLAG($state, data) {
    $state.uiFlags = { ...$state.uiFlags, ...data };
  },
  SET_RECORDS($state, records) {
    $state.records = records;
  },
  ADD_RECORD($state, record) {
    $state.records.unshift(record);
  },
  SET_CURRENT_RUN($state, run) {
    $state.currentRun = run;
  },
  SET_META($state, meta) {
    $state.meta = {
      totalCount: Number(meta.total_count || 0),
      page: Number(meta.page || 1),
    };
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
