/* global axios */
import ApiClient from './ApiClient';

class FaqCategoriesAPI extends ApiClient {
  constructor() {
    super('faq_categories', { accountScoped: true });
  }

  getTree() {
    return axios.get(`${this.url}/tree`);
  }

  toggleVisibility(id) {
    return axios.post(`${this.url}/${id}/toggle_visibility`);
  }

  move(id, { parentId, position }) {
    return axios.post(`${this.url}/${id}/move`, {
      parent_id: parentId,
      position,
    });
  }
}

export default new FaqCategoriesAPI();
