/* global axios */
import ApiClient from '../ApiClient';

class CaptainAssistantFilters extends ApiClient {
  constructor() {
    super('captain/assistant_filters', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  create(params = {}) {
    return axios.post(this.url, { assistant_filter: params });
  }

  update(id, params = {}) {
    return axios.patch(`${this.url}/${id}`, { assistant_filter: params });
  }

  delete(id) {
    return axios.delete(`${this.url}/${id}`);
  }
}

export default new CaptainAssistantFilters();
